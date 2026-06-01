#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys
from pathlib import Path

import bridge


def run_command(command, allow_failure=False):
    print("[quota-runner] $ " + " ".join(str(item) for item in command))
    result = subprocess.run(command)

    if result.returncode != 0 and not allow_failure:
        raise RuntimeError(
            f"command failed with exit code {result.returncode}: "
            + " ".join(str(item) for item in command)
        )

    return result.returncode


def collect_workload(label, quota, args, out_dir):
    log_path = out_dir / f"{label}.jsonl"
    transcript_path = out_dir / f"{label}_qemu.log"

    command = [
        sys.executable,
        "collect_memstress.py",
        "--quota",
        str(quota),
        "--step",
        str(args.step),
        "--procs",
        str(args.procs),
        "--ticks",
        str(args.ticks),
        "--interval",
        str(args.interval),
        "--out",
        str(log_path),
        "--transcript",
        str(transcript_path),
        "--timeout",
        str(args.timeout),
    ]

    run_command(command)

    return log_path, transcript_path


def run_hard_verifier(label, log_path, transcript_path, out_dir):
    verifier_result_path = out_dir / f"{label}_hard_verifier.json"

    command = [
        sys.executable,
        "hard_verifier.py",
        "--log",
        str(log_path),
        "--transcript",
        str(transcript_path),
        "--fail-on-quota-denied",
        "--out",
        str(verifier_result_path),
    ]

    run_command(command, allow_failure=True)

    if not verifier_result_path.exists():
        raise RuntimeError(
            f"hard verifier result was not created: {verifier_result_path}"
        )

    result = json.loads(
        verifier_result_path.read_text(encoding="utf-8")
    )

    return result, verifier_result_path


