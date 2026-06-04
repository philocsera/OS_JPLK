#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys
from pathlib import Path

from quota_groq_retry_runner import extract_prompt_json
from quota_groq_retry_runner import load_json
from quota_groq_retry_runner import save_json

POLICY_ACTIONS = {
    "no_action",
    "keep_quota",
    "inspect_process",
    "increase_quota",
    "decrease_quota",
    "release_quota",
    "swapout",
}

QUOTA_ACTIONS = {
    "increase_quota",
    "decrease_quota",
    "release_quota",
}

SWAP_ACTIONS = {
    "swapout",
}


def run(command, allow_failure=False):
    print("[memory-live] $ " + " ".join(str(item) for item in command))
    result = subprocess.run(command)

    if result.returncode != 0 and not allow_failure:
        raise RuntimeError(
            "command failed with exit code "
            f"{result.returncode}: "
            + " ".join(str(item) for item in command)
        )

    return result.returncode


def normalize_proposal(proposal):
    proposal = dict(proposal)

    proposal.setdefault("action", "no_action")
    proposal.setdefault("target_pid", 0)
    proposal.setdefault("target_quota", None)
    proposal.setdefault("swapout_pages", None)
    proposal.setdefault("reason", "")
    proposal.setdefault("confidence", "low")

    if proposal["action"] not in POLICY_ACTIONS:
        raise ValueError(f"unsupported action: {proposal['action']}")

    proposal["target_pid"] = int(proposal.get("target_pid", 0) or 0)

    if proposal.get("target_quota") is not None:
        proposal["target_quota"] = int(proposal["target_quota"])

    if proposal.get("swapout_pages") is not None:
        proposal["swapout_pages"] = int(proposal["swapout_pages"])

    return proposal


def build_memory_policy_prompt(prompt_log):
    try:
        prompt = extract_prompt_json(prompt_log)
    except Exception:
        prompt = {
            "raw_bridge_prompt": Path(prompt_log).read_text(
                encoding="utf-8",
                errors="replace",
            )
        }

    prompt["policy_mode"] = "integrated_memory_policy_selection"

    prompt["available_runtime_policies"] = [
        {
            "action": "increase_quota",
            "meaning": "raise target process memory quota",
            "evaluation": "candidate score must improve over baseline",
        },
        {
            "action": "decrease_quota",
            "meaning": "lower target process memory quota",
            "evaluation": "candidate score must improve over baseline",
        },
        {
            "action": "release_quota",
            "meaning": "remove target process quota",
            "evaluation": "must pass hard verifier",
        },
        {
            "action": "swapout",
            "meaning": "swap out writable pages from target process",
            "evaluation": (
                "must pass hard verifier, target must stay alive, "
                "and thrashing must be below threshold"
            ),
        },
        {
            "action": "no_action",
            "meaning": "do not mutate xv6 state",
            "evaluation": "allowed when risk is low or evidence is insufficient",
        },
        {
            "action": "inspect_process",
            "meaning": "request another memwatch snapshot",
            "evaluation": "allowed when evidence is insufficient",
        },
    ]

    constraints = prompt.setdefault("safety_constraints", [])
    integrated_rule = (
        "Select exactly one policy. Do not assume quota must run before swap. "
        "Choose quota when the main problem is uncontrolled growth. "
        "Choose swapout when the main problem is immediate RAM pressure and "
        "safe writable pages can be reclaimed. If a previous attempt failed, "
        "avoid repeating the same unsafe policy."
    )

    if integrated_rule not in constraints:
        constraints.append(integrated_rule)

    return prompt


def add_retry_feedback(prompt, attempt, proposal, failure_code, reason):
    retry_context = prompt.setdefault("retry_context", [])

    retry_context.append(
        {
            "attempt": attempt,
            "rejected_proposal": proposal,
            "failure_code": failure_code,
            "reason": reason,
        }
    )

    instruction = (
        f"Runtime attempt {attempt} was rejected. "
        f"failure_code={failure_code}. "
        f"reason={reason}. "
        "Choose a different safer policy or reduce the intensity of the "
        "same policy. For swapout thrashing, reduce swapout_pages or choose "
        "quota. For hard verifier failure, avoid swapout unless there is "
        "clear evidence it is safe."
    )

    constraints = prompt.setdefault("safety_constraints", [])

    if instruction not in constraints:
        constraints.append(instruction)

    return prompt


