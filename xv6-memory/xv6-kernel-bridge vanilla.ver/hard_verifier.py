#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

PROTECTED = {
    1: "init",
    2: "sh",
}

COUNT_FIELDS = {
    "quota_denied_count",
    "swapout_count",
    "swapin_count",
}


def load_snapshots(path):
    snapshots = []
    errors = []

    for line_no, raw in enumerate(
        Path(path).read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        raw = raw.strip()

        if not raw:
            continue

        try:
            snapshot = json.loads(raw)
        except json.JSONDecodeError:
            errors.append(f"line={line_no}: invalid JSON")
            continue

        if snapshot.get("type") != "memstat":
            errors.append(f"line={line_no}: type must be memstat")
            continue

        if not isinstance(snapshot.get("processes"), list):
            errors.append(f"line={line_no}: processes must be a list")
            continue

        snapshots.append(snapshot)

    if not snapshots:
        errors.append("no valid snapshot found")

    return snapshots, errors


def verify(snapshots, require_swap_activity):
    errors = []
    saw_swapout = False
    saw_swapin = False

    for snapshot in snapshots:
        tick = snapshot.get("tick", "?")
        swap = snapshot.get("swap", {})

        used_slots = int(swap.get("used_slots", -1))
        total_slots = int(swap.get("total_slots", -1))

        if total_slots <= 0:
            errors.append(f"tick={tick}: total_slots must be positive")

        if used_slots < 0:
            errors.append(f"tick={tick}: used_slots must not be negative")

        if total_slots > 0 and used_slots > total_slots:
            errors.append(f"tick={tick}: used_slots exceeds total_slots")

        processes = snapshot.get("processes", [])
        by_pid = {}

        for proc in processes:
            pid = int(proc.get("pid", -1))
            by_pid[pid] = proc

            for field in COUNT_FIELDS:
                value = int(proc.get(field, 0))

                if value < 0:
                    errors.append(
                        f"tick={tick} pid={pid}: {field} is negative"
                    )

            if int(proc.get("swapout_count", 0)) > 0:
                saw_swapout = True

            if int(proc.get("swapin_count", 0)) > 0:
                saw_swapin = True

        for pid, expected_name in PROTECTED.items():
            proc = by_pid.get(pid)

            if proc is None:
                errors.append(f"tick={tick}: protected pid={pid} missing")
                continue

            if proc.get("name") != expected_name:
                errors.append(
                    f"tick={tick}: pid={pid} expected name={expected_name}"
                )

        if not any(
            proc.get("name") == "memwatch"
            for proc in processes
        ):
            errors.append(f"tick={tick}: memwatch missing")

    if require_swap_activity and not saw_swapout:
        errors.append("swapout was not observed")

    if require_swap_activity and not saw_swapin:
        errors.append("swapin was not observed")

    checks = {
        "snapshot_count": len(snapshots),
        "protected_processes_alive": not any(
            "protected pid" in error
            for error in errors
        ),
        "memwatch_available": not any(
            "memwatch missing" in error
            for error in errors
        ),
        "swapout_observed": saw_swapout,
        "swapin_observed": saw_swapin,
    }

    return checks, errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True)
    parser.add_argument("--require-swap-activity", action="store_true")
    parser.add_argument(
        "--out",
        default="logs/hard_verifier_result.json",
    )
    args = parser.parse_args()

    snapshots, parse_errors = load_snapshots(args.log)

    checks, verify_errors = verify(
        snapshots,
        args.require_swap_activity,
    )

    errors = parse_errors + verify_errors

    result = {
        "hard_verifier_passed": not errors,
        "checks": checks,
        "errors": errors,
    }

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    out_path.write_text(
        json.dumps(result, indent=2) + "\n",
        encoding="utf-8",
    )

    if errors:
        print("[hard-verifier] FAIL")

        for error in errors:
            print(f"- {error}")

        print(f"[hard-verifier] result saved: {out_path}")
        raise SystemExit(1)

    print("[hard-verifier] PASS")
    print(f"[hard-verifier] snapshots: {len(snapshots)}")
    print("[hard-verifier] protected processes: alive")
    print("[hard-verifier] memwatch: available")

    if args.require_swap_activity:
        print("[hard-verifier] swapout: observed")
        print("[hard-verifier] swapin: observed")

    print(f"[hard-verifier] result saved: {out_path}")


if __name__ == "__main__":
    main()
