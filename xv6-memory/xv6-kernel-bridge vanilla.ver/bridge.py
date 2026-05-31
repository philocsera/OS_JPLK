#!/usr/bin/env python3
import json
import sys
import argparse
from pathlib import Path

PROTECTED_NAMES = {"init", "sh"}
WARN_USAGE = 70
DANGER_USAGE = 90
SWAP_WARN_USAGE = 50.0
SWAP_DANGER_USAGE = 80.0
SWAP_CYCLE_WINDOW = 5
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

    # 시스템 전체 swap 상태와 이전 snapshot 대비 변화량
    swap = snapshot.get("swap", {})
    used_slots = int(swap.get("used_slots", 0))
    total_slots = int(swap.get("total_slots", 0))

    if total_slots > 0:
        swap_usage_percent = round((used_slots * 100.0) / total_slots, 2)
    else:
        swap_usage_percent = -1.0

    prev_system = state.get("_system", {})
    prev_used_slots = int(prev_system.get("used_slots", used_slots))
    swap_used_delta = used_slots - prev_used_slots

    state["_system"] = {
        "used_slots": used_slots,
        "total_slots": total_slots,
        "swap_usage_percent": swap_usage_percent,
    }

    snapshot["_bridge_swap"] = {
        "used_slots": used_slots,
        "total_slots": total_slots,
        "swap_usage_percent": swap_usage_percent,
        "used_slots_delta": swap_used_delta,
    }

    # system swap pressure
    if swap_usage_percent >= SWAP_DANGER_USAGE:
        results.append((
            0,
            "system",
            "DANGER",
            f"swap_usage={swap_usage_percent}% "
            f"used_slots={used_slots}/{total_slots} "
            f"delta={swap_used_delta}",
            "send_to_llm",
        ))
    elif swap_usage_percent >= SWAP_WARN_USAGE and swap_used_delta > 0:
        results.append((
            0,
            "system",
            "WARN",
            f"swap_usage={swap_usage_percent}% "
            f"used_slots={used_slots}/{total_slots} "
            f"delta={swap_used_delta}",
            "log_only",
        ))

    for p in snapshot.get("processes", []):
        pid = p.get("pid")
        name = p.get("name", "")
        sz = int(p.get("sz", 0))
        quota = int(p.get("quota", 0))
        usage = int(p.get("usage", -1))
        quota_denied_count = int(p.get("quota_denied_count", 0))
        swapout_count = int(p.get("swapout_count", 0))
        swapin_count = int(p.get("swapin_count", 0))

        key = f"{pid}:{name}"
        prev = state.get(key, {})

        prev_sz = int(prev.get("sz", sz))
        prev_quota_denied = int(
            prev.get("quota_denied_count", quota_denied_count)
        )
        prev_swapout = int(prev.get("swapout_count", swapout_count))
        prev_swapin = int(prev.get("swapin_count", swapin_count))

        growth = sz - prev_sz
        quota_denied_delta = quota_denied_count - prev_quota_denied
        swapout_delta = swapout_count - prev_swapout
        swapin_delta = swapin_count - prev_swapin

        prev_outstanding = int(
            prev.get(
                "outstanding_swap_pages",
                max(0, prev_swapout - prev_swapin),
            )
        )
        outstanding_swap_pages = max(0, swapout_count - swapin_count)

        swap_cycle_count = int(prev.get("swap_cycle_count", 0))
        swap_activity_age = int(prev.get("swap_activity_age", 0))

        if swapout_delta > 0 or swapin_delta > 0:
            swap_activity_age = 0
        else:
            swap_activity_age += 1

        if swap_activity_age > SWAP_CYCLE_WINDOW:
            swap_cycle_count = 0

        if swapin_delta > 0 and prev_outstanding > 0:
            swap_cycle_count += 1

        thrashing_suspected = swap_cycle_count >= 2

        state[key] = {
            "pid": pid,
            "name": name,
            "sz": sz,
            "quota": quota,
            "usage": usage,
            "growth": growth,
            "quota_denied_count": quota_denied_count,
            "quota_denied_delta": quota_denied_delta,
            "swapout_count": swapout_count,
            "swapout_delta": swapout_delta,
            "swapin_count": swapin_count,
            "swapin_delta": swapin_delta,
            "outstanding_swap_pages": outstanding_swap_pages,
            "swap_cycle_count": swap_cycle_count,
            "swap_activity_age": swap_activity_age,
            "thrashing_suspected": thrashing_suspected,
        }

        snapshot.setdefault("_bridge_process_metrics", {})[key] = state[key]

        if name in PROTECTED_NAMES:
            results.append((pid, name, "SKIP", "protected process", "no_action"))
            continue

        danger_reasons = []
        watch_reasons = []

        if quota > 0 and usage >= DANGER_USAGE:
            danger_reasons.append(f"quota_usage={usage}%")

        if quota_denied_delta > 0:
            danger_reasons.append(
                f"quota_denied_delta={quota_denied_delta}"
            )

        if thrashing_suspected:
            danger_reasons.append(
                f"thrashing_suspected "
                f"swap_cycle_count={swap_cycle_count} "
                f"swapout_delta={swapout_delta} "
                f"swapin_delta={swapin_delta}"
            )

        if quota > 0 and WARN_USAGE <= usage < DANGER_USAGE:
            watch_reasons.append(f"quota_usage={usage}%")

        if growth > 0 and sz >= 32768:
            watch_reasons.append(f"growth={growth} sz={sz}")

        if swapout_delta > 0:
            watch_reasons.append(f"swapout_delta={swapout_delta}")

        if swapin_delta > 0:
            watch_reasons.append(f"swapin_delta={swapin_delta}")

        if swap_cycle_count == 1 and not thrashing_suspected:
            watch_reasons.append("swap_recovery_cycle=1")

        if danger_reasons:
            results.append((
                pid,
                name,
                "DANGER",
                ", ".join(danger_reasons),
                "send_to_llm",
            ))
        elif watch_reasons:
            results.append((
                pid,
                name,
                "WATCH",
                ", ".join(watch_reasons),
                "log_only",
            ))
        else:
            results.append((
                pid,
                name,
                "OK",
                f"sz={sz} quota={quota}",
                "no_action",
            ))

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

    process_lookup = snapshot.get("_bridge_process_metrics", {})

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
                    "action": action,
                    "metrics": (
                        snapshot.get("_bridge_swap", {})
                        if pid == 0
                        else process_lookup.get(f"{pid}:{name}", {})
                    )
                })

        # dict style support for future version
        elif isinstance(r, dict):
            if r.get("action") == "send_to_llm":
                danger_processes.append(r)

    if not danger_processes:
        return None

    prompt_data = {
        "task": "Analyze xv6 quota pressure, swap pressure, and possible thrashing. Recommend exactly one safe runtime policy candidate.",
        "system_context": {
            "os": "xv6-riscv",
            "kernel_policy": "growproc blocks memory growth when process size exceeds mem_quota",
            "swap_policy": "swapout moves a selected process page to swap.img; later access triggers page-fault-based swapin",
            "protected_processes": ["init", "sh"],
            "bridge_rule": "Only DANGER findings are sent to the LLM. WATCH findings are logged locally."
        },
        "snapshot_tick": snapshot.get("tick", "?"),
        "system_swap": snapshot.get("_bridge_swap", snapshot.get("swap", {})),
        "danger_processes": danger_processes,
        "observed_processes": snapshot.get("processes", []),
        "safety_constraints": [
            "Recommend only one action for at most one target pid.",
            "Do not execute commands or modify kernel state directly.",
            "Never modify or swap out protected processes: init, sh.",
            "decrease_quota requires target_quota >= current_sz + 4096.",
            "release_quota requires target_quota = 0 and manual approval.",
            "swapout requires a conservative positive page count and manual approval."
        ],
        "allowed_actions": [
            "no_action",
            "keep_quota",
            "increase_quota",
            "decrease_quota",
            "release_quota",
            "swapout",
            "inspect_process"
        ],
        "response_format": {
            "action": "one of allowed_actions",
            "target_pid": "integer process pid, or 0 for system-wide inspection",
            "target_quota": "integer bytes or null",
            "swapout_pages": "positive integer pages or null",
            "reason": "short explanation based on observed metrics",
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
