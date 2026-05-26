# xv6-process 리팩토링·개선 후보 보고서

> 대상: `xv6-process/` (LLM advisor가 추가된 xv6 RISC-V 포크)
> 작성일: 2026-05-26
> 범위: 커널 신규 시스템콜·proc.c 변경분·사용자 프로그램·빌드 산출물

---

## 1. 요약

| 심각도 | 항목 | 위치 |
|--------|------|------|
| High | trace_test / sysinfo_test 는 빌드 불가능한 dead code | `user/trace_test.c`, `user/sysinfo_test.c` |
| High | `sys_getprocstat_all` 가 커널 스택에 ~5KB 버퍼 할당 | `kernel/sysproc.c:198` |
| Medium | `procstat_get`의 `p->parent->pid` 읽기 race (wait_lock 미보유) | `kernel/proc.c:768` |
| Medium | `procstat_tick` 의 가짜 "try-acquire" (실제로는 blocking) | `kernel/proc.c:735~738` |
| Medium | `proc_setclass` 가 `quantum_ticks` 를 silently 덮어씀 | `kernel/proc.c:834` |
| Low | `procstat_get` / `procstat_all` 필드 복사 코드 중복 | `kernel/proc.c:761~816` |
| Low | `proc_setclass` / `proc_setquantum` 의 NPROC 순회 패턴 중복 | `kernel/proc.c:822~864` |
| Low | 매직 넘버 `for (int i = 0; i < 16; i++)` | `kernel/proc.c:778, 810` |
| Low | 빌드 산출물(`*.o`, `*.d`, `*.asm`, `*.sym`)이 소스 트리에 잔존 | `user/`, `kernel/` |

---

## 2. 상세 분석

### 2.1 [High] trace_test / sysinfo_test 는 빌드 불가능한 dead code

`user/trace_test.c` 는 `trace(1 << SYS_fork)` 를, `user/sysinfo_test.c` 는 `sysinfo(&info)` 를 호출한다. 그러나:

- `user/usys.pl` 에 `trace`, `sysinfo` 엔트리가 없다.
- `kernel/syscall.h` 의 syscall 번호 최대값은 `SYS_getprocstat_all = 27` 이며 `SYS_trace`, `SYS_sysinfo` 가 존재하지 않는다.
- `kernel/syscall.c` 의 `syscalls[]` 테이블에도 두 함수가 등록되어 있지 않다.
- Makefile `UPROGS` (line 128~149) 에 `_trace_test`, `_sysinfo_test` 가 빠져 있다.

그럼에도 `user/_trace_test`, `user/_sysinfo_test` 바이너리 및 `.o/.asm/.sym` 산출물이 트리에 남아 있어 코드 리뷰어를 혼란시킨다.

**조치 옵션**
1. `trace`, `sysinfo` 시스템 콜을 끝까지 구현하고 UPROGS 에 추가.
2. `.c` 파일과 stale 바이너리/산출물을 모두 삭제.

본 보고서는 **옵션 2 (삭제)** 를 권장한다. 현재 advisord/advstat 가 procstat 계열 통계를 충분히 노출하고 있어 별도의 trace/sysinfo 가 학습 목적에 추가 가치를 주지 않는다.

---

### 2.2 [High] `sys_getprocstat_all` 커널 스택 버퍼

```c
// kernel/sysproc.c:194~214
uint64
sys_getprocstat_all(void)
{
  ...
  struct procstat buf[PROCSTAT_MAX];   // ← 64 × ~80 bytes ≈ 5,120 bytes on kstack
  ...
}
```

- `PROCSTAT_MAX = 64` (`kernel/procstat.h:27`).
- `sizeof(struct procstat)` ≈ 80 bytes (6×int + 5×uint64 + char[16]).
- 커널 스택 크기는 `KSTACK(p) = 2 * PGSIZE = 8192 bytes` (`kernel/memlayout.h:48`).

8KB 스택에서 5KB 를 단일 로컬 배열에 쓰면 syscall trap frame, 호출 체인의 다른 프레임을 고려할 때 안전 마진이 거의 사라진다. 인터럽트가 중첩되거나 advisord 변형이 더 깊은 호출 체인을 추가하면 stack overflow 가능.

**조치**: 청크 단위(예: 8 entries × 80 bytes = 640 bytes)로 `procstat_all` 을 호출하고 `copyout` 을 반복한다.

