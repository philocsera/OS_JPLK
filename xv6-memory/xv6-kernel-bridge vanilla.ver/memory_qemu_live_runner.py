#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path

import pexpect

from collect_swap_scenario import Tee, stop_qemu
from execute_quota_runtime_scenario import (
    apply_quota,
    collect_snapshot,
    compute_final_score,
    load_snapshots,
)
from memory_live_groq_runner import (
    QUOTA_ACTIONS,
    SWAP_ACTIONS,
    add_retry_feedback,
    build_memory_policy_prompt,
    estimate_swap_stab,
    normalize_proposal,
)
from quota_groq_retry_runner import extract_prompt_json, load_json, save_json

PAGE_SIZE = 4096
READ_ONLY_ACTIONS = {"no_action", "keep_quota", "inspect_process"}


def run(command, allow_failure=False):
    print("[memory-qemu] $ " + " ".join(str(x) for x in command))
    result = subprocess.run(command)

    if result.returncode and not allow_failure:
        raise RuntimeError(
            f"command failed ({result.returncode}): "
            + " ".join(str(x) for x in command)
        )

    return result.returncode


def final_proc(lines, pid):
    snapshots = load_snapshots(lines)

    if not snapshots:
        raise RuntimeError("snapshot list is empty")

    for proc in snapshots[-1].get("processes", []):
        if int(proc.get("pid", -1)) == pid:
            return proc

    raise RuntimeError(f"target pid disappeared: {pid}")


def start_qemu(timeout, transcript_path):
    child = pexpect.spawn(
        "make",
        ["qemu", "CPUS=1"],
        encoding="utf-8",
        timeout=timeout,
    )

    transcript_path.parent.mkdir(parents=True, exist_ok=True)
    transcript_file = transcript_path.open("w", encoding="utf-8")
    child.logfile = Tee(sys.stdout, transcript_file)

    child.expect_exact("$ ", timeout=timeout)

    return child, transcript_file


def apply_swapout(child, pid, pages, timeout):
    command = f"swapctl {pid} {pages}"

    print(f"[memory-qemu] xv6 command: {command}")
    child.sendline(command)

    child.expect(
        rf"swapctl pid={pid} requested={pages} success=(\d+)",
        timeout=timeout,
    )

    success = int(child.match.group(1))

    child.expect_exact("$ ", timeout=timeout)

    print(f"[memory-qemu] swapped pages: {success}")

    return success > 0


def verify_candidate(
    log_path,
    transcript_path,
    out_path,
    pid,
    is_swap,
):
    command = [
        sys.executable,
        "hard_verifier.py",
        "--log",
        str(log_path),
        "--transcript",
        str(transcript_path),
        "--target-pid",
        str(pid),
        "--out",
        str(out_path),
    ]

    if is_swap:
        command.append("--require-swapout-activity")

    return run(command, allow_failure=True) == 0


def build_prompt(baseline_log, prompt_log, previous_prompt):
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

    prompt = build_memory_policy_prompt(prompt_log)

    if previous_prompt:
        prompt["retry_context"] = previous_prompt.get(
            "retry_context",
            [],
        )

        constraints = prompt.setdefault("safety_constraints", [])

        for item in previous_prompt.get("safety_constraints", []):
            if item not in constraints:
                constraints.append(item)

    return prompt


