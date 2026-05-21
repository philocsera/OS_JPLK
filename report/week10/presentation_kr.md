# 10주차 발표

이번 주 작업은 xv6 기반 커널에 추가한 서로 보완적인 두 가지 기능을 다룬다:

1. **프로세스별 메모리 쿼터** — 커널이 각 프로세스의 메모리 사용량을 보고하고 상한을 걸 수 있게 한다.
2. **스케줄러용 LLM 어드바이저 인터페이스** — 프로세스별 스케줄링 상태를 노출해, 외부 어드바이저가 커널 fast path를 건드리지 않고도 프로세스를 재분류할 수 있게 한다.

두 작업은 같은 철학을 공유한다: 커널은 자기 일을 그대로 하고, 우리는 작고 잘 격리된 인터페이스를 통해 그것을 *관측하고* *조정하는* 능력만 더한다.

---

## Part 1 — 프로세스별 메모리 쿼터

### 목표

프로세스별 메모리 사용량을 **관측 가능**하고 **강제 가능**하게 만든다. 누구든(사용자, 테스트, 또는 어드바이저)이 한 프로세스가 메모리를 얼마나 쓰는지 읽고, 그 사용량에 하드 상한을 설정할 수 있어야 한다.

### 기능

- **`getmemstat` syscall** — 프로세스의 현재 메모리 사용량(예: `sz`)과 설정된 쿼터를 보고한다.
- **`setmemquota` syscall** — 프로세스별 메모리 제한값을 설정한다.
- **`struct proc`의 `mem_quota` 필드** — 각 프로세스가 자신의 쿼터를 갖는다.
- **`growproc`에서의 쿼터 강제** — 프로세스가 주소 공간을 확장할 때, 커널이 요청을 쿼터와 비교해 한계를 초과하면 확장을 실패시키고 `sbrk()`가 에러를 반환한다.

### 동작 방식

- 프로세스는 자신(또는 다른 프로세스)의 메모리 사용량과 제한값을 언제든 조회할 수 있다.
- 특정 프로세스에 제한값을 부여할 수 있다.
- 사용량이 쿼터에 도달하면, 조용히 늘어나는 대신 추가 할당이 거부된다.

### 검증

두 개의 작은 프로그램으로 기능을 시험한다:

- **`memstress`** — 메모리를 반복 할당해 프로세스를 쿼터 근처(및 초과)로 밀어붙인다.
- **`memstat_test`** — `sz`와 `quota`를 되읽어 커널의 회계가 정확한지 확인한다.

수용 기준은 단순하고 곧바로 검증 가능하다:

| 질문 | 검증 수단 |
|---|---|
| 프로세스별 메모리 사용량을 볼 수 있는가? | `getmemstat` / `memstat_test` |
| 특정 프로세스에 메모리 상한을 설정할 수 있는가? | `setmemquota` |
| 쿼터를 초과하면 `sbrk()`가 실패하는가? | 쿼터 적용 전/후 `memstress` |

실험은 쿼터 적용 **전**과 **후**의 `memstress` 로그를 비교해, 제한이 없을 때는 할당이 자유롭게 성공하고 제한이 걸리면 차단되는 것을 보여준다.

---

## Part 2 — 스케줄러용 LLM 어드바이저 인터페이스

### 목표

"옆에 LLM 어드바이저가 있는 xv6"의 **커널 측 절반**을 구현한다. 커널은 기존 스케줄링 로직을 유지하고, 우리는 외부 어드바이저가 그 상태를 읽고 흔들기 위해 필요한 정책 상태와 syscall만 추가한다. 핵심 아이디어: *커널 함수들은 그대로다 — 그것들이 읽는 값의 품질만 달라진다.*

### 커널이 새로 노출하는 것

- **새로운 프로세스별 정책 상태** — 기존 `priority`와 함께, 각 프로세스는 **클래스**(`class_id`)와 **타임슬라이스 길이**(`quantum_ticks`), 그리고 가벼운 카운터들을 갖게 된다.
- **커널과 사용자 공간이 공유하는 `procstat` 스냅샷** — 어드바이저가 필요로 하는 모든 것을 하나의 구조체로 담는다:

  ```c
  struct procstat {
    int pid, ppid, state, priority, class_id, quantum_ticks;
    uint64 ready_ticks, run_ticks, sleep_ticks, ctxsw_count, lifetime;
    char name[16];
  };
  ```

- **6개의 프로세스 클래스** — `INTERACTIVE / IO_BOUND / NORMAL / CPU_BOUND / BATCH / SYSTEM`.
- **클래스 → 디폴트 타임슬라이스 매핑** (커널 측의 유일한 정책):

  | 클래스 | 퀀텀 (ticks) | 이유 |
  |---|---|---|
  | INTERACTIVE | 1 | 지연시간 우선 — 매 tick yield |
  | IO_BOUND | 1 | 자주 sleep하므로 슬라이스를 늘릴 필요 없음 |
  | NORMAL | 1 | 원본 xv6와 동일 |
  | CPU_BOUND | 4 | 컨텍스트 스위치 감소 |
  | BATCH | 8 | 백그라운드 throughput 우선 |
  | SYSTEM | 2 | 짧되 약간의 여유 |

### 신규 syscall