```c
// 권장 형태 (의사 코드)
#define CHUNK 8
struct procstat buf[CHUNK];
int written = 0, max;
argint(1, &max);
if (max > PROCSTAT_MAX) max = PROCSTAT_MAX;

while (written < max) {
  int want = max - written;
  if (want > CHUNK) want = CHUNK;
  int n = procstat_all_chunk(written, buf, want);   // 새 헬퍼
  if (n <= 0) break;
  if (copyout(p->pagetable, addr + written * sizeof(struct procstat),
              (char *)buf, n * sizeof(struct procstat)) < 0)
    return -1;
  written += n;
  if (n < want) break;
}
return written;
```

`procstat_all_chunk(start, dst, want)` 는 `proc[start..]` 부터 최대 `want` 개를 채우고 다음 시작 인덱스를 반환하면 된다.

---

### 2.3 [Medium] `procstat_get` 의 parent race

```c
// kernel/proc.c:761~785
int procstat_get(int pid, struct procstat *out) {
  ...
  acquire(&p->lock);
  if (p->pid == pid && p->state != UNUSED) {
    out->pid  = p->pid;
    out->ppid = p->parent ? p->parent->pid : 0;   // ← wait_lock 미보유
    ...
  }
  release(&p->lock);
  ...
}
```

`p->parent` 는 xv6 관례상 `wait_lock` 보호 객체이다. `procstat_all` (line 798~799) 은 "torn read 허용" 주석으로 명시하지만, `procstat_get` 은 무주석이다. 더구나 line 759 주석에서 *"used by sys_setclass and friends to verify"* 라고 했듯, `procstat_get` 의 출력은 단순 통계가 아니라 검증 경로에서도 쓰인다.

**조치**:
- `wait_lock` 을 짧게 잡고 `ppid` 만 채운 뒤 해제하거나,
- 검증 경로에서는 ppid 를 사용하지 않도록 호출자 측 의도를 명확히 한다.

본 보고서는 차순위 작업이므로 우선 주석 정정 + `wait_lock` 보호 도입을 권장.

---

### 2.4 [Medium] `procstat_tick` 의 가짜 try-acquire

```c
// kernel/proc.c:728~755
void procstat_tick(void) {
  ...
  for (p = proc; p < &proc[NPROC]; p++) {
    if (p->state == UNUSED) continue;
    // try-acquire. spinlocks in xv6 don't expose try_acquire, so we
    // gate on the cheap state read and accept that under contention
    // we drop the tick — the counters are statistical anyway.
    acquire(&p->lock);        // ← 사실은 blocking
    switch (p->state) { ... }
    release(&p->lock);
  }
}
```

주석은 "try-acquire 실패 시 tick drop" 이라고 하지만 실제로는 blocking. clockintr 컨텍스트에서 다른 CPU 가 같은 `p->lock` 을 들고 있으면 인터럽트 핸들러가 길어진다. clockintr 은 cpu0 에서만 호출되긴 하지만, 그 동안 cpu0 의 인터럽트 처리 지연이 누적된다.

**조치 옵션**

A. **진짜 `try_acquire` 추가** — `kernel/spinlock.c` 에 한 줄 헬퍼.

```c
// kernel/spinlock.h
int try_acquire(struct spinlock *lk);

// kernel/spinlock.c
int try_acquire(struct spinlock *lk) {
  push_off();
  if (holding(lk)) panic("try_acquire");
  if (__sync_lock_test_and_set(&lk->locked, 1) != 0) {
    pop_off();
    return 0;
  }
  __sync_synchronize();
  lk->cpu = mycpu();
  return 1;
}
```

그리고 `procstat_tick` 에서:

```c
if (!try_acquire(&p->lock)) continue;   // 진짜 drop
```

B. **lockless** — `ready_ticks`/`run_ticks`/`sleep_ticks`/`slice_used` 를 atomic 증가로 바꾸고 락 없이 state 만 읽기. 다만 state 가 락 없이 읽힌다는 점에서 다른 race 가 도입될 수 있어 옵션 A 가 안전.

본 보고서는 **A** 를 채택한다.

---

### 2.5 [Medium] `proc_setclass` 의 silent quantum 덮어쓰기

