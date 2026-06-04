# 통합 깊이 논의 (discuss.md) — Q4: xv6-memory ↔ xv6-process 연동 범위

> 작성일: 2026-06-04 · 관련 문서: [`integration_plan.md`](./integration_plan.md)
> 상태: **미결정 (논의용)** — 결과물 위치는 신규 `xv6-unified/` 디렉터리로 확정(Q1).
> 이 문서는 "두 서브시스템을 얼마나 깊게 엮을 것인가"의 선택지를 기록한다. 결정은 나중에.

---

## 0. 논의의 전제 — 지금 둘은 완전히 독립이다

코드 확인 결과(2026-06-04):

- process의 스케줄 advisor(`tools/bridge.py`)는 **swap/quota를 전혀 인지하지 않음**
  (`grep -i 'swap|quota|memstat'` → 0건).
- memory는 **자체 LLM 스택을 따로 보유**:
  `groq_client.py`, `hard_verifier.py`, `proposal_guard.py`,
  `quota_agent_runner.py / quota_groq_retry_runner.py / quota_live_groq_runner.py / quota_policy_runner.py`,
  `score_proto.py`, `run_pipeline.py`, `collect_*` 수집기들.

→ 통합하면 **한 커널 안에 LLM 어드바이저가 둘** 존재한다.
  하나는 *스케줄링*(priority/class/quantum)을 결정하고,
  하나는 *메모리 정책*(quota/swap)을 결정한다.
  Q4는 "이 둘을 따로 둘 것인가(공존), 엮을 것인가(연동)"의 문제다.

핵심 자산 위치:
| 서브시스템 | 관측 syscall | 제어 syscall | userspace | LLM 파이프라인 | LLM 백엔드 |
|---|---|---|---|---|---|
| process(스케줄) | `getprocstat(_all)`, `getnamepriors` | `setpriority/setclass/setquantum/setjob*` | `advisord, advstat, wlagent` | `tools/bridge.py`, `diagnose.py` | **로컬 Ollama** (`localhost:11434`, num_ctx 튜닝) |
| memory(메모리) | `getmemstat`, `getswapstat` | `setmemquota`, `swapout` | `memwatch, swapctl, setquota` | `groq_client`+`hard_verifier`+`proposal_guard`+`quota_*_runner`+`score_proto` | **Groq 클라우드** (`gpt-oss`, openai 호환) |

> ⚠️ 두 스택 모두 `bridge.py`를 갖지만 **내용이 완전히 다름**(935줄 차이) → 한 폴더에 두면 이름 충돌.
> 또한 LLM 백엔드가 **로컬 Ollama vs Groq 클라우드**로 갈려 있어, 합치려면 제공자 선택이 따른다(§7 참조).

---

## 1. Level 0 — 공존만 (Coexistence)

**정의**: 한 커널/한 빌드에 두 기능이 모두 들어가지만 서로 대화하지 않는다.

- 커널: 양쪽 syscall·`struct proc` 필드·서브시스템이 모두 컴파일됨.
  advisord는 스케줄을, swap/quota는 메모리를 **각자** 관리.
- userspace: `advisord`와 `quota_*_runner`가 독립 실행. 두 LLM 파이프라인이 병렬 가동.
- **신규 로직: 0.** 순수 병합.

**장점**
- 리스크 최소. `integration_plan.md`의 작업만으로 끝남.
- "두 기능이 한 OS에서 빌드·부팅·동작"이라는 명확한 검증 목표.
- 각 팀의 기존 데모/리포트가 그대로 재현됨.

**단점**
- 두 어드바이저가 서로의 결정을 모른다. 예: swap이 thrashing을 겪는 프로세스를
  스케줄러는 여전히 고우선순위로 돌릴 수 있음(국소 최적, 전역 비최적).
- LLM 파이프라인 중복(두 개의 Groq/bridge 호출 경로).

**검증**: `make qemu` 부팅 + advisor 스모크(advstat/setcls/jobtest) + memory 스모크(setquota/memstress/swapctl/swaptest) + usertests.

