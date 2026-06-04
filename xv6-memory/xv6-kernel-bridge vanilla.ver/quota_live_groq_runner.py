#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys
from pathlib import Path

import pexpect

from collect_swap_scenario import Tee
from collect_swap_scenario import stop_qemu
from execute_quota_runtime_scenario import apply_quota
from execute_quota_runtime_scenario import collect_snapshot
from execute_quota_runtime_scenario import compute_final_score
from execute_quota_runtime_scenario import find_quota
from execute_quota_runtime_scenario import load_snapshots
from execute_quota_runtime_scenario import run_verifier
from quota_groq_retry_runner import build_quota_only_prompt
from quota_groq_retry_runner import extract_prompt_json
from quota_groq_retry_runner import load_json
from quota_groq_retry_runner import normalize_quota_proposal
from quota_groq_retry_runner import save_json

PAGE_SIZE = 4096
QUOTA_ACTIONS = {"increase_quota", "decrease_quota"}


def run(command, allow_failure=False):
    print("[live-groq] $ " + " ".join(str(item) for item in command))

    result = subprocess.run(command)

    if result.returncode != 0 and not allow_failure:
        raise RuntimeError(
            f"command failed with exit code {result.returncode}: "
            + " ".join(str(item) for item in command)
        )

    return result.returncode


def find_process(lines, target_pid):
    snapshots = load_snapshots(lines)

    if not snapshots:
        raise RuntimeError("snapshot list is empty")

    for proc in snapshots[-1].get("processes", []):
        if int(proc.get("pid", -1)) == target_pid:
            return proc

    raise RuntimeError(f"target pid disappeared: {target_pid}")


