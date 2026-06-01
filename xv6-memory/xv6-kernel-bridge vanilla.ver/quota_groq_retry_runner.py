#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys
from pathlib import Path

PAGE_SIZE = 4096

QUOTA_ACTIONS = {
    "increase_quota",
    "decrease_quota",
}


def run(command, allow_failure=False):
    print("[groq-retry] $ " + " ".join(str(item) for item in command))
    result = subprocess.run(command)

    if result.returncode != 0 and not allow_failure:
        raise RuntimeError(
            f"command failed with exit code {result.returncode}: "
            + " ".join(str(item) for item in command)
        )

    return result.returncode


def load_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def extract_prompt_json(path):
    raw = Path(path).read_text(encoding="utf-8")

    start = raw.find("{")
    end = raw.rfind("}")

    if start == -1 or end == -1 or start >= end:
        raise RuntimeError(f"JSON prompt object not found: {path}")

    return json.loads(raw[start:end + 1])


def save_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def normalize_quota_proposal(proposal):
    action = proposal.get("action")
    target_quota = proposal.get("target_quota")

    if action not in QUOTA_ACTIONS:
        return proposal

    if not isinstance(target_quota, int) or target_quota <= 0:
        return proposal

    aligned_quota = (
        (target_quota + PAGE_SIZE - 1) // PAGE_SIZE
    ) * PAGE_SIZE

    if aligned_quota != target_quota:
        print(
            "[groq-retry] align target_quota: "
            f"{target_quota} -> {aligned_quota}"
        )

        proposal["target_quota"] = aligned_quota
        proposal["reason"] = (
            proposal.get("reason", "")
            + f" Normalized upward to the {PAGE_SIZE}-byte page boundary."
        )

    return proposal


def build_quota_only_prompt(prompt):
    prompt["allowed_actions"] = [
        "no_action",
        "keep_quota",
        "increase_quota",
        "decrease_quota",
        "inspect_process",
    ]

    constraints = prompt.setdefault("safety_constraints", [])

    extra_constraints = [
        (
            "target_quota must be a positive multiple of 4096 bytes."
        ),
        (
            "For this quota-only run, do not recommend swapout or "
            "release_quota."
        ),
        (
            "The kernel quota check compares process sz with mem_quota. "
            "Swapping out pages does not reduce sz and cannot resolve a "
            "quota denial caused by sz reaching mem_quota."
        ),
        (
            "When a non-protected process reaches its quota and allocation "
            "is denied, prefer a conservative increase_quota proposal."
        ),
    ]

    for rule in extra_constraints:
        if rule not in constraints:
            constraints.append(rule)

    return prompt


