# Workload-based Scheduling Policy 설계 계획

> **작업 기준 경로:** `report/week12/김경선/xv6-copy-kks/`
> **조현성 원본:** `report/week09/조현성/xv6-copy/` — 절대 수정 금지
> **방향:** 후보 B — LLM workload 분석 기반 xv6 scheduling policy / timeslice 자동 전환

---

## 1. 구현 목표

조현성이 구현한 **priority 기반 개별 프로세스 조정(schedhint)** 위에,
**시스템 전체 workload를 LLM이 분류하여 스케줄링 정책(policy)을 자동 전환**하는 레이어를 추가한다.

구체적으로:
- xv6 스케줄러의 **타임슬라이스(timeslice) 길이**를 workload에 따라 동적으로 바꾼다
- 4가지 정책(`balanced` / `throughput` / `interactive` / `background`)을 커널에 구현하고
- `workloadagent`라는 사용자 프로그램이 주기적으로 프로세스 상태를 수집하여 bridge → LLM에 전달하면
- LLM이 현재 workload를 분류하고 정책 번호를 응답하면
- `setpolicy()` 시스콜로 커널 정책을 실시간 전환한다

**핵심 조건:** LLM은 "분석 도구"가 아니라 실제 커널 동작(타임슬라이스 길이)을 바꾸는 결정 주체여야 한다.

---

## 2. 조현성 기능과의 역할 분리

| 구분 | 조현성 (schedhint) | 김경선 (workloadagent) |
|------|------------------|----------------------|
| **단위** | 개별 프로세스 | 시스템 전체 |
| **변경 대상** | 프로세스별 `priority` 값 | 전역 `current_policy` (timeslice 길이) |
| **LLM 판단** | "이 프로세스가 얼마나 중요한가" | "지금 시스템이 어떤 상황인가" |
| **적용 시스콜** | `setpriority(pid, val)` | `setpolicy(policy_id)` |
| **bridge 마커** | `<<PROCS>>` / `<<SETPRI>>` | `<<WORKLOAD>>` / `<<POLICY>>` |
| **스케줄러 영향** | best-pick 선택 기준 변화 | timeslice 사이클 수 변화 |

→ 두 기능은 **독립적으로 동작**하며 서로를 간섭하지 않는다.
schedhint가 priority를 조정하면 누가 먼저 실행될지가 결정되고,
workloadagent가 policy를 바꾸면 얼마나 오래 실행될지가 결정된다.

---

## 3. Scheduler Policy 구조 확장 방법

### 기존 스케줄러 구조 (조현성, `proc.c:scheduler()`)

```
for(;;) {
    best = 0
    for each proc:
        if RUNNABLE && priority < best.priority → best = p
    if best: best->state = RUNNING; best->run_ticks++; swtch()
}
```

→ **이 루프는 건드리지 않는다.**

### 확장 방향: timeslice 길이만 바꾼다

타임슬라이스는 `trap.c`의 `clockintr()`에서 결정된다:

```c
// 현재 (고정값)
w_stimecmp(r_time() + 1000000);  // ~0.1초 고정
```

이를 다음과 같이 변경한다:

```c
// 변경 후 (policy 기반 동적값)
extern uint64 policy_timeslice_cycles[];
w_stimecmp(r_time() + policy_timeslice_cycles[current_policy]);
```

### 4가지 정책 파라미터

| policy_id | 이름 | timeslice cycles | 의도 |
|-----------|------|-----------------|------|
| 0 | `balanced` | 1,000,000 | 기본 라운드 로빈 (변경 없음) |
| 1 | `throughput` | 4,000,000 | 컨텍스트 스위칭 최소화 → CPU 집중 작업 유리 |
| 2 | `interactive` | 250,000 | 빠른 순환 → 사용자 입력 응답성 우선 |
| 3 | `background` | 2,000,000 | 배치 작업 중 긴 슬라이스, 인터럽트 여유 |

> **cycles 근거:** `clockintr()`의 1,000,000 = RISC-V 10MHz 기준 ~0.1초.
> throughput은 4배(~0.4초), interactive는 1/4배(~0.025초).

