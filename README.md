# OS_22 — LLM 기반 xv6 통합 프로젝트

이 저장소는 vanilla xv6-riscv를 두 갈래로 확장한 뒤 하나로 합치는 프로젝트다.

- **`xv6-process/`** — LLM 어드바이저 **스케줄러** (우선순위·클래스·job 그룹)
- **`xv6-memory/`** — **swap + 메모리 quota** 서브시스템
- 두 갈래를 단일 커널로 합치는 작업이 진행 중이며, 통합 설계는
  [`integration_plan.md`](report/week14/조현성/integration_plan.md), 통합 깊이 논의는
  [`discuss.md`](./discuss.md) 에 정리돼 있다.

문서 구성:
- **Part 1** — 통합 깊이 논의 (discuss.md 요약)
- **Part 2** — xv6-memory 구현 내용
- **Part 3** — xv6-process 구현 내용

---

# Part 1 — 통합 깊이 논의 (Coexistence → Observation → Control)

> 출처: [`discuss.md`](./discuss.md). 통합 산출물 위치는 신규 `xv6-unified/` 디렉터리로 확정(Q1).
> 아래 통합 깊이(Q4)·파이썬 툴링(Q5)은 **미결정**이며 이 문서는 선택지를 기록한다.

## 전제 — 지금 두 서브시스템은 완전히 독립이다

- process의 스케줄 advisor(`tools/bridge.py`)는 swap/quota를 **전혀 인지하지 않음**.
- memory는 **자체 LLM 스택을 따로 보유**(`groq_client`, `hard_verifier`,
  `proposal_guard`, `quota_*_runner`, `score_proto`).
- 통합하면 **한 커널 안에 LLM 어드바이저가 둘** — 하나는 *스케줄링*, 하나는 *메모리 정책* 을 결정.

| 서브시스템 | 관측 syscall | 제어 syscall | LLM 백엔드 |
|---|---|---|---|
| process(스케줄) | `getprocstat(_all)`, `getnamepriors` | `setpriority/setclass/setquantum/setjob*` | **로컬 Ollama** (`:11434`) |
| memory(메모리) | `getmemstat`, `getswapstat` | `setmemquota`, `swapout` | **Groq 클라우드** (`gpt-oss`) |

> 두 스택 모두 `bridge.py`를 갖지만 내용이 완전히 다름(935줄 차이) → 한 폴더에 두면 이름 충돌.

## 통합 깊이 3단계 (Q4)

### Level 0 — 공존만 (권장)
한 커널/한 빌드에 두 기능이 모두 들어가지만 **서로 대화하지 않음**. 신규 로직 0, 순수 병합,
리스크 최소. "두 기능이 한 OS에서 빌드·부팅·동작"을 증명하는 게 목표.

### Level 1 — 공유 관측 (read-only)
스케줄 advisor가 메모리 압박을 **볼 수 있게**만 함. `getprocstat` 스냅샷에
`mem_quota/quota_denied_count/swapout_count/swapin_count`를 노출해 LLM이 thrashing을 *인지*.
커널 변경 작음, 정책은 불변. 중간 리스크.

### Level 2 — 교차 제어 / 정책 엔진 통합
advisor가 메모리 신호에 **실제로 반응**(thrashing 프로세스 자동 강등 등)하거나
두 LLM 파이프라인을 하나로 합침. 신규 로직 多 + 안전성 검증 필요. 사실상 신규 개발.

| 항목 | L0 공존 | L1 관측 | L2 제어 |
|---|---|---|---|
| 커널 신규 로직 | 없음 | 적음 | 많음 |
| 두 LLM 파이프라인 | 따로 | 따로(프롬프트만 확장) | 통합 검토 |
| 리스크 | 낮음 | 중간 | 높음 |
| 성격 | 순수 병합 | 병합+α | 신규 개발 |

**제안**: 먼저 Level 0으로 공존을 확정한 뒤, 원하면 Level 1을 후속으로. Level 2는 별도 기획.