def run_guard(proposal_path):
    return run(
        [
            sys.executable,
            "proposal_guard.py",
            "--proposal",
            str(proposal_path),
        ],
        allow_failure=True,
    )


def run_apply_dry_run(proposal_path, approve):
    command = [
        sys.executable,
        "apply_policy.py",
        "--proposal",
        str(proposal_path),
        "--dry-run",
    ]

    if approve:
        command.append("--approve")

    return run(command, allow_failure=True)


def load_jsonl(path):
    snapshots = []

    for raw in Path(path).read_text(
        encoding="utf-8",
        errors="replace",
    ).splitlines():
        raw = raw.strip()

        if not raw:
            continue

        try:
            item = json.loads(raw)
        except json.JSONDecodeError:
            continue

        if item.get("type") == "memstat":
            snapshots.append(item)

    return snapshots


def find_final_process(snapshot_log, target_pid):
    snapshots = load_jsonl(snapshot_log)

    if not snapshots:
        return None

    for proc in snapshots[-1].get("processes", []):
        if int(proc.get("pid", -1)) == int(target_pid):
            return proc

    return None


def estimate_swap_stab(snapshot_log, target_pid):
    proc = find_final_process(snapshot_log, target_pid)

    if not proc:
        return 0.0, 0

    swapout_count = int(proc.get("swapout_count", 0))
    swapin_count = int(proc.get("swapin_count", 0))
    swap_cycle_sum = min(swapout_count, swapin_count)

    thrash_ratio = min(float(swap_cycle_sum) / 5.0, 1.0)
    stab = 1.0 - 0.5 * thrash_ratio

    return stab, swap_cycle_sum


