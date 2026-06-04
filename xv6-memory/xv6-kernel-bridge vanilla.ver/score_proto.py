#!/usr/bin/env python3
# score_proto.py — swap-positive 통합 score 프로토타입 (bridge.py 무접촉)
#
# 목적: bridge.compute_score(3축 기하평균)의 perf 축에 "메모리 압박 대비
#       swap 흡수량"을 곱해, swap이 OOM 압박을 실제로 풀어주면 perf를 지키고,
#       압박이 있는데 swap을 안 하면 perf를 깎는 신호를 넣는다.
#       stab/eff 는 bridge.compute_score 와 동일 로직(참고 일관성 유지).
#
# 핵심 공식:
#   pressure    = min( total_sz_pages / RAM_PAGES, 1.0 )     # 메모리 압박도(sz 기준)
#   swap_relief = min( used_slots / SWAP_CAPACITY, 1.0 )     # swap 흡수량
#   unrelieved  = max( pressure - swap_relief, 0 )           # 압박 중 swap 못 푼 부분
#   quota_perf  = 1 - min(denied_rate, 1)                    # 기존 bridge perf
#   perf        = quota_perf * (1 - unrelieved)              # ★ swap 통합
#   stab        = 1 - 0.5 * thrash_ratio                     # 기존 그대로
#   eff         = adequacy * activeness                      # 기존 그대로
#   score       = 100 * (perf * stab * eff) ** (1/3)
#
# 게임 방지(수학적 보장):
#   swap_factor = (1 - unrelieved) = 1 - max(pressure - swap_relief, 0) <= 1
#   → perf = quota_perf * swap_factor <= quota_perf  (항상)
#   즉 swap 은 perf 를 quota 기준선 이하로만 움직인다(보존/감점). 절대 보너스 없음.
#   등호(perf == quota_perf)는 unrelieved == 0 일 때 = 압박이 없거나(pressure 0)
#   swap 이 압박을 다 흡수(swap_relief >= pressure)했을 때.

# ── 상수 ──
PGSIZE = 4096
RAM_PAGES = 32768          # 128MB / 4KB  (Makefile -m 128M, PHYSTOP=KERNBASE+128MB)
SWAP_CAPACITY = 16384      # NSWAP (swap.h:30) = 64MB / 4KB
SWAP_CYCLE_WINDOW = 5      # bridge.py 와 동일


def _clamp01(x):
    # 각 축을 [0,1]로 강제 (기하평균 입력 안전 보장) — bridge._clamp01 과 동일
    return max(0.0, min(1.0, x))


def compute_score_proto(snapshot, state):
    """bridge.compute_score 미러 + perf 에 swap-positive 통합.

    snapshot 구조(= bridge 가 만드는 것과 동일):
      snapshot["processes"]               : [{pid,name,state,sz,quota, ...}, ...]
      snapshot["_bridge_process_metrics"] : {"pid:name": {quota_denied_delta,
                                             swap_cycle_count, ...}}
      snapshot["swap"]                    : {used_slots, total_slots}
    """
    procs = snapshot.get("processes", [])
    metrics = snapshot.get("_bridge_process_metrics", {})

    def met(p):
        return metrics.get(f"{p.get('pid')}:{p.get('name', '')}", {})

    # ── 성능항(quota 부분) — bridge.compute_score 와 동일 ──
    total_denied_delta = sum(
        max(0, int(met(p).get("quota_denied_delta", 0))) for p in procs
    )
    active = len([p for p in procs if p.get("state") in (3, 4)])  # RUNNABLE+RUNNING
    denied_rate = total_denied_delta / max(active, 1)
    quota_perf = _clamp01(1 - min(denied_rate, 1))

    # ── 성능항(swap 통합) — ★ 신규 ──
    # 압박도: 전체 proc 의 sz 합(=RAM 점유 추정). bridge 의 sz 는 byte 라 page 로 환산.
    #  ⚠️ managed(quota>0)만 보는 eff 와 달리, 물리 RAM 압박은 quota 없는 memfill/sh 도
    #     포함해야 하므로 '전체 proc' 의 sz 를 합한다.
    total_sz_bytes_all = sum(int(p.get("sz", 0)) for p in procs)
    total_sz_pages = total_sz_bytes_all / PGSIZE
    pressure = min(total_sz_pages / RAM_PAGES, 1.0)

    swap = snapshot.get("swap", {})
    used_slots = int(swap.get("used_slots", 0))
    swap_relief = min(used_slots / SWAP_CAPACITY, 1.0)

    unrelieved = max(pressure - swap_relief, 0.0)
    swap_factor = 1 - unrelieved                       # <= 1 (게임 방지 보장)
    perf = _clamp01(quota_perf * swap_factor)

    # ── 안정성항: thrashing 이 없나 — bridge 와 동일 ──
    swap_cycle_sum = sum(int(met(p).get("swap_cycle_count", 0)) for p in procs)
    thrash_ratio = min(swap_cycle_sum / SWAP_CYCLE_WINDOW, 1)
    stab = _clamp01(1 - 0.5 * thrash_ratio)

    # ── 효율성항: 적정성 × 활성성 — bridge 와 동일 ──
    managed = [p for p in procs if int(p.get("quota", 0)) > 0]
    total_sz = sum(int(p.get("sz", 0)) for p in managed)
    total_quota = sum(int(p.get("quota", 0)) for p in managed)
    usage_ratio = total_sz / max(total_quota, 1)

    load_now = len([p for p in procs if p.get("state") in (3, 4)])
    score_state = state.setdefault("_score", {})
    prev_load = float(score_state.get("prev_load", load_now))
    load_avg = prev_load * 0.7 + load_now * 0.3
    score_state["prev_load"] = load_avg

    expected = min(0.5 + 0.1 * load_avg, 0.95)
    adequacy = _clamp01(1 - abs(usage_ratio - expected) / max(expected, 0.3))

    active_mem = sum(
        int(p.get("sz", 0)) for p in managed if p.get("state") in (2, 3, 4)
    )
    activeness = _clamp01(active_mem / max(total_sz, 1))
    eff = _clamp01(adequacy * activeness)

    # ── 기하평균 ──
    score = 100 * (perf * stab * eff) ** (1.0 / 3.0)

    return {
        "score": round(score, 1),
        "perf": round(perf, 3),
        "stab": round(stab, 3),
        "eff": round(eff, 3),
        "breakdown": {
            # perf 분해 (quota × swap)
            "quota_perf": round(quota_perf, 3),
            "pressure": round(pressure, 3),
            "swap_relief": round(swap_relief, 3),
            "unrelieved": round(unrelieved, 3),
            "swap_factor": round(swap_factor, 3),
            "used_slots": used_slots,
            "total_sz_pages": round(total_sz_pages, 1),
            # 기존 축
            "denied_rate": round(denied_rate, 3),
            "swap_cycle_sum": swap_cycle_sum,
            "thrash_ratio": round(thrash_ratio, 3),
            "usage_ratio": round(usage_ratio, 3),
            "adequacy": round(adequacy, 3),
            "activeness": round(activeness, 3),
        },
    }


