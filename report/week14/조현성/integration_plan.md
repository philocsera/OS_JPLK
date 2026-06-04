# xv6-memory ↔ xv6-process 통합 계획 (integration_plan.md)

> 작성일: 2026-06-04 · 대상 브랜치: `feat/llm-advisor-sec04-07`
> 목적: 두 갈래로 분기되어 발전한 xv6 변형을 **하나의 커널 트리**로 합쳐,
> "LLM 어드바이저 스케줄러"와 "swap + 메모리 quota" 서브시스템이 한 빌드에서 함께 동작하게 한다.

---

## 1. 목표 & 비목표

**목표**
- 단일 xv6 트리에서 다음이 모두 빌드/부팅/동작:
  - (process) 우선순위·클래스·job 그룹 스케줄링, procstat 카운터, name_priors,
    virtio-console 어드바이저 채널, 관련 syscall 일습.
  - (memory) swap 서브시스템(swap.c), 메모리 quota, memstat/swapstat, 관련 syscall 일습.
- 두 기능의 userspace 프로그램(UPROGS)과 진단 파이썬 툴링을 한 곳에 모은다.

**비목표(이번 통합 범위 밖)**
- 두 기능을 *상호작용*시키는 신규 로직(예: swap 압박을 어드바이저 입력으로 사용)은 만들지 않는다.
  먼저 **공존(coexistence)** 만 달성하고, 연동은 후속 작업으로 남긴다.
- 알고리즘 개선/리팩터링 없음. 순수 병합.

---

## 2. 현황 분석

### 2.1 디렉터리 구조
| | 위치 | 비고 |
|---|---|---|
| process | `xv6-process/` (repo 루트, 깔끔한 `kernel/` `user/` `tools/`) | 빌드 산출물 미포함 |
| memory | `xv6-memory/xv6-kernel-bridge vanilla.ver/` (한 단계 더 들어감) | `.o/.d/.asm/.sym` 빌드 산출물 다수 커밋됨 |

두 트리 모두 **동일한 vanilla xv6-riscv** 에서 분기했음을 확인(베이스 파일 다수가 바이트 동일).

### 2.2 각 트리가 vanilla에 추가한 것
**process (스케줄러 / LLM advisor)**
- 커널 신규: `procstat.h`, `sysinfo.h`, `virtio_console.c`
- `struct proc` 추가 필드: `priority, class_id, quantum_ticks, slice_used, group_id,
  ready_ticks, run_ticks, sleep_ticks, ctxsw_count, alloc_tick`
- syscall: `setpriority/getpriority/setclass/setquantum/getprocstat/getprocstat_all/
  getnamepriors/setjob/getjob/setjobpriority/setjobclass/note/crash/setnamepriors`
- UPROGS: `advisord, advstat, wl, priors, jobtest, wlagent, setcls, iohog, cc, fbomb,
  crashme, setjprio, ftree, advd, spin, priority_test`
- 툴링: `xv6-process/tools/` (bridge.py, diagnose.py, …)

**memory (swap / quota)**
- 커널 신규: `swap.c`, `swap.h`, `swapstat.h`, `memstat.h`
- `struct proc` 추가 필드: `mem_quota, quota_denied_count, trace_mask,
  swap_clock_hand, swapout_count, swapin_count`
- syscall: `trace/setpriority/getpriority/getmemstat/setmemquota/swapout/getswapstat`
- UPROGS: `trace_test, memstat_test, memstress, memwatch, setquota, memhold,
  memfill, swapctl, swaptest, priority_test`
- 툴링: 루트의 `*.py` (groq_client, hard_verifier, run_pipeline, …)

### 2.3 충돌 표면 — 공유하지만 내용이 다른 커널 파일
diff 라인 수(`xv6-process` vs `xv6-memory` 동일 파일):

| 라인차 | 파일 | 병합 성격 |
|---:|---|---|
| 763 | `proc.c` | **수동 3-way** (양쪽이 allocproc/fork/scheduler/freeproc에 서로 다른 필드 초기화) |
| 381 | `virtio_disk.c` | **가산** (process=vanilla, memory가 swap 디스크 I/O 추가 → memory판 채택) |
| 302 | `sysproc.c` | **가산 분리** (서로 다른 sys_* 함수, 거의 비충돌) |
|  63 | `syscall.c` | 번호표/디스패치 — 재번호 필요 |
|  54 | `vm.c` | memory의 quota 훅(uvmalloc) + swap 훅 → 가산 |
|  45 | `defs.h` | 양쪽 프로토타입 union |
|  36 | `trap.c` | process=clockintr 카운터/quantum, memory=거의 vanilla → 가산 |
|  28 | `proc.h` | `struct proc` 필드 union (아래 §4.2) |
|  24 | `spinlock.c` | 점검 필요(대개 사소) |
|  21 | `syscall.h` | 번호 재배치(아래 §4.1) |
|  ≤6 | `exec.c, virtio.h, plic.c, main.c, memlayout.h, printf.c, param.h, file.h` | 사소·가산 |