def run_hard_verifier(
    log_path,
    transcript_path,
    out_path,
    proposal,
    min_swap_stab,
):
    action = proposal.get("action")
    target_pid = int(proposal.get("target_pid", 0) or 0)

    command = [
        sys.executable,
        "hard_verifier.py",
        "--log",
        str(log_path),
        "--out",
        str(out_path),
    ]

    if transcript_path:
        command.extend(["--transcript", str(transcript_path)])

    if target_pid > 0:
        command.extend(["--target-pid", str(target_pid)])

    if action == "swapout":
        command.append("--require-swap-activity")

    code = run(command, allow_failure=True)

    if code != 0:
        return False, "HARD_VERIFIER_FAILED", "hard verifier failed"

    if action == "swapout":
        stab, swap_cycle_sum = estimate_swap_stab(log_path, target_pid)

        if stab < min_swap_stab:
            return (
                False,
                "SWAP_THRASHING_DETECTED",
                f"stab={stab:.3f} < min_stab={min_swap_stab}; "
                f"swap_cycle_sum={swap_cycle_sum}",
            )

    return True, None, None


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Integrated xv6 memory policy loop: "
            "Bridge prompt -> Groq policy -> Guard -> dry-run command -> "
            "optional Hard Verifier -> retry feedback."
        )
    )

    parser.add_argument("--memwatch-log", required=True)
    parser.add_argument("--transcript")
    parser.add_argument("--candidate-log")
    parser.add_argument("--out-dir", default="logs/memory_live")
    parser.add_argument("--max-attempts", type=int, default=2)
    parser.add_argument("--min-swap-stab", type=float, default=0.85)
    parser.add_argument("--model")
    parser.add_argument(
        "--reasoning-effort",
        choices=["low", "medium", "high"],
        default="medium",
    )
    parser.add_argument("--approve", action="store_true")
    parser.add_argument("--reset-state", action="store_true")
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    prompt_log = out_dir / "bridge_prompt.txt"
    summary_path = out_dir / "summary.json"

    run_pipeline_command = [
        sys.executable,
        "run_pipeline.py",
        "--memwatch-log",
        str(args.memwatch_log),
        "--prompt-out",
        str(prompt_log),
    ]

    if args.reset_state:
        run_pipeline_command.append("--reset-state")

    run(run_pipeline_command)

    prompt = build_memory_policy_prompt(prompt_log)

    summary = {
        "memwatch_log": str(args.memwatch_log),
        "transcript": str(args.transcript) if args.transcript else None,
        "candidate_log": (
            str(args.candidate_log) if args.candidate_log else None
        ),
        "attempts": [],
        "accepted": False,
    }

    for attempt in range(1, args.max_attempts + 1):
        print()
        print(f"[memory-live] attempt {attempt}/{args.max_attempts}")

        attempt_dir = out_dir / f"attempt_{attempt}"
        attempt_dir.mkdir(parents=True, exist_ok=True)

        prompt_path = attempt_dir / "prompt.json"
        proposal_path = attempt_dir / "proposal.json"
        verifier_path = attempt_dir / "hard_verifier.json"

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

        proposal = normalize_proposal(load_json(proposal_path))
        save_json(proposal_path, proposal)

        action = proposal.get("action")

        if action in {"no_action", "keep_quota", "inspect_process"}:
            decision = "ACCEPT_READ_ONLY"
            reason = "LLM selected non-mutating policy"

            summary["attempts"].append(
                {
                    "attempt": attempt,
                    "proposal": proposal,
                    "decision": decision,
                    "reason": reason,
                }
            )
            summary["accepted"] = True
            summary["accepted_proposal"] = proposal
            break

        guard_code = run_guard(proposal_path)

        if guard_code != 0:
            failure_code = "PROPOSAL_GUARD_REJECTED"
            reason = "proposal_guard rejected the proposal"

            summary["attempts"].append(
                {
                    "attempt": attempt,
                    "proposal": proposal,
                    "decision": "ROLLBACK",
                    "failure_code": failure_code,
                    "reason": reason,
                }
            )

            prompt = add_retry_feedback(
                prompt,
                attempt,
                proposal,
                failure_code,
                reason,
            )
            continue

        apply_code = run_apply_dry_run(proposal_path, args.approve)

        if apply_code != 0:
            failure_code = "APPLY_DRY_RUN_FAILED"
            reason = "apply_policy dry-run failed"

            summary["attempts"].append(
                {
                    "attempt": attempt,
                    "proposal": proposal,
                    "decision": "ROLLBACK",
                    "failure_code": failure_code,
                    "reason": reason,
                }
            )

            prompt = add_retry_feedback(
                prompt,
                attempt,
                proposal,
                failure_code,
                reason,
            )
            continue

        if not args.candidate_log:
            decision = "ACCEPT_DRY_RUN"
            reason = (
                "proposal passed guard and command generation; "
                "candidate verifier was skipped because --candidate-log "
                "was not provided"
            )

            summary["attempts"].append(
                {
                    "attempt": attempt,
                    "proposal": proposal,
                    "decision": decision,
                    "reason": reason,
                }
            )
            summary["accepted"] = True
            summary["accepted_proposal"] = proposal
            break

        verifier_ok, failure_code, reason = run_hard_verifier(
            args.candidate_log,
            args.transcript,
            verifier_path,
            proposal,
            args.min_swap_stab,
        )

        if not verifier_ok:
            if action in QUOTA_ACTIONS and failure_code == "HARD_VERIFIER_FAILED":
                failure_code = "QUOTA_HARD_VERIFIER_FAILED"

            if action in SWAP_ACTIONS and failure_code == "HARD_VERIFIER_FAILED":
                failure_code = "SWAP_HARD_VERIFIER_FAILED"

            summary["attempts"].append(
                {
                    "attempt": attempt,
                    "proposal": proposal,
                    "decision": "ROLLBACK",
                    "failure_code": failure_code,
                    "reason": reason,
                }
            )

            prompt = add_retry_feedback(
                prompt,
                attempt,
                proposal,
                failure_code,
                reason,
            )
            continue

        decision = "ACCEPT"
        reason = "proposal passed guard, dry-run, and hard verifier"

        summary["attempts"].append(
            {
                "attempt": attempt,
                "proposal": proposal,
                "decision": decision,
                "reason": reason,
            }
        )
        summary["accepted"] = True
        summary["accepted_proposal"] = proposal
        break

    if not summary["accepted"]:
        summary["final_decision"] = "NO_ACCEPTED_POLICY"
        print("[memory-live] result: NO_ACCEPTED_POLICY")
    else:
        summary["final_decision"] = "ACCEPTED"
        print("[memory-live] result: ACCEPTED")

    save_json(summary_path, summary)
    print(f"[memory-live] summary saved: {summary_path}")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