def print_score_proto(label, s):
    b = s["breakdown"]
    print(f"[{label}] score = {s['score']}/100  "
          f"(perf={s['perf']} stab={s['stab']} eff={s['eff']})")
    print(f"    perf = quota_perf({b['quota_perf']}) x swap_factor({b['swap_factor']})  "
          f"| pressure={b['pressure']} swap_relief={b['swap_relief']} "
          f"unrelieved={b['unrelieved']} (used_slots={b['used_slots']})")
    print()


# ============================================================
# 합성 데이터 테스트
# ============================================================
#
# 4개 케이스는 perf 축만 격리하려고 stab/eff 입력을 동일하게 고정한다:
#   - 고정 proc: worker(quota>0, sz/quota=0.5, RUNNING) → eff 일정
#   - swap_cycle_count=0, quota_denied_delta=0 → stab=1.0, quota_perf=1.0
#   - 변하는 것: memfill 의 sz(=압박) 와 swap.used_slots(=흡수) 뿐
# 따라서 score 차이는 전적으로 perf(swap 통합)에서 나온다.

WORKER = {                       # 고정 managed proc (eff 일정용)
    "pid": 3, "name": "worker", "state": 4,
    "sz": 256 * 1024,            # 256KB
    "quota": 512 * 1024,         # usage_ratio = 0.5
}

MB = 1024 * 1024


def make_snapshot(memfill_sz, used_slots):
    procs = [
        dict(WORKER),
        {"pid": 4, "name": "memfill", "state": 4, "sz": memfill_sz, "quota": 0},
    ]
    metrics = {
        "3:worker":  {"quota_denied_delta": 0, "swap_cycle_count": 0},
        "4:memfill": {"quota_denied_delta": 0, "swap_cycle_count": 0},
    }
    return {
        "processes": procs,
        "_bridge_process_metrics": metrics,
        "swap": {"used_slots": used_slots, "total_slots": SWAP_CAPACITY},
    }


def run_case(label, memfill_sz, used_slots):
    snap = make_snapshot(memfill_sz, used_slots)
    state = {}                   # cold start → load_avg = load_now (케이스 독립)
    s = compute_score_proto(snap, state)
    print_score_proto(label, s)
    return s


if __name__ == "__main__":
    print("=" * 72)
    print("swap-positive 통합 score 프로토타입 — 4 케이스 검증")
    print("RAM_PAGES=%d (128MB)  SWAP_CAPACITY=%d (64MB)" % (RAM_PAGES, SWAP_CAPACITY))
    print("=" * 72)
    print()

    # 1. 압박 없음 + swap 0 → perf=quota_perf (정상)
    run_case("case1  no-pressure  swap=0   ", memfill_sz=0,        used_slots=0)

    # 2. 압박 없음 + swap 많음 → perf=quota_perf (보너스 없음 = 게임 방지)
    run_case("case2  no-pressure  swap=many", memfill_sz=0,        used_slots=12000)

    # 3. 압박 큼 + swap 충분 → perf 유지 (swap 보상)
    run_case("case3  pressure-HI  swap=enuf", memfill_sz=110 * MB, used_slots=15000)

    # 4. 압박 큼 + swap 없음 → perf ↓ (OOM 위험 벌점)
    run_case("case4  pressure-HI  swap=0   ", memfill_sz=110 * MB, used_slots=0)

    print("기대:")
    print("  case1 == case2 (압박 0 → swap 무관, 둘 다 quota_perf)")
    print("  case3 ~= case1 (압박 큼이지만 swap 이 흡수 → perf 보존)")
    print("  case4 << others (압박 큼 + swap 0 → perf 급락)")
