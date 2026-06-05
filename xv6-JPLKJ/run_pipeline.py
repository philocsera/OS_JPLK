#!/usr/bin/env python3
import argparse
import subprocess
from pathlib import Path

DEFAULT_PROMPT_LOG = Path("/tmp/xv6_llm_prompt.log")


def run_command(command):
    return subprocess.run(
        command,
        text=True,
        capture_output=True,
        check=False,
    )


def print_output(result):
    if result.stdout:
        print(result.stdout, end="")

    if result.stderr:
        print(result.stderr, end="")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--memwatch-log", required=True)
    parser.add_argument("--proposal")
    parser.add_argument("--prompt-out", default=str(DEFAULT_PROMPT_LOG))
    parser.add_argument("--approve", action="store_true")
    parser.add_argument("--reset-state", action="store_true")
    args = parser.parse_args()

    memwatch_log = Path(args.memwatch_log)
    prompt_out = Path(args.prompt_out)

    if not memwatch_log.exists():
        print(f"[pipeline] ERROR: log file not found: {memwatch_log}")
        raise SystemExit(1)

    if args.reset_state:
        result = run_command(["python3", "bridge.py", "--reset"])
        print_output(result)

        if result.returncode != 0:
            raise SystemExit(result.returncode)

    print("[pipeline] stage 1: analyze memwatch log")

    bridge_result = run_command(
        [
            "python3",
            "bridge.py",
            "--file",
            str(memwatch_log),
            "--prompt",
        ]
    )

    print_output(bridge_result)

    if bridge_result.returncode != 0:
        print("[pipeline] ERROR: bridge analysis failed")
        raise SystemExit(bridge_result.returncode)

    prompt_out.write_text(bridge_result.stdout, encoding="utf-8")

    prompt_created = "[bridge] generated LLM prompt" in bridge_result.stdout

    if not prompt_created:
        print("[pipeline] result: NO_LLM_REQUEST")
        print("[pipeline] no policy proposal is required")
        return

    print(f"[pipeline] LLM prompt saved: {prompt_out}")

    if not args.proposal:
        print("[pipeline] status: WAITING_FOR_LLM_PROPOSAL")
        print("[pipeline] no command executed")
        return

    proposal_path = Path(args.proposal)

    if not proposal_path.exists():
        print(f"[pipeline] ERROR: proposal file not found: {proposal_path}")
        raise SystemExit(1)

    print("[pipeline] stage 2: validate proposal")

    guard_result = run_command(
        [
            "python3",
            "proposal_guard.py",
            "--proposal",
            str(proposal_path),
        ]
    )

    print_output(guard_result)

    if guard_result.returncode != 0:
        print("[pipeline] result: PROPOSAL_REJECTED")
        raise SystemExit(guard_result.returncode)

    print("[pipeline] stage 3: build approved dry-run command")

    apply_command = [
        "python3",
        "apply_policy.py",
        "--proposal",
        str(proposal_path),
        "--dry-run",
    ]

    if args.approve:
        apply_command.append("--approve")

    apply_result = run_command(apply_command)
    print_output(apply_result)

    if apply_result.returncode != 0:
        print("[pipeline] result: APPLY_DRY_RUN_FAILED")
        raise SystemExit(apply_result.returncode)

    if args.approve:
        print("[pipeline] result: APPROVED_DRY_RUN_COMPLETE")
    else:
        print("[pipeline] result: PENDING_APPROVAL")

    print("[pipeline] no xv6 command executed")


if __name__ == "__main__":
    main()
