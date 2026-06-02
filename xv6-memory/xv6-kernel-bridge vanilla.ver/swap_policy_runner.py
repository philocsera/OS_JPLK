#!/usr/bin/env python3
# swap_policy_runner.py — quota_policy_runner.py 의 swap 판 미러링.
#
# baseline(swapout 미실행) 과 candidate(swapout N pages) 를 같은 memhold 워크로드로
# 돌린다.
#
# ★ 평가 = "안전성 verdict" (효율 score 개선이 아님). 이유:
#   이 toy 커널에서 swap(NSWAP=1024=4MB)은 RAM(PHYSTOP=128MB)의 3%라 생존을 가르는
#   pivot이 못 된다(=baseline OOM→candidate 생존하는 recovery 프레임 불가능).
#   게다가 swapout 은 proc->sz 를 줄이지 않아 quota 기반 eff/usage_ratio 가 baseline
#   과 candidate 에서 동일 → 효율 score 로는 swap 의 차이를 표현할 수 없다.
#   따라서 swap 정책은 "이 swapout 이 안전한가(thrash/사망/데이터손실 없나)" 로 평가한다.
#   compute_score 의 stab(thrashing) 축만이 swap 에 반응하는 유일한 신호다.
#   (효율 score 자체는 observability 용으로만 summary 에 남긴다.)
#
# ★ quota 와의 비대칭 (SWAP_ROLLBACK_DESIGN.md 참고):
#   - candidate 축 = quota 값이 아니라 swapout_pages 개수.
#   - 적용 = setquota 가 아니라 swapctl(=swapout). baseline 은 swapout-pages=0.
#   - 롤백 = OS lazy swapin 위임 → 강제 복원 명령 없음(no-op). 이 runner 는
#     오프라인 A/B 채점이라 어차피 live 상태를 안 건드린다(quota_policy_runner 와 동일).
#   - summary 의 quota `rollback_quota=<값>` 자리에 `rollback_action="lazy_swapin"`
#     (복원할 값이 아니라 복원 방식)을 노출한다.
#   - verifier: candidate 에만 --require-swap-activity(swapout/swapin 관측 강제).
#     --fail-on-quota-denied 는 끈다(swap 시나리오는 quota deny 무관).
#     RAM 압박 사망은 usertrap(): unexpected 패턴으로 hard_verifier 가 자동 캐치.

import argparse
import json
import subprocess
import sys
from pathlib import Path

import bridge


def run_command(command, allow_failure=False):
    print("[swap-runner] $ " + " ".join(str(item) for item in command))
    result = subprocess.run(command)

    if result.returncode != 0 and not allow_failure:
        raise RuntimeError(
            f"command failed with exit code {result.returncode}: "
            + " ".join(str(item) for item in command)
        )

    return result.returncode


def collect_workload(label, swapout_pages, args, out_dir):
    log_path = out_dir / f"{label}.jsonl"
    transcript_path = out_dir / f"{label}_qemu.log"

    command = [
        sys.executable,
        "collect_swap_scenario.py",
        "--pages",
        str(args.pages),
        "--swapout-pages",
        str(swapout_pages),
        "--delay",
        str(args.delay),
        "--ticks",
        str(args.ticks),
        "--interval",
        str(args.interval),
        "--out",
        str(log_path),
        "--transcript",
        str(transcript_path),
        "--timeout",
        str(args.timeout),
    ]

    run_command(command)

    return log_path, transcript_path


def run_hard_verifier(
    label,
    log_path,
    transcript_path,
    out_dir,
    require_swap_activity,
):
    verifier_result_path = out_dir / f"{label}_hard_verifier.json"

    command = [
        sys.executable,
        "hard_verifier.py",
        "--log",
        str(log_path),
        "--transcript",
        str(transcript_path),
        "--out",
        str(verifier_result_path),
    ]

    # swapout 을 실행한 워크로드(candidate, 또는 before-pages>0 인 baseline)에만
    # swapout/swapin 관측을 강제한다. swapout 미실행 baseline 은 켜지 않는다.
    if require_swap_activity:
        command.append("--require-swap-activity")

    run_command(command, allow_failure=True)

    if not verifier_result_path.exists():
        raise RuntimeError(
            f"hard verifier result was not created: {verifier_result_path}"
        )

    result = json.loads(
        verifier_result_path.read_text(encoding="utf-8")
    )

    return result, verifier_result_path