def add_retry_feedback(prompt, attempt, proposal, reason):
    retry_context = prompt.setdefault("retry_context", [])

    retry_context.append(
        {
            "attempt": attempt,
            "rejected_proposal": proposal,
            "hard_verifier_feedback": reason,
        }
    )

    previous_quota = proposal.get("target_quota")

    if isinstance(previous_quota, int) and previous_quota > 0:
        instruction = (
            f"Attempt {attempt} failed Hard Verifier. "
            f"The rejected target_quota was {previous_quota}. "
            "Do not repeat a one-page increase. Recommend a materially "
            "larger target_quota with enough headroom for repeated sbrk "
            "growth. Prefer at least 1 MiB of additional headroom above "
            "the currently observed process sz."
        )
    else:
        instruction = (
            f"Attempt {attempt} failed. Recommend an increase_quota action "
            "with a positive target_quota and enough headroom for repeated "
            "sbrk growth."
        )

    constraints = prompt.setdefault("safety_constraints", [])

    if instruction not in constraints:
        constraints.append(instruction)

    return prompt


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Generate quota-only Groq proposals and retry rejected "
            "recovery candidates using Hard Verifier feedback."
        )
    )

    parser.add_argument("--memwatch-log", required=True)
    parser.add_argument("--before-quota", type=int, required=True)
    parser.add_argument("--max-attempts", type=int, default=3)
    parser.add_argument("--ticks", type=int, default=50)
    parser.add_argument("--interval", type=int, default=1)
    parser.add_argument("--step", type=int, default=4096)
    parser.add_argument("--timeout", type=int, default=240)

    parser.add_argument(
        "--reasoning-effort",
        choices=["low", "medium", "high"],
        default="low",
    )

    parser.add_argument("--model")
    parser.add_argument("--out-dir", default="logs/quota_groq_retry")

    args = parser.parse_args()

    if args.before_quota <= 0:
        raise SystemExit("[groq-retry] ERROR: before quota must be positive")

    if args.max_attempts <= 0:
        raise SystemExit("[groq-retry] ERROR: max attempts must be positive")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    initial_prompt_log = out_dir / "initial_prompt.log"

    print("[groq-retry] stage 1: generate initial LLM prompt")

    run(
        [
            sys.executable,
            "run_pipeline.py",
            "--memwatch-log",
            args.memwatch_log,
            "--prompt-out",
            str(initial_prompt_log),
            "--reset-state",
        ]
    )

    prompt = build_quota_only_prompt(
        extract_prompt_json(initial_prompt_log)
    )

    overall_summary = {
        "result": "RETRY_EXHAUSTED",
        "attempts": [],
    }

    for attempt in range(1, args.max_attempts + 1):
        print()
        print(f"[groq-retry] attempt {attempt}/{args.max_attempts}")

        attempt_dir = out_dir / f"attempt_{attempt}"
        attempt_dir.mkdir(parents=True, exist_ok=True)

        prompt_path = attempt_dir / "quota_prompt.json"
        proposal_path = attempt_dir / "proposal.json"
        agent_out_dir = attempt_dir / "agent"

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

        if action not in QUOTA_ACTIONS:
            reason = (
                "quota-only retry runner rejected unsupported action: "
                f"{action}"
            )

            print(f"[groq-retry] rejected: {reason}")

            overall_summary["attempts"].append(
                {
                    "attempt": attempt,
                    "proposal": proposal,
                    "decision": "REJECT_UNSUPPORTED_ACTION",
                    "reason": reason,
                }
            )

            prompt = add_retry_feedback(
                prompt,
                attempt,
                proposal,
                reason,
            )

            continue

        run(
            [
                sys.executable,
                "quota_agent_runner.py",
                "--memwatch-log",
                args.memwatch_log,
                "--proposal",
                str(proposal_path),
                "--before-quota",
                str(args.before_quota),
                "--approve",
                "--ticks",
                str(args.ticks),
                "--interval",
                str(args.interval),
                "--step",
                str(args.step),
                "--timeout",
                str(args.timeout),
                "--out-dir",
                str(agent_out_dir),
            ],
            allow_failure=True,
        )

        summary_path = agent_out_dir / "verification" / "summary.json"

        if not summary_path.exists():
            raise RuntimeError(
                f"verification summary was not created: {summary_path}"
            )

        verification = load_json(summary_path)
        decision = verification.get("decision", "UNKNOWN")
        reason = verification.get("reason", "reason unavailable")

        overall_summary["attempts"].append(
            {
                "attempt": attempt,
                "proposal": proposal,
                "decision": decision,
                "reason": reason,
                "verification_summary": str(summary_path),
            }
        )

        if decision in {"ACCEPT", "ACCEPT_RECOVERY"}:
            overall_summary["result"] = "RECOVERY_ACCEPTED"
            overall_summary["accepted_attempt"] = attempt
            overall_summary["accepted_proposal"] = proposal

            overall_summary_path = out_dir / "summary.json"
            save_json(overall_summary_path, overall_summary)

            print()
            print("[groq-retry] result: RECOVERY_ACCEPTED")
            print(f"[groq-retry] accepted attempt: {attempt}")
            print(
                "[groq-retry] accepted target quota: "
                f"{proposal.get('target_quota')}"
            )
            print(f"[groq-retry] summary: {overall_summary_path}")

            return

        print(f"[groq-retry] rejected decision: {decision}")
        print(f"[groq-retry] feedback: {reason}")

        prompt = add_retry_feedback(
            prompt,
            attempt,
            proposal,
            reason,
        )

    overall_summary_path = out_dir / "summary.json"
    save_json(overall_summary_path, overall_summary)

    print()
    print("[groq-retry] result: RETRY_EXHAUSTED")
    print(f"[groq-retry] summary: {overall_summary_path}")

    raise SystemExit(1)


if __name__ == "__main__":
    main()
