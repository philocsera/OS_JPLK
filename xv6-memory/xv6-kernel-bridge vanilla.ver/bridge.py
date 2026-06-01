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

    processes = snapshot.get("processes", [])
    current_keys = {
        f"{p.get('pid')}:{p.get('name', '')}"
        for p in processes
    }

    # 이전 snapshot에 있던 quota 관리 프로세스가 사라졌는지 확인
    for key, prev in list(state.items()):
        if key.startswith("_") or not isinstance(prev, dict):
            continue

        prev_quota = int(prev.get("quota", 0))

        if prev_quota <= 0 or key in current_keys:
            continue

        if prev.get("disappearance_reported", False):
            continue

        prev_pid = prev.get("pid", 0)
        prev_name = prev.get("name", "")
        prev_sz = int(prev.get("sz", 0))

        results.append((
            prev_pid,
            prev_name,
            "DANGER",
            f"managed_process_disappeared "
            f"previous_sz={prev_sz} "
            f"previous_quota={prev_quota}",
            "send_to_llm",
        ))

        prev["disappearance_reported"] = True

    for p in processes:
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
            "disappearance_reported": False,
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

def _clamp01(x):
    # 각 축을 [0,1]로 강제 (기하평균 입력 안전 보장)
    return max(0.0, min(1.0, x))


