#!/usr/bin/env python3
# collect_memstress.py — memstress(quota 성장형 워크로드) 압박 중에 memstat JSON을
# 안정적으로 캡처한다. collect_swap_scenario.py 의 검증된 pexpect 패턴을 그대로 따른다.
#
# 왜 이게 필요한가:
#   - collect_memwatch.py 는 memwatch 만 띄워서 idle 시스템만 잡는다(압박 없음).
#   - collect_swap_scenario.py 는 memhold+swapctl 로 swap 만 잡는다(memstress 아님).
#   - 손으로 콘솔을 치면 memstress 가 memwatch 샘플링 전에 끝나버려 JSON 에 안 잡힌다.
#
# 어떻게 타이밍을 맞추나:
#   1) memstress 를 백그라운드(&)로, 출력은 파일로 리다이렉트(> msN)해서 띄운다.
#      → 리다이렉트가 없으면 memstress 의 "allocated=" 콘솔 폭주가 memwatch JSON 라인과
#        뒤섞여 파싱이 깨진다. 파일로 보내면 콘솔은 memwatch JSON 만 남는다.
#   2) quota/step 을 크게/작게 줘서 memstress 가 샘플링 구간(ticks*interval) 내내
#      살아서 메모리를 키우도록 한다(예: quota 32MB, step 4096 → 오래 성장).
#   3) 그 동안 memwatch json 으로 여러 번 찍는다.
#
# 출력은 bridge.py 가 그대로 먹는 jsonl(compact memstat 라인) 이다:
#   python3 bridge.py --file logs/memwatch_memstress.jsonl
#
# 주의: quota "deny" 자체는 캡처가 불안정하다 — memstress 는 첫 sbrk 실패(=한도 도달)에서
#   곧바로 break/exit 하므로 quota_denied_count 가 1 로 잠깐 찍히고 프로세스가 사라진다.
#   따라서 이 도구는 growth/usage/RUNNABLE(부하) 신호에 적합하고, deny 순간 포착은 best-effort.

import argparse
import sys
from pathlib import Path

import pexpect

from collect_swap_scenario import Tee
from collect_swap_scenario import extract_memstat_lines
from collect_swap_scenario import stop_qemu


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--quota", type=int, default=33554432,
                        help="각 memstress 의 메모리 quota(bytes). 0 이면 무제한")
    parser.add_argument("--step", type=int, default=4096,
                        help="sbrk 증가 단위(bytes). 작을수록 오래 성장")
    parser.add_argument("--procs", type=int, default=1,
                        help="동시에 띄울 memstress 개수(부하/RUNNABLE 측정용)")
    parser.add_argument("--ticks", type=int, default=30,
                        help="memwatch 샘플 횟수")
    parser.add_argument("--interval", type=int, default=2,
                        help="샘플 사이 pause 틱 수")
    parser.add_argument("--out", default="logs/memwatch_memstress.jsonl")
    parser.add_argument("--transcript", default="logs/qemu_memstress.log")
    parser.add_argument("--timeout", type=int, default=240)
    args = parser.parse_args()

    if args.procs <= 0:
        raise SystemExit("[memstress] ERROR: procs must be positive")
    if args.ticks <= 0:
        raise SystemExit("[memstress] ERROR: ticks must be positive")
    if args.interval < 0:
        raise SystemExit("[memstress] ERROR: interval must be non-negative")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    transcript_path = Path(args.transcript)
    transcript_path.parent.mkdir(parents=True, exist_ok=True)

    print("[memstress] starting QEMU")

    child = pexpect.spawn(
        "make",
        ["qemu", "CPUS=1"],
        encoding="utf-8",
        timeout=args.timeout,
    )

    transcript_file = transcript_path.open("w", encoding="utf-8")
    child.logfile = Tee(sys.stdout, transcript_file)

    try:
        child.expect_exact("$ ")

        # memstress 를 백그라운드 + 출력 리다이렉트로 띄운다.
        # 이 sh 는 "A & B" 한 줄 체이닝을 지원하지 않으므로 반드시 한 줄에 하나씩.
        for i in range(args.procs):
            command = (
                f"memstress {args.quota} {args.step} > ms{i} &"
            )
            print(f"[memstress] xv6 command: {command}")
            child.sendline(command)
            # 백그라운드(&)는 즉시 프롬프트가 돌아온다.
            child.expect_exact("$ ")

        memwatch_command = f"memwatch json {args.ticks} {args.interval}"
        print(f"[memstress] xv6 command: {memwatch_command}")
        child.sendline(memwatch_command)

        child.expect_exact("$ ", timeout=args.timeout)
        captured = child.before

    except Exception as error:
        print(f"[memstress] ERROR: {error}")
        stop_qemu(child)
        transcript_file.close()
        raise SystemExit(1)

    stop_qemu(child)
    transcript_file.close()

    lines = extract_memstat_lines(captured)

    if not lines:
        print("[memstress] ERROR: no memstat JSON captured")
        raise SystemExit(1)

    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"[memstress] saved snapshots: {len(lines)}")
    print(f"[memstress] output: {out_path}")
    print(f"[memstress] transcript: {transcript_path}")


if __name__ == "__main__":
    main()