def load_snapshots(log_path):
    snapshots = []

    for line_number, raw in enumerate(
        log_path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        raw = raw.strip()

        if not raw:
            continue

        try:
            snapshot = json.loads(raw)
        except json.JSONDecodeError as error:
            raise RuntimeError(
                f"{log_path}: line {line_number}: invalid JSON: {error}"
            ) from error

        if snapshot.get("type") == "memstat":
            snapshots.append(snapshot)

    if not snapshots:
        raise RuntimeError(f"no memstat snapshot found: {log_path}")

    return snapshots


def compute_final_score(log_path):
    snapshots = load_snapshots(log_path)
    state = {}
    score_history = []

    for snapshot in snapshots:
        bridge.analyze_snapshot(snapshot, state)
        score = bridge.compute_score(snapshot, state)
        score_history.append(
            {
                "tick": snapshot.get("tick"),
                **score,
            }
        )

    return score_history[-1], score_history


def format_errors(verifier_result):
    errors = verifier_result.get("errors", [])

    if not errors:
        return "none"

    return "; ".join(str(error) for error in errors)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Compare a baseline quota and a candidate quota using "
            "the same memstress workload."
        )
    )

    parser.add_argument(
        "--before-quota",
        type=int,
        required=True,
        help="baseline quota in bytes",
    )

    parser.add_argument(
        "--candidate-quota",
        type=int,
        required=True,
        help="candidate quota in bytes",
    )

    parser.add_argument("--step", type=int, default=4096)
    parser.add_argument("--procs", type=int, default=1)
    parser.add_argument("--ticks", type=int, default=30)
    parser.add_argument("--interval", type=int, default=2)
    parser.add_argument("--timeout", type=int, default=240)

    parser.add_argument(
        "--allow-invalid-baseline",
        action="store_true",
        help="continue candidate verification when baseline policy is already invalid",
    )

    parser.add_argument(
        "--min-improvement",
        type=float,
        default=0.0,
        help="minimum score improvement required for ACCEPT",
    )

    parser.add_argument(
        "--out-dir",
        default="logs/quota_policy_runner",
    )

    args = parser.parse_args()

    if args.before_quota <= 0:
        raise SystemExit("[quota-runner] ERROR: before quota must be positive")

    if args.candidate_quota <= 0:
        raise SystemExit(
            "[quota-runner] ERROR: candidate quota must be positive"
        )

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print()
    print("[quota-runner] collect baseline workload")
    before_log, before_transcript = collect_workload(
        "before",
        args.before_quota,
        args,
        out_dir,
    )

    before_score, before_history = compute_final_score(before_log)

    before_verifier, before_verifier_path = run_hard_verifier(
        "before",
        before_log,
        before_transcript,
        out_dir,
    )

    baseline_passed = before_verifier.get(
        "hard_verifier_passed",
        False,
    )

    if not baseline_passed and not args.allow_invalid_baseline:
        decision = "ABORT_BASELINE_INVALID"
        reason = (
            "baseline policy failed hard verifier: "
            + format_errors(before_verifier)
        )

        summary = {
            "decision": decision,
            "reason": reason,
            "before_quota": args.before_quota,
            "candidate_quota": args.candidate_quota,
            "before_score": before_score,
            "before_verifier": before_verifier,
            "before_verifier_result": str(before_verifier_path),
        }

        summary_path = out_dir / "summary.json"
        summary_path.write_text(
            json.dumps(summary, indent=2) + "\n",
            encoding="utf-8",
        )

        print()
        print(f"[quota-runner] decision: {decision}")
        print(f"[quota-runner] reason: {reason}")
        print(f"[quota-runner] summary: {summary_path}")

        raise SystemExit(1)

    if not baseline_passed:
        print()
        print("[quota-runner] baseline hard verifier: FAIL")
        print("[quota-runner] recovery mode: candidate verification continues")

    print()
    print("[quota-runner] collect candidate workload")
    candidate_log, candidate_transcript = collect_workload(
        "candidate",
        args.candidate_quota,
        args,
        out_dir,
    )

    candidate_score, candidate_history = compute_final_score(candidate_log)

    candidate_verifier, candidate_verifier_path = run_hard_verifier(
        "candidate",
        candidate_log,
        candidate_transcript,
        out_dir,
    )

    before_value = float(before_score["score"])
    candidate_value = float(candidate_score["score"])

    candidate_passed = candidate_verifier.get(
        "hard_verifier_passed",
        False,
    )

    if not candidate_passed:
        if baseline_passed:
            decision = "ROLLBACK"
            reason = (
                "candidate policy failed hard verifier: "
                + format_errors(candidate_verifier)
            )
        else:
            decision = "REJECT_RECOVERY_CANDIDATE"
            reason = (
                "candidate policy also failed hard verifier: "
                + format_errors(candidate_verifier)
            )

    elif not baseline_passed:
        decision = "ACCEPT_RECOVERY"
        reason = (
            "candidate recovered from an invalid baseline and "
            f"passed hard verifier: candidate={candidate_value}"
        )

    elif candidate_value <= before_value + args.min_improvement:
        decision = "ROLLBACK"
        reason = (
            "candidate score did not improve enough: "
            f"before={before_value}, candidate={candidate_value}, "
            f"required_improvement>{args.min_improvement}"
        )

    else:
        decision = "ACCEPT"
        reason = (
            "candidate passed hard verifier and improved score: "
            f"before={before_value}, candidate={candidate_value}"
        )

    summary = {
        "decision": decision,
        "reason": reason,
        "before_quota": args.before_quota,
        "candidate_quota": args.candidate_quota,
        "rollback_quota": (
            args.before_quota if decision == "ROLLBACK" else None
        ),
        "before_score": before_score,
        "candidate_score": candidate_score,
        "before_verifier": before_verifier,
        "candidate_verifier": candidate_verifier,
        "artifacts": {
            "before_log": str(before_log),
            "before_transcript": str(before_transcript),
            "before_verifier_result": str(before_verifier_path),
            "candidate_log": str(candidate_log),
            "candidate_transcript": str(candidate_transcript),
            "candidate_verifier_result": str(candidate_verifier_path),
        },
        "score_history": {
            "before": before_history,
            "candidate": candidate_history,
        },
    }

    summary_path = out_dir / "summary.json"
    summary_path.write_text(
        json.dumps(summary, indent=2) + "\n",
        encoding="utf-8",
    )

    print()
    print("[quota-runner] comparison complete")
    print(
        f"[quota-runner] baseline score: "
        f"{before_score['score']}/100 "
        f"(quota={args.before_quota})"
    )
    print(
        f"[quota-runner] candidate score: "
        f"{candidate_score['score']}/100 "
        f"(quota={args.candidate_quota})"
    )
    print(
        "[quota-runner] candidate hard verifier: "
        + (
            "PASS"
            if candidate_verifier.get("hard_verifier_passed", False)
            else "FAIL"
        )
    )
    print(f"[quota-runner] decision: {decision}")
    print(f"[quota-runner] reason: {reason}")

    if decision == "ROLLBACK":
        print(
            f"[quota-runner] rollback target quota: "
            f"{args.before_quota}"
        )

    print(f"[quota-runner] summary: {summary_path}")


if __name__ == "__main__":
    main()
