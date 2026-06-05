# xv6-JPLKJ — LLM-Integrated xv6

`xv6-JPLKJ/` is a single xv6-riscv kernel that merges two LLM-driven subsystems into
one build: an **LLM advisor scheduler** (Part 3, process) and a **swap + memory-quota
engine with an LLM policy pipeline** (Part 2, memory). Both run on the same kernel over
three virtio-mmio devices.

**Language / 언어:** [English](#english) · [한국어](#한국어)

---

# English

## Build & Run

```sh
cd xv6-JPLKJ

# The default `make` builds only the kernel — name fs.img / swap.img explicitly.
make TOOLPREFIX=riscv64-elf- kernel/kernel fs.img swap.img

# Boot in QEMU (three virtio-mmio devices: fs=bus.0, swap=bus.1, advisor console=bus.2)
make qemu CPUS=1
```

Requires a RISC-V "newlib" toolchain and `riscv64-softmmu` QEMU
(<https://pdos.csail.mit.edu/6.1810/>). `swap.img` is a 64 MB second virtio disk
(`dd count=64`, must match `NSWAP`).

**Optional — LLM pipelines** (the kernel boots and works without them):

```sh
# Part 3 — process advisor (local, no API key, offline after pull)
brew install ollama && ollama pull qwen2.5:3b
python3 tools/bridge.py                 # host bridge → Ollama → setclass

# Part 2 — memory policy (Groq cloud)
pip install groq python-dotenv pexpect
echo 'GROQ_API_KEY=gsk_...' > .env       # read by groq_client.py via python-dotenv
python3 memory_qemu_live_runner.py --approve   # full live loop: QEMU → bridge → Groq → verify
```

## Part 2 — Memory: swap + memory quota

A swap subsystem and per-process memory quota added to the kernel, plus a host-side
pipeline where an external LLM (Groq cloud) proposes and a verifier checks memory policy.

**Kernel** (`kernel/swap.c`, `swap.h`)
- **Swap** on a second virtio disk (`SWAPDEV=2`, `NSWAP=16384` slots × 4 KB). Victim
  selection is simple (first user page) or **A-bit Clock** (`-DSWAP_VICTIM_CLOCK=1`).
  Swapped PTE = `V=0, U=1, PPN←slot`; lazy page = `*pte==0`. Chain:
  `swapout(pid)` → `select_victim` → `swap_write_slot` → `kfree`; reverse on fault:
  `vmfault` → `swapin_page` → `swap_read_slot` → restore PTE.
- **Quota** — `uvmalloc` blocks growth past `mem_quota` and counts `quota_denied_count`.
- **Syscalls 36–40** — `getmemstat`(36), `setmemquota`(37), `swapout`(38),
  `getswapstat`(39), `trace`(40). (Renumbered above the process subsystem's 22–35 to
  avoid collision during the merge.)
- `struct proc` fields: `mem_quota, quota_denied_count, trace_mask, swap_clock_hand,
  swapout_count, swapin_count`.

**Userspace:** `memstress, memfill, memhold, memwatch, memstat_test, setquota, swapctl,
swaptest, trace_test`.

**LLM policy pipeline (Groq cloud)**
- `bridge.py` (memory-side, distinct from the process `tools/bridge.py`) parses `memwatch`
  JSON, classifies OK/WATCH/DANGER, emits a 3-axis efficiency score and an LLM prompt.
- `groq_client.py` calls Groq `openai/gpt-oss-120b` with a strict JSON schema (action,
  target, `diagnosis`, reason, confidence); reads `GROQ_API_KEY` from `.env`.
- `proposal_guard.py` / `hard_verifier.py` / `score_proto.py` validate and score the
  proposal (protected processes checked **by name**, swap/quota safety constraints).
- `run_pipeline.py` (analyze → propose → guard → dry-run apply) and the live runners
  `memory_qemu_live_runner.py` / `memory_agent_loop.py` / `memory_live_groq_runner.py`
  (boot QEMU, apply `setquota`/`swapctl`, verify, accept or QEMU-restart rollback).

## Part 3 — Process: LLM advisor scheduler

vanilla xv6's round-robin is replaced by a **priority scheduler**, and an external LLM
(local Ollama) observes process state to apply **class / priority / job-group** policy.

| Axis | stock xv6 | modern OS | LLM advisor |
|---|---|---|---|
| who runs next | FIFO / arrival | priority queue + shell boost | name tag (`make`/`sh`/`cc`) pre-classified |
| child class | copy parent prio | classify after observing | classified at `exec()` by name |
| quantum | 1 tick for all | fixed per tier | inferred per process |
| exit stats | discarded at `wait()` | ETW / `/proc` | accumulated as per-name priors |
| fork-bomb | none until NPROC | `rlimit` / `pids.max` | semantic suspicious-tree detection |

**Kernel**
- **Priority scheduler** (`kernel/proc.c::scheduler`) — `priority` 0 (highest)…20, single
  best-candidate pass, `slice_used` reset + `ctxsw_count++` per dispatch.
- **Classes / job groups** — `class_id`, `quantum_ticks`, `group_id` (inherited on fork →
  whole `sh→make→cc` tree gets one BATCH policy via `setjob`).
- **procstat counters** (clock-driven): `ready_ticks, run_ticks, sleep_ticks,
  ctxsw_count, alloc_tick`; **name_priors** persist name→class learning across reboots.
- **Dedicated virtio-console advisor channel** (`kernel/virtio_console.c`, "Plan A") on
  the third virtio-mmio slot (**VIRTIO2**, `0x10003000`, IRQ 3 — moved up from VIRTIO1 so
  swap can use bus.1). Exposed as `/advisor`; advisor traffic (`@@WL`/`setcls`) never
  mixes with the UART human shell. Best-effort boot if the device is absent.
- **Syscalls 22–35** — `getprocstat(_all)`, `getnamepriors`, `setpriority/getpriority`,
  `setclass`, `setquantum`, `setjob/getjob/setjobpriority/setjobclass`, `setnamepriors`,
  `note`, `crash`.

**Userspace:** `advisord, advd, advstat, wl, wlagent, priors, jobtest, setcls, setjprio,
iohog, cc, fbomb, crashme, ftree, priority_test, spin` — plus **`advmem`**, the unified
tree's cross-control daemon that demotes a swap-pressured process to BATCH and restores it
(hysteresis), linking the memory signal to the scheduler.

**LLM advisor (local Ollama)**
```
virtio-console  --@@WL frames-->  bridge.py  --HTTP-->  Ollama (local model)
(unix socket)   <--"setcls .."--  bridge.py  <--JSON--  classification
```
- `tools/bridge.py` classifies `advd`-exported procstat via Ollama and applies decisions
  through the existing `setclass` syscall — the kernel never knows an LLM exists.
- `tools/diagnose.py` (offline fallback), `tools/test_advd.py` (UART-noninterference E2E).
- Default model `qwen2.5:3b` (local, no API key, fully offline after pull).

---

# 한국어

## 빌드 & 실행

```sh
cd xv6-JPLKJ

# 기본 `make`는 커널만 빌드한다 — fs.img / swap.img 는 명시적으로 지정.
make TOOLPREFIX=riscv64-elf- kernel/kernel fs.img swap.img

# QEMU 부팅 (virtio-mmio 3개: fs=bus.0, swap=bus.1, advisor 콘솔=bus.2)
make qemu CPUS=1
```

RISC-V "newlib" 툴체인과 `riscv64-softmmu` QEMU가 필요하다
(<https://pdos.csail.mit.edu/6.1810/>). `swap.img`는 64 MB 두 번째 virtio 디스크
(`dd count=64`, `NSWAP`와 일치해야 함).

**선택 — LLM 파이프라인** (없어도 커널은 정상 부팅·동작):

```sh
# Part 3 — 프로세스 어드바이저 (로컬, API 키 불필요, pull 후 오프라인)
brew install ollama && ollama pull qwen2.5:3b
python3 tools/bridge.py                 # 호스트 브리지 → Ollama → setclass

# Part 2 — 메모리 정책 (Groq 클라우드)
pip install groq python-dotenv pexpect
echo 'GROQ_API_KEY=gsk_...' > .env       # groq_client.py 가 python-dotenv 로 읽음
python3 memory_qemu_live_runner.py --approve   # 풀 라이브 루프: QEMU → bridge → Groq → verify
```

## Part 2 — 메모리: swap + 메모리 quota

커널에 **swap 서브시스템**과 **프로세스별 메모리 quota**를 추가하고, 메모리 정책을 외부
LLM(Groq 클라우드)이 제안·검증하는 호스트측 파이프라인을 갖춘다.

**커널** (`kernel/swap.c`, `swap.h`)
- **swap** — 두 번째 virtio 디스크(`SWAPDEV=2`, `NSWAP=16384` 슬롯 × 4 KB). victim 선택은
  단순(첫 user page) 또는 **A-bit Clock**(`-DSWAP_VICTIM_CLOCK=1`). swap된 PTE는
  `V=0, U=1, PPN←slot`, lazy는 `*pte==0`. 체인: `swapout(pid)` → `select_victim` →
  `swap_write_slot` → `kfree`, 역방향은 fault → `vmfault` → `swapin_page` →
  `swap_read_slot` → PTE 복구.
- **quota** — `uvmalloc`에서 `mem_quota` 초과 alloc을 차단하고 `quota_denied_count` 누적.
- **syscall 36–40** — `getmemstat`(36), `setmemquota`(37), `swapout`(38),
  `getswapstat`(39), `trace`(40). (병합 시 충돌을 피해 프로세스 서브시스템의 22–35 위로 재번호.)
- `struct proc` 추가 필드: `mem_quota, quota_denied_count, trace_mask, swap_clock_hand,
  swapout_count, swapin_count`.

**userspace:** `memstress, memfill, memhold, memwatch, memstat_test, setquota, swapctl,
swaptest, trace_test`.

**LLM 정책 파이프라인 (Groq 클라우드)**
- `bridge.py` (메모리용, 프로세스의 `tools/bridge.py`와 다른 파일) — `memwatch` JSON을
  파싱해 OK/WATCH/DANGER 분류, 3축 효율성 점수와 LLM 프롬프트 생성.
- `groq_client.py` — Groq `openai/gpt-oss-120b`를 strict JSON 스키마(action, target,
  `diagnosis`, reason, confidence)로 호출. `GROQ_API_KEY`는 `.env`에서 읽음.
- `proposal_guard.py` / `hard_verifier.py` / `score_proto.py` — 제안 안전 검증·점수화
  (보호 프로세스는 **이름 기준** 판정, swap/quota 안전 제약 적용).
- `run_pipeline.py` (분석 → 제안 → guard → dry-run 적용) + 라이브 러너
  `memory_qemu_live_runner.py` / `memory_agent_loop.py` / `memory_live_groq_runner.py`
  (QEMU 부팅 → `setquota`/`swapctl` 적용 → 검증 → accept 또는 QEMU 재시작 롤백).

## Part 3 — 프로세스: LLM 어드바이저 스케줄러

vanilla xv6의 라운드로빈을 **우선순위 스케줄러**로 바꾸고, 프로세스 상태를 외부
LLM(로컬 Ollama)이 관찰해 **클래스 · 우선순위 · job 그룹** 정책을 적용한다.

| 축 | 기존 xv6 | 현대 OS | LLM 어드바이저 |
|---|---|---|---|
| 누가 다음에 실행 | FIFO·도착순 | 우선순위 큐 + 셸 승격 | 이름표(`make`/`sh`/`cc`) 사전 분류 |
| 자식 분류 | 부모 우선순위 복사 | 실행 관찰 후 분류 | `exec()` 직후 이름으로 분류 |
| Quantum | 전원 1 tick | 등급별 고정 | 프로세스별 추론값 |
| 종료 통계 | `wait()`시 폐기 | ETW·`/proc` | 이름별 prior로 누적 학습 |
| fork bomb | NPROC까지 무방어 | `rlimit`/`pids.max` | 의미·패턴 기반 의심 트리 탐지 |

**커널**
- **우선순위 스케줄러** (`kernel/proc.c::scheduler`) — `priority` 0(최고)~20, 단일 패스로
  best 후보 선택, dispatch마다 `slice_used` 리셋 + `ctxsw_count++`.
- **클래스 / job 그룹** — `class_id`, `quantum_ticks`, `group_id`(fork 시 상속 →
  `sh→make→cc` 트리 전체에 BATCH 정책을 `setjob`으로 일괄 적용).
- **procstat 카운터**(clock 구동): `ready_ticks, run_ticks, sleep_ticks, ctxsw_count,
  alloc_tick`; **name_priors**는 이름→클래스 학습을 재부팅 후에도 유지.
- **virtio-console 전용 어드바이저 채널**(`kernel/virtio_console.c`, "Plan A") — 세 번째
  virtio-mmio 슬롯(**VIRTIO2**, `0x10003000`, IRQ 3 — swap이 bus.1을 쓰도록 VIRTIO1에서
  올림)을 `/advisor` 디바이스로 노출. advisor 트래픽(`@@WL`/`setcls`)이 UART(사람 셸)와
  절대 섞이지 않음. 디바이스 부재 시 panic 없이 best-effort 부팅.
- **syscall 22–35** — `getprocstat(_all)`, `getnamepriors`, `setpriority/getpriority`,
  `setclass`, `setquantum`, `setjob/getjob/setjobpriority/setjobclass`, `setnamepriors`,
  `note`, `crash`.

**userspace:** `advisord, advd, advstat, wl, wlagent, priors, jobtest, setcls, setjprio,
iohog, cc, fbomb, crashme, ftree, priority_test, spin` — 그리고 통합 트리의 교차 제어
데몬 **`advmem`**: swap 압박 프로세스를 BATCH로 강등했다가 복원(hysteresis)해 메모리
신호를 스케줄러에 연결한다.

**LLM 어드바이저 (로컬 Ollama)**
```
virtio-console  --@@WL frames-->  bridge.py  --HTTP-->  Ollama (로컬 모델)
(unix socket)   <--"setcls .."--  bridge.py  <--JSON--  classification
```
- `tools/bridge.py` — `advd`가 export한 procstat을 Ollama로 분류, 결정을 기존 `setclass`
  syscall로 적용(커널은 LLM 존재를 모름).
- `tools/diagnose.py`(오프라인 폴백), `tools/test_advd.py`(UART 무간섭 E2E 검증).
- 기본 모델 `qwen2.5:3b`(로컬, API 키 불필요, pull 후 완전 오프라인).
