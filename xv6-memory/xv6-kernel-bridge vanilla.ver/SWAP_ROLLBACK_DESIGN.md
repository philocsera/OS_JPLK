# SWAP 롤백 설계 (swap_policy_runner)

동료분 통합 루프(LLM이 quota/swap 선택) 틀에 **swap 정책 + 롤백**을 끼우는 설계.
독립 swap 루프를 새로 만들지 않는다. quota 루프 형식을 그대로 미러링하고,
swap의 비대칭(아래)만 형식 안에서 표현한다.

> 팀 분담: 동료분 = 통합 루프 / 나 = swap 롤백 + 오류 tag.
> 브랜치: `add-swap-loop` (main `1f5e4a3` 기반).
> ★ 커널 C 코드는 건드리지 않는다. 강제 swapin syscall을 만들지 않는다.

---

## 1. 핵심 결론 — 롤백 = OS lazy swapin 위임

xv6는 **swapout 후 그 페이지에 접근하면 vmfault가 자동으로 swapin** 한다(검증 완료).
따라서 swap 롤백은 **강제 복원 명령을 보내지 않는다**. 그냥 두면 프로세스가
페이지에 접근할 때 OS가 알아서 되돌린다.

| 항목 | quota | swap |
|---|---|---|
| candidate 축 | `target_quota` (값) | **`swapout_pages` (개수)** |
| 적용 명령 | `setquota {pid} {quota}` | **`swapctl {pid} {pages}`** |
| 롤백 동작 | `setquota` 로 옛 값 복원 | **no-op (명령 없음, lazy swapin에 위임)** |
| 롤백 검증 | `restored == before` 즉시 단언 | **워크로드 재구동 + hard_verifier 판정** |
| summary 노출 | `rollback_quota` (복원할 값) | **`rollback_action: "lazy_swapin"`** (복원 방식) |
| decision 코드 | ACCEPT / ROLLBACK / … | **동일 코드 재사용** (ROLLBACK_APPLIED 등) |

---

## 2. 비대칭 2가지 (형식 안에서 표현)

### (A) 즉시성 부재
- quota: 롤백 직후 `find_quota` 로 `restored_quota == before_quota` 를 **즉시 단언**
  (`quota_live_groq_runner.py:543`, `execute_quota_runtime_scenario.py:290`).
- swap: 강제 swapin을 안 하므로 "복원 완료" 시점이 비결정적(프로세스 접근 시).
  → `restored == before` 즉시 단언은 **제거**. 대신 롤백 후 **워크로드를 다시 돌려
  hard_verifier PASS** 로 "정상 복귀"를 판정한다.
- summary 의 복원 표현: quota 의 `rollback_quota=<값>` 자리에
  **`rollback_action="lazy_swapin"`** 을 넣는다(값이 아니라 방식).

### (B) RAM 압박 사망 — verifier 보완 불필요 (자동 캐치 확인됨)
- 과다 swapout → 자동 swapin이 `kalloc()==0` 으로 실패(`swap.c:399` → `-1`)
  → `vmfault` 가 `0` 반환(`vm.c:503-504`)
  → `usertrap` 의 `&&` 단락평가가 깨져 `else` 진입
  → **`printf("usertrap(): unexpected scause ...")` 출력 후 `setkilled`**
  (`trap.c:71-77`).
- 이 문자열은 `hard_verifier.BAD_TRANSCRIPT_PATTERNS` 의 `"usertrap(): unexpected"`
  와 부분일치 → transcript 스캔이 **자동으로 candidate FAIL 처리**.
- ★ 결론: **verifier 보완(target 생존 체크 추가) 불필요.** 기존 hard_verifier 를
  `--require-swap-activity` 만 켜서 그대로 재사용한다.
  (※ syscall copyin/copyout 경로의 swapped 페이지 접근은 `-1` 반환=syscall 실패일
   뿐 kill·출력이 없지만, 이는 "RAM 사망"이 아니라 별개이며 위험 대상 아님.)

---

## 3. verifier 사용 규약

`hard_verifier.py` 는 이미 swap을 안다(`swap.used_slots/total_slots` 검사,
`COUNT_FIELDS` 에 `swapout_count`/`swapin_count`, `--require-swap-activity` 플래그).

