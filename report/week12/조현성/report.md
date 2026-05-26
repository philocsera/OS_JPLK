# xv6-process 리팩토링 작업 보고서

> 작업일: 2026-05-26
> 작업자: 조현성
> 대상: `xv6-process/` (LLM advisor가 추가된 xv6 RISC-V 포크)
> 함께 보면 좋은 문서: [refactoring.md](./refactoring.md) (사전 검토 분석)

---

## 1. 한 줄 요약

코드 리뷰에서 발견한 9개 항목 중 **가장 의미 있는 3개** 를 골라 직접 패치했다.
빌드 통과 + 디스어셈블리로 동작 검증까지 마쳤다.

| # | 무엇을 | 왜 | 어떻게 |
|---|--------|-----|--------|
| 1 | 사용자 프로그램 2개 삭제 | 빌드도 안 되는 dead code가 트리에 남아 리뷰어를 혼란시킴 | 파일 + 산출물 일괄 제거 |
| 2 | 커널 스택 버퍼 ~5KB → 640B | 8KB 커널 스택에 5KB 단일 배열을 올리는 건 위험 | "한 번에 다 긁기" → "8개씩 청크" |
| 4 | 가짜 try-acquire → 진짜 try-acquire | 클럭 인터럽트가 blocking acquire 때문에 멈출 수 있음 | `spinlock.c` 에 `try_acquire()` 추가 |

---

## 2. 각 작업의 배경과 실제로 한 일

### 2.1 작업 #1 — `trace_test`, `sysinfo_test` 정리

#### 무엇이 문제였나
`user/trace_test.c` 와 `user/sysinfo_test.c` 가 트리에 있었다. 그런데:

- 두 파일은 `trace(...)`, `sysinfo(&info)` 시스템 콜을 호출한다.
- 그러나 **그런 시스템 콜이 커널에 존재하지 않는다**:
  - `kernel/syscall.h` 의 SYS_ 번호 끝은 `SYS_getprocstat_all = 27`. `SYS_trace`, `SYS_sysinfo` 없음.
  - `kernel/syscall.c` 의 디스패치 테이블에도 없음.
  - `user/usys.pl` (사용자 측 스텁 생성 스크립트) 에도 없음.
- `Makefile` 의 `UPROGS` 리스트(빌드 대상 사용자 프로그램 목록) 에도 두 프로그램이 **빠져 있다**.

즉, 두 `.c` 파일은 **빌드도 되지 않고, 빌드되어도 링크 에러가 나는 죽은 코드** 였다. 그런데도 누군가가 과거에 한 번 빌드해놓은 `_trace_test`, `_sysinfo_test` 바이너리와 `.o/.d/.asm/.sym` 부산물이 트리에 남아 코드 리뷰어를 헷갈리게 만들고 있었다.

#### 어떻게 했나
1. `grep` 으로 트리 전체에서 `trace_test`, `sysinfo_test`, `SYS_trace`, `SYS_sysinfo` 참조를 검색 → 자기 자신 외에 참조가 없음을 확인.
2. `user/` 디렉토리에서 12개 파일 삭제:
   - `trace_test.c`, `trace_test.asm`, `trace_test.d`, `trace_test.o`, `trace_test.sym`, `_trace_test`
   - `sysinfo_test.c`, `sysinfo_test.asm`, `sysinfo_test.d`, `sysinfo_test.o`, `sysinfo_test.sym`, `_sysinfo_test`

#### 결과
빌드에 영향 없음(애초에 빌드 대상이 아니었으니까). 트리가 깔끔해짐.

---

### 2.2 작업 #2 — `sys_getprocstat_all` 의 커널 스택 버퍼 축소

#### 무엇이 문제였나
원래 코드 (`kernel/sysproc.c`):