---

## 4. Workload 분류 기준

LLM에게 다음 기준으로 4가지 중 하나를 선택하게 한다.

| workload 분류 | 특징 | 추천 policy |
|-------------|------|-----------|
| `compile` | gcc/ld/make 등 CPU 집중 프로세스 다수 | `throughput` (1) |
| `interactive` | sh 중심, CPU% 낮음, 사용자 입력 대기 | `interactive` (2) |
| `background` | spin/stressfs 등 장시간 저우선순위 작업 | `background` (3) |
| `balanced` | 혼합 또는 판단 불가 | `balanced` (0) |

LLM에게 보내는 정보:
- 각 프로세스의 `pid`, `name`, `cpu_pct`(run_ticks 기반 추정), `state`
- 총 프로세스 수

LLM에게 받는 정보:
- `workload` 분류명
- `policy_id` (0~3)
- `reason` (로그용)

---

## 5. 추가해야 할 시스콜

현재 최대 syscall 번호: `SYS_proclist = 26`

| 번호 | 이름 | 시그니처 | 설명 |
|------|------|---------|------|
| 27 | `SYS_setpolicy` | `setpolicy(int policy_id)` | 전역 `current_policy` 변경 (0~3) |
| 28 | `SYS_getpolicy` | `getpolicy(void) → int` | 현재 policy_id 반환 |

---

## 6. 수정/추가해야 할 핵심 파일

모든 경로는 `report/week12/김경선/xv6-copy-kks/` 기준.

### 신규 파일

| 파일 | 설명 |
|------|------|
| `kernel/policy.h` | policy 상수, `current_policy` 전역 선언, `policy_timeslice_cycles[]` 선언 |
| `user/workloadagent.c` | proclist 수집 → `<<WORKLOAD>>` 출력 → `<<POLICY>>` 수신 → `setpolicy()` 호출 |
| `bridge/prompts/workload.txt` | LLM system prompt (workload 분류 가이드) |

### 수정 파일

| 파일 | 수정 내용 | 조현성 코드와 충돌 여부 |
|------|----------|----------------------|
| `kernel/policy.h` | 신규 생성 | 없음 |
| `kernel/trap.c` | `clockintr()` 내 `w_stimecmp` 값을 `policy_timeslice_cycles[current_policy]`로 교체 | **조현성이 건드리지 않은 파일 — 충돌 없음** |
| `kernel/sysproc.c` | `sys_setpolicy()`, `sys_getpolicy()` 함수 추가 | 함수 추가만이므로 merge 가능 |
| `kernel/syscall.h` | `SYS_setpolicy = 27`, `SYS_getpolicy = 28` 추가 | 번호가 겹치지 않아 충돌 없음 |
| `kernel/syscall.c` | dispatch table에 두 항목 추가, syscall_names 배열에 문자열 추가 | 배열 끝에 추가하므로 충돌 없음 |
| `kernel/defs.h` | `setpolicy`, `getpolicy`, `get_current_policy` 등 함수 선언 추가 | 선언 추가이므로 충돌 없음 |
| `user/user.h` | `setpolicy(int)`, `getpolicy(void)` 선언 추가 | 선언 추가이므로 충돌 없음 |
| `user/usys.pl` | `entry("setpolicy")`, `entry("getpolicy")` 추가 | 끝에 추가, 충돌 없음 |
| `Makefile` | `UPROGS`에 `$U/_workloadagent` 추가 | 목록 추가이므로 충돌 없음 |
| `bridge/bridge.py` | `handle_workload()` 함수 추가, `_maybe_intercept()`에 `<<WORKLOAD>>` 마커 처리 추가 | 새 마커라 기존 핸들러와 독립 |

---

## 7. 구현 순서

