# xv6 통합 Level 0 / 1 / 2 구현 및 성능 테스트

> 작성일: 2026-06-04 · 관련 문서: [`discuss.md`](./discuss.md) (Q4 레벨 정의)
> 결과물: 저장소 루트의 `xv6-lv0/`, `xv6-lv1/`, `xv6-lv2/` (각각 독립 빌드·부팅·테스트 가능)

`discuss.md`의 Level 0/1/2를 각각 별도 디렉터리로 구현하고 QEMU에서 실제 부팅·기능 검증·성능 측정을 수행했다.

---

## 0. 통합 베이스와 병합 전략

- 두 서브시스템은 같은 MIT xv6-riscv(커밋 `1eec3aa` "nits in preparation for clang-format")에서 포크됨을 확인.
- 병합 공식: **`xv6-lv0 = xv6-process 트리 + (xv6-memory − vanilla)`**.
  - `xv6-process`(스케줄 LLM 어드바이저, 로컬 Ollama `qwen2.5:3b`)를 베이스로,
  - `xv6-memory`(swap+quota, Groq 클라우드)가 vanilla 대비 추가한 델타만 이식.
- 두 트리 모두 **lazy allocation + `vmfault`/`ismapped`** 인프라를 공유(클래스 포크 베이스에 이미 포함) → swap-in 훅을 기존 `vmfault`에 끼워 넣는 형태로 병합이 단순해짐.

### 핵심 충돌과 해소
| 충돌 | 내용 | 해소 |
|---|---|---|
| **virtio MMIO 슬롯** | process=콘솔, memory=swap 디스크가 **둘 다 VIRTIO1(0x10002000, IRQ2)** 사용 | 어드바이저 콘솔을 **VIRTIO2(0x10003000, IRQ3)** 로 이동. fs=bus.0, swap=bus.1, console=bus.2 |
| **syscall 번호** | memory(22~28)가 process(22~35)와 충돌, 양쪽이 독립적으로 `setpriority/getpriority` 정의 | memory 고유 syscall을 **36~40**으로 재번호화(`getmemstat=36 … trace=40`), 중복 `setpriority/getpriority`는 process 것 사용 |
| `virtio_disk.c` | memory가 다중 디스크(배열)로 재작성, `virtio_disk_intr(int)` | memory판 통째로 채택 + `devintr()` 3-way 라우팅(VIRTIO0→disk(1), VIRTIO1→disk(2), VIRTIO2→console) |
| `growproc`/`kfork` | memory가 quota 검사·`uvmcopy` 중 sleep 대비 락 해제 추가 | memory 로직 이식 + process의 group/class/priority 상속 보존 |
| FSSIZE | 두 서브시스템 user 프로그램 합본이 2MB 이미지 초과 | `FSSIZE 2000 → 8000` (8MB) |

빌드: `make TOOLPREFIX=riscv64-elf- kernel/kernel fs.img swap.img` (세 디렉터리 모두 클린 빌드 성공).

---

## 1. Level 0 — 공존 (Coexistence)

**정의**: 한 커널에 스케줄 어드바이저 + 메모리(swap/quota)가 모두 들어가되 서로 대화하지 않음.

**검증 (QEMU, smp 3)** — 양쪽 서브시스템 모두 정상 동작:

| 영역 | 테스트 | 결과 |
|---|---|---|
| 스케줄 | `priority_test` | **All tests passed!** (setpriority/상속/우선순위 선점) |
| 스케줄 | `jobtest` | **ALL PASSED (0 failures)** (그룹 전파·전체-잡 정책) |
| 메모리(swap) | `swaptest 2` / `swaptest 16` | **전체 PASS** (self/자식 swapout + 패턴 보존 + init/sh 보호 거부) |
| 메모리(quota) | `memstress 65536 8192` | `[quota denied] … resident=65536` → 정상 거부 |
| 메모리(관측) | `memwatch 0` | memstat 스냅샷 + `[swap] used/total slots` 정상 출력 |
| 메모리 | `memstat_test 131072` | setmemquota 전/후 테이블 정상 (※ 아래 버그 1건 수정) |