**핵심 결론**: 진짜 어려운 수동 병합은 `proc.c` **하나**. 나머지는 가산(한쪽이 vanilla)이거나 분리된 함수라 기계적으로 합쳐진다.

---

## 3. 통합 전략

- **베이스 = `xv6-process/`** 를 선택한다.
  - 이유: repo 루트에 깔끔한 레이아웃, 빌드 산출물 미포함, 현재 작업 브랜치의 주 트리.
  - 그 위에 memory의 swap/quota 변경을 **가산 레이어**로 얹는다.
- **결과물 위치**: `xv6-process/` 를 그대로 통합 트리로 승격(또는 `xv6-unified/`로 복제 후 작업 —
  되돌리기 쉬움. §8 미해결 질문 참조).
- **syscall 번호**: process의 22~35를 유지하고, memory 고유 syscall을 **36 이후로 재번호**.
  중복(`setpriority/getpriority`)은 process판으로 단일화.
- **검증 우선**: 각 단계 후 `make qemu` 부팅 + 양쪽 기능 스모크 테스트.

---

## 4. 충돌 해소 상세 설계

### 4.1 syscall 번호 재배치
process 1~35는 유지. memory 고유 syscall만 이동:

| memory 원래 | 이름 | 통합 후 |
|---:|---|---:|
| 22 | `trace` | **36** |
| 23 | `setpriority` | 22 (process와 시맨틱 **동일 — 통합 확정**, §8-Q3) |
| 24 | `getpriority` | 23 (process와 시맨틱 **동일 — 통합 확정**, §8-Q3) |
| 25 | `getmemstat` | **37** |
| 26 | `setmemquota` | **38** |
| 27 | `swapout` | **39** |
| 28 | `getswapstat` | **40** |

> ✅ `setpriority/getpriority`는 두 트리에서 시맨틱 동일(§8-Q3 확인 완료).
> 인자 `(pid, priority)`·범위 `[0,20]`·반환 규약 일치. memory판이 `state != UNUSED`
> 가드를 추가로 가지므로 **그 가드를 채택**해 단일 구현으로 통합.

영향 파일: `syscall.h`(번호), `syscall.c`(extern + `syscalls[]` 디스패치 표),
`user/usys.pl`(스텁), `user/user.h`(선언).

### 4.2 `struct proc` 필드 union (`proc.h`)
vanilla 필드 + 양쪽 추가 필드를 합친다(서로 disjoint, `priority`만 공통 → 1개로):
```
// 공통
int priority;
// --- process (LLM advisor) ---
int class_id; int quantum_ticks; int slice_used; int group_id;
uint64 ready_ticks, run_ticks, sleep_ticks, ctxsw_count, alloc_tick;
// --- memory (swap/quota) ---
uint64 mem_quota; uint64 quota_denied_count; int trace_mask;
uint64 swap_clock_hand, swapout_count, swapin_count;
```

### 4.3 `proc.c` 수동 병합 (가장 중요)
함수별로 양쪽 변경을 **둘 다** 반영(필드가 겹치지 않음):
- `allocproc()`: process 필드 초기화 + memory 필드 초기화(`mem_quota` 기본값, swap 카운터 0).
- `fork()`: 자식이 부모로부터 상속하는 필드 — process(class_id/group_id 등) + memory(mem_quota/trace_mask) 양쪽 라인 모두 삽입.
- `freeproc()`: 양쪽이 추가한 정리 코드 모두.
- `scheduler()`: **process판 단독 채택**(우선순위 픽). memory의 scheduler()는 vanilla
  round-robin으로 확인됨(§8-Q2 완료) → 병합 충돌 없음, process판 그대로 사용.
- `usertrap`/clockintr 연계 카운터: process판 유지.

### 4.4 가산 병합(낮은 위험)
- `virtio_disk.c` → **memory판 전체 채택**(process는 vanilla).
- `vm.c` → memory의 quota/swap 훅을 process판 위에 추가(uvmalloc의 quota 체크, swap 연동).
- `trap.c` → process의 clockintr 카운터/quantum 로직 유지 + memory 추가분(있으면) 병합.
- `sysproc.c` → 양쪽 `sys_*` 함수 단순 합집합.
- `defs.h` → swap.c/virtio_console.c 등 신규 프로토타입 union.
- `Makefile`:
  - `OBJS`에 `$K/virtio_console.o` **및** `$K/swap.o` 둘 다.
  - `UPROGS`를 양쪽 합집합으로(중복 `priority_test`는 1개).
- 신규 파일 복사: memory→ `swap.c swap.h swapstat.h memstat.h`,
  process→ `procstat.h sysinfo.h virtio_console.c` (이미 베이스에 존재).

### 4.5 userspace & 툴링
- `user/*.c`: 양쪽 프로그램 모두 복사(이름 충돌 없음 확인됨; `priority_test`만 공통 → 동일성 확인 후 1개).
- 파이썬 툴링: `xv6-process/tools/`(advisor)와 memory 루트의 swap/quota 파이썬을
  `tools/` 아래 하위 폴더(예: `tools/advisor/`, `tools/memory/`)로 정리.