### 1단계: 커널 기반 구조 (policy.h + trap.c)
```
1. kernel/policy.h 생성
   - POLICY_BALANCED, THROUGHPUT, INTERACTIVE, BACKGROUND 상수 정의
   - current_policy 전역 변수 선언
   - policy_timeslice_cycles[] 배열 선언

2. kernel/trap.c 수정
   - clockintr()에서 w_stimecmp() 값을 동적으로 변경
   - current_policy 전역 변수 include

3. QEMU에서 부팅만 되는지 확인 (policy = 0이면 동작 완전히 동일해야 함)
```

### 2단계: 시스콜 추가 (setpolicy / getpolicy)
```
4. kernel/syscall.h에 SYS_setpolicy=27, SYS_getpolicy=28 추가
5. kernel/sysproc.c에 sys_setpolicy(), sys_getpolicy() 구현
6. kernel/syscall.c dispatch table, names 배열 업데이트
7. user/user.h, user/usys.pl에 스텁 추가
8. policy_test.c 간단히 작성하여 setpolicy(1) → getpolicy() == 1 확인
```

### 3단계: workloadagent 사용자 프로그램
```
9. user/workloadagent.c 작성
   - proclist() 호출
   - <<WORKLOAD>> 블록 stdout 출력
   - stdin에서 <<POLICY>> N 수신
   - setpolicy(N) 호출
   - pause() 후 루프 반복
10. Makefile에 등록
11. bridge 없이 수동 테스트: workloadagent 실행 후
    stdin에 "<<POLICY>> 1" 직접 입력 → getpolicy() 확인
```

### 4단계: bridge.py 확장
```
12. bridge/prompts/workload.txt 작성 (LLM system prompt)
13. bridge/bridge.py에 handle_workload() 함수 추가
14. _maybe_intercept()에 <<WORKLOAD>> / <<WORKLOAD_END>> 처리 추가
    - 응답 형식: <<POLICY>> <policy_id>
15. offline 모드에서 <<POLICY>> 0 fallback 처리
```

### 5단계: LLM 연동 end-to-end 테스트
```
16. UPSTAGE_API_KEY 설정 후 bridge.py 실행
17. xv6 부팅 → workloadagent 실행
18. spin 다수 실행 → LLM이 "background" 분류 → policy 3 전환 확인
19. 로그 출력 형식 확인 ("policy changed: balanced → throughput, reason: ...")
```

### 6단계: 성능 측정 실험
```
20. AI OFF vs ON 조건에서 시나리오별 측정
    - spin × 3 + sh 응답 시간
    - 컴파일 워크로드 완료 시간
21. 결과 수집 및 정리
```

---

## 8. 예상 충돌 지점과 회피 방법

### [충돌 1] proc.c — 조현성이 이미 수정한 파일

조현성의 `scheduler()` 루프와 `allocproc()`을 건드리지 않는다.
`current_policy`는 스케줄러 루프 바깥에서 참조되므로 루프 자체 수정이 불필요하다.
만약 BACKGROUND 정책에서 priority offset을 적용하고 싶다면 → 나중에 추가 논의 후 결정.

### [충돌 2] sysproc.c — 조현성이 이미 수정한 파일

함수를 파일 끝에 **추가**하는 방식이라 기존 함수와 겹치지 않는다.
단, `#include "policy.h"`를 파일 상단에 추가해야 한다.

### [충돌 3] bridge.py — <<PROCS>> 마커와 혼동

`<<WORKLOAD>>` / `<<WORKLOAD_END>>` 마커는 기존 `<<PROCS>>` / `<<PROCS_END>>`와 완전히 다른 문자열이다.
`_maybe_intercept()` 내에 독립적인 분기로 추가하면 기존 핸들러에 영향 없음.

```python
# 기존 (조현성)
if stripped == "<<PROCS>>":      → handle_procs
# 추가 (김경선)
if stripped == "<<WORKLOAD>>":   → handle_workload  ← 새로운 분기
```

### [충돌 4] policy_timeslice_cycles[] 전역 변수 — 멀티코어 race condition