---

## 2. Level 1 — 공유 관측 (Shared observability, read-only)

**정의**: 스케줄 advisor가 메모리 압박을 **볼 수 있게**만 한다. 제어는 하지 않는다(단방향, read-only).

- `getprocstat` 스냅샷(`procstat.h`)에 프로세스별
  `mem_quota / quota_denied_count / swapout_count / swapin_count` 필드를 추가 노출.
- `advstat` 표와 `tools/bridge.py` 프롬프트에 메모리 컬럼 추가
  → LLM이 "이 프로세스는 thrashing 중/ quota 차단 다발"임을 **인지**.
- 결정 로직은 그대로(advisor의 출력은 여전히 스케줄만). 메모리 정책도 불변.

**장점**
- 커널 변경이 작다(구조체 필드 노출 + 채움). 정책 동작은 안 바뀌어 회귀 위험 낮음.
- advisor가 더 풍부한 컨텍스트로 판단 → 데모 설득력 상승("LLM이 메모리 상태까지 보고 스케줄").
- Level 2로 가기 위한 자연스러운 디딤돌.

**단점/결정 필요**
- 방향: 메모리→스케줄 가시성만(권장) vs 양방향(메모리 정책도 procstat의 ctxsw/run_ticks를 봄).
- 두 LLM 파이프라인은 여전히 분리(프롬프트만 확장). 통합 아님.
- 프롬프트가 길어져 LLM 지연/토큰 증가(기존 num_ctx/num_predict 튜닝 재점검 필요).

**추가 검증**: advstat에 메모리 컬럼이 올바른 값으로 뜨는지, swap 유발 시 그 값이 advisor 입력에 반영되는지.

---

## 3. Level 2 — 교차 제어 / 정책 엔진 통합 (Cross-control)

**정의**: advisor가 메모리 신호에 **실제로 반응**하거나, 두 LLM 파이프라인을 **하나로 합친다**.

대표 시나리오(택1 또는 조합):
- (a) **자동 강등**: thrashing(`swapout_count` 급증) 프로세스를 advisor가 priority↑ 또는 BATCH 클래스로 강등.
- (b) **quota 연동**: advisor가 스케줄 판단의 일부로 `setmemquota`를 조정(메모리 많이 먹는 저우선 작업 조이기).
- (c) **단일 정책 엔진**: memory의 안전 레이어(`proposal_guard` + `hard_verifier` + `score_proto`)를
  스케줄 정책에도 적용해, 스케줄·메모리 결정을 **하나의 검증된 파이프라인**에서 발급.

**장점**
- 진짜 "통합 OS 어드바이저". 전역 최적(메모리 압박↔스케줄 동시 고려).
- 두 팀 자산을 하나의 정책/검증 프레임으로 수렴.

**단점/리스크**
- **신규 로직 多 + 안전성 검증 필수.** 잘못된 강등이 starvation·우선순위 역전 유발 가능.
- 두 파이프라인의 정책 충돌 조정(스케줄 advisor와 quota advisor가 상반된 결정을 낼 때).
- 사실상 "병합"이 아니라 **새 기능 개발** → 일정/검증 비용 큼.
- LLM 결정의 안전 경계(가드레일)를 양 도메인에서 동시에 보장해야 함.

**추가 검증**: 정책 안전성 회귀(강등이 starvation 안 만드는지), 두 advisor 상호작용 시 진동(oscillation) 없는지, hard_verifier가 교차 정책도 거르는지.

---

## 4. 한눈 비교

| 항목 | Level 0 공존 | Level 1 관측 | Level 2 제어 |
|---|---|---|---|
| 커널 신규 로직 | 없음 | 적음(필드 노출) | 많음 |
| 두 LLM 파이프라인 | 따로 | 따로(프롬프트만 확장) | 통합 검토 |
| 방향성 | 무관 | 메모리→스케줄(단방향) | 양방향/교차 |
| 리스크 | 낮음 | 중간 | 높음 |
| 성격 | 순수 병합 | 병합+α | 신규 개발 |
| 검증 범위 | 빌드+양쪽 스모크 | +advstat 메모리 컬럼 | +정책 안전성 회귀 |
| 되돌리기 | 쉬움 | 쉬움 | 어려움 |

