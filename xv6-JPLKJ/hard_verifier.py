#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

# lv2 적응: memory 전용 커널은 sh=pid2였지만, process 트리와 병합된 lv2에선 부팅 시
# pid 슬롯 사용이 달라 sh=pid3가 된다. pid 하드코딩 대신 이름으로 보호 판정한다
# (bridge.py의 PROTECTED_NAMES와 동일 의미, pid 배치 변화에 견고).
PROTECTED_NAMES = {"init", "sh"}

COUNT_FIELDS = {
    "quota_denied_count",
    "swapout_count",
    "swapin_count",
}

BAD_TRANSCRIPT_PATTERNS = {
    "panic:",
    "kerneltrap",
    "usertrap(): unexpected",
    "memhold: pattern mismatch",
    "memfill: pattern mismatch",
}

QUOTA_DENIED_PATTERN = "[quota denied]"


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


def verify(
    snapshots,
    require_swap_activity,
    require_swapout_activity=False,
    require_swapin_activity=False,
    target_pid=None,
):
    errors = []
    saw_swapout = False
    saw_swapin = False

    require_swapout = (
        require_swap_activity or require_swapout_activity
    )

    require_swapin = (
        require_swap_activity or require_swapin_activity
    )

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

        for expected_name in PROTECTED_NAMES:
            if not any(
                proc.get("name") == expected_name
                for proc in processes
            ):
                errors.append(
                    f"tick={tick}: protected {expected_name} missing"
                )

        if not any(
            proc.get("name") == "memwatch"
            for proc in processes
        ):
            errors.append(f"tick={tick}: memwatch missing")

    if require_swapout and not saw_swapout:
        errors.append("swapout was not observed")

    if require_swapin and not saw_swapin:
        errors.append("swapin was not observed")

    target_process_alive = True

    if target_pid is not None:
        target_process_alive = False

        if snapshots:
            final_processes = snapshots[-1].get("processes", [])
            target_process_alive = any(
                int(proc.get("pid", -1)) == target_pid
                for proc in final_processes
            )

        if not target_process_alive:
            errors.append(f"final snapshot: target pid={target_pid} missing")

    checks = {
        "snapshot_count": len(snapshots),
        "protected_processes_alive": not any(
            "protected " in error
            for error in errors
        ),
        "memwatch_available": not any(
            "memwatch missing" in error
            for error in errors
        ),
        "target_process_alive": target_process_alive,
        "swapout_observed": saw_swapout,
        "swapin_observed": saw_swapin,
    }

    return checks, errors


def verify_transcript(path, fail_on_quota_denied=False):
    if not path:
        return {
            "checked": False,
            "fatal_patterns": [],
        "quota_denied": False,
        }, []

    text = Path(path).read_text(
        encoding="utf-8",
        errors="replace",
    )

    hits = [
        pattern
        for pattern in BAD_TRANSCRIPT_PATTERNS
        if pattern in text
    ]

    errors = [
        f"transcript contains fatal pattern: {pattern}"
        for pattern in hits
    ]

    quota_denied = QUOTA_DENIED_PATTERN in text
    if fail_on_quota_denied and quota_denied:
        errors.append(
            f"transcript contains quota denial: {QUOTA_DENIED_PATTERN}"
        )

    return {
        "checked": True,
        "fatal_patterns": hits,
        "quota_denied": quota_denied,
    }, errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True)
    parser.add_argument(
        "--require-swap-activity",
        action="store_true",
        help="legacy mode: require both swapout and swapin",
    )
    parser.add_argument(
        "--require-swapout-activity",
        action="store_true",
        help="require at least one observed swapout",
    )
    parser.add_argument(
        "--require-swapin-activity",
        action="store_true",
        help="require at least one observed swapin",
    )
    parser.add_argument("--transcript")
    parser.add_argument(
        "--target-pid",
        type=int,
        help="optionally require the target process to exist in the final snapshot",
    )
    parser.add_argument(
        "--fail-on-quota-denied",
        action="store_true",
        help="treat a quota denial in the transcript as policy verification failure",
    )
    parser.add_argument(
        "--out",
        default="logs/hard_verifier_result.json",
    )
    args = parser.parse_args()

    snapshots, parse_errors = load_snapshots(args.log)

    checks, verify_errors = verify(
        snapshots,
        args.require_swap_activity,
        args.require_swapout_activity,
        args.require_swapin_activity,
        args.target_pid,
    )

    transcript_checks, transcript_errors = verify_transcript(
        args.transcript,
        args.fail_on_quota_denied,
    )

    errors = parse_errors + verify_errors + transcript_errors

    result = {
        "hard_verifier_passed": not errors,
        "checks": {
            **checks,
            "transcript": transcript_checks,
        },
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

    if (
        args.require_swap_activity
        or args.require_swapout_activity
    ):
        print("[hard-verifier] swapout: observed")

    if (
        args.require_swap_activity
        or args.require_swapin_activity
    ):
        print("[hard-verifier] swapin: observed")

    print(f"[hard-verifier] result saved: {out_path}")


if __name__ == "__main__":
    main()