xv6는 NCPU=8까지 지원하므로 여러 CPU가 동시에 `clockintr()`을 호출할 수 있다.
`current_policy`는 단순 int 읽기이므로 tearing 없이 안전하다.
(쓰기는 `setpolicy()` 시스콜에서 한 번만 발생, 정확한 동기화가 필요하다면 spinlock 추가 고려)

### [충돌 5] workloadagent 백그라운드 실행

xv6 sh는 `&`를 지원하지 않는다.
`workloadagent.c` 내부에서 `fork()` 후 **부모가 `exit()`**, 자식이 루프를 도는 방식으로 구현.

---

## 9. 발표 / Demo 시나리오

### 시나리오 1: CPU 집중 workload (throughput 전환)

```
[설명] spin 3개 실행 → sh 응답 체감 변화 없음 (우선순위 낮아도 슬라이스가 짧아야 sh가 빨리 회전)

[LLM OFF]
$ spin &; spin &; spin &
$ workloadagent → policy stays balanced
→ timeslice = 0.1초 고정

[LLM ON]
$ workloadagent (background로 실행)
→ LLM: "background detected: spin × 3" → policy 3 전환
→ timeslice = 0.2초 → spin이 CPU를 조금 덜 자주 양보

결과: 로그 화면에 "policy: balanced → background (reason: multiple spin processes)"
```

### 시나리오 2: 정책 자동 전환 (핵심 시연)

```
[초기 상태] sh 대화형 → interactive(2) 선택됨 → timeslice 짧음
[gcc 실행]  컴파일 시작 → throughput(1) 선택됨 → timeslice 길어짐
[완료 후]   sh로 돌아옴 → interactive(2) 재선택됨

콘솔 출력 예시:
  policy changed: interactive → throughput  (compile workload detected)
  policy changed: throughput  → interactive (idle workload detected)
```

### 시나리오 3: 측정 비교

```
측정: sh에서 명령 입력 → 프롬프트 재출력까지 시간 (ms)

조건 1: LLM OFF, policy = balanced → X ms
조건 2: LLM ON,  policy = interactive 자동 선택 → Y ms (Y < X 기대)

측정: spin × 3 실행 상태에서 위 두 조건 반복
```

---

## 10. 현재 구조에서 가장 먼저 확인해야 할 파일

우선순위 순서로:

| 순서 | 파일 | 확인 목적 |
|------|------|----------|
| 1 | `kernel/trap.c` | `clockintr()` 내 `w_stimecmp()` 위치와 인수 형식 확인 → timeslice 변경 방법 파악 |
| 2 | `kernel/proc.c` | `scheduler()` 루프 구조 재확인 → 건드릴 필요가 없는지 검증 |
| 3 | `kernel/syscall.h` | 현재 최대 번호 확인 (26) → 27, 28 번호 배정 |
| 4 | `kernel/syscall.c` | dispatch table 구조 확인 → 새 항목 추가 방법 파악 |
| 5 | `bridge/bridge.py` | `_maybe_intercept()` 구조 확인 → 새 마커 삽입 위치 파악 |
| 6 | `user/schedhint.c` | proclist 호출 방식 참고 → workloadagent 작성 시 재사용 |

---

## 부록: 프로토콜 전체 정리

### xv6 → bridge (workloadagent 출력)

```
<<WORKLOAD>>
process_count: 5
processes:
  pid  name   run_ticks  state
  3    sh     200        SLEEP
  4    gcc    8500       RUN
  5    gcc    7800       RUNBL
  6    ld     4200       RUNBL
  7    spin   9000       RUNBL
<<WORKLOAD_END>>
```

### bridge → xv6 (workloadagent stdin으로 전달)

```
<<POLICY>> 1
```

workloadagent가 수신 후 `setpolicy(1)` 호출 → 커널 timeslice 변경.

### LLM 응답 JSON 형식

```json
{
  "workload": "compile",
  "policy_id": 1,
  "reason": "gcc/ld processes dominate CPU, compilation workload detected"
}
```

### 로그 출력 (workloadagent → 콘솔)

```
workloadagent: policy changed 0 → 1 (throughput)
workloadagent: reason: gcc/ld processes dominate CPU
```
