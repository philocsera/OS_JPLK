#!/usr/bin/env python3
import argparse
import contextlib
import io
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

import pexpect

from collect_swap_scenario import stop_qemu
from execute_quota_runtime_scenario import (
    apply_quota,
    collect_snapshot,
    compute_final_score,
)
from memory_live_groq_runner import (
    QUOTA_ACTIONS,
    SWAP_ACTIONS,
    build_memory_policy_prompt,
    estimate_swap_stab,
    normalize_proposal,
)
from quota_groq_retry_runner import load_json, save_json

PAGE_SIZE = 4096

READ_ONLY_ACTIONS = {
    "no_action",
    "keep_quota",
    "inspect_process",
}

ACTION_KO = {
    "no_action": "변경 없음",
    "keep_quota": "현재 quota 유지",
    "inspect_process": "추가 관찰",
    "increase_quota": "quota 증가",
    "decrease_quota": "quota 감소",
    "release_quota": "quota 해제",
    "swapout": "swapout",
}


def quiet(function, *args, **kwargs):
    with contextlib.redirect_stdout(io.StringIO()):
        return function(*args, **kwargs)


def parse_snapshot(raw):
    if isinstance(raw, dict):
        return raw

    try:
        return json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return None


def find_process(lines, pid):
    for raw in reversed(lines):
        snapshot = parse_snapshot(raw)

        if not snapshot:
            continue

        for process in snapshot.get("processes", []):
            if int(process.get("pid", -1)) == int(pid):
                return process

    return None


def start_qemu(timeout, transcript_path):
    transcript_path.parent.mkdir(parents=True, exist_ok=True)

    transcript_file = transcript_path.open(
        "w",
        encoding="utf-8",
    )

    child = pexpect.spawn(
        "make",
        ["qemu", "CPUS=1"],
        encoding="utf-8",
        timeout=timeout,
    )

    child.logfile = transcript_file
    child.expect_exact("$ ", timeout=timeout)

    return child, transcript_file


def setup_workload(child, args, initial_log):
    child.sendline(f"memhold {args.pages} {args.delay} &")

    child.expect(
        r"memhold ready pid=(\d+) pages=\d+ delay=\d+",
        timeout=args.timeout,
    )

    pid = int(child.match.group(1))

    lines = quiet(
        collect_snapshot,
        child,
        1,
        0,
        initial_log,
        args.timeout,
    )

    process = find_process(lines, pid)

    if process is None:
        raise RuntimeError("초기 workload 프로세스를 찾지 못했습니다.")

    size = int(process.get("sz", 0))

    baseline_quota = (
        size
        + args.baseline_headroom_pages * PAGE_SIZE
    )

    if not quiet(
        apply_quota,
        child,
        pid,
        baseline_quota,
        args.timeout,
    ):
        raise RuntimeError("초기 quota 적용에 실패했습니다.")

    return pid


def run_pipeline(snapshot_log, prompt_log, pipeline_log, reset):
    command = [
        sys.executable,
        "run_pipeline.py",
        "--memwatch-log",
        str(snapshot_log),
        "--prompt-out",
        str(prompt_log),
    ]

    if reset:
        command.append("--reset-state")

    result = subprocess.run(
        command,
        text=True,
        capture_output=True,
    )

    pipeline_log.write_text(
        result.stdout + result.stderr,
        encoding="utf-8",
    )

    if result.returncode != 0:
        raise RuntimeError("Bridge 분석에 실패했습니다.")

    if "[bridge] generated LLM prompt" not in result.stdout:
        return None

    return build_memory_policy_prompt(prompt_log)


