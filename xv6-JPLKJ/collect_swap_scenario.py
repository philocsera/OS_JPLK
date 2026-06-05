#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

import pexpect


class Tee:
    def __init__(self, *streams):
        self.streams = streams

    def write(self, data):
        for stream in self.streams:
            stream.write(data)
            stream.flush()

    def flush(self):
        for stream in self.streams:
            stream.flush()


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

        lines.append(json.dumps(snapshot, separators=(",", ":")))

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
    parser.add_argument("--pages", type=int, default=8)
    parser.add_argument("--swapout-pages", type=int, default=4)
    parser.add_argument("--delay", type=int, default=1000)
    parser.add_argument("--ticks", type=int, default=20)
    parser.add_argument("--interval", type=int, default=100)
    parser.add_argument(
        "--out",
        default="logs/memwatch_swap_actual.jsonl",
    )
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument(
        "--transcript",
        default="logs/qemu_swap_actual.log",
    )
    args = parser.parse_args()

    if args.pages <= 0:
        raise SystemExit("[scenario] ERROR: pages must be positive")

    if args.swapout_pages <= 0:
        raise SystemExit("[scenario] ERROR: swapout-pages must be positive")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    transcript_path = Path(args.transcript)
    transcript_path.parent.mkdir(parents=True, exist_ok=True)

    print("[scenario] starting QEMU")

    child = pexpect.spawn(
        "make",
        ["qemu", "CPUS=1"],
        encoding="utf-8",
        timeout=args.timeout,
    )

    transcript_file = transcript_path.open(
        "w",
        encoding="utf-8",
    )

    child.logfile = Tee(sys.stdout, transcript_file)

    try:
        child.expect_exact("$ ")

        memhold_command = f"memhold {args.pages} {args.delay} &"
        print(f"[scenario] xv6 command: {memhold_command}")
        child.sendline(memhold_command)

        child.expect(
            r"memhold ready pid=(\d+) pages=\d+ delay=\d+"
        )

        target_pid = int(child.match.group(1))
        print(f"[scenario] detected memhold pid: {target_pid}")

        swapctl_command = (
            f"swapctl {target_pid} {args.swapout_pages}"
        )

        print(f"[scenario] xv6 command: {swapctl_command}")
        child.sendline(swapctl_command)

        child.expect(
            rf"swapctl pid={target_pid} "
            rf"requested={args.swapout_pages} "
            rf"success=(\d+)"
        )

        success = int(child.match.group(1))

        if success <= 0:
            raise RuntimeError("swapctl did not swap out any page")

        child.expect_exact("$ ")

        memwatch_command = (
            f"memwatch json {args.ticks} {args.interval}"
        )

        print(f"[scenario] xv6 command: {memwatch_command}")
        child.sendline(memwatch_command)

        child.expect_exact("$ ", timeout=args.timeout)
        captured = child.before

    except Exception as error:
        print(f"[scenario] ERROR: {error}")
        stop_qemu(child)
        raise SystemExit(1)

    stop_qemu(child)
    transcript_file.close()

    lines = extract_memstat_lines(captured)

    if not lines:
        raise SystemExit("[scenario] ERROR: no memstat JSON captured")

    out_path.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )

    print(f"[scenario] saved snapshots: {len(lines)}")
    print(f"[scenario] output: {out_path}")
    print(f"[scenario] transcript: {transcript_path}")


if __name__ == "__main__":
    main()