```c
// kernel/proc.c:822~841
int proc_setclass(int pid, int class_id) {
  ...
  p->class_id = class_id;
  // class change auto-updates the recommended quantum, but the
  // advisor can override via setquantum afterward.
  p->quantum_ticks = class_default_quantum[class_id];
  ...
}
```

advisord 가 `setquantum(pid, q)` → `setclass(pid, c)` 순서로 호출하면 `q` 가 silently 사라진다. 호출 순서 의존성이 인터페이스로 노출되지 않는다.

**조치 (이번 PR 범위 밖, 차후 권장)**:
- `setclass` 에서 quantum 자동 변경 제거.
- `int recommend_quantum_for_class(int class_id)` 헬퍼를 따로 두고 advisord 가 명시적으로 호출.

---

### 2.6 [Low] 리팩토링 후보

#### 2.6.1 procstat 필드 복사 중복

`procstat_get` (line 767~778) 과 `procstat_all` (line 797~810) 의 필드 복사가 12줄씩 거의 동일. 헬퍼로 추출:

```c
static void
procstat_fill(struct procstat *dst, struct proc *p)
{
  dst->pid           = p->pid;
  dst->ppid          = p->parent ? p->parent->pid : 0;
  dst->state         = (int)p->state;
  dst->priority      = p->priority;
  dst->class_id      = p->class_id;
  dst->quantum_ticks = p->quantum_ticks;
  dst->ready_ticks   = p->ready_ticks;
  dst->run_ticks     = p->run_ticks;
  dst->sleep_ticks   = p->sleep_ticks;
  dst->ctxsw_count   = p->ctxsw_count;
  dst->lifetime      = (uint64)(ticks - p->alloc_tick);
  for (uint i = 0; i < sizeof(dst->name); i++)
    dst->name[i] = p->name[i];
}
```

#### 2.6.2 pid 검색 루프 중복

`proc_setclass` / `proc_setquantum` 모두 NPROC 순회 + pid 매칭 + lock 보호 패턴 동일. `static struct proc *find_proc_by_pid_locked(int pid)` 헬퍼 도입 가능.

#### 2.6.3 매직 넘버

`for (int i = 0; i < 16; i++) out->name[i] = p->name[i];` (line 778, 810) → `sizeof(out->name)` 사용.

#### 2.6.4 빌드 산출물

`user/`, `kernel/` 디렉토리에 `*.o`, `*.d`, `*.asm`, `*.sym` 및 `_*` 바이너리가 다수 존재. `make clean` 후 `git status` 로 추적 여부 확인 필요.

---

## 3. 이번 PR 작업 범위

본 리팩토링 PR 에서는 **#1, #2, #4** 만 적용한다. 이유:

- #1: 즉각 제거 가능한 dead code → 코드베이스 정리 효과 큼.
- #2: 잠재적 커널 스택 overflow → 안전성 직결.
- #4: 잘못된 주석/blocking interrupt → spinlock 인프라 추가는 다른 곳에서도 재사용 가능.

#3 (parent race), #5 (setclass side effect), #6 (리팩토링) 는 advisord 의 의미론과 맞물려 별도 논의가 필요하므로 후속 PR 에서 다룬다.

---

## 4. Agent 검토 시 부정확했던 주장 (검증 결과)

코드 리뷰 보조 에이전트가 *Critical* 로 표시한 다음 항목은 **실제로는 문제 없음** 으로 검증되었다. 향후 같은 함정에 빠지지 않도록 기록한다.

| 주장 | 검증 결과 |
|------|----------|
| "kexit 가 `wait_lock` 보유한 채 `sched()` 호출" | **틀림.** `kernel/proc.c:409` 에서 release 후 line 412 `sched()` 호출. `sched()` 가 요구하는 `noff == 1`, `p->lock holding` 조건을 정확히 만족. |
| "scheduler 에서 두 CPU 가 같은 proc 을 RUNNING 으로 만드는 race" | **틀림.** `best->lock` 을 swtch 까지 유지. 표준 xv6 패턴과 동일하게 안전. |
| "freeproc 의 advisor 필드 clear 가 ZOMBIE 스냅샷과 모순" | **틀림.** `freeproc` 은 `kwait` 안에서 ZOMBIE 리핑 *이후* 호출. advisor 는 이미 ZOMBIE 스냅샷을 관측한 뒤이므로 모순 없음. |