def request_llm(prompt, prompt_path, proposal_path, args):
    save_json(prompt_path, prompt)

    command = [
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
        command.extend(["--model", args.model])

    result = subprocess.run(
        command,
        text=True,
        capture_output=True,
    )

    if result.returncode != 0:
        raise RuntimeError("LLM 호출에 실패했습니다.")

    proposal = normalize_proposal(
        load_json(proposal_path)
    )

    save_json(proposal_path, proposal)

    return proposal


def validate(proposal_path):
    result = subprocess.run(
        [
            sys.executable,
            "proposal_guard.py",
            "--proposal",
            str(proposal_path),
        ],
        text=True,
        capture_output=True,
    )

    return (
        result.returncode == 0,
        (result.stdout + result.stderr).strip(),
    )


def apply_swapout(child, pid, pages, timeout):
    child.sendline(f"swapctl {pid} {pages}")

    child.expect(
        rf"swapctl pid={pid} requested={pages} success=(\d+)",
        timeout=timeout,
    )

    success = int(child.match.group(1))

    child.expect_exact("$ ", timeout=timeout)

    return success


def verify(
    candidate_log,
    transcript_path,
    verifier_path,
    pid,
    require_swapout=False,
):
    command = [
        sys.executable,
        "hard_verifier.py",
        "--log",
        str(candidate_log),
        "--transcript",
        str(transcript_path),
        "--target-pid",
        str(pid),
        "--out",
        str(verifier_path),
    ]

    if require_swapout:
        command.append("--require-swapout-activity")

    result = subprocess.run(
        command,
        text=True,
        capture_output=True,
    )

    return result.returncode == 0


def forced_proposal(action, pid, current_quota, args):
    if action == "increase_quota":
        return normalize_proposal(
            {
                "diagnosis": "시험용 quota 압박 상황",
                "action": "increase_quota",
                "target_pid": pid,
                "target_quota": current_quota + PAGE_SIZE,
                "swapout_pages": None,
                "reason": "quota 실제 적용 경로 확인",
                "confidence": "high",
            }
        )

    return normalize_proposal(
        {
            "diagnosis": "시험용 RAM 압박 상황",
            "action": "swapout",
            "target_pid": pid,
            "target_quota": None,
            "swapout_pages": args.force_swapout_pages,
            "reason": "swapout 실제 적용 경로 확인",
            "confidence": "high",
        }
    )


def print_normal(cycle):
    print()
    print(f"[관찰 {cycle:02d}] 정상")
    print("이상 징후   : 없음")
    print("처리 결과   : 다음 감시 주기로 이동")


def print_detection(cycle, proposal):
    print()
    print(f"[관찰 {cycle:02d}] 이상 감지")
    print(f"대상 PID    : {proposal.get('target_pid', '-')}")
    print(
        "LLM 분석    : "
        + proposal.get(
            "diagnosis",
            proposal.get("reason", "-"),
        )
    )
    print(
        "선택 정책   : "
        + ACTION_KO.get(
            proposal.get("action"),
            proposal.get("action", "-"),
        )
    )
    print(f"판단 근거   : {proposal.get('reason', '-')}")
    print(f"신뢰도      : {proposal.get('confidence', '-')}")


def print_accept(command, detail):
    print(f"적용 명령   : {command}")
    print("검증 결과   : PASS")
    print(f"평가 결과   : {detail}")
    print("최종 판단   : 정책 적용 유지")
    print("후속 동작   : 감시 루프로 복귀")


def print_reject(code, reason, rollback):
    print("검증 결과   : FAIL")
    print(f"실패 코드   : {code}")
    print(f"실패 원인   : {reason}")
    print(f"rollback    : {rollback}")
    print("후속 동작   : 실패 정보를 포함하여 재탐색")


def main():
    parser = argparse.ArgumentParser(
        description="xv6 LLM 기반 메모리 지속 감시 Agent loop"
    )

    parser.add_argument("--cycles", type=int, default=5)
    parser.add_argument("--pages", type=int, default=32)
    parser.add_argument("--delay", type=int, default=100000)
    parser.add_argument("--ticks", type=int, default=3)
    parser.add_argument("--interval", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--max-restarts", type=int, default=2)
    parser.add_argument("--baseline-headroom-pages", type=int, default=1)
    parser.add_argument("--min-improvement", type=float, default=1.0)
    parser.add_argument("--min-swap-stab", type=float, default=0.85)
    parser.add_argument("--approve", action="store_true")
    parser.add_argument("--model")

    parser.add_argument(
        "--reasoning-effort",
        choices=["low", "medium", "high"],
        default="low",
    )

    parser.add_argument(
        "--force-action",
        choices=["increase_quota", "swapout"],
        help="시험 전용: LLM 대신 지정한 정책 실행",
    )

    parser.add_argument(
        "--force-swapout-pages",
        type=int,
        default=1,
    )

    args = parser.parse_args()

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    root = Path(__file__).resolve().parent
    out_dir = root / "logs" / "agent_loop" / timestamp
    out_dir.mkdir(parents=True, exist_ok=True)

    summary_path = out_dir / "summary.json"

    summary = {
        "result": "RUNNING",
        "observations": [],
        "qemu_restarts": 0,
    }

    retry_context = []
    restart_count = 0
    child = None
    transcript_file = None
    reset_bridge_state = True

    try:
        for cycle in range(1, args.cycles + 1):
            if child is None:
                session_dir = out_dir / f"session_{restart_count:02d}"
                transcript_path = session_dir / "qemu_transcript.txt"

                child, transcript_file = start_qemu(
                    args.timeout,
                    transcript_path,
                )

                pid = setup_workload(
                    child,
                    args,
                    session_dir / "initial.jsonl",
                )

                reset_bridge_state = True

            cycle_dir = out_dir / f"observation_{cycle:02d}"
            cycle_dir.mkdir(parents=True, exist_ok=True)

            snapshot_log = cycle_dir / "snapshot.jsonl"
            prompt_log = cycle_dir / "bridge_prompt.txt"
            pipeline_log = cycle_dir / "pipeline.txt"
            prompt_path = cycle_dir / "prompt.json"
            proposal_path = cycle_dir / "proposal.json"
            candidate_log = cycle_dir / "candidate.jsonl"
            verifier_path = cycle_dir / "hard_verifier.json"

            lines = quiet(
                collect_snapshot,
                child,
                args.ticks,
                args.interval,
                snapshot_log,
                args.timeout,
            )

            baseline_score = compute_final_score(lines)
            baseline_value = float(baseline_score["score"])

            prompt = run_pipeline(
                snapshot_log,
                prompt_log,
                pipeline_log,
                reset_bridge_state,
            )

            reset_bridge_state = False

            if prompt is None:
                print_normal(cycle)

                summary["observations"].append(
                    {
                        "cycle": cycle,
                        "decision": "NORMAL",
                    }
                )

                save_json(summary_path, summary)
                continue

            if retry_context:
                prompt["retry_context"] = retry_context

            process = find_process(lines, pid)

            if process is None:
                raise RuntimeError("대상 프로세스가 사라졌습니다.")

            current_quota = int(process.get("quota", 0))

            if args.force_action:
                proposal = forced_proposal(
                    args.force_action,
                    pid,
                    current_quota,
                    args,
                )

                save_json(proposal_path, proposal)
            else:
                proposal = request_llm(
                    prompt,
                    prompt_path,
                    proposal_path,
                    args,
                )

            print_detection(cycle, proposal)

            action = proposal.get("action")
            proposal_pid = int(proposal.get("target_pid", 0) or 0)

            if action in READ_ONLY_ACTIONS:
                print("최종 판단   : 현재 정책 유지")
                print("후속 동작   : 감시 루프로 복귀")

                summary["observations"].append(
                    {
                        "cycle": cycle,
                        "decision": "ACCEPT_READ_ONLY",
                        "proposal": proposal,
                    }
                )

                save_json(summary_path, summary)
                continue

            valid, guard_message = validate(proposal_path)

            if not valid:
                code = "PROPOSAL_GUARD_REJECTED"

                print_reject(
                    code,
                    guard_message,
                    "정책 미적용",
                )

                retry_context.append(
                    {
                        "cycle": cycle,
                        "proposal": proposal,
                        "failure_code": code,
                        "reason": guard_message,
                    }
                )

                save_json(summary_path, summary)
                continue

            if not args.approve:
                print("적용 결과   : 사용자 승인 대기")
                print("후속 동작   : 미적용 상태로 감시 지속")
                continue

            if action in QUOTA_ACTIONS:
                before_quota = int(
                    find_process(lines, proposal_pid).get("quota", 0)
                )

                target_quota = int(proposal.get("target_quota", 0))
                command = f"setquota {proposal_pid} {target_quota}"

                if not quiet(
                    apply_quota,
                    child,
                    proposal_pid,
                    target_quota,
                    args.timeout,
                ):
                    raise RuntimeError("quota 적용 실패")

                candidate_lines = quiet(
                    collect_snapshot,
                    child,
                    args.ticks,
                    args.interval,
                    candidate_log,
                    args.timeout,
                )

                transcript_file.flush()

                verifier_ok = verify(
                    candidate_log,
                    transcript_path,
                    verifier_path,
                    proposal_pid,
                )

                candidate_score = compute_final_score(candidate_lines)
                candidate_value = float(candidate_score["score"])

                accepted = (
                    verifier_ok
                    and candidate_value
                    > baseline_value + args.min_improvement
                )

                if accepted:
                    print_accept(
                        command,
                        f"score {baseline_value:.1f} → {candidate_value:.1f}",
                    )
                else:
                    code = (
                        "QUOTA_SCORE_NOT_IMPROVED"
                        if verifier_ok
                        else "QUOTA_HARD_VERIFIER_FAILED"
                    )

                    reason = (
                        f"score {baseline_value:.1f} "
                        f"→ {candidate_value:.1f}"
                    )

                    quiet(
                        apply_quota,
                        child,
                        proposal_pid,
                        before_quota,
                        args.timeout,
                    )

                    print_reject(
                        code,
                        reason,
                        f"quota {before_quota} 복원",
                    )

                    retry_context.append(
                        {
                            "cycle": cycle,
                            "proposal": proposal,
                            "failure_code": code,
                            "reason": reason,
                        }
                    )

                summary["observations"].append(
                    {
                        "cycle": cycle,
                        "action": action,
                        "baseline_score": baseline_score,
                        "candidate_score": candidate_score,
                        "accepted": accepted,
                    }
                )

            elif action in SWAP_ACTIONS:
                pages = int(proposal.get("swapout_pages", 0))
                command = f"swapctl {proposal_pid} {pages}"

                success = apply_swapout(
                    child,
                    proposal_pid,
                    pages,
                    args.timeout,
                )

                if success <= 0:
                    raise RuntimeError("swapout 적용 실패")

                candidate_lines = quiet(
                    collect_snapshot,
                    child,
                    args.ticks,
                    args.interval,
                    candidate_log,
                    args.timeout,
                )

                transcript_file.flush()

                verifier_ok = verify(
                    candidate_log,
                    transcript_path,
                    verifier_path,
                    proposal_pid,
                    require_swapout=True,
                )

                stab, swap_cycles = estimate_swap_stab(
                    candidate_log,
                    proposal_pid,
                )

                accepted = (
                    verifier_ok
                    and stab >= args.min_swap_stab
                )

                if accepted:
                    print_accept(
                        command,
                        f"stab={stab:.3f}, cycles={swap_cycles}",
                    )
                else:
                    code = (
                        "SWAP_STABILITY_BELOW_THRESHOLD"
                        if verifier_ok
                        else "SWAP_HARD_VERIFIER_FAILED"
                    )

                    reason = (
                        f"stab={stab:.3f}, "
                        f"기준={args.min_swap_stab}"
                    )

                    print_reject(
                        code,
                        reason,
                        "QEMU checkpoint 재시작",
                    )

                    retry_context.append(
                        {
                            "cycle": cycle,
                            "proposal": proposal,
                            "failure_code": code,
                            "reason": reason,
                        }
                    )

                    stop_qemu(child)
                    transcript_file.close()

                    child = None
                    transcript_file = None

                    restart_count += 1
                    summary["qemu_restarts"] = restart_count

                    if restart_count > args.max_restarts:
                        raise RuntimeError(
                            "최대 QEMU 재시작 횟수를 초과했습니다."
                        )

                summary["observations"].append(
                    {
                        "cycle": cycle,
                        "action": action,
                        "stab": stab,
                        "swap_cycles": swap_cycles,
                        "accepted": accepted,
                    }
                )

            save_json(summary_path, summary)

        summary["result"] = "COMPLETED"

    except Exception as error:
        summary["result"] = "ERROR"
        summary["error"] = str(error)

        print()
        print("[Agent 오류]")
        print(f"내용        : {error}")

    finally:
        if child is not None:
            stop_qemu(child)

        if transcript_file is not None:
            transcript_file.close()

        save_json(summary_path, summary)

    print()
    print("========================================")
    print("           지속 감시 종료 보고")
    print("========================================")
    print(f"최종 결과   : {summary['result']}")
    print(f"관찰 횟수   : {len(summary['observations'])}")
    print(f"QEMU 재시작 : {summary['qemu_restarts']}")
    print(f"상세 결과   : {summary_path}")


if __name__ == "__main__":
    main()