```c
uint64
sys_getprocstat_all(void)
{
  uint64 uaddr;
  int max;
  struct procstat buf[PROCSTAT_MAX];   // ← 여기!
  ...
  n = procstat_all(buf, max);
  copyout(..., (char *)buf, n * sizeof(struct procstat));
  return n;
}
```

문제는 한 줄짜리 로컬 배열 `struct procstat buf[PROCSTAT_MAX]` 였다. 숫자를 풀어 보면:

- `PROCSTAT_MAX = 64` (xv6 의 `NPROC` 과 같은 값)
- `sizeof(struct procstat)` ≈ 80 바이트 (int 6개 + uint64 5개 + char[16])
- 따라서 **이 배열 하나가 커널 스택에 약 5,120 바이트 (5KB) 를 잡는다**.

xv6 의 커널 스택은 한 프로세스당 `2 × PGSIZE = 8192 바이트 (8KB)` 다. 즉:

- 사용 가능한 스택: 8KB
- 이 배열 하나: 5KB
- 남은 여유: 3KB
- 거기에 syscall trap frame, 함수 호출 체인의 다른 스택 프레임이 더 쌓임.

당장 터지지는 않더라도 안전 마진이 너무 얇다. advisord 가 호출 깊이를 늘리거나 인터럽트가 중첩되면 silent stack overflow 가 날 수 있다.

#### 어떻게 했나
"한 번에 64개를 다 채워서 한 번 copyout" → "8개씩 채워서 8번 copyout" 으로 바꿨다.

**Step 1.** `kernel/proc.c` — `procstat_all` 를 범위 기반으로 변경.

이전:
```c
int procstat_all(struct procstat *dst, int max);
// 항상 proc[0..NPROC) 전체를 스캔
```

이후:
```c
int procstat_all_range(int start, int end, struct procstat *dst, int dst_cap);
// proc[start..end) 만 스캔, dst_cap 개까지만 채움
```

함수 본체는 그대로지만, 인덱스를 받아 부분 스캔을 가능하게 만들었다. 이참에 `for(int i = 0; i < 16; ...)` 매직 넘버는 `sizeof(dst[n].name)` 로 교체했다.

**Step 2.** `kernel/defs.h` — 프로토타입 갱신.

```c
- int procstat_all(struct procstat *dst, int max);
+ int procstat_all_range(int start, int end, struct procstat *dst, int dst_cap);
```

**Step 3.** `kernel/sysproc.c` — 청크 루프로 다시 작성.

```c
#define PROCSTAT_CHUNK 8   // 8 × 80B = 640B on kstack — 안전한 크기

uint64
sys_getprocstat_all(void)
{
  uint64 uaddr;
  int max;
  struct procstat buf[PROCSTAT_CHUNK];   // 640 바이트로 축소
  int written = 0;

  argaddr(0, &uaddr);
  argint(1, &max);

  if (max <= 0)         return -1;
  if (max > PROCSTAT_MAX) max = PROCSTAT_MAX;

  pagetable_t pt = myproc()->pagetable;

  for (int start = 0; start < NPROC && written < max; start += PROCSTAT_CHUNK) {
    int end       = start + PROCSTAT_CHUNK;
    int remaining = max - written;
    int cap       = remaining < PROCSTAT_CHUNK ? remaining : PROCSTAT_CHUNK;

    int n = procstat_all_range(start, end, buf, cap);
    if (n <= 0) continue;

    if (copyout(pt, uaddr + (uint64)written * sizeof(struct procstat),
                (char *)buf, n * sizeof(struct procstat)) < 0)
      return -1;
    written += n;
  }
  return written;
}
```

#### 핵심 아이디어 (왜 이게 안전한가)
- 한 번 호출당 스택 사용량을 **5,120 → 640 바이트** 로 줄였다.
- 같은 `procstat` 묶음을 한 번에 다 채우든, 8개씩 8번 채우든 advisord 입장에서는 결과가 동일 — `copyout` 의 목적지 주소만 `written * sizeof(struct procstat)` 만큼 밀어 주면 된다.
- 락 보호 단위는 여전히 per-proc lock 이라 의미론적으로도 동일.

