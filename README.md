# 2026 운영체제 팀 프로젝트

xv6-RISCV 에 **LLM 어드바이저(advisord)** 를 얹어, 스케줄링·프로세스 분류·quantum·이상 탐지를 의미 정보 기반으로 보강하는 실험.

## 핵심 비교 — 세 가지 스케줄러 방식

| 축 | 기존 xv6 | 현대 OS (Windows·macOS·Linux) | LLM 어드바이저 |
|---|---|---|---|
| **누가 다음으로 일하나** | FIFO · 도착 순서 | 우선순위 큐 + 셸 자동 승격 | 이름표(`make`/`sh`/`cc`)로 사전 분류 |
| **자식 분류 시점** | 부모 우선순위 그대로 복사 | 실행을 관찰한 뒤 분류 (오분류 구간 존재) | `exec()` 직후 이름으로 즉시 분류 |
| **Quantum 길이** | 전원 동일 1 tick | 등급별 고정값 | 프로세스 특성에 맞춘 추론값 |
| **종료 통계** | 휘발 — `wait()` 시 폐기 | ETW · `/proc` 에 축적 (자동 재활용 X) | 이름별 prior 로 누적 학습 |
| **프로세스 트리** | `ppid` 포인터뿐 | cgroup/Job Object (수동) | 이름 + 트리 모양으로 자동 묶기 |
| **fork bomb 방어** | NPROC 한도 도달까지 무방어 | `rlimit`/`pids.max` 양적 한도 | 의미·패턴 기반 의심 트리 탐지 |
| **panic 시 진단** | `panic: trap` + 레지스터 | 메모리 덤프(BSOD/kdump) | 시계열 기반 자연어 진단 |

세 방식은 경쟁이 아닌 **‘덮어쓰기’ 관계** — 뒤로 갈수록 앞 방식 위에 새로운 차원을 얹는다. LLM 어드바이저는 현대 OS 의 행동 관찰을 *대체하지 않고 보강*: 행동을 보기 **전**의 의미 정보를 활용한다.

## 디렉토리

- `xv6-process/` — LLM advisor 가 추가된 xv6 RISC-V 포크
- `xv6-copy/` — 비교용 stock xv6 사본
- `report/weekNN/` — 주차별 보고서 (week09 ~ week14)

## 주요 보고서

- **▶ [스케줄러 3종 비교 (Live 페이지)](https://philocsera.github.io/OS_JPLKJ/description.html)** — GitHub Pages 로 호스팅된 인터랙티브 보고서 (소스: [report/week13/조현성/process_summary.html](report/week13/조현성/process_summary.html))
- [report/week12/조현성/refactoring.md](report/week12/조현성/refactoring.md) — xv6-process 트리 9개 개선 후보 분석
- [report/week12/조현성/report.md](report/week12/조현성/report.md) — Dead code 제거, kstack 5KB→640B 축소, 진짜 `try_acquire()` 구현
