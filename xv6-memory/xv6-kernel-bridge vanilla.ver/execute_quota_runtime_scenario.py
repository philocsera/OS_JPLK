#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys
from pathlib import Path

import pexpect

import bridge
from collect_swap_scenario import Tee
from collect_swap_scenario import extract_memstat_lines
from collect_swap_scenario import stop_qemu


def write_jsonl(path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def load_snapshots(lines):
    return [json.loads(line) for line in lines]


def compute_final_score(lines):
    state = {}
    score = None

    for snapshot in load_snapshots(lines):
        bridge.analyze_snapshot(snapshot, state)
        score = bridge.compute_score(snapshot, state)

    if score is None:
        raise RuntimeError("score could not be calculated")

    return score


def find_quota(lines, target_pid):
    snapshots = load_snapshots(lines)
    processes = snapshots[-1].get("processes", [])

    for proc in processes:
        if int(proc.get("pid", -1)) == target_pid:
            return int(proc.get("quota", -1))

    raise RuntimeError(f"target pid disappeared: {target_pid}")


def apply_quota(child, target_pid, quota, timeout):
    command = f"setquota {target_pid} {quota}"
    print(f"[runtime] xv6 command: {command}")
    child.sendline(command)

    index = child.expect(
        [
            rf"setquota ok pid={target_pid} quota={quota}",
            rf"setquota failed pid={target_pid} quota={quota}",
        ],
        timeout=timeout,
    )

    child.expect_exact("$ ", timeout=timeout)
    return index == 0


def collect_snapshot(child, ticks, interval, path, timeout):
    command = f"memwatch json {ticks} {interval}"
    print(f"[runtime] xv6 command: {command}")
    child.sendline(command)
    child.expect_exact("$ ", timeout=timeout)

    lines = extract_memstat_lines(child.before)

    if not lines:
        raise RuntimeError("memwatch JSON was not captured")

    write_jsonl(path, lines)
    return lines


def run_verifier(log_path, transcript_path, out_path):
    command = [
        sys.executable,
        "hard_verifier.py",
        "--log",
        str(log_path),
        "--transcript",
        str(transcript_path),
        "--fail-on-quota-denied",
        "--out",
        str(out_path),
    ]

    print("[runtime] $ " + " ".join(command))

    result = subprocess.run(
        command,
        text=True,
        capture_output=True,
        check=False,
    )

    if result.stdout:
        print(result.stdout, end="")

    if result.stderr:
        print(result.stderr, end="")

    return result.returncode == 0


def main():
    parser = argparse.ArgumentParser(
        description="Apply and rollback quota on the same live xv6 process."
    )

    parser.add_argument("--pages", type=int, default=32)
    parser.add_argument("--delay", type=int, default=1000)
    parser.add_argument("--ticks", type=int, default=5)
    parser.add_argument("--interval", type=int, default=2)
    parser.add_argument("--timeout", type=int, default=240)

    parser.add_argument(
        "--before-quota",
        type=int,
        default=262144,
    )

    parser.add_argument(
        "--candidate-quota",
        type=int,
        default=4194304,
    )

    parser.add_argument(
        "--min-improvement",
        type=float,
        default=0.0,
    )

    parser.add_argument(
        "--out-dir",
        default="logs/quota_runtime",
    )

    args = parser.parse_args()

    if args.pages <= 0:
        raise SystemExit("[runtime] ERROR: pages must be positive")

    if args.before_quota <= 0 or args.candidate_quota <= 0:
        raise SystemExit("[runtime] ERROR: quotas must be positive")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    baseline_log = out_dir / "baseline.jsonl"
    candidate_log = out_dir / "candidate.jsonl"
    rollback_log = out_dir / "rollback.jsonl"
    transcript_path = out_dir / "qemu.log"
    baseline_verifier = out_dir / "baseline_hard_verifier.json"
    candidate_verifier = out_dir / "candidate_hard_verifier.json"
    summary_path = out_dir / "summary.json"

    print("[runtime] starting QEMU")

    child = pexpect.spawn(
        "make",
        ["qemu", "CPUS=1"],
        encoding="utf-8",
        timeout=args.timeout,
    )

    transcript_file = transcript_path.open("w", encoding="utf-8")
    child.logfile = Tee(sys.stdout, transcript_file)

    summary = {}

    try:
        child.expect_exact("$ ")

        memhold_command = f"memhold {args.pages} {args.delay} &"
        print(f"[runtime] xv6 command: {memhold_command}")
        child.sendline(memhold_command)

        child.expect(
            r"memhold ready pid=(\d+) pages=\d+ delay=\d+",
            timeout=args.timeout,
        )

        target_pid = int(child.match.group(1))
        print(f"[runtime] detected target pid: {target_pid}")

        if not apply_quota(
            child,
            target_pid,
            args.before_quota,
            args.timeout,
        ):
            raise RuntimeError("baseline quota application failed")

        baseline_lines = collect_snapshot(
            child,
            args.ticks,
            args.interval,
            baseline_log,
            args.timeout,
        )

        baseline_score = compute_final_score(baseline_lines)

        baseline_passed = run_verifier(
            baseline_log,
            transcript_path,
            baseline_verifier,
        )

        if not baseline_passed:
            raise RuntimeError("baseline policy failed hard verifier")

        if not apply_quota(
            child,
            target_pid,
            args.candidate_quota,
            args.timeout,
        ):
            raise RuntimeError("candidate quota application failed")

        candidate_lines = collect_snapshot(
            child,
            args.ticks,
            args.interval,
            candidate_log,
            args.timeout,
        )

        candidate_score = compute_final_score(candidate_lines)

        candidate_passed = run_verifier(
            candidate_log,
            transcript_path,
            candidate_verifier,
        )

        before_value = float(baseline_score["score"])
        candidate_value = float(candidate_score["score"])

        if (
            candidate_passed
            and candidate_value > before_value + args.min_improvement
        ):
            decision = "ACCEPT"
            reason = (
                "candidate passed hard verifier and improved score: "
                f"before={before_value}, candidate={candidate_value}"
            )
            final_quota = find_quota(candidate_lines, target_pid)

        else:
            decision = "ROLLBACK_APPLIED"

            if candidate_passed:
                reason = (
                    "candidate score did not improve: "
                    f"before={before_value}, candidate={candidate_value}"
                )
            else:
                reason = "candidate failed hard verifier"

            if not apply_quota(
                child,
                target_pid,
                args.before_quota,
                args.timeout,
            ):
                raise RuntimeError("runtime rollback command failed")

            rollback_lines = collect_snapshot(
                child,
                1,
                0,
                rollback_log,
                args.timeout,
            )

            final_quota = find_quota(rollback_lines, target_pid)

            if final_quota != args.before_quota:
                raise RuntimeError(
                    "rollback verification failed: "
                    f"expected={args.before_quota}, actual={final_quota}"
                )

        summary = {
            "decision": decision,
            "reason": reason,
            "target_pid": target_pid,
            "before_quota": args.before_quota,
            "candidate_quota": args.candidate_quota,
            "final_quota": final_quota,
            "baseline_score": baseline_score,
            "candidate_score": candidate_score,
            "candidate_hard_verifier_passed": candidate_passed,
        }

    except Exception as error:
        print(f"[runtime] ERROR: {error}")
        raise SystemExit(1)

    finally:
        stop_qemu(child)
        transcript_file.close()

    summary_path.write_text(
        json.dumps(summary, indent=2) + "\n",
        encoding="utf-8",
    )

    print()
    print(f"[runtime] baseline score: {summary['baseline_score']['score']}")
    print(f"[runtime] candidate score: {summary['candidate_score']['score']}")
    print(f"[runtime] decision: {summary['decision']}")
    print(f"[runtime] reason: {summary['reason']}")
    print(f"[runtime] final quota: {summary['final_quota']}")
    print(f"[runtime] summary: {summary_path}")


if __name__ == "__main__":
    main()