> **버그 수정 1건(메모리 서브시스템 기존 결함, 병합 무관)**: `memstat_test.c`가 `struct memstat[64]`(4KB=1페이지)를 **스택**에 두어 store page fault(scause 0xf). 같은 트리의 `memwatch.c`가 이미 주석으로 경고하며 `static`을 쓰던 것과 동일하게 `static` 처리하여 해결.

---

## 2. Level 1 — 공유 관측 (Shared observability, read-only)

**정의**: 스케줄 어드바이저가 메모리 압박을 **볼 수 있게**만 함(단방향, 제어 없음).

**구현**:
- `struct procstat`에 `mem_quota / quota_denied_count / swapout_count / swapin_count` 4필드 추가, `procstat_get`·`procstat_all_range`에서 채움.
- `advstat` 표에 `qtaKB swO swI qD` 컬럼 추가.
- `wlagent` 프레임(`@@WL [...]`)에 `swapout/swapin/qdeny` 추가, `bridge.py` 프롬프트에 "thrashing(swapout>5)→BATCH" 규칙·slim payload `swapout` 추가.

**검증**: `memhold` 백그라운드 → `swapctl 5 12`(12페이지 swapout) → `advstat`:
```
pid ... name      prio cls ...  qtaKB swO swI  qD
  5 ... memhold     10 NRM ...      0  12   0   0      <- swap 활동이 어드바이저 입력에 반영됨
```
→ discuss.md Level 1 합격 기준("advstat 메모리 컬럼이 올바른 값, swap 유발 시 반영") 충족.
런타임 동작은 Level 0과 동일(읽기 전용) → 회귀 없음.

---

## 3. Level 2 — 교차 제어 (Cross-control)

**정의**: 스케줄 어드바이저가 메모리 신호에 **실제로 반응**(discuss.md §3 시나리오 (a) 자동 강등).

**구현**: 신규 유저 데몬 `advmem` (LLM 불필요·결정론적).
- Level 1이 노출한 `swapout_count/swapin_count`를 폴링 → `outstanding = swapout − swapin`.
- `outstanding ≥ 4` → **강등**: `setpriority(pid,18)` + `setclass(pid,BATCH)`.
- `outstanding ≤ 1` (페이지 복귀) → **복원**: 원래 prio/class로 되돌림 (히스테리시스로 starvation·진동 방지).
- `advmem scan` = 1회 패스(테스트용), 인자 없으면 데몬.

**검증** — 완전한 피드백 루프 확인:
```
swapctl 5 12                       # 메모리측: 12페이지 swapout
[advmem] DEMOTE pid=5 ... prio 10->18 class NORMAL->BATCH   # 스케줄측 반응
... memhold가 페이지 touch -> swapin ...
[advmem] RESTORE pid=5 ... prio 18->10 class BATCH->NORMAL  # 압박 해소 -> 복원
advstat: pid5 memhold  prio 10 NRM   # 원상 복귀 (영구 starvation 없음)
```
→ memory 행동(swap) → Level-1 신호(swapout_count) → scheduler 반응(강등/복원)의 교차 제어가 동작.

---

## 4. 성능 테스트

### 4.1 환경·방법
- QEMU `-smp 1`(단일 CPU)에서 측정 — 이 커널 스케줄러는 우선순위 번호가 작을수록 우선,
  **동일 우선순위는 proc[] 슬롯 인덱스가 낮은 쪽이 독점**(시분할 아님, round-robin 주석은 부정확).
- 워크로드: **메모리 압박 hog**(`bench 20`: 20페이지 상주 후 CPU 점유) vs **생산적 good job**(`bench 0`: 순수 CPU, 고정 일 12만 iter).
- 측정값: good job이 고정 일을 **끝내는 데 걸린 게스트 틱**(전역 `uptime` 기준, 낮을수록 좋음).
- 시나리오: hog를 먼저 띄워 낮은 슬롯 확보 → `swapctl`로 12페이지 swapout → (lv2만) `advmem scan`이 강등 → good job 투입.
  (hog에 startup pause를 주어 컨트롤러가 hog에 굶지 않도록 함 — §4.3 참고.)