def ask_groq(prompt, prompt_path, proposal_path, args):
    save_json(prompt_path, prompt)

    command = [
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
        command.extend(["--model", args.model])

    run(command)

    proposal = normalize_proposal(load_json(proposal_path))

    save_json(proposal_path, proposal)

    return proposal


def add_failure(
    summary,
    prompt,
    attempt,
    proposal,
    code,
    reason,
):
    summary["attempts"].append(
        {
            "attempt": attempt,
            "proposal": proposal,
            "decision": "ROLLBACK_QEMU_RESTART",
            "failure_code": code,
            "reason": reason,
        }
    )

    return add_retry_feedback(
        prompt,
        attempt,
        proposal,
        code,
        reason,
    )


def main():
    parser = argparse.ArgumentParser(
        description=(
            "MVP live loop: QEMU -> memhold -> Bridge -> Groq -> "
            "quota or swapout -> verifier -> accept or QEMU restart rollback"
        )
    )

    parser.add_argument("--pages", type=int, default=32)
    parser.add_argument("--delay", type=int, default=100000)
    parser.add_argument("--ticks", type=int, default=5)
    parser.add_argument("--interval", type=int, default=2)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--max-attempts", type=int, default=2)
    parser.add_argument("--min-improvement", type=float, default=1.0)
    parser.add_argument("--min-swap-stab", type=float, default=0.85)
    parser.add_argument("--out-dir", default="logs/memory_qemu_live")
    parser.add_argument("--model")

    parser.add_argument(
        "--reasoning-effort",
        choices=["low", "medium", "high"],
        default="low",
    )

    parser.add_argument(
        "--approve",
        action="store_true",
        help="actually apply the LLM-selected xv6 mutation",
    )

    parser.add_argument(
        "--force-action",
        choices=["increase_quota", "swapout"],
        help=(
            "smoke-test only: bypass Groq policy choice and force one "
            "mutating branch while preserving guard and verifier checks"
        ),
    )

    parser.add_argument(
        "--force-quota-headroom-pages",
        type=int,
        default=1,
    )

    parser.add_argument(
        "--force-swapout-pages",
        type=int,
        default=1,
    )

    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    summary_path = out_dir / "summary.json"

    summary = {
        "result": "FAILED",
        "rollback_mode": "qemu_restart_checkpoint",
        "attempts": [],
    }

    prompt = None
    accepted = False

    for attempt in range(1, args.max_attempts + 1):
        print()
        print(f"[memory-qemu] attempt {attempt}/{args.max_attempts}")

        attempt_dir = out_dir / f"attempt_{attempt}"
        attempt_dir.mkdir(parents=True, exist_ok=True)

        initial_log = attempt_dir / "initial.jsonl"
        baseline_log = attempt_dir / "baseline.jsonl"
        candidate_log = attempt_dir / "candidate.jsonl"
        prompt_log = attempt_dir / "bridge_prompt.txt"
        prompt_path = attempt_dir / "prompt.json"
        proposal_path = attempt_dir / "proposal.json"
        verifier_path = attempt_dir / "hard_verifier.json"
        transcript_path = attempt_dir / "qemu_transcript.txt"

        child = None
        transcript_file = None

        try:
            print("[memory-qemu] starting QEMU")

            child, transcript_file = start_qemu(
                args.timeout,
                transcript_path,
            )

            command = f"memhold {args.pages} {args.delay} &"

            print(f"[memory-qemu] xv6 command: {command}")

            child.sendline(command)

            child.expect(
                r"memhold ready pid=(\d+) pages=\d+ delay=\d+",
                timeout=args.timeout,
            )

            pid = int(child.match.group(1))

            print(f"[memory-qemu] target pid: {pid}")

            initial_lines = collect_snapshot(
                child,
                1,
                0,
                initial_log,
                args.timeout,
            )

            current_sz = int(
                final_proc(initial_lines, pid).get("sz", 0)
            )

            if current_sz <= 0:
                raise RuntimeError("invalid initial size")

            baseline_quota = current_sz + PAGE_SIZE

            print(f"[memory-qemu] baseline quota: {baseline_quota}")

            if not apply_quota(
                child,
                pid,
                baseline_quota,
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

            prompt = build_prompt(
                baseline_log,
                prompt_log,
                prompt,
            )

            if args.force_action == "increase_quota":
                proposal = normalize_proposal(
                    {
                        "action": "increase_quota",
                        "target_pid": pid,
                        "target_quota": (
                            baseline_quota
                            + args.force_quota_headroom_pages * PAGE_SIZE
                        ),
                        "swapout_pages": None,
                        "reason": (
                            "Forced quota smoke test for the real QEMU "
                            "executor branch."
                        ),
                        "confidence": "high",
                    }
                )

                save_json(proposal_path, proposal)

                print(
                    "[memory-qemu] forced smoke-test proposal: "
                    "increase_quota"
                )

            elif args.force_action == "swapout":
                proposal = normalize_proposal(
                    {
                        "action": "swapout",
                        "target_pid": pid,
                        "target_quota": None,
                        "swapout_pages": args.force_swapout_pages,
                        "reason": (
                            "Forced swapout smoke test for the real QEMU "
                            "executor branch."
                        ),
                        "confidence": "high",
                    }
                )

                save_json(proposal_path, proposal)

                print(
                    "[memory-qemu] forced smoke-test proposal: swapout"
                )

            else:
                proposal = ask_groq(
                    prompt,
                    prompt_path,
                    proposal_path,
                    args,
                )

            action = proposal["action"]

            if action in READ_ONLY_ACTIONS:
                summary["attempts"].append(
                    {
                        "attempt": attempt,
                        "proposal": proposal,
                        "decision": "ACCEPT_READ_ONLY",
                    }
                )

                summary["result"] = "LIVE_POLICY_ACCEPTED"
                summary["accepted_proposal"] = proposal

                accepted = True
                break

            if int(proposal.get("target_pid", 0) or 0) != pid:
                prompt = add_failure(
                    summary,
                    prompt,
                    attempt,
                    proposal,
                    "PROPOSAL_PID_MISMATCH",
                    (
                        f"expected pid={pid}, "
                        f"actual={proposal.get('target_pid')}"
                    ),
                )

                continue

            if run(
                [
                    sys.executable,
                    "proposal_guard.py",
                    "--proposal",
                    str(proposal_path),
                ],
                allow_failure=True,
            ):
                prompt = add_failure(
                    summary,
                    prompt,
                    attempt,
                    proposal,
                    "PROPOSAL_GUARD_REJECTED",
                    "proposal_guard rejected the proposal",
                )

                continue

            if not args.approve:
                summary["attempts"].append(
                    {
                        "attempt": attempt,
                        "proposal": proposal,
                        "decision": "PENDING_APPROVAL",
                    }
                )

                summary["result"] = "PENDING_APPROVAL"
                summary["pending_proposal"] = proposal

                break

            if action in QUOTA_ACTIONS:
                quota = proposal.get("target_quota")

                if not isinstance(quota, int) or quota <= 0:
                    raise RuntimeError("invalid target_quota")

                if not apply_quota(
                    child,
                    pid,
                    quota,
                    args.timeout,
                ):
                    raise RuntimeError(
                        "candidate quota application failed"
                    )

            elif action in SWAP_ACTIONS:
                pages = proposal.get("swapout_pages")

                if not isinstance(pages, int) or pages <= 0:
                    raise RuntimeError("invalid swapout_pages")

                if not apply_swapout(
                    child,
                    pid,
                    pages,
                    args.timeout,
                ):
                    raise RuntimeError(
                        "candidate swapout failed"
                    )

            else:
                raise RuntimeError(
                    f"unsupported action: {action}"
                )

            candidate_lines = collect_snapshot(
                child,
                args.ticks,
                args.interval,
                candidate_log,
                args.timeout,
            )

            transcript_file.flush()

            verifier_passed = verify_candidate(
                candidate_log,
                transcript_path,
                verifier_path,
                pid,
                action in SWAP_ACTIONS,
            )

            candidate_score = compute_final_score(candidate_lines)
            candidate_value = float(candidate_score["score"])

            if action in QUOTA_ACTIONS:
                ok = (
                    verifier_passed
                    and candidate_value
                    > baseline_value + args.min_improvement
                )

                code = (
                    "QUOTA_SCORE_NOT_IMPROVED"
                    if verifier_passed
                    else "QUOTA_HARD_VERIFIER_FAILED"
                )

                reason = (
                    f"quota baseline={baseline_value}, "
                    f"candidate={candidate_value}, "
                    f"required_delta>{args.min_improvement}"
                )

            else:
                stab, cycles = estimate_swap_stab(
                    candidate_log,
                    pid,
                )

                ok = (
                    verifier_passed
                    and stab >= args.min_swap_stab
                )

                code = (
                    "SWAP_STABILITY_BELOW_THRESHOLD"
                    if verifier_passed
                    else "SWAP_HARD_VERIFIER_FAILED"
                )

                reason = (
                    f"swap stab={stab:.3f}, "
                    f"min_stab={args.min_swap_stab}, "
                    f"cycles={cycles}"
                )

            attempt_result = {
                "attempt": attempt,
                "proposal": proposal,
                "baseline_score": baseline_score,
                "candidate_score": candidate_score,
                "decision": (
                    "ACCEPT"
                    if ok
                    else "ROLLBACK_QEMU_RESTART"
                ),
                "reason": reason,
            }

            summary["attempts"].append(attempt_result)

            if ok:
                summary["result"] = "LIVE_POLICY_ACCEPTED"
                summary["target_pid"] = pid
                summary["accepted_proposal"] = proposal
                summary["baseline_score"] = baseline_score
                summary["candidate_score"] = candidate_score

                accepted = True
                break

            attempt_result["failure_code"] = code

            prompt = add_retry_feedback(
                prompt,
                attempt,
                proposal,
                code,
                reason,
            )

        except Exception as error:
            reason = str(error)

            print(f"[memory-qemu] ERROR: {reason}")

            summary["attempts"].append(
                {
                    "attempt": attempt,
                    "decision": "ERROR_QEMU_RESTART",
                    "reason": reason,
                }
            )

            if prompt is not None:
                prompt = add_retry_feedback(
                    prompt,
                    attempt,
                    {},
                    "RUNTIME_ERROR",
                    reason,
                )

        finally:
            if child is not None:
                stop_qemu(child)

            if transcript_file is not None:
                transcript_file.close()

    if not accepted and summary["result"] == "FAILED":
        summary["result"] = "LIVE_RETRY_EXHAUSTED"

    save_json(summary_path, summary)

    print()
    print(f"[memory-qemu] result: {summary['result']}")
    print(f"[memory-qemu] summary: {summary_path}")
    print(json.dumps(summary, indent=2))

    if summary["result"] not in {
        "LIVE_POLICY_ACCEPTED",
        "PENDING_APPROVAL",
    }:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