## 파이썬 툴링 (Q5)
- **A. 폴더만 분리(권장)** — `tools/advisor/`(Ollama) + `tools/memory/`(Groq), 코드 병합 없음.
- **B. 공용 LLM 클라이언트 추출** — Ollama/Groq 추상화.
- **C. 단일 파이프라인 통합** — ≈ Q4 Level 2.
- Q5는 Q4에 종속: Level 0/1이면 자동으로 **A**, 최소한 `bridge.py` 이름 충돌만 폴더 분리로 해소.

> 결정 대기 항목 전체는 `discuss.md` §8 표 참조.

---

# Part 2 — xv6-memory: swap + 메모리 quota

위치: `xv6-memory/xv6-kernel-bridge vanilla.ver/`. vanilla xv6에 **swap 서브시스템**과
**프로세스별 메모리 quota** 를 추가했고, 메모리 정책을 외부 LLM(Groq)이 제안·검증하는
파이프라인을 갖춘다.

## 커널 구현
- **swap 서브시스템** (`kernel/swap.c`, `swap.h`)
  - 두 번째 virtio 디스크(`SWAPDEV=2`)를 64MB swap 영역으로 사용
    (`NSWAP=16384` 슬롯 × 4KB; `Makefile`의 `swap.img dd count=64`와 일치 필수).
  - victim 선택: 단순(첫 user page) / **A-bit Clock**(`-DSWAP_VICTIM_CLOCK=1`) 전환 가능.
  - PTE 인코딩: swap된 페이지는 `V=0, U=1, PPN자리=swap slot`; lazy는 `*pte==0`.
  - 호출 체인: `swapout(pid)` syscall → `select_victim` → `swap_write_slot` → `kfree`,
    역방향은 page fault → `vmfault` → `swapin_page` → `swap_read_slot` → PTE 복구.
- **메모리 quota** — `struct proc`에 `mem_quota`, `quota_denied_count` 추가.
  `uvmalloc` 경로에서 quota 초과 alloc을 차단하고 차단 횟수를 누적.
- **관측/제어 syscall**
  - `getmemstat` — 프로세스별 `struct memstat`(pid/state/sz/mem_quota/quota_denied/swapout/swapin/name) 스냅샷.
  - `setmemquota` — quota 설정, `swapout` — 강제 swapout, `getswapstat` — swap 통계.
  - `trace` — syscall 추적 마스크(`trace_mask`).
- `struct proc` 추가 필드: `mem_quota, quota_denied_count, trace_mask,
  swap_clock_hand, swapout_count, swapin_count`.

## userspace 프로그램
`memstress, memfill, memhold, memwatch, memstat_test, setquota, swapctl, swaptest, trace_test`

## LLM 정책 파이프라인 (Groq 클라우드)
- `groq_client.py` — Groq `gpt-oss` 모델(openai 호환) 호출.
- `proposal_guard.py` / `hard_verifier.py` / `score_proto.py` — 제안된 정책의 안전 검증·점수화.
- `quota_agent_runner.py`, `quota_groq_retry_runner.py`, `quota_live_groq_runner.py`,
  `quota_policy_runner.py` — quota 최적화 루프(제안→검증→적용→롤백).
- `collect_memstress.py / collect_memwatch.py / collect_swap_scenario.py` — 시나리오 수집기.
- `run_pipeline.py` — 통합 파이프라인 진입점.

---

# Part 3 — xv6-process: LLM 어드바이저 스케줄러

위치: `xv6-process/`. vanilla xv6의 라운드로빈을 **우선순위 기반 스케줄러**로 바꾸고,
프로세스 상태를 외부 LLM(로컬 Ollama)이 관찰해 **분류·우선순위·job 그룹 정책**을 적용한다.

## 핵심 비교 — 세 가지 스케줄러 방식
| 축 | 기존 xv6 | 현대 OS | LLM 어드바이저 |
|---|---|---|---|
| 누가 다음으로 일하나 | FIFO·도착 순서 | 우선순위 큐 + 셸 자동 승격 | 이름표(`make`/`sh`/`cc`)로 사전 분류 |
| 자식 분류 시점 | 부모 우선순위 복사 | 실행 관찰 후 분류 | `exec()` 직후 이름으로 즉시 분류 |
| Quantum 길이 | 전원 동일 1 tick | 등급별 고정값 | 프로세스 특성에 맞춘 추론값 |
| 종료 통계 | 휘발(`wait()`시 폐기) | ETW·`/proc` 축적 | 이름별 prior로 누적 학습 |
| fork bomb 방어 | NPROC 한도까지 무방어 | `rlimit`/`pids.max` 양적 한도 | 의미·패턴 기반 의심 트리 탐지 |