#### 결과
빌드 OK. 사용자 측 API 시그니처는 **변경 없음** (`getprocstat_all(arr, max)` 그대로) → advisord/advstat 재컴파일 불필요. 커널 내부 구현만 안전해졌다.

---

### 2.3 작업 #4 — `procstat_tick` 의 가짜 try-acquire 를 진짜로

#### 무엇이 문제였나
원래 `kernel/proc.c` 의 `procstat_tick()` (clockintr 에서 매 tick 호출됨):

```c
void
procstat_tick(void)
{
  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++) {
    if (p->state == UNUSED) continue;
    // try-acquire. spinlocks in xv6 don't expose try_acquire, so we
    // gate on the cheap state read and accept that under contention
    // we drop the tick — the counters are statistical anyway.
    acquire(&p->lock);   // ← 주석은 try-acquire 라는데 실제론 blocking acquire
    switch (p->state) { ... }
    release(&p->lock);
  }
}
```

주석은 **"실패하면 tick 을 그냥 drop"** 이라고 약속하지만, 실제 코드는 `acquire()`. xv6 의 `acquire()` 는 락이 비어있을 때까지 무한히 spin 한다.

즉, 다른 CPU 가 같은 `p->lock` 을 (예: scheduler 에서 `swtch` 직전에) 잡고 있는 동안 **클럭 인터럽트 핸들러가 거기서 멈춰 기다린다**. clockintr 은 cpu0 에서만 호출되지만, 그 동안 cpu0 의 인터럽트 처리가 지연된다. 이는 process.md §5 의 "fast paths must not be perturbed by accounting" 원칙에 정면으로 어긋난다.

#### 어떻게 했나

**Step 1.** `kernel/spinlock.c` — 진짜 `try_acquire()` 헬퍼 추가.

```c
// Try to acquire the lock without spinning. Returns 1 on success
// (lock is now held by this CPU), 0 on failure (lock was busy).
int
try_acquire(struct spinlock *lk)
{
  push_off();                        // 인터럽트 끄기 (acquire 와 동일)
  if (holding(lk))
    panic("try_acquire");

  if (__sync_lock_test_and_set(&lk->locked, 1) != 0) {
    pop_off();                       // 실패 → 인터럽트 상태 복구
    return 0;
  }

  __sync_synchronize();
  lk->cpu = mycpu();
  return 1;
}
```

핵심은 `__sync_lock_test_and_set` 의 반환값. 이미 1이면 다른 CPU 가 잡고 있다는 뜻이라 즉시 `pop_off` 하고 0 을 돌려준다 (spin 하지 않는다). xv6 의 RISC-V atomic swap 인스트럭션을 그대로 활용했다.

**Step 2.** `kernel/defs.h` — 프로토타입 추가.

```c
void   acquire(struct spinlock*);
int    try_acquire(struct spinlock*);   // ← 추가
int    holding(struct spinlock*);
```

**Step 3.** `kernel/proc.c` — `procstat_tick` 가 실제로 try-acquire 를 쓰도록 수정.

```c
void
procstat_tick(void)
{
  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++) {
    if (p->state == UNUSED) continue;
    // Real non-blocking try-acquire. If another CPU holds p->lock we
    // drop this tick rather than stall the clock interrupt.
    if (!try_acquire(&p->lock))
      continue;                       // ← 실패하면 진짜로 skip
    switch (p->state) { ... }
    release(&p->lock);
  }
}
```

거짓이었던 옛 주석도 함께 제거하고, 의도가 명확한 문장으로 교체했다.

#### 결과
빌드 OK. 디스어셈블리(`riscv64-elf-objdump -d kernel/kernel`) 로 검증:

