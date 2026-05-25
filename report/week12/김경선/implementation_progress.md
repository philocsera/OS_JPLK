# 구현 진행 현황 보고서

> **작업 경로:** `report/week12/김경선/xv6-copy-kks/`
> **기준일:** 2026-05-25
> **담당:** 김경선

---

## 1. 프로젝트 목표

조현성이 구현한 **priority 기반 프로세스별 스케줄링(schedhint)** 위에,
**시스템 전체 workload를 LLM이 분류하여 스케줄링 정책을 자동 전환**하는 레이어를 추가한다.

- xv6 커널의 **타임슬라이스 길이**를 workload에 따라 동적으로 변경
- 4가지 정책: `balanced(0)` / `throughput(1)` / `interactive(2)` / `background(3)`
- `workloadagent`가 주기적으로 프로세스 상태를 수집 → bridge → LLM 분류 → `setpolicy()` 적용

**역할 분리:**

| 기능 | 담당 | 변경 대상 |
|------|------|----------|
| 프로세스별 우선순위 조정 | 조현성 (schedhint) | 개별 프로세스 `priority` 값 |
| 시스템 전체 정책 전환 | 김경선 (workloadagent) | 전역 `current_policy` (timeslice 길이) |

두 기능은 **독립적으로 동작**하며 서로 간섭하지 않는다.

---

## 2. 완료된 구현 단계

### Stage 1 — 커널 policy 인프라 + syscall (완료)

- `kernel/policy.h` 신규 생성: 4가지 policy 상수, 전역 변수 선언
- `kernel/trap.c` 수정: `clockintr()`의 타임슬라이스를 고정값 → `policy_timeslice_cycles[current_policy]`로 교체
- `kernel/sysproc.c` 수정: `sys_setpolicy()`, `sys_getpolicy()` 구현 + 전역 변수 정의
- `kernel/syscall.h` / `kernel/syscall.c` 수정: 번호 등록, dispatch table, 이름 배열 추가
- `user/user.h` / `user/usys.pl` 수정: 사용자 공간 선언 + RISC-V 스텁 추가
- `mkfs/` 디렉터리 복사 (원본 누락으로 별도 추가)
- **빌드 성공 확인:** `kernel/kernel` (277K), `fs.img` (2.0M)

### Stage 2 — workloadagent + bridge 확장 (완료)

- `user/workloadagent.c` 신규 생성 (아래 §5 참조)
- `Makefile` 수정: UPROGS에 `$U/_workloadagent` 추가, fs.img 포함 확인
- `bridge/bridge.py` 수정: `handle_workload()` 함수 추가, `<<WORKLOAD>>` 마커 처리 추가
- `bridge/prompts/workload.txt` 신규 생성: LLM workload 분류 system prompt

---

## 3. 추가된 syscall

| 번호 | 이름 | 시그니처 | 설명 |
|------|------|----------|------|
| 27 | `SYS_setpolicy` | `int setpolicy(int policy_id)` | 전역 policy 변경 (0~3), 범위 외는 -1 반환 |
| 28 | `SYS_getpolicy` | `int getpolicy(void)` | 현재 policy_id 반환 |

기존 최대 번호는 조현성의 `SYS_proclist = 26`이며, 번호 충돌 없음.

---

## 4. 수정/추가한 파일 목록

모든 경로는 `report/week12/김경선/xv6-copy-kks/` 기준.

### 신규 생성

| 파일 | 내용 |
|------|------|
| `kernel/policy.h` | policy 상수, extern 전역 변수 선언 |
| `user/workloadagent.c` | proclist 수집 → bridge 통신 → setpolicy 적용 루프 |
| `bridge/prompts/workload.txt` | LLM workload 분류 system prompt |

### 수정

| 파일 | 수정 내용 |
|------|----------|
| `kernel/trap.c` | `#include "policy.h"` 추가, `w_stimecmp` 인수를 동적 값으로 교체 |
| `kernel/sysproc.c` | `#include "policy.h"` 추가, 전역 변수 정의, `sys_setpolicy/getpolicy` 추가 |
| `kernel/syscall.h` | `SYS_setpolicy = 27`, `SYS_getpolicy = 28` 추가 |
| `kernel/syscall.c` | extern 선언, dispatch table, syscall_names 배열에 두 항목 추가 |
| `user/user.h` | `setpolicy(int)`, `getpolicy(void)` 선언 추가 |
| `user/usys.pl` | `entry("setpolicy")`, `entry("getpolicy")` 추가 |
| `Makefile` | UPROGS에 `$U/_workloadagent` 추가 |
| `bridge/bridge.py` | `handle_workload()` 추가, `Bridge.__init__`에 workload 버퍼 추가, `_maybe_intercept()`에 `<<WORKLOAD>>` 분기 추가 |

### 복사 (원본 없이 누락된 파일)

| 파일 | 출처 |
|------|------|
| `mkfs/mkfs.c` 외 | `/home/userkks/projects/2026-lecture-operating-system/xv6-riscv/mkfs/` |

---

## 5. workloadagent 동작 방식