swap_policy_runner 호출 시:
- **`--require-swap-activity` 켠다** (swapout·swapin 관측 강제).
- **`--fail-on-quota-denied` 는 끈다** (swap 시나리오는 quota deny 무관).
- BAD_TRANSCRIPT_PATTERNS(`panic:` / `kerneltrap` / `usertrap(): unexpected`)로
  RAM 사망·커널 트랩 자동 캐치.

⚠️ baseline(=swapout 미실행)에는 swapout/swapin 관측이 없다.
→ baseline verifier 호출에는 `--require-swap-activity` 를 **켜지 않는다**
  (candidate 에만 켠다). baseline 은 panic/protected/ memwatch 존재만 확인.

---

## 4. baseline 수집 — collector 0 허용 (결정됨)

quota 는 baseline/candidate 둘 다 같은 memstress 를 quota 값만 바꿔 돌린다.
swap 은 **baseline = swapout 미실행 / candidate = swapout N pages** 라 비대칭.

`collect_swap_scenario.py` 는 현재 `--swapout-pages > 0` 강제 + `success<=0` 시
RuntimeError → no-swapout baseline 을 못 만든다.

**결정: `collect_swap_scenario.py` 에 `--swapout-pages 0` 지원 추가**
(하위호환 — 기본값 4 유지, swapctl 단계만 스킵하여 `memhold + memwatch` 만 실행).
- 0 이면: memhold 띄우고 → swapctl **스킵** → 바로 memwatch json.
- >0 이면: 기존 동작 그대로(swapctl 후 success 검사).
- quota 루프는 이 파일의 `main()` 을 쓰지 않고 `Tee`/`stop_qemu`/`extract_memstat_lines`
  만 import 하므로 영향 없음.
- 커널 C 무수정. Python collector 만 확장.

---

## 5. swap_policy_runner.py 구조 (quota_policy_runner 미러링)

`quota_policy_runner.py` 를 1:1 미러링한다.

```
collect_workload(label, swapout_pages, args, out_dir)
  → collect_swap_scenario.py --pages --swapout-pages <N> --delay
      --ticks --interval --out <label>.jsonl --transcript <label>_qemu.log --timeout
  (baseline: swapout_pages=0 / candidate: swapout_pages=N)

run_hard_verifier(label, log, transcript, out_dir, require_swap_activity)
  → hard_verifier.py --log --transcript --out
     (+ --require-swap-activity  ← candidate 에만)

compute_final_score(log_path)
  → bridge.analyze_snapshot + bridge.compute_score (★내 score 함수, quota 와 동일)
  → (last_score, score_history) 반환

main():
  --before-pages(=0 기본, baseline)  --candidate-pages(=N, required)
  --pages(memhold 크기)  --delay  --ticks --interval --timeout
  --min-improvement  --allow-invalid-baseline  --out-dir
```

### 결정 매트릭스 — ★ 안전성 verdict (score 개선 아님)

★ 근본 제약 (커널 코드로 확정): 이 toy 커널에서 swap 의 "이득" 은 효율 score 로
표현할 수 없다. 따라서 quota 의 score-개선 비교를 **그대로 미러링하지 않고**,
swap 은 "이 swapout 이 안전한가" 로 평가한다.

- **규모 불일치**: RAM(PHYSTOP)=128MB=32,768페이지, swap(NSWAP)=1024슬롯=4MB
  = RAM 의 3.1%. → swap 은 OOM 생존을 가르는 pivot 이 못 됨
  (baseline OOM→candidate 생존하는 recovery 프레임 **불가능**, 둘 다 ~RAM 한계에서 사망).
- **sz 불변**: swapout 은 물리 거주만 바꾸고 `proc->sz` 는 그대로 → quota 기반
  eff/usage_ratio 가 baseline 과 candidate 에서 **동일** → 효율 score 차이 0.
- **압박 없으면 swap=순수 오버헤드**: clean swap 조차 stab 0.9 < 1.0 (1 recovery cycle).
- → swap 에 반응하는 유일한 score 축은 **stab(thrashing)**, 그것도 음의 방향(harm)뿐.