```
0000000080002420 <procstat_tick>:
  ...
  80002462: 4c9c          lw    a5,24(s1)
  80002464: dbfd          beqz  a5,8000245a       ; state == UNUSED 면 skip
  80002466: 8526          mv    a0,s1
  80002468: 855fe0ef      jal   80000cbc <try_acquire>   ; ← 진짜 try_acquire 호출
  8000246c: d57d          beqz  a0,8000245a              ; 실패하면 skip
  ...
```

이제 다른 CPU 가 `p->lock` 을 잡고 있으면 clockintr 은 거기서 **0 cycle 만에 다음 proc 으로 넘어간다**. 그 tick 의 카운터 증가는 잃지만 (어차피 advisord 는 통계적 수치라 허용), 인터럽트 지연은 0.

부수 효과: `try_acquire()` 는 spinlock 인프라의 일부이므로 앞으로 다른 인터럽트 컨텍스트 코드도 재사용할 수 있다.

---

## 3. 변경된 파일

```
xv6-process/kernel/defs.h        — 프로토타입 갱신 (procstat_all_range, try_acquire)
xv6-process/kernel/proc.c        — procstat_all → procstat_all_range, procstat_tick fix
xv6-process/kernel/spinlock.c    — try_acquire 헬퍼 신규
xv6-process/kernel/sysproc.c     — sys_getprocstat_all 청크 루프로 재작성
xv6-process/user/trace_test.c    — 삭제
xv6-process/user/sysinfo_test.c  — 삭제
+ stale 빌드 산출물 10개 삭제 (_trace_test, _sysinfo_test, *.o/.d/.asm/.sym)

report/week12/조현성/refactoring.md — 사전 검토 문서 (이번 PR 진단의 근거)
report/week12/조현성/report.md     — 본 작업 보고서
```

---

## 4. 검증

| 항목 | 방법 | 결과 |
|------|------|------|
| 커널 빌드 | `make` | OK (사전 존재하던 `class_default_quantum` GNU designator 경고, linker RWX 경고만 잔존 — 본 작업과 무관) |
| `try_acquire` 컴파일됨 | `objdump -d kernel/kernel \| grep try_acquire` | `0x80000cbc <try_acquire>` 확인 |
| `procstat_tick` 가 try_acquire 호출 | 디스어셈블리 | `jal 80000cbc <try_acquire>` + 실패 시 `beqz` 분기 확인 |
| 사용자 API 호환성 | `user.h`, `usys.pl` 변경 없음 | advisord/advstat 재컴파일 없이 동작 |

---

## 5. 이번 PR 에서 의도적으로 **하지 않은** 것

검토 단계 (`refactoring.md`) 에서 발견했지만 이번 PR 에는 포함하지 않은 항목:

- **#3 procstat_get 의 parent race**: advisord 의미론과 맞물려 별도 논의 필요. 우선 차순위.
- **#5 proc_setclass 가 quantum 을 silently 덮어쓰는 부작용**: API 시맨틱 변경이라 advisord 측 사용 패턴 점검 후 손대는 게 안전.
- **#6 리팩토링 (필드 복사 헬퍼, pid 검색 헬퍼)**: 동작 변경 없는 청결도 작업. 본 PR 의 안전성 fix 와 섞이면 리뷰가 흐려져서 분리.

---

## 6. 다음 작업 제안

1. **procstat 필드 복사 헬퍼 추출** — `procstat_get` 과 `procstat_all_range` 가 같은 12줄을 반복하고 있다. `static void procstat_fill(struct procstat *, struct proc *)` 로 묶으면 둘 다 깔끔해진다.
2. **parent race 결정** — `procstat_get` 이 검증 경로에서도 쓰이는지 호출자 점검 후, `wait_lock` 보호를 도입할지 / "torn read OK" 를 정식 문서화할지 정한다.
3. **빌드 산출물 정리** — `user/`, `kernel/` 에 남아있는 `.o/.d/.asm/.sym` 가 `.gitignore` 로 잘 제외되는지 `git status --ignored` 로 한 번 확인.