```
$ workloadagent
  └─ fork()
       ├─ 부모: "started (pid N)" 출력 후 exit(0)  →  sh 프롬프트 즉시 복귀
       └─ 자식(daemon): 아래 루프 반복
            1. proclist()  →  프로세스 스냅샷 수집
            2. <<WORKLOAD>> ... <<WORKLOAD_END>> 출력  →  bridge가 LLM에 전달
            3. gets()로 stdin 대기  →  bridge가 <<POLICY>> N 응답
            4. setpolicy(N) 호출  →  커널 timeslice 즉시 변경
            5. policy 변경 시 로그 출력: "workloadagent: policy X -> Y"
            6. pause(100)  →  ~1초 대기 후 1번으로
```

**xv6 sh는 `&` 미지원**이므로, workloadagent 내부 fork로 백그라운드 실행을 구현함.

**수동 테스트 방법 (bridge 없이):**
xv6 셸에서 `workloadagent` 실행 후, 별도 터미널에서 QEMU stdin에 `<<POLICY>> 1` 입력
→ `getpolicy()` 결과가 1로 바뀌는지 확인.

---

## 6. bridge.py 확장 내용

### 추가된 함수

```python
def handle_workload(snapshot: list[str], solar: SolarClient) -> str:
    # LLM에 workload 스냅샷 전달 → JSON 응답에서 policy_id 추출
    # 오류 시 fallback: <<POLICY>> 0 (balanced)
```

### _maybe_intercept() 처리 흐름 (추가 분기)

```
<<WORKLOAD>>      → _workload_buf 초기화, 수집 시작
(수집 중 라인)    → _workload_buf에 누적 + 콘솔 echo
<<WORKLOAD_END>>  → LLM 호출(online) 또는 <<POLICY>> 0(offline)
```

기존 `<<PROCS>>` / `<<LLM>>` / `<<DOC>>` 핸들러와 **마커 문자열이 완전히 달라 충돌 없음**.
offline 모드에서는 `<<POLICY>> 0` (balanced)으로 fallback.

### bridge 로그 출력 (stderr)
```
[bridge] workload=compile policy=1 reason=gcc/ld processes dominate CPU
```

---

## 7. 빌드 및 QEMU 부팅 결과

| 항목 | 결과 |
|------|------|
| `make` (커널 빌드) | 성공 — `kernel/kernel` (277K) |
| `make user/_workloadagent` | 성공 — `-Wall -Werror` 경고 없음 |
| `make fs.img` | 성공 — `fs.img` (2.0M), workloadagent 포함 확인 |
| QEMU 부팅 | 성공 (Stage 1 완료 시점 확인) |

---

## 8. 남은 작업

| 단계 | 내용 | 상태 |
|------|------|------|
| Stage 3 | bridge 확장 | **완료** (Stage 2에 통합) |
| Stage 4 | `UPSTAGE_API_KEY` 설정 후 end-to-end LLM 연동 테스트 | **예정** |
| Stage 4 | spin × N 실행 → LLM "background" 분류 → policy 3 전환 확인 | **예정** |
| Stage 5 | LLM OFF vs ON 조건에서 sh 응답 시간 / 컴파일 시간 측정 비교 | **예정** |
| Stage 5 | 측정 결과 정리 및 발표 자료 작성 | **예정** |

---

## 9. 현재 확인된 위험 요소

| 요소 | 수준 | 대응 방안 |
|------|------|----------|
| **stdin 공유** — workloadagent `gets()` 대기 중 사용자 키 입력이 bridge 응답과 섞일 수 있음 | 중 | 데모 중 LLM 응답 수신 전까지 키 입력 자제. xv6 단일 콘솔의 구조적 한계. |
| **LLM 응답 지연** — API latency 동안 workloadagent 루프 전체가 블로킹됨 | 낮 | Solar Pro 3 평균 1–3초 응답 → 100 tick(~1초) 폴링 간격 기준 허용 범위 |
| **`make qemu-nox`** — bridge.py 기본 qemu 명령이 Makefile에 없을 수 있음 | 낮 | 실행 시 `--qemu-cmd "make qemu QEMU_EXTRA=-nographic"` 옵션으로 지정 |
| **멀티코어 race** — `current_policy` plain int를 여러 CPU가 동시 읽음 | 매우 낮 | int 단일 읽기는 tearing 없음. 데모 범위에서 실용적 문제 없음. |

---

## 10. 조현성 원본 유지 확인

이번 구현은 **조현성의 코드를 전혀 수정하지 않는 방식**으로 설계되었다.

- `report/week09/조현성/xv6-copy/` 내 모든 파일: git diff 0줄 (무변경)
- 명시적으로 **건드리지 않은** 파일:
  - `kernel/proc.c` — priority 기반 scheduler 루프 보존
  - `kernel/proc.h` — struct proc, struct proc_info 보존
  - `user/schedhint.c` — 기존 LLM 우선순위 조정 로직 보존
- 확장 방식: 기존 코드에서 사용하지 않는 **syscall 번호(27, 28)**, **마커(`<<WORKLOAD>>`)**,
  **전역 변수(`current_policy`)**, **커널 헤더(`policy.h`)** 를 새로 추가하는 방식으로만 구현

schedhint(누가 먼저 실행)와 workloadagent(얼마나 오래 실행)는 **서로 독립된 두 개의 레이어**로 동작하며,
동시에 실행해도 상호 간섭이 없다.