def load_snapshots(log_path):
    snapshots = []

    for line_number, raw in enumerate(
        log_path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        raw = raw.strip()

        if not raw:
            continue

        try:
            snapshot = json.loads(raw)
        except json.JSONDecodeError as error:
            raise RuntimeError(
                f"{log_path}: line {line_number}: invalid JSON: {error}"
            ) from error

        if snapshot.get("type") == "memstat":
            snapshots.append(snapshot)

    if not snapshots:
        raise RuntimeError(f"no memstat snapshot found: {log_path}")

    return snapshots


def compute_final_score(log_path):
    snapshots = load_snapshots(log_path)
    state = {}
    score_history = []

    for snapshot in snapshots:
        bridge.analyze_snapshot(snapshot, state)
        score = bridge.compute_score(snapshot, state)
        score_history.append(
            {
                "tick": snapshot.get("tick"),
                **score,
            }
        )

    return score_history[-1], score_history


def format_errors(verifier_result):
    errors = verifier_result.get("errors", [])

    if not errors:
        return "none"

    return "; ".join(str(error) for error in errors)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Compare a baseline (no swapout) and a candidate swapout policy "
            "using the same memhold workload."
        )
    )

    parser.add_argument(
        "--candidate-pages",
        type=int,
        required=True,
        help="pages to swap out for the candidate policy",
    )

    parser.add_argument(
        "--before-pages",
        type=int,
        default=0,
        help="pages to swap out for the baseline; 0 means no swapout",
    )

    parser.add_argument(
        "--pages",
        type=int,
        default=8,
        help="memhold size in pages (workload, same for both runs)",
    )

    parser.add_argument("--delay", type=int, default=1000)
    parser.add_argument("--ticks", type=int, default=20)
    parser.add_argument("--interval", type=int, default=100)
    parser.add_argument("--timeout", type=int, default=240)

    parser.add_argument(
        "--allow-invalid-baseline",
        action="store_true",
        help="continue candidate verification when baseline policy is already invalid",
    )

    parser.add_argument(
        "--min-stab",
        type=float,
        default=0.85,
        help=(
            "minimum candidate stab (thrashing axis) required for a safe "
            "ACCEPT. clean single-cycle swap ~0.9 passes; >=2 swap cycles "
            "(thrashing) ~<=0.8 is rolled back. default 0.85"
        ),
    )

    parser.add_argument(
        "--out-dir",
        default="logs/swap_policy_runner",
    )

    args = parser.parse_args()

    if args.candidate_pages <= 0:
        raise SystemExit(
            "[swap-runner] ERROR: candidate pages must be positive"
        )

    if args.before_pages < 0:
        raise SystemExit(
            "[swap-runner] ERROR: before pages must be non-negative"
        )

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print()
    print("[swap-runner] collect baseline workload")
    before_log, before_transcript = collect_workload(
        "before",
        args.before_pages,
        args,
        out_dir,
    )

    before_score, before_history = compute_final_score(before_log)

    before_verifier, before_verifier_path = run_hard_verifier(
        "before",
        before_log,
        before_transcript,
        out_dir,
        require_swap_activity=args.before_pages > 0,
    )

    baseline_passed = before_verifier.get(
        "hard_verifier_passed",
        False,
    )

    if not baseline_passed and not args.allow_invalid_baseline:
        decision = "ABORT_BASELINE_INVALID"
        reason = (
            "baseline policy failed hard verifier: "
            + format_errors(before_verifier)
        )

        summary = {
            "decision": decision,
            "reason": reason,
            "before_pages": args.before_pages,
            "candidate_pages": args.candidate_pages,
            "before_score": before_score,
            "before_verifier": before_verifier,
            "before_verifier_result": str(before_verifier_path),
        }

        summary_path = out_dir / "summary.json"
        summary_path.write_text(
            json.dumps(summary, indent=2) + "\n",
            encoding="utf-8",
        )

        print()
        print(f"[swap-runner] decision: {decision}")
        print(f"[swap-runner] reason: {reason}")
        print(f"[swap-runner] summary: {summary_path}")

        raise SystemExit(1)

    if not baseline_passed:
        print()
        print("[swap-runner] baseline hard verifier: FAIL")
        print("[swap-runner] recovery mode: candidate verification continues")

    print()
    print("[swap-runner] collect candidate workload")
    candidate_log, candidate_transcript = collect_workload(
        "candidate",
        args.candidate_pages,
        args,
        out_dir,
    )

    candidate_score, candidate_history = compute_final_score(candidate_log)

    candidate_verifier, candidate_verifier_path = run_hard_verifier(
        "candidate",
        candidate_log,
        candidate_transcript,
        out_dir,
        require_swap_activity=args.candidate_pages > 0,
    )

    # 효율 score 는 observability 용으로만 남긴다(decision 에 안 씀).
    before_value = float(before_score["score"])
    candidate_value = float(candidate_score["score"])

    # ★ 안전성 verdict (docstring 참고). decision 은 candidate 의 verifier 생존 +
    # stab(thrashing) 으로만 낸다. baseline 은 환경 sanity control 일 뿐
    # (FAIL 이면 위에서 ABORT). recovery/score 비교 분기는 swap 에 적용 불가라 제거.
    candidate_passed = candidate_verifier.get(
        "hard_verifier_passed",
        False,
    )
    candidate_stab = float(candidate_score.get("stab", 0.0))
    candidate_swap_cycles = int(
        candidate_score.get("breakdown", {}).get("swap_cycle_sum", 0)
    )

    if not candidate_passed:
        # panic / usertrap kill(RAM 압박 over-swap) / 슬롯 불일치 / 데이터손실
        decision = "ROLLBACK"
        reason = (
            "unsafe swap: candidate failed hard verifier: "
            + format_errors(candidate_verifier)
        )

    elif candidate_stab < args.min_stab:
        # 살아남았지만 thrashing — swap out 한 페이지를 proc 이 계속 되불러옴
        decision = "ROLLBACK"
        reason = (
            "unsafe swap: thrashing detected: "
            f"stab={candidate_stab} < min_stab={args.min_stab}, "
            f"swap_cycle_sum={candidate_swap_cycles}"
        )

    else:
        decision = "ACCEPT"
        reason = (
            f"safe swap: {args.candidate_pages} pages swapped out, "
            f"verifier PASS, no thrashing "
            f"(stab={candidate_stab}, swap_cycle_sum={candidate_swap_cycles})"
        )

    summary = {
        "decision": decision,
        "reason": reason,
        "evaluation_mode": "safety_verdict",
        "before_pages": args.before_pages,
        "candidate_pages": args.candidate_pages,
        # quota 의 rollback_quota(복원할 값) 자리. swap 은 복원할 값이 없고
        # OS lazy swapin 에 위임하므로 "복원 방식" 을 노출한다. 강제 명령은 보내지 않음.
        "rollback_action": (
            "lazy_swapin" if decision == "ROLLBACK" else None
        ),
        "candidate_stab": candidate_stab,
        "candidate_swap_cycle_sum": candidate_swap_cycles,
        "min_stab": args.min_stab,
        # 효율 score 는 observability 용(decision 에 안 씀 — docstring 참고).
        "before_score": before_score,
        "candidate_score": candidate_score,
        "before_verifier": before_verifier,
        "candidate_verifier": candidate_verifier,
        "artifacts": {
            "before_log": str(before_log),
            "before_transcript": str(before_transcript),
            "before_verifier_result": str(before_verifier_path),
            "candidate_log": str(candidate_log),
            "candidate_transcript": str(candidate_transcript),
            "candidate_verifier_result": str(candidate_verifier_path),
        },
        "score_history": {
            "before": before_history,
            "candidate": candidate_history,
        },
    }

    summary_path = out_dir / "summary.json"
    summary_path.write_text(
        json.dumps(summary, indent=2) + "\n",
        encoding="utf-8",
    )

    print()
    print("[swap-runner] swap safety evaluation complete")
    print(
        f"[swap-runner] candidate swapout pages: {args.candidate_pages}"
    )
    print(
        "[swap-runner] candidate hard verifier: "
        + ("PASS" if candidate_passed else "FAIL")
    )
    print(
        f"[swap-runner] candidate stab: {candidate_stab} "
        f"(min_stab={args.min_stab}, swap_cycle_sum={candidate_swap_cycles})"
    )
    print(f"[swap-runner] decision: {decision}")
    print(f"[swap-runner] reason: {reason}")
    print(
        "[swap-runner] (efficiency score is observability-only: "
        f"baseline={before_score['score']} candidate={candidate_score['score']})"
    )

    if decision == "ROLLBACK":
        # 강제 swapin 을 보내지 않는다. 프로세스가 페이지에 접근하면 OS 가
        # 자동으로 swapin 한다(검증 완료). live runner 가 적용을 되돌릴 때도 동일.
        print(
            "[swap-runner] rollback action: lazy_swapin "
            "(no forced swapin; OS restores pages on access)"
        )

    print(f"[swap-runner] summary: {summary_path}")


if __name__ == "__main__":
    main()
