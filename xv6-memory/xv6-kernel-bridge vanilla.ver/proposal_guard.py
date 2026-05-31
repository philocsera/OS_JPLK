import argparse
import json
from pathlib import Path

STATE_FILE = Path(".bridge_state.json")

PROTECTED_NAMES = {"init", "sh"}
PROTECTED_PIDS = {1, 2}

PAGE_SIZE = 4096
MAX_SWAPOUT_PAGES = 16

ALLOWED_ACTIONS = {
    "no_action",
    "keep_quota",
    "increase_quota",
    "decrease_quota",
    "release_quota",
    "swapout",
    "inspect_process",
}

MUTATING_ACTIONS = {
    "increase_quota",
    "decrease_quota",
    "release_quota",
    "swapout",
}


def load_json(path):
    with Path(path).open("r", encoding="utf-8") as f:
        return json.load(f)


def load_state():
    if not STATE_FILE.exists():
        raise ValueError("run bridge.py first: state file not found")

    with STATE_FILE.open("r", encoding="utf-8") as f:
        return json.load(f)


def find_process(state, target_pid):
    for key, proc in state.items():
        if key == "_system":
            continue

        if int(proc.get("pid", -1)) == target_pid:
            return proc

    return None


def validate_proposal(proposal, state):
    errors = []

    action = proposal.get("action")
    target_pid = proposal.get("target_pid", 0)
    target_quota = proposal.get("target_quota")
    swapout_pages = proposal.get("swapout_pages")
    reason = proposal.get("reason", "")
    confidence = proposal.get("confidence")

    if action not in ALLOWED_ACTIONS:
        return [f"unsupported action: {action}"]

    if not isinstance(target_pid, int):
        return ["target_pid must be an integer"]

    if not isinstance(reason, str) or not reason.strip():
        errors.append("reason must be a non-empty string")

    if confidence not in {"low", "medium", "high"}:
        errors.append("confidence must be low, medium, or high")

    if action == "no_action":
        return errors

    if action == "inspect_process" and target_pid == 0:
        return errors

    proc = find_process(state, target_pid)

    if proc is None:
        return [f"target pid not found: {target_pid}"]

    name = proc.get("name", "")
    current_sz = int(proc.get("sz", 0))
    current_quota = int(proc.get("quota", 0))

    if target_pid in PROTECTED_PIDS or name in PROTECTED_NAMES:
        return [
            f"protected process cannot be modified: "
            f"pid={target_pid} name={name}"
        ]

    if action == "increase_quota":
        if not isinstance(target_quota, int):
            errors.append("increase_quota requires integer target_quota")
        elif target_quota <= current_quota:
            errors.append("target_quota must exceed current quota")

    elif action == "decrease_quota":
        if not isinstance(target_quota, int):
            errors.append("decrease_quota requires integer target_quota")
        elif target_quota < current_sz + PAGE_SIZE:
            errors.append("target_quota must be at least current sz + 4096")
        elif current_quota == 0 or target_quota >= current_quota:
            errors.append(
                "target_quota must be below current nonzero quota"
            )

    elif action == "release_quota":
        if target_quota != 0:
            errors.append("release_quota requires target_quota = 0")

    elif action == "swapout":
        if not isinstance(swapout_pages, int):
            errors.append("swapout requires integer swapout_pages")
        elif not 1 <= swapout_pages <= MAX_SWAPOUT_PAGES:
            errors.append("swapout_pages must be between 1 and 16")
        else:
            system = state.get("_system", {})
            used_slots = int(system.get("used_slots", 0))
            total_slots = int(system.get("total_slots", 0))
            free_slots = total_slots - used_slots

            if total_slots > 0 and swapout_pages > free_slots:
                errors.append("not enough free swap slots")

    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--proposal", required=True)
    args = parser.parse_args()

    try:
        proposal = load_json(args.proposal)
        state = load_state()
        errors = validate_proposal(proposal, state)
    except Exception as error:
        print(f"[guard] ERROR: {error}")
        raise SystemExit(1)

    if errors:
        print("[guard] REJECTED")

        for error in errors:
            print(f"- {error}")

        raise SystemExit(1)

    print("[guard] VALIDATED")

    if proposal.get("action") in MUTATING_ACTIONS:
        print("[guard] status: PENDING_APPROVAL")
    else:
        print("[guard] status: SAFE_READ_ONLY")

    print("[guard] no command executed")
    print(json.dumps(proposal, indent=2))


if __name__ == "__main__":
    main()