```
baseline verifier FAIL & not allow_invalid  → ABORT_BASELINE_INVALID  (exit 1)
                                               (baseline 은 환경 sanity control 일 뿐)
candidate verifier FAIL                      → ROLLBACK  (unsafe: panic/kill/슬롯/데이터손실)
candidate PASS & stab < min_stab             → ROLLBACK  (unsafe: thrashing)
candidate PASS & stab >= min_stab            → ACCEPT    (safe swap)
```
- `min_stab` 기본 0.85: clean 단일 cycle swap(stab~0.9) → ACCEPT,
  2+ cycle thrashing(stab<=0.8) → ROLLBACK.
- quota 의 recovery/score-개선 분기(ACCEPT_RECOVERY / REJECT_RECOVERY_CANDIDATE /
  score 미개선 ROLLBACK)는 swap 에 적용 불가라 **제거**.
- 효율 score(before/candidate)는 observability 용으로만 summary 에 남긴다.

> ※ 물리메모리 헤드룸을 보상하는 4번째 score 축(kalloc free-page 카운터 → memstat)
>   은 swap 의 이득을 양수 방향으로 표현하는 원론적 해법이나 **커널 C 수정 필요**라
>   이번 범위 밖(후속, 동료 협의). 그때 PHYSTOP 축소/NSWAP 확대로 recovery 프레임을
>   살리는 선택지도 함께 검토.

### summary.json (안전성 verdict 형식)
```json
{
  "decision": "ACCEPT | ROLLBACK | ABORT_BASELINE_INVALID",
  "reason": "<safe swap ... | unsafe swap: thrashing ... | unsafe swap: verifier ...>",
  "evaluation_mode": "safety_verdict",
  "before_pages": 0,
  "candidate_pages": N,
  "rollback_action": "lazy_swapin",       ← ROLLBACK 일 때만 (quota 의 rollback_quota 자리)
  "candidate_stab": 0.9,                   ← thrashing 판별자
  "candidate_swap_cycle_sum": 1,
  "min_stab": 0.85,
  "before_score": {...},                   ← observability 용(decision 에 안 씀)
  "candidate_score": {...},
  "before_verifier": {...},
  "candidate_verifier": {...},
  "artifacts": { ...로그/transcript 경로... },
  "score_history": { "before": [...], "candidate": [...] }
}
```
- quota 의 `rollback_quota=<값>` → swap 은 **`rollback_action="lazy_swapin"`**.
  ROLLBACK 이 아니면 `None`.
- 롤백을 위한 **강제 명령은 보내지 않는다** (no-op). 이 runner 는 A/B 오프라인
  채점이라 어차피 live 상태를 안 건드린다 — quota_policy_runner 와 동일.

---

## 6. tag / 피드백 형식 — 동료분 형식 그대로

- 내부 decision 코드(enum류 문자열 상수)는 **quota 와 동일 집합 재사용**.
- LLM 재제안 피드백(`retry_context` dict + `safety_constraints` 자유텍스트)도
  동료분 함수 형식 그대로. **`reason` 문자열만 swap 맥락**으로 작성
  (예: "candidate swapout of N pages did not improve score" /
   "candidate caused usertrap kill under memory pressure").
- LLM 스키마(`groq_client.PROPOSAL_SCHEMA`)·`proposal_guard.py` 의 `swapout` 검증은
  **이미 구현되어 있어 변경 0** (action enum `swapout`, `swapout_pages` 필드,
  guard 의 `1<=pages<=16` + free_slots 검사).

---

## 7. 범위 / 비범위

**이번 (add-swap-loop, 나):**
- `collect_swap_scenario.py` 에 `--swapout-pages 0` 지원 추가 (Python).
- `swap_policy_runner.py` 신규 (quota_policy_runner 미러링, 오프라인 A/B).
- 본 설계 문서.

**비범위 (커널/동료분 영역):**
- 커널 C 무수정 (강제 swapin syscall 안 만듦).
- live 실행/Groq 루프(swap_agent_runner / execute_swap_runtime_scenario /
  swap_live_groq_runner)는 후속 — policy_runner 검증 후 quota 대응물 미러링.
- `.gitignore`/빌드 산출물 추적 문제는 동료와 상의 후 별도 처리.

**검증:** `py_compile` 로 syntax 만 확인. qemu live 실행은 사용자가 WSL 에서.
```

