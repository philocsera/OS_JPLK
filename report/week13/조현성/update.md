# Week13 작업 업데이트 — LLM 어드바이저 검증 & sec 04~07 구현

날짜: 2026-05-29
대상: `xv6-process` (process_summary.html에서 설명한 "LLM 어드바이저 스케줄러")

---

## 1. 보고서대로 동작하는지 실제 검증

`riscv64-elf-` 툴체인으로 빌드해 QEMU에서 항목별로 확인했다.
(주의: Makefile의 TOOLPREFIX 자동탐지는 `riscv64-unknown-elf-`를 먼저 찾아 실패하므로
`make TOOLPREFIX=riscv64-elf-` 로 빌드해야 한다. `sleep` 시스템콜은 이 xv6에서 `pause`로 개명돼 있다.)

### 동작 확인된 핵심 메커니즘 (`priority_test`, 직접 작성한 `advtest`)
- **우선순위 스케줄러**: 낮은 숫자=높은 우선순위, HIGH가 먼저 완료
- **fork 상속**: 자식이 부모 priority/class/quantum 그대로 상속
- **클래스별 quantum**: `setclass` → CPU_BOUND=4, BATCH=8, INTERACTIVE=1틱
- **procstat 카운터**: run/sleep(실제 I/O 채널)/ready/ctxsw 누적
- **경계값 검증**: setclass/setquantum 범위 거부, 없는 pid 거부
- **advisord 폴링 루프**: spin을 NORMAL→CPU_BOUND로 실시간 재분류

### 검증 중 발견한 버그 (출고 상태 기준, 별도 수정 필요)
1. **(치명적) `advstat`·`advisord` 시작 즉시 크래시** — `usertrap scause 0xf`.
   `struct procstat buf[64]`(~5KB)를 **스택 배열**로 선언하는데 xv6 유저 스택은 1페이지(4KB)뿐 → 스택 오버플로.
   → 버퍼를 `static`(BSS)으로 바꾸면 정상 동작. (커널측 getprocstat_all은 커널 스택 보호로 청크 처리돼 있으나 유저측은 미보호였음.)
2. **(경미) `advstat` 출력 깨짐** — xv6 minimal printf가 `%3d`·`%-16s`·`%5ld` 폭 지정자를 미지원 → 표가 깨짐.
3. **(측정 아티팩트) timer-sleeper는 `sleep_ticks` 미집계** — `clockintr`가 `wakeup(&ticks)`를 `procstat_tick()`보다 먼저 호출해 항상 RUNNABLE로 샘플링됨. 파이프/콘솔/디스크 등 실제 I/O 블록은 정상 집계.

---

## 2. "LLM은 누가 수행하나?" — 구조 정리

현재 저장소에는 **실제 LLM이 없었다**(API 키도 불필요). "LLM 어드바이저"는 아키텍처 명칭일 뿐,
실제 분류는 `advisord.c`/`proc.c`의 **하드코딩 휴리스틱**이 수행. LLM이 들어갈 자리는 두 경로:
- (a) 호스트 브리지: 게스트가 데이터를 내보내고 호스트의 LLM이 분류해 써넣음 ← **이번에 구현**
- (b) 개발 시점에 LLM이 휴리스틱을 설계해 코드에 박제

---

## 3. 보고서 sec 04~07 prototype 구현 (모두 QEMU 검증)

설계 원칙: 커널 fast-path는 손대지 않고, **커널은 데이터 노출 + 정책 쓰기만**, 지능은 유저/호스트.