---

## 5. 의사결정 가이드 (제안)

- **단계적 접근 권장**: 먼저 **Level 0**으로 "한 OS에서 둘 다 동작"을 확정(= `integration_plan.md` 범위).
  그 위에서 원하면 **Level 1**을 후속 PR로 얹는다(저위험·고효과).
  **Level 2**는 별도 기획 문서로 분리해 다루는 게 안전.
- 이렇게 하면 각 단계가 독립적으로 빌드·검증·롤백 가능하고, 데모 스토리도
  "공존 → 관측 → 제어"로 점증적으로 강화된다.

---

## 7. Q5 — 파이썬 툴링 통합 범위

**전제(코드 확인)**: 두 스택은 단순 중복이 아니다.
- 같은 `bridge.py` 이름, 그러나 내용 완전 상이(935줄 차이) → **이름 충돌 반드시 해소**.
- 백엔드 분리: process=**로컬 Ollama**, memory=**Groq 클라우드**.
- 규모 비대칭: process는 `bridge`+`diagnose` 중심, memory는 검증 파이프라인
  (`proposal_guard`+`hard_verifier`+`score_proto`)까지 갖춘 큰 스택.

### 선택지
| | 내용 | 작업량 | Q4 연계 |
|---|---|---|---|
| **A. 폴더만 분리** (권장) | `tools/advisor/`(Ollama) + `tools/memory/`(Groq). 코드 병합 없음, `bridge.py` 충돌은 하위 폴더로 해소. 각자 제공자 유지 | 최소 | Level 0/1 |
| **B. 공용 LLM 클라이언트 추출** | Ollama/Groq를 추상화한 공통 client로 묶어 한 제공자로 호출 가능하게 | 중간 | Level 1~2 |
| **C. 단일 파이프라인 통합** | 하나의 `run_pipeline`이 스케줄+메모리 정책을 공통 검증(proposal_guard/hard_verifier)으로 발급 | 큼 | **= Q4 Level 2** |

### 핵심: Q5는 Q4와 묶여 있다
- **Q5-C ≈ Q4 Level 2**(파이썬 쪽 구현). 따라서 **Q4를 Level 0/1로 가면 Q5는 자연히 A**.
- Level 0이라도 최소한 `bridge.py` 이름 충돌은 폴더 분리로 해소해야 함(필수 작업).
- 즉 Q5는 완전 독립 결정이 아니라 **Q4 레벨이 정해지면 대부분 따라온다**.

### 부수 결정(어느 선택지든 공통)
- 제공자 유지 정책: Ollama(로컬·오프라인 가능)와 Groq(클라우드·API키 필요)를 둘 다 둘지, 하나로 통일할지.
- `__pycache__` 등 산출물·캐시는 통합 트리에 가져오지 않음.

---

## 8. 결정 대기 항목

| # | 질문 | 선택지 | 상태 |
|---|---|---|---|
| Q4-a | 목표 레벨 | L0 / L0→L1 / L2 | **미결정** |
| Q4-b | (L1 선택 시) 관측 방향 | 단방향(메모리→스케줄) / 양방향 | 미결정 |
| Q4-c | (L2 선택 시) 시나리오 | 자동강등 / quota연동 / 정책엔진통합 | 미결정 |
| Q5 | 파이썬 툴링 | A 폴더분리 / B 공용클라이언트 / C 파이프라인통합 | 미결정 (Q4에 종속) |
| Q5-부수 | LLM 제공자 | Ollama+Groq 병존 / 하나로 통일 | 미결정 |

> 참고: Q4를 Level 0/1로 정하면 Q5는 자동으로 **A(폴더 분리)** 로 수렴.
> 결정되면 `integration_plan.md`에 반영하고 작업 착수.