- memory 트리에 커밋된 **빌드 산출물(.o/.d/.asm/.sym)은 통합 트리로 가져오지 않는다**
  (`.gitignore` 확인).

---

## 5. 단계별 작업 순서 (각 단계 후 빌드 검증)

1. **준비**: 통합 작업 브랜치 생성, 베이스=`xv6-process/` 확정. (clean 빌드 베이스라인 확보)
2. **신규 파일 반입**: `swap.{c,h}`, `swapstat.h`, `memstat.h` 복사. (아직 Makefile 미등록 → 빌드 영향 없음)
3. **`proc.h`**: §4.2 필드 union.
4. **`syscall.h/.c` + `usys.pl` + `user.h`**: §4.1 재번호 + memory syscall 등록.
5. **`sysproc.c`**: memory의 sys_* 함수 추가(`sys_getmemstat` 등).
6. **`vm.c` / `virtio_disk.c`**: quota·swap 훅 및 디스크 I/O 반입(virtio_disk는 memory판 채택).
7. **`proc.c`**: §4.3 수동 병합. ← 가장 신중하게.
8. **`trap.c`, `defs.h`, 기타 사소 파일**: 가산 병합.
9. **`Makefile`**: OBJS·UPROGS 합집합.
10. **userspace 프로그램·툴링** 반입 및 정리.
11. **전체 빌드 + QEMU 통합 검증**(§6).
12. 문서/README 갱신, PR.

---

## 6. 검증 계획

**빌드**: `cd <통합트리> && make clean && make`
- `TOOLPREFIX=riscv64-elf-` (이 환경 표준, 메모리에 기록됨).

**부팅**: `make qemu` → 셸 프롬프트 도달 + virtio-console 디바이스 부재시 best-effort 부팅 확인(기존 수정 보존).

**process 기능 스모크**
- `advstat` 출력 정상(표 안 깨짐), `setcls`/`setjprio`로 클래스·우선순위 반영,
  `jobtest`로 group BATCH 정책, `getprocstat` 카운터 증가.

**memory 기능 스모크**
- `setquota`로 quota 설정 → 초과 alloc 차단(`quota_denied_count` 증가),
  `memstress`/`memfill`로 swap 유발 → `swapctl`/`getswapstat`로 swapout/in 카운터 확인,
  `swaptest` 통과.

**회귀**: `usertests` (또는 핵심 서브셋) 통과.

**자동화**: 양쪽의 expect 기반 QEMU 테스트(`test-xv6.py` / `test_advd.py`)를 통합 트리에서 각각 구동.

---

## 7. 리스크

| 리스크 | 영향 | 완화 |
|---|---|---|
| `proc.c` 병합 오류 | 부팅 불가/스케줄 오동작 | 함수 단위 병합 + 단계별 빌드, 필드 초기화 누락 점검 |
| `setpriority/getpriority` 시맨틱 불일치 | 한쪽 기능 깨짐 | §8-Q3 먼저 확인, 다르면 분리 번호 |
| swap 디스크 I/O ↔ fs.img 레이아웃 | swap 영역과 파일시스템 충돌 | memory의 `memlayout.h`/swap 영역 정의(64MB 확장) 채택 확인 |
| virtio-console(advisor) 와 virtio-disk(swap) 동시 등록 | 디바이스 초기화 순서 | `main.c`/`plic.c` 병합 시 둘 다 init 되는지 검증 |
| memory 트리의 빌드 산출물 유입 | 리포 오염 | 산출물 제외, `.gitignore` 확인 |

---

## 8. 미해결 질문 (작업 착수 전 확정 필요)

- **Q1. 결과물 위치** *(미정)*: `xv6-process/`를 통합 트리로 승격 vs 신규 `xv6-unified/`로 복제?
  (후자가 롤백 안전, 전자가 정리 깔끔)
- ~~**Q2. `scheduler()`**~~ ✅ **확인 완료**: memory의 `scheduler()`는 vanilla round-robin.
  → process의 우선순위 스케줄러를 **단독 채택**, 병합 충돌 없음.
- ~~**Q3. `setpriority/getpriority`**~~ ✅ **확인 완료**: 두 트리 시맨틱 동일(인자·범위·반환).
  → **단일 syscall로 통합**(memory의 `state != UNUSED` 가드 채택).
- **Q4. 기능 연동 범위** *(미정)*: 이번엔 "공존"만(권장) vs swap↔advisor 연동까지?
- **Q5. 파이썬 툴링** *(미정)*: 두 파이프라인을 한 venv/실행 진입점으로 통합할지, 폴더만 분리해 둘지.

---

## 9. 작업량 추정
- 기계적 가산 병합(파일 10여 개): 비교적 단순.
- `proc.c` 수동 병합 + syscall 재번호: 집중 작업 1건.
- 빌드/QEMU 검증 + 회귀: 반복 루프.
- → **핵심 난이도는 `proc.c`와 syscall 표 한 번**, 나머지는 조립.