| 항목 | 구현 | 검증 |
|---|---|---|
| **04 exit 통계 학습** | 이름별 prior 테이블(proc.c), `kexit`에서 학습, `exec`에서 첫 명령부터 seed. syscall `getnamepriors`(#28). progs `wl`, `priors` | `wl` 1회차 NORMAL → 2회차 CPU_BOUND(quantum 4) seed ✅ |
| **05 job 그룹화** | fork로 전파되는 `group_id`, `setjob`으로 리셋. `setjob/getjob/setjobpriority/setjobclass`(#29~32)로 트리 전체 정책 일괄 적용. prog `jobtest` | child/grandchild 그룹 상속, outsider 격리, 일괄 priority/class 적용 ALL PASS ✅ |
| **06 fork bomb 방어** | job당 `GROUP_PROC_LIMIT=16`(param.h)을 `kfork`에서 `proc_group_count()`로 강제(init 그룹 1은 예외). prog `fbomb` | 15개서 차단, 셸 STILL_ALIVE ✅ |
| **07 panic 자연어 진단** | 커널 이벤트 링(proc.c, `proc_log_event`/`eventlog_dump`)을 `kexit`/`kfork`-deny/`note`(#33)에서 기록, `panic()`이 `@@PANIC`/`@@EV` 타임라인 덤프. `crash`(#34). prog `crashme` | crashme→panic 타임라인 덤프, diagnose.py가 fork-bomb→OOM 근본원인 자연어 설명 ✅ |

---

## 4. 진짜 로컬 LLM 어드바이저 (option-a, 무료·오프라인)

`tools/bridge.py` (호스트) ↔ `wlagent`/`setcls` (게스트):

```
QEMU stdout --@@WL 프레임--> bridge.py --HTTP--> Ollama(로컬 오픈모델)
QEMU stdin  <--"setcls"---- bridge.py <--JSON--- 분류결과
```

- **런타임**: Ollama(`brew services start ollama`), HTTP `localhost:11434`, **API 키 불필요·완전 오프라인**.
- **모델 선정**: qwen2.5:0.5b·llama3.2:1b/3b는 이 분류에 불안정(오분류/포맷위반) →
  **`qwen2.5:3b` + slim 페이로드**(pid,name,run,sleep,life만)가 결정론적 정답.
- **멀티 워크로드 데모**: `spin`→CPU_BOUND, `iohog`→IO_BOUND, **`cc`→BATCH**.
  cc는 spin과 동일한 무한 CPU 루프인데 **이름이 빌드툴**이라 BATCH로 분류 → 보고서의 "이름으로 분류" 실증.
- **하이브리드**(`--hybrid --min-life N`): cold-start에 한 번만 LLM 호출, 정상상태 0회.
- **fail-static**: LLM 실패 시 휴리스틱 강등, 커널이 항상 range-check, LLM은 제안만.
- **panic 진단**: `tools/diagnose.py`가 `@@PANIC` 타임라인을 LLM에 먹여 자연어 사후분석 출력.

실행:
```sh
make TOOLPREFIX=riscv64-elf- kernel/kernel fs.img
python3 tools/bridge.py --hybrid --min-life 10 --workload "spin,iohog,cc"
python3 tools/diagnose.py --workload crashme
```
(상세는 `xv6-process/tools/README.md`)

---

## 5. 변경 요약
- 커널 13파일 수정(+497줄): defs.h, exec.c, param.h, printf.c, proc.c, proc.h, procstat.h, syscall.{c,h}, sysproc.c, user.h, usys.pl, Makefile
- 신규 유저 프로그램 9개: `wl, priors, jobtest, wlagent, setcls, iohog, cc, fbomb, crashme`
- 신규 호스트 도구: `tools/bridge.py`, `tools/diagnose.py`, `tools/README.md`
- 회귀: `priority_test`·`jobtest` 통과 (fast-path 무손상)
- 브랜치: `feat/llm-advisor-sec04-07`

## 6. 미완 (다음 작업)
- **Plan A — virtio-console 전용 채널**: 현재 브리지는 콘솔 공유(Plan B). 전용 디바이스 드라이버로 채널 분리는 미구현(실제 커널 드라이버 ~수백 줄, 별도 작업).
- `advstat`/`advisord` 출고 버그(스택 오버플로, printf 폭지정자) 정식 수정.
- 상세는 저장소 루트 `todo.md` 참고.
