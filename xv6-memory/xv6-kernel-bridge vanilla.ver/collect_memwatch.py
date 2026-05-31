#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

import pexpect


def extract_memstat_lines(text):
    lines = []

    for raw in text.splitlines():
        start = raw.find('{"type":"memstat"')

        if start == -1:
            continue

        candidate = raw[start:].strip()

        try:
            snapshot = json.loads(candidate)
        except json.JSONDecodeError:
            continue

        lines.append(
            json.dumps(snapshot, separators=(",", ":"))
        )

    return lines


def stop_qemu(child):
    if not child.isalive():
        return

    try:
        child.sendcontrol("a")
        child.send("x")
        child.expect(pexpect.EOF, timeout=5)
    except Exception:
        child.close(force=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ticks", type=int, default=5)
    parser.add_argument("--interval", type=int, default=100)
    parser.add_argument(
        "--out",
        default="logs/memwatch_actual.jsonl",
    )
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()

    if args.ticks <= 0:
        raise SystemExit("[collector] ERROR: ticks must be positive")

    if args.interval < 0:
        raise SystemExit("[collector] ERROR: interval must be non-negative")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    print("[collector] starting QEMU")

    child = pexpect.spawn(
        "make",
        ["qemu", "CPUS=1"],
        encoding="utf-8",
        timeout=args.timeout,
    )

    child.logfile = sys.stdout

    try:
        child.expect_exact("$ ")

        command = f"memwatch json {args.ticks} {args.interval}"
        print(f"[collector] xv6 command: {command}")

        child.sendline(command)
        child.expect_exact("$ ", timeout=args.timeout)

        captured = child.before
    except Exception as error:
        print(f"[collector] ERROR: {error}")
        stop_qemu(child)
        raise SystemExit(1)

    stop_qemu(child)

    lines = extract_memstat_lines(captured)

    if not lines:
        print("[collector] ERROR: no memstat JSON captured")
        raise SystemExit(1)

    out_path.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )

    print(f"[collector] saved snapshots: {len(lines)}")
    print(f"[collector] output: {out_path}")


if __name__ == "__main__":
    main()
