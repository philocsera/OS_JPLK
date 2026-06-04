#!/usr/bin/env python3
import argparse
import json

from proposal_guard import (
    MUTATING_ACTIONS,
    load_json,
    load_state,
    validate_proposal,
)


def build_xv6_command(proposal):
    action = proposal.get("action")
    target_pid = proposal.get("target_pid", 0)
    target_quota = proposal.get("target_quota")
    swapout_pages = proposal.get("swapout_pages")

    if action in {"no_action", "keep_quota"}:
        return None

    if action == "inspect_process":
        return "memwatch json 1 0"

    if action in {
        "increase_quota",
        "decrease_quota",
        "release_quota",
    }:
        return f"setquota {target_pid} {target_quota}"

    if action == "swapout":
        return f"swapctl {target_pid} {swapout_pages}"

    raise ValueError(f"unsupported action: {action}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--proposal", required=True)
    parser.add_argument("--approve", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.dry_run:
        print("[apply] ERROR: only --dry-run mode is supported")
        print("[apply] no command executed")
        raise SystemExit(1)

    try:
        proposal = load_json(args.proposal)
        state = load_state()
        errors = validate_proposal(proposal, state)
    except Exception as error:
        print(f"[apply] ERROR: {error}")
        raise SystemExit(1)

    if errors:
        print("[apply] REJECTED")

        for error in errors:
            print(f"- {error}")

        print("[apply] no command executed")
        raise SystemExit(1)

    action = proposal.get("action")
    command = build_xv6_command(proposal)

    if action in MUTATING_ACTIONS and not args.approve:
        print("[apply] VALIDATED")
        print("[apply] status: PENDING_APPROVAL")

        if command:
            print(f"[apply] proposed xv6 command: {command}")

        print("[apply] no command executed")
        return

    if action in MUTATING_ACTIONS:
        print("[apply] VALIDATED")
        print("[apply] status: APPROVED_DRY_RUN")
    else:
        print("[apply] VALIDATED")
        print("[apply] status: SAFE_READ_ONLY")

    if command:
        print(f"[apply] proposed xv6 command: {command}")
    else:
        print("[apply] proposed xv6 command: none")

    print("[apply] no command executed")
    print(json.dumps(proposal, indent=2))


if __name__ == "__main__":
    main()