| 시그니처 | 역할 |
|---|---|
| `int setclass(int pid, int class_id)` | 프로세스의 클래스 설정 + 디폴트 퀀텀 동기화 |
| `int setquantum(int pid, int q)` | 퀀텀만 별도 override (1..64) |
| `int getprocstat(int pid, struct procstat *out)` | 한 프로세스의 스냅샷 |
| `int getprocstat_all(struct procstat *arr, int max)` | 모든 활성 프로세스의 스냅샷 |

기존 `getpriority` / `setpriority`는 그대로 사용한다. `setclass`는 의도적으로 priority 변경과 분리되어, 클래스와 priority를 독립적으로 조정할 수 있다.

### tick 회계 (가볍게 유지)

타이머 tick마다 한 번, 커널은 각 프로세스의 상태를 샘플링해 단일 카운터를 증가시킨다 — RUNNABLE이면 `ready_ticks`, RUNNING이면 `run_ticks`, SLEEPING이면 `sleep_ticks`. 이 샘플링 방식은 의도적으로 가볍고(tick당 한 번의 패스), 어드바이저가 ~500ms 주기로 프로세스를 분류하기에 충분한 해상도(~100ms)를 제공한다.

### 가변 타임슬라이스 (퀀텀 기반 yield)

타이머의 yield 결정이 무조건 yield하는 대신 `slice_used >= quantum_ticks`를 확인하도록 바뀌었다. 디폴트 퀀텀 1에서는 동작이 **원본 xv6와 비트 단위로 동일**하다. 퀀텀 4로 올린 CPU 바운드 프로세스는 네 번째 tick마다만 yield하므로 컨텍스트 스위치 빈도가 1/4로 줄어든다 — 배치성 작업에서 우리가 원하는 throughput 이득이 정확히 이것이다.

### 어드바이저 데몬 (`advisord`)

사용자 공간 데모 데몬이 단순한 폴링 루프로 이를 묶는다:

```
loop {
  n = getprocstat_all(buf, MAX_PROCS);
  for each process in buf:
    new_class = classify(process);   // <- 여기가 LLM 호출이 들어갈 자리
    if (new_class != current class) {
      setclass(pid, new_class);
      setpriority(pid, class_to_priority(new_class));
    }
  pause(~500ms);
}
```

`classify()` 함수가 **LLM 자리의 표식자**다. 현재는 단순 휴리스틱(sleep/run 비율 + 이름 매칭)이지만, 인터페이스가 깔끔하게 분리되어 있으므로 실제 LLM 호출로 교체하는 데 **커널 변경이 필요 없다**. 안전장치로 데몬은 자기 자신이나 핵심 프로세스(`init`, `sh`)를 재분류하지 않는다.

동반 인스펙터 **`advstat`**는 동일한 `procstat` 스냅샷을 사람용으로 출력해, 사람이 어드바이저가 보는 것을 그대로 보고 그 판단을 검증할 수 있게 한다.

### 설계 보장

- **Fast path 불변** — `scheduler()`, `sched()`, `swtch()`, `sleep`/`wakeup`, fork의 RUNNABLE 전이는 그대로다. 카운터 쓰기 몇 줄과 분기 하나만 추가했다.
- **정책 상태의 품질만 변함** — 커널은 클래스를 해석하지 않는다. 의미는 전적으로 사용자 공간에 있다.
- **결정성 회복 가능** — 모든 어드바이저 syscall은 단순 값 쓰기라, 결정적 분류기를 쓰면 전체 시스템이 결정적이다.
- **Fail-static** — `advisord`가 시작하지 않거나 죽어도 모든 프로세스는 `NORMAL` / 퀀텀 1을 디폴트로 가지므로 원래 RR 스케줄링이 그대로 작동한다.
- **Observable** — `^P`(procdump), `advstat`, `getprocstat_all`이 모두 동일한 데이터를 노출한다.

### 의도적으로 범위에서 제외한 것 (다음 단계)

다단계 피드백 큐(MLFQ), aging boost, 사후분석용 panic 시점 ring buffer, fork rate 자동 강등, cross-instance lifetime 캐시는 모두 후속 작업으로 남겨두었다 — 커널은 데이터를 노출하고, 더 똑똑한 정책은 어드바이저의 향후 사용자 공간 버전에 들어간다.

---

## 요약

| | Part 1: 메모리 쿼터 | Part 2: LLM 어드바이저 인터페이스 |
|---|---|---|
| **추가하는 것** | 프로세스별 메모리 회계 + 하드 상한 | 프로세스별 스케줄링 상태 + 외부 어드바이저용 syscall |
| **핵심 syscall** | `getmemstat`, `setmemquota` | `setclass`, `setquantum`, `getprocstat`, `getprocstat_all` |
| **강제 지점** | `growproc` (쿼터 초과 `sbrk()` 거부) | 타이머 경로의 퀀텀 기반 yield |
| **공유 원칙** | 핵심 동작 변경 없이 관측 + 상한 | fast path 불변으로 관측 + 조정 |

두 파트 모두 커널의 기존 동작을 그대로 두고, 얇고 격리된 인터페이스만 더한다 — 그래서 시스템은 기본적으로 정확하고 결정적으로 유지되면서, 외부에서 관측하고 안내할 수 있는 능력을 얻는다.