### 4.2 결과

| 레벨 | good job 지연(틱) | 강등 발생 | 해석 |
|---|---|---|---|
| **lv0** (제어 없음) | **302** | 0 | good이 동급 우선순위 hog 뒤에서 **완전 기아** |
| **lv1** (관측만) | **303** | 0 | lv0과 동일 — 관측은 read-only, **런타임 비용 0** |
| **lv2** (교차 제어) | **52** | 1 | hog를 BATCH/prio18로 강등 → good이 **즉시 진행** |

→ **lv2가 good job 지연을 302→52 틱으로 ~5.8× 단축.** lv0≈lv1(302≈303)은 Level 1이
순수 관측(동작 불변)임을 실증. lv2의 강등 1회(`demotes=1`)가 메모리 압박 프로세스로부터
CPU를 회수해 생산적 작업에 돌려줌(전역 최적).

### 4.3 부수 발견 — 컨트롤러도 굶을 수 있다
초기 측정에서 lv2도 302틱(강등 0)이 나왔는데, 원인은 **CPU를 독점하는 hog가 advmem(컨트롤러)
까지 굶겨** 강등이 일어나기 전이었다. 즉 "swap을 일으키는 워크로드가 CPU도 독점"하면 제어 데몬
자체가 스케줄을 못 받는다. 교훈: **교차-제어 데몬은 워크로드보다 높은 우선순위(또는 전용 CPU)에서
돌아야 한다.** 본 측정은 hog에 startup pause를 주어(상주하지만 미점유 구간) 이 효과를 분리했고,
실배치라면 advmem을 elevated priority 시스템 데몬으로 띄우면 된다.

### 4.4 공통 비용 (세 레벨 동일)
- swap 왕복 정확성/지연은 세 레벨 동일(같은 swap 서브시스템): `swaptest 16` 전체 PASS.
- 스케줄 회귀 없음: `priority_test`/`jobtest` 세 레벨 모두 통과.
- 메모리 점유: Level 1의 procstat 4필드(32B/proc) + advmem 상태 배열(lv2)만 추가 — 무시할 수준.

---

## 5. 한눈 요약

| 항목 | lv0 공존 | lv1 관측 | lv2 제어 |
|---|---|---|---|
| 빌드/부팅 | ✅ | ✅ | ✅ |
| 스케줄 회귀(priority_test/jobtest) | ✅ | ✅ | ✅ |
| swap 왕복(swaptest) | ✅ | ✅ | ✅ |
| quota 거부(memstress) | ✅ | ✅ | ✅ |
| advstat 메모리 컬럼 | — | ✅ | ✅ |
| 자동 강등/복원(advmem) | — | — | ✅ |

---

## 6. 재현 방법

```sh
# 빌드 (세 디렉터리 동일)
cd xv6-lv0   # 또는 xv6-lv1 / xv6-lv2
make TOOLPREFIX=riscv64-elf- kernel/kernel fs.img swap.img

# 부팅 (fs=bus.0, swap=bus.1, advisor console=bus.2)
make TOOLPREFIX=riscv64-elf- qemu        # 종료: Ctrl-A x

# 기능 테스트 (게스트 셸에서)
priority_test          # 스케줄 회귀
jobtest                # 잡 그룹 정책
swaptest 16            # swap 왕복(전체 PASS)
memstress 65536 8192   # quota 거부
memwatch 0             # memstat/swapstat 스냅샷
advstat                # (lv1/lv2) 메모리 컬럼 포함 표

# lv2 교차 제어 데모
memhold 30 600 &       # 메모리 보유 프로세스(pid 5)
swapctl 5 12           # 메모리측: 12페이지 swapout
advmem scan            # 스케줄측: 강등 (prio 10->18, NORMAL->BATCH)
advstat                # pid5가 prio 18 BAT로 강등됨 확인
```

비대화식 검증/성능 스크립트는 `tools_test/`에 있음
(`runxv6.exp` 부팅·기능, `perf7.exp` 성능). 가드: `make clean`은 `fs.img`를 지우므로
`make TOOLPREFIX=riscv64-elf- fs.img swap.img`로 재생성.