def add_live_retry_feedback(
    prompt,
    attempt,
    proposal,
    reason,
    baseline_score,
    candidate_score=None,
):
    retry_context = prompt.setdefault("retry_context", [])

    retry_context.append(
        {
            "attempt": attempt,
            "rejected_proposal": proposal,
            "reason": reason,
            "baseline_score": baseline_score,
            "candidate_score": candidate_score,
        }
    )

    instruction = (
        f"Runtime attempt {attempt} was rejected. "
        f"Reason: {reason} "
        "The process remains alive and the previous quota was restored. "
        "Recommend a different page-aligned target_quota. "
        "Avoid an excessively large quota because low usage ratio reduces "
        "the efficiency score. Aim for a moderate quota with useful "
        "headroom while keeping usage reasonably close to 0.7."
    )

    constraints = prompt.setdefault("safety_constraints", [])

    if instruction not in constraints:
        constraints.append(instruction)

    return prompt


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Run a live Groq quota optimization loop on one persistent "
            "xv6 process with real quota apply and rollback."
        )
    )

    parser.add_argument("--pages", type=int, default=32)
    parser.add_argument("--delay", type=int, default=100000)
    parser.add_argument("--ticks", type=int, default=5)
    parser.add_argument("--interval", type=int, default=2)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--max-attempts", type=int, default=4)
    parser.add_argument("--min-improvement", type=float, default=3.0)

    parser.add_argument(
        "--before-quota",
        type=int,
        default=0,
        help=(
            "baseline quota in bytes; 0 automatically uses current sz "
            "+ one page to create a safe but near-limit baseline"
        ),
    )

    parser.add_argument(
        "--reasoning-effort",
        choices=["low", "medium", "high"],
        default="low",
    )

    parser.add_argument("--model")
    parser.add_argument("--approve", action="store_true")

    parser.add_argument(
        "--out-dir",
        default="logs/quota_live_groq",
    )

    args = parser.parse_args()

    if not args.approve:
        raise SystemExit(
            "[live-groq] ERROR: --approve is required before runtime changes"
        )

    if args.pages <= 0:
        raise SystemExit("[live-groq] ERROR: pages must be positive")

    if args.max_attempts <= 0:
        raise SystemExit("[live-groq] ERROR: max attempts must be positive")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    transcript_path = out_dir / "qemu.log"
    initial_log = out_dir / "initial.jsonl"
    baseline_log = out_dir / "baseline.jsonl"
    baseline_verifier = out_dir / "baseline_hard_verifier.json"
    prompt_log = out_dir / "initial_prompt.log"
    summary_path = out_dir / "summary.json"

    print("[live-groq] starting QEMU")

    child = pexpect.spawn(
        "make",
        ["qemu", "CPUS=1"],
        encoding="utf-8",
        timeout=args.timeout,
    )

    transcript_file = transcript_path.open("w", encoding="utf-8")
    child.logfile = Tee(sys.stdout, transcript_file)

    summary = {
        "result": "FAILED",
        "attempts": [],
    }

    try:
        child.expect_exact("$ ")

        memhold_command = f"memhold {args.pages} {args.delay} &"
        print(f"[live-groq] xv6 command: {memhold_command}")
        child.sendline(memhold_command)

        child.expect(
            r"memhold ready pid=(\d+) pages=\d+ delay=\d+",
            timeout=args.timeout,
        )

        target_pid = int(child.match.group(1))
        print(f"[live-groq] detected target pid: {target_pid}")

        initial_lines = collect_snapshot(
            child,
            1,
            0,
            initial_log,
            args.timeout,
        )

        initial_proc = find_process(initial_lines, target_pid)
        current_sz = int(initial_proc.get("sz", 0))

        if current_sz <= 0:
            raise RuntimeError("invalid initial process size")

        if args.before_quota > 0:
            before_quota = args.before_quota
        else:
            before_quota = current_sz + PAGE_SIZE

        if before_quota < current_sz + PAGE_SIZE:
            raise RuntimeError(
                "baseline quota must be at least current sz + one page: "
                f"sz={current_sz}, requested={before_quota}"
            )

        print(f"[live-groq] baseline quota: {before_quota}")

        if not apply_quota(
            child,
            target_pid,
            before_quota,
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
        baseline_value = float(baseline_score["score"])

        transcript_file.flush()

        if not run_verifier(
            baseline_log,
            transcript_path,
            baseline_verifier,
        ):
            raise RuntimeError("baseline policy failed Hard Verifier")

        print(f"[live-groq] baseline score: {baseline_value}")

        run(
            [
                sys.executable,
                "run_pipeline.py",
                "--memwatch-log",
                str(baseline_log),
                "--prompt-out",
                str(prompt_log),
                "--reset-state",
            ]
        )

        prompt = build_quota_only_prompt(
            extract_prompt_json(prompt_log)
        )

        constraints = prompt.setdefault("safety_constraints", [])

        live_rule = (
            "This is a live optimization run for a persistent process. "
            "Recommend a page-aligned quota that improves efficiency without "
            "making the quota excessively large. The target process remains "
            "alive during evaluation and rejected candidates are rolled back."
        )

        if live_rule not in constraints:
            constraints.append(live_rule)

        accepted = False

        for attempt in range(1, args.max_attempts + 1):
            print()
            print(
                f"[live-groq] attempt {attempt}/{args.max_attempts}"
            )

            attempt_dir = out_dir / f"attempt_{attempt}"
            attempt_dir.mkdir(parents=True, exist_ok=True)

            prompt_path = attempt_dir / "prompt.json"
            proposal_path = attempt_dir / "proposal.json"
            candidate_log = attempt_dir / "candidate.jsonl"
            candidate_verifier = (
                attempt_dir / "candidate_hard_verifier.json"
            )
            rollback_log = attempt_dir / "rollback.jsonl"

            save_json(prompt_path, prompt)

            groq_command = [
                sys.executable,
                "groq_client.py",
                "--prompt",
                str(prompt_path),
                "--out",
                str(proposal_path),
                "--reasoning-effort",
                args.reasoning_effort,
            ]

            if args.model:
                groq_command.extend(["--model", args.model])

            run(groq_command)

            proposal = normalize_quota_proposal(
                load_json(proposal_path)
            )

            save_json(proposal_path, proposal)

            action = proposal.get("action")
            proposal_pid = int(proposal.get("target_pid", -1))
            target_quota = proposal.get("target_quota")

            if action not in QUOTA_ACTIONS:
                reason = (
                    f"unsupported quota-only action: {action}"
                )

                print(f"[live-groq] rejected: {reason}")

                summary["attempts"].append(
                    {
                        "attempt": attempt,
                        "proposal": proposal,
                        "decision": "REJECT_UNSUPPORTED_ACTION",
                        "reason": reason,
                    }
                )

                prompt = add_live_retry_feedback(
                    prompt,
                    attempt,
                    proposal,
                    reason,
                    baseline_value,
                )

                continue

            if proposal_pid != target_pid:
                reason = (
                    f"proposal pid mismatch: expected={target_pid}, "
                    f"actual={proposal_pid}"
                )

                print(f"[live-groq] rejected: {reason}")

                summary["attempts"].append(
                    {
                        "attempt": attempt,
                        "proposal": proposal,
                        "decision": "REJECT_PID_MISMATCH",
                        "reason": reason,
                    }
                )

                prompt = add_live_retry_feedback(
                    prompt,
                    attempt,
                    proposal,
                    reason,
                    baseline_value,
                )

                continue

            if not isinstance(target_quota, int) or target_quota <= 0:
                reason = "target_quota must be a positive integer"

                print(f"[live-groq] rejected: {reason}")

                summary["attempts"].append(
                    {
                        "attempt": attempt,
                        "proposal": proposal,
                        "decision": "REJECT_INVALID_QUOTA",
                        "reason": reason,
                    }
                )

                prompt = add_live_retry_feedback(
                    prompt,
                    attempt,
                    proposal,
                    reason,
                    baseline_value,
                )

                continue

            guard_code = run(
                [
                    sys.executable,
                    "proposal_guard.py",
                    "--proposal",
                    str(proposal_path),
                ],
                allow_failure=True,
            )

            if guard_code != 0:
                reason = "proposal_guard rejected the proposal"

                summary["attempts"].append(
                    {
                        "attempt": attempt,
                        "proposal": proposal,
                        "decision": "REJECT_GUARD",
                        "reason": reason,
                    }
                )

                prompt = add_live_retry_feedback(
                    prompt,
                    attempt,
                    proposal,
                    reason,
                    baseline_value,
                )

                continue

            if not apply_quota(
                child,
                target_pid,
                target_quota,
                args.timeout,
            ):
                reason = "candidate quota application failed"

                summary["attempts"].append(
                    {
                        "attempt": attempt,
                        "proposal": proposal,
                        "decision": "REJECT_APPLY_FAILED",
                        "reason": reason,
                    }
                )

                prompt = add_live_retry_feedback(
                    prompt,
                    attempt,
                    proposal,
                    reason,
                    baseline_value,
                )

                continue

            candidate_lines = collect_snapshot(
                child,
                args.ticks,
                args.interval,
                candidate_log,
                args.timeout,
            )

            candidate_score = compute_final_score(candidate_lines)
            candidate_value = float(candidate_score["score"])

            transcript_file.flush()

            candidate_passed = run_verifier(
                candidate_log,
                transcript_path,
                candidate_verifier,
            )

            improved = (
                candidate_passed
                and candidate_value
                > baseline_value + args.min_improvement
            )

            if improved:
                final_quota = find_quota(
                    candidate_lines,
                    target_pid,
                )

                summary["result"] = "LIVE_POLICY_ACCEPTED"
                summary["target_pid"] = target_pid
                summary["before_quota"] = before_quota
                summary["final_quota"] = final_quota
                summary["baseline_score"] = baseline_score
                summary["accepted_attempt"] = attempt
                summary["accepted_proposal"] = proposal
                summary["candidate_score"] = candidate_score

                summary["attempts"].append(
                    {
                        "attempt": attempt,
                        "proposal": proposal,
                        "decision": "ACCEPT",
                        "candidate_score": candidate_score,
                    }
                )

                accepted = True
                break

            if candidate_passed:
                reason = (
                    "candidate score did not improve enough: "
                    f"baseline={baseline_value}, "
                    f"candidate={candidate_value}, "
                    f"required_delta>{args.min_improvement}"
                )
            else:
                reason = "candidate failed Hard Verifier"

            print(f"[live-groq] rejected: {reason}")
            print("[live-groq] applying runtime rollback")

            if not apply_quota(
                child,
                target_pid,
                before_quota,
                args.timeout,
            ):
                raise RuntimeError("runtime rollback failed")

            rollback_lines = collect_snapshot(
                child,
                1,
                0,
                rollback_log,
                args.timeout,
            )

            restored_quota = find_quota(
                rollback_lines,
                target_pid,
            )

            if restored_quota != before_quota:
                raise RuntimeError(
                    "rollback verification failed: "
                    f"expected={before_quota}, "
                    f"actual={restored_quota}"
                )

            summary["attempts"].append(
                {
                    "attempt": attempt,
                    "proposal": proposal,
                    "decision": "ROLLBACK_APPLIED",
                    "reason": reason,
                    "candidate_score": candidate_score,
                }
            )

            prompt = add_live_retry_feedback(
                prompt,
                attempt,
                proposal,
                reason,
                baseline_value,
                candidate_value,
            )

        if not accepted:
            summary["result"] = "LIVE_RETRY_EXHAUSTED"
            summary["target_pid"] = target_pid
            summary["before_quota"] = before_quota
            summary["final_quota"] = before_quota
            summary["baseline_score"] = baseline_score

    except Exception as error:
        summary["result"] = "ERROR"
        summary["error"] = str(error)
        print(f"[live-groq] ERROR: {error}")

    finally:
        stop_qemu(child)
        transcript_file.close()

    save_json(summary_path, summary)

    print()
    print(f"[live-groq] result: {summary['result']}")

    if "target_pid" in summary:
        print(f"[live-groq] target pid: {summary['target_pid']}")

    if "before_quota" in summary:
        print(
            f"[live-groq] baseline quota: "
            f"{summary['before_quota']}"
        )

    if "final_quota" in summary:
        print(
            f"[live-groq] final quota: "
            f"{summary['final_quota']}"
        )

    print(f"[live-groq] summary: {summary_path}")

    if summary["result"] != "LIVE_POLICY_ACCEPTED":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