def compute_score(snapshot, state):
    # 3축 기하평균 효율성 score. analyze_snapshot 이후에 호출해야 한다
    # (snapshot["_bridge_process_metrics"]가 채워져 있어야 deltas 접근 가능).
    # 규칙 분류기(OK/WATCH/DANGER)와는 완전히 별개 — 분류기=트리거, score=평가.
    procs = snapshot.get("processes", [])
    metrics = snapshot.get("_bridge_process_metrics", {})

    def met(p):
        return metrics.get(f"{p.get('pid')}:{p.get('name', '')}", {})

    # ── 성능항: quota deny가 적나 (soft deny → "막힌 정도") ──
    # delta는 같은 key 기준 단조증가지만 pid 재활용 대비 max(0,·) 방어.
    total_denied_delta = sum(
        max(0, int(met(p).get("quota_denied_delta", 0))) for p in procs
    )
    active = len([p for p in procs if p.get("state") in (3, 4)])  # RUNNABLE+RUNNING
    denied_rate = total_denied_delta / max(active, 1)
    perf = _clamp01(1 - min(denied_rate, 1))

    # ── 안정성항: thrashing이 없나 ──
    swap_cycle_sum = sum(int(met(p).get("swap_cycle_count", 0)) for p in procs)
    thrash_ratio = min(swap_cycle_sum / SWAP_CYCLE_WINDOW, 1)
    stab = _clamp01(1 - 0.5 * thrash_ratio)

    # ── 효율성항: 적정성 × 활성성 ──
    # [버그수정1] quota>0 proc만으로 분자·분모를 맞춰 apples-to-apples 비교.
    # 예전엔 분자 total_sz가 전체 proc(init/sh 포함)을 세고 분모는 quota>0만 세서,
    # quota 없는 init/sh의 sz가 분자에만 새어 usage_ratio가 부풀려졌다.
    # → deny가 0인데도 eff=0 → score 0 나오던 문제의 원인. 이제 양쪽 다 managed만.
    managed = [p for p in procs if int(p.get("quota", 0)) > 0]
    total_sz = sum(int(p.get("sz", 0)) for p in managed)
    total_quota = sum(int(p.get("quota", 0)) for p in managed)
    usage_ratio = total_sz / max(total_quota, 1)          # 할당 대비 실사용

    # 부하 = RUNNABLE+RUNNING, bridge가 이동평균으로 근사 (state["_score"]에 누적).
    # [버그수정2/임시] RUNNABLE(3)만 세면 CPUS=1에서 돌고 있는 워크로드가 늘 RUNNING(4)이라
    # load_now가 0이 됨 → RUNNING(4)도 포함시켜 1개라도 부하로 잡히게.
    # ★임시방편: 실제 부하의 정답은 커널 ready_ticks(시간 적분)다. 실측 후 배선 결정.
    # ★ state["_system"]은 analyze_snapshot이 통째로 덮어쓰므로 거기 저장 금지.
    load_now = len([p for p in procs if p.get("state") in (3, 4)])
    score_state = state.setdefault("_score", {})
    prev_load = float(score_state.get("prev_load", load_now))  # cold start = 현재값
    load_avg = prev_load * 0.7 + load_now * 0.3
    score_state["prev_load"] = load_avg

    expected = min(0.5 + 0.1 * load_avg, 0.95)            # 일 많으면 높은 사용률 기대
    adequacy = _clamp01(1 - abs(usage_ratio - expected) / max(expected, 0.3))

    # 활성성: 살아있는 프로세스가 메모리를 실제로 쓰고 있나.
    # [버그수정3] 활성=RUNNABLE(3)+RUNNING(4)+SLEEPING(2). 비활성=ZOMBIE(5)만.
    #   기준3의 진짜 의도는 "죽었는데 메모리 쥔(ZOMBIE)" 감점이다. SLEEPING은 디스크
    #   I/O 대기 등 정상 활동인데, 예전엔 (3,4)만 활성으로 봐서 I/O 대기 순간을 "노는 것"
    #   으로 오판 → active_mem=0 → eff=0 → score 0 (중간 틱 0점 버그). 이제 SLEEPING 포함.
    #   ★ load_now(CPU 부하)와는 구분: load는 "CPU 대기"라 (3,4) 유지가 맞고,
    #     activeness(메모리 활용)는 I/O 대기도 살아있으므로 (2,3,4)가 맞다.
    # total_sz와 동일하게 managed(quota>0)만 대상으로 맞춰 비율 일관성 유지.
    active_mem = sum(int(p.get("sz", 0)) for p in managed if p.get("state") in (2, 3, 4))
    activeness = _clamp01(active_mem / max(total_sz, 1))

    eff = _clamp01(adequacy * activeness)

    # ── 기하평균 (한 축 0이면 전체 0 — 의도된 동작, 버그 아님) ──
    score = 100 * (perf * stab * eff) ** (1.0 / 3.0)

    return {
        "score": round(score, 1),
        "perf": round(perf, 3),
        "stab": round(stab, 3),
        "eff": round(eff, 3),
        "breakdown": {
            "total_denied_delta": total_denied_delta,
            "active": active,
            "denied_rate": round(denied_rate, 3),
            "swap_cycle_sum": swap_cycle_sum,
            "thrash_ratio": round(thrash_ratio, 3),
            "total_sz": total_sz,
            "total_quota": total_quota,
            "usage_ratio": round(usage_ratio, 3),
            "load_now": load_now,
            "load_avg": round(load_avg, 3),
            "expected": round(expected, 3),
            "adequacy": round(adequacy, 3),
            "active_mem": active_mem,
            "activeness": round(activeness, 3),
        },
    }


def print_score(s):
    axes = {"perf": s["perf"], "stab": s["stab"], "eff": s["eff"]}
    worst = min(axes, key=axes.get)
    print(
        f"[bridge] efficiency score = {s['score']}/100  "
        f"(perf={s['perf']} stab={s['stab']} eff={s['eff']})  "
        f"<- lowest axis: {worst}"
    )
    b = s["breakdown"]
    print(
        f"  perf : denied_delta={b['total_denied_delta']} "
        f"active={b['active']} denied_rate={b['denied_rate']}"
    )
    print(
        f"  stab : swap_cycle_sum={b['swap_cycle_sum']} "
        f"thrash_ratio={b['thrash_ratio']}"
    )
    print(
        f"  eff  : usage_ratio={b['usage_ratio']} "
        f"(sz={b['total_sz']}/quota={b['total_quota']}) "
        f"expected={b['expected']} adequacy={b['adequacy']}"
    )
    print(
        f"         active_mem={b['active_mem']} activeness={b['activeness']} "
        f"| load_now={b['load_now']} load_avg={b['load_avg']}"
    )


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

        score = compute_score(snapshot, state)
        print_score(score)

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