LLM 어드바이저는 현대 OS의 행동 관찰을 *대체하지 않고 보강* — 행동을 보기 **전**의 의미 정보를 활용한다.

## 커널 구현
- **우선순위 스케줄러** (`kernel/proc.c::scheduler`)
  - `priority` 0(최고)~20(최저), 단일 패스로 best 후보 선택, 동순위는 선형 스캔 라운드로빈.
  - dispatch마다 `slice_used` 리셋, `ctxsw_count++` (advisord가 관측).
- **스케줄링 클래스 / job 그룹**
  - `class_id`(CLASS_*), `quantum_ticks`(슬라이스 길이), `group_id`(job/process-group).
  - `group_id`는 fork 시 상속 → `sh→make→cc` 트리 전체에 BATCH 정책을 일괄 적용(`setjob`).
- **procstat 카운터** (clockintr 구동): `ready_ticks, run_ticks, sleep_ticks,
  ctxsw_count, alloc_tick`.
- **name_priors 영속화** — 이름 기반 클래스 학습을 재부팅 후에도 유지.
- **virtio-console 전용 어드바이저 채널** (`kernel/virtio_console.c`, "Plan A")
  - 두 번째 virtio-mmio 슬롯(`0x10002000`, IRQ 2)을 `/advisor` 디바이스 파일로 노출.
  - advisor 트래픽(`@@WL`/`setcls`)이 UART(사람 셸)와 **절대 섞이지 않음**.
  - 디바이스 부재 시 panic 없이 best-effort 부팅.
- **관측/제어 syscall**: `getprocstat(_all)`, `getnamepriors`, `setpriority/getpriority`,
  `setclass`, `setquantum`, `setjob/getjob/setjobpriority/setjobclass`,
  `setnamepriors`, `note`, `crash`.
- `struct proc` 추가 필드: `priority, class_id, quantum_ticks, slice_used, group_id,
  ready_ticks, run_ticks, sleep_ticks, ctxsw_count, alloc_tick`.

## userspace 프로그램
`advisord, advd, advstat, wl, wlagent, priors, jobtest, setcls, setjprio,
iohog, cc, fbomb, crashme, ftree, priority_test, spin`

## LLM 어드바이저 (로컬 Ollama)
```
virtio-console  --@@WL frames-->  bridge.py  --HTTP-->  Ollama (로컬 모델)
(unix socket)   <--"setcls .."--  bridge.py  <--JSON--  classification
```
- `tools/bridge.py` — 호스트 측 브리지. `advd`가 export한 procstat을 Ollama로 분류,
  결정을 기존 `setclass` syscall로 적용(커널은 LLM 존재를 모름).
- `tools/diagnose.py` — 진단(오프라인 폴백 지원).
- `tools/test_advd.py` — UART 무간섭 end-to-end 검증.
- 기본 모델 `qwen2.5:3b` (로컬, API 키 불필요, pull 후 완전 오프라인);
  지연 튜닝 노브: `num_ctx`/`num_predict`/`keep_alive`.

---

## 디렉토리
- `xv6-process/` — LLM advisor 스케줄러 (Part 3)
- `xv6-memory/`  — swap + 메모리 quota (Part 2)
- `xv6-copy/`    — 비교용 stock xv6 사본
- `report/weekNN/` — 주차별 보고서 (week09 ~ week14)

## 주요 보고서
- **▶ [스케줄러 3종 비교 (Live 페이지)](https://philocsera.github.io/OS_JPLKJ/description.html)** — GitHub Pages 인터랙티브 보고서 (소스: [report/week13/조현성/process_summary.html](report/week13/조현성/process_summary.html))

## 빌드 & 실행 (각 트리 공통)
```sh
make clean && make
make qemu        # TOOLPREFIX=riscv64-elf-
```
xv6 자체는 RISC-V "newlib" 툴체인과 riscv64-softmmu QEMU가 필요하다
(https://pdos.csail.mit.edu/6.1810/).
