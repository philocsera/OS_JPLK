#!/usr/bin/env python3
import json
import sys
import argparse
from pathlib import Path

PROTECTED_NAMES = {"init", "sh"}
WARN_USAGE = 70
DANGER_USAGE = 90
STATE_FILE = Path(".bridge_state.json")

def load_state():
    if not STATE_FILE.exists():
        return {}
    try:
        with STATE_FILE.open("r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def save_state(state):
    with STATE_FILE.open("w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)

def extract_json_lines(text):
    snapshots = []

    for raw in text.splitlines():
        raw = raw.strip()
        if not raw:
            continue

        start = raw.find('{"type":"memstat"')
        if start == -1:
            start = raw.find('{"type": "memstat"')
        if start == -1:
            continue

        candidate = raw[start:]

        try:
            snapshots.append(json.loads(candidate))
        except json.JSONDecodeError:
            pass

    return snapshots

def analyze_snapshot(snapshot, state):
    results = []

    for p in snapshot.get("processes", []):
        pid = p.get("pid")
        name = p.get("name", "")
        sz = int(p.get("sz", 0))
        quota = int(p.get("quota", 0))
        usage = int(p.get("usage", -1))

        key = f"{pid}:{name}"
        prev_sz = int(state.get(key, {}).get("sz", sz))
        growth = sz - prev_sz

        state[key] = {
            "pid": pid,
            "name": name,
            "sz": sz,
            "quota": quota,
            "usage": usage,
        }

        if name in PROTECTED_NAMES:
            results.append((pid, name, "SKIP", "protected process", "no_action"))
            continue

        if quota > 0:
            if usage >= DANGER_USAGE:
                results.append((pid, name, "DANGER", f"usage={usage}% quota={quota}", "send_to_llm"))
            elif usage >= WARN_USAGE:
                results.append((pid, name, "WARN", f"usage={usage}% quota={quota}", "log_only"))
            else:
                results.append((pid, name, "OK", f"usage={usage}% quota={quota}", "no_action"))
        else:
            if growth > 0 and sz >= 32768:
                results.append((pid, name, "WATCH", f"sz={sz} growth={growth}", "maybe_send_to_llm"))
            else:
                results.append((pid, name, "OK", f"sz={sz} quota=0", "no_action"))

    return results

def print_results(results):
    print("[bridge] dry-run diagnosis")

    need_llm = False

    for pid, name, level, detail, action in results:
        print(f"- [{level}] pid={pid} name={name} {detail} action={action}")

        if action in ("send_to_llm", "maybe_send_to_llm"):
            need_llm = True

    if need_llm:
        print("[bridge] result: LLM diagnosis is needed")
    else:
        print("[bridge] result: LLM diagnosis is not needed")


def build_llm_prompt(snapshot, results):
    danger_processes = []

    for r in results:
        # tuple style used by current bridge.py:
        # (pid, name, level, detail, action)
        if isinstance(r, tuple):
            pid, name, level, detail, action = r

            if action == "send_to_llm":
                danger_processes.append({
                    "level": level,
                    "pid": pid,
                    "name": name,
                    "detail": detail,
                    "action": action
                })

        # dict style support for future version
        elif isinstance(r, dict):
            if r.get("action") == "send_to_llm":
                danger_processes.append(r)

    if not danger_processes:
        return None

    prompt_data = {
        "task": "Analyze xv6 process memory quota status and recommend an action.",
        "system_context": {
            "os": "xv6-riscv",
            "kernel_policy": "growproc blocks memory growth when process size exceeds mem_quota",
            "protected_processes": ["init", "sh"],
            "bridge_rule": "Only processes with quota usage >= 90% are sent to LLM"
        },
        "snapshot_tick": snapshot.get("tick", "?"),
        "danger_processes": danger_processes,
        "allowed_actions": [
            "no_action",
            "recommend_keep_quota",
            "recommend_setquota",
            "recommend_increase_quota",
            "recommend_inspect_process"
        ],
        "response_format": {
            "action": "one of allowed_actions",
            "pid": "target process pid",
            "quota": "recommended quota value or current quota",
            "reason": "short explanation",
            "confidence": "low | medium | high"
        }
    }

    prompt_header = "\n".join([
        "You are an OS memory diagnosis assistant.",
        "Analyze the following xv6 memory quota status.",
        "Do not directly execute commands.",
        "Return only one JSON object using the required response_format."
    ]) + "\n\n"

    return prompt_header + json.dumps(prompt_data, indent=2)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--stdin", action="store_true")
    parser.add_argument("--file")
    parser.add_argument("--reset", action="store_true")
    parser.add_argument("--prompt", action="store_true", help="print LLM prompt when needed")
    args = parser.parse_args()

    if args.reset:
        if STATE_FILE.exists():
            STATE_FILE.unlink()
        print("[bridge] state reset")
        return

    if args.file:
        text = Path(args.file).read_text(encoding="utf-8")
    elif args.stdin:
        text = sys.stdin.read()
    else:
        print("usage:")
        print("  python3 bridge.py --reset")
        print("  python3 bridge.py --stdin")
        print("  python3 bridge.py --file memwatch.log")
        return

    snapshots = extract_json_lines(text)

    if not snapshots:
        print("[bridge] no memstat JSON found")
        return

    state = load_state()

    for snapshot in snapshots:
        tick = snapshot.get("tick", "?")
        print(f"\n[bridge] snapshot tick={tick}")
        results = analyze_snapshot(snapshot, state)
        print_results(results)

        if args.prompt:
            prompt = build_llm_prompt(snapshot, results)
            if prompt:
                print("\n[bridge] generated LLM prompt")
                print("----- BEGIN LLM PROMPT -----")
                print(prompt)
                print("----- END LLM PROMPT -----")

    save_state(state)

if __name__ == "__main__":
    main()
