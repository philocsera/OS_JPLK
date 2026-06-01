#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys
from pathlib import Path

QUOTA_ACTIONS = {"increase_quota", "decrease_quota"}


def run(command):
    print("[quota-agent] $ " + " ".join(str(item) for item in command))
    return subprocess.run(command).returncode


def load_proposal(path):
    proposal = json.loads(Path(path).read_text(encoding="utf-8"))

    action = proposal.get("action")
    target_quota = proposal.get("target_quota")

    if action not in QUOTA_ACTIONS:
        raise ValueError(
            "quota agent supports only increase_quota or decrease_quota"
        )

    if not isinstance(target_quota, int) or target_quota <= 0:
        raise ValueError("target_quota must be a positive integer")

    return proposal


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Validate an approved quota proposal and compare its score "
            "against the baseline quota."
        )
    )

    parser.add_argument("--memwatch-log", required=True)
    parser.add_argument("--proposal", required=True)
    parser.add_argument("--before-quota", type=int, required=True)
    parser.add_argument("--approve", action="store_true")
    parser.add_argument("--step", type=int, default=4096)
    parser.add_argument("--procs", type=int, default=1)
    parser.add_argument("--ticks", type=int, default=30)
    parser.add_argument("--interval", type=int, default=2)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--out-dir", default="logs/quota_agent_runner")

    args = parser.parse_args()

    if args.before_quota <= 0:
        raise SystemExit("[quota-agent] ERROR: before quota must be positive")

    try:
        proposal = load_proposal(args.proposal)
    except Exception as error:
        raise SystemExit(f"[quota-agent] ERROR: {error}")

    candidate_quota = proposal["target_quota"]
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print("[quota-agent] stage 1: validate proposal and approval boundary")

    pipeline_command = [
        sys.executable,
        "run_pipeline.py",
        "--memwatch-log",
        args.memwatch_log,
        "--proposal",
        args.proposal,
        "--prompt-out",
        str(out_dir / "llm_prompt.log"),
        "--reset-state",
    ]

    if args.approve:
        pipeline_command.append("--approve")

    if run(pipeline_command) != 0:
        raise SystemExit("[quota-agent] ERROR: proposal pipeline failed")

    if not args.approve:
        print("[quota-agent] result: PENDING_APPROVAL")
        print("[quota-agent] verification workload was not executed")
        return

    print()
    print("[quota-agent] stage 2: verify approved candidate quota")

    runner_command = [
        sys.executable,
        "quota_policy_runner.py",
        "--before-quota",
        str(args.before_quota),
        "--candidate-quota",
        str(candidate_quota),
        "--step",
        str(args.step),
        "--procs",
        str(args.procs),
        "--ticks",
        str(args.ticks),
        "--interval",
        str(args.interval),
        "--timeout",
        str(args.timeout),
        "--out-dir",
        str(out_dir / "verification"),
    ]

    if proposal["action"] == "increase_quota":
        runner_command.append("--allow-invalid-baseline")

    exit_code = run(runner_command)

    if exit_code != 0:
        raise SystemExit(
            f"[quota-agent] ERROR: verification runner failed "
            f"with exit code {exit_code}"
        )

    summary_path = out_dir / "verification" / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    decision = summary.get("decision", "UNKNOWN")

    result_map = {
        "ACCEPT": "POLICY_ACCEPTED",
        "ROLLBACK": "POLICY_ROLLBACK_REQUIRED",
        "ACCEPT_RECOVERY": "RECOVERY_ACCEPTED",
        "REJECT_RECOVERY_CANDIDATE": "RECOVERY_CANDIDATE_REJECTED",
        "ABORT_BASELINE_INVALID": "BASELINE_INVALID",
    }

    result = result_map.get(decision, "VERIFICATION_COMPLETE")

    print()
    print(f"[quota-agent] result: {result}")
    print(f"[quota-agent] decision: {decision}")
    print(f"[quota-agent] candidate quota: {candidate_quota}")

    rollback_quota = summary.get("rollback_quota")
    if rollback_quota is not None:
        print(f"[quota-agent] rollback target quota: {rollback_quota}")

    print(f"[quota-agent] summary: {summary_path}")


if __name__ == "__main__":
    main()
