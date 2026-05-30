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
- `advstat`/`advisord` 출고 버그(스택 오버플로, printf 폭지정자) 정식 수정. → **§7에서 완료**
- 상세는 저장소 루트 `todo.md` 참고.

---

## 7. (추가) 출고 버그 정식 수정 + sec04/06/07 기능 보강 + PR (2026-05-29)

§1에서 발견한 버그 3건을 정식 수정하고, sec 04/06/07의 미완·개선 항목을 구현했다.
모든 변경은 **실증(QEMU smp3) + 로컬 LLM(Ollama qwen2.5:3b) + 적대적 멀티에이전트 리뷰**로 이중 검증.

### 7.1 출고 버그 정식 수정 (`196303b`)
| 버그 | 수정 | 검증 |
|---|---|---|
| advstat/advisord 시작 크래시(scause 0xf) | `struct procstat buf[64]`(~5.5KB)를 `static`(BSS) 이동 | 두 프로그램 크래시 없이 동작, `nm`에 `buf.0` 확인 |
| advstat 표 깨짐 | 폭 지정자 제거 → 수동 정렬 헬퍼 `padnum(long,w)`/`padstr(s,w)` | 컬럼 정렬 정상 출력 |
| sleep_ticks 오집계 | `clockintr`에서 `procstat_tick()`을 `acquire(&tickslock)/ticks++/wakeup(&ticks)` **앞**으로 이동 (procstat_tick은 `ticks` 미참조·try_acquire라 데드락 불가, wakeup은 여전히 tickslock 내부 → lost-wakeup 불변식 유지) | pause(5) 슬리퍼(advisord)가 `slp=1447/rdy=0`로 정상 집계, `priority_test` "All tests passed!" 무회귀 |
| diagnose.py 오독 | 3B가 FORKFAIL을 "insufficient memory"로 오독 → 시스템 프롬프트 재작성 + one-shot few-shot, d1/d2 필드 의미를 커널과 정확 일치 | `crashme` end-to-end: FORKFAIL을 "job-group 16 상한(cap)"으로 정확 해석 |

### 7.2 EV_CLASS 이벤트 실제 로깅 (`c1df7cb`, sec 07 타임라인 보강)
- `EV_CLASS`는 enum에만 있고 어디서도 기록되지 않아 panic 타임라인에 어드바이저 재분류가 안 보였다(리뷰 중 확인).
- `proc_setclass`/`proc_setjobclass`의 **실제 클래스 변경** 시 `proc_log_event(EV_CLASS, pid, name, old, new, ...)` 기록.
  old를 덮어쓰기 전에 캡처하고 **p->lock 해제 후** 로깅(락 순서 항상 p->lock→ev_lock → 데드락 불가).
- 검증: `advisord & + spin &` → 어드바이저가 spin을 NORMAL(2)→CPU_BOUND(3)로 재분류,
  crashme panic 타임라인에 `@@EV type=CLASS pid=6 name=spin d1=2 d2=3 msg=set` 출력 ✅

### 7.3 name_priors 영속화 (`f9f15c8`, sec 04 개선)
- 기존: 학습 테이블이 **재부팅 시 휘발** → `wl`이 매 부팅 NORMAL 시작. 유저스페이스 방식으로 영속화(커널 fs 직접접근 회피).
- 신규 syscall `setnamepriors`(SYS #35) + `proc_set_priors()`(유저 입력 **재검증**: class_id 범위·name NUL·n≤NPRIOR 후 테이블 교체).
- `priors save|load [path]` 서브커맨드(파일 포맷: `int count` + `count×struct nameprior`, `read_full`/`write_full`).
- **init이 부팅 시 `priors load /priors.db` 자동 실행**(파일 없음/손상 시 무출력 no-op → 부팅 절대 안 막힘).
- 검증(동일 fs.img 2세션): 세션1 `wl`(NORMAL)→exit로 `wl→CPU_BOUND` 학습→`priors save`.
  세션2 재부팅 → init "loaded 1 entries" 자동 복원 → 워크로드 재실행 없이 `priors`가 `wl→CPU_BOUND` 표시,
  `wl` 첫 실행이 명령어 0에서 CPU_BOUND(quantum=4) 시드 ✅

### 7.4 bridge 측 LLM 포크폭탄 선제 방어 (`6aec34c`, sec 06 개선)
- 커널 숫자 cap(`GROUP_PROC_LIMIT`)에 더해, **호스트 브리지가 job-group 크기를 보고 LLM으로
  "정상 병렬 빌드 vs 런어웨이 포크폭탄"을 판단**, 폭탄이면 cap이 작동하기 전에 `setjprio`로 그룹 전체 선제 강등.
- `wlagent` 프레임에 `"group"` 필드 추가 → 브리지가 그룹 단위 집계.
- 신규 CLI `setjprio <group> <prio>`(setjobpriority 래퍼, 전 멤버 일괄 강등 실행기).
- 신규 데모 워크로드 `ftree [secs]`: fbomb과 달리 자식을 상주시켜 그룹이 여러 폴 주기 동안 보이게 함(브리지 관찰 시간 확보).
- `bridge.py`: `judge_group()`이 LLM(few-shot)으로 판정 + 휴리스틱 폴백, bomb이면 `setjprio <g> 19` 주입, 강등 그룹은 분류 루프에서 제외(클래스→우선순위 보정이 강등을 되돌리지 않게). 플래그 `--no-defend/--bomb-threshold/--bomb-prio`.
- 검증: bridge가 13-proc `ftree` 그룹(run~0, 갓 스폰)을 LLM이 **bomb** 판정 → `setjprio 5 19` 주입.
  커널측 독립 검증: `advstat`에서 13개 멤버 priority 10→19 일괄 강등 확인 ✅
- 한계: wlagent 프레임과 setjprio 콘솔 출력이 문자 단위로 섞여 guest 확인 라인 간헐 누락(= Plan A 전용 채널이 해결할 그 문제). 동작 정확성과 무관.

### 7.5 적대적 멀티에이전트 리뷰 (실제 결함 0건)
워크플로우 2회(차원별 병렬 리뷰 → 발견마다 독립 검증 에이전트가 반박 시도):
- 1차(버그 수정 4파일): 제기 5건 → **전부 반박**(padnum 경계값·uint64→long 일관·name NUL·clockintr 락안전·diagnose 필드의미 모두 정상).
- 2차(신규 3기능): 제기 9건 → **전부 반박**(setnamepriors copyin 경계·proc_set_priors 인덱스/검증·prior_lock·init 부팅 안전성·EV_CLASS 락순서 모두 정상).
- 합계 제기 14건, **실제 결함 0건**. 리뷰 지적 중 사소한 코드 위생(브리지 그룹 키 폴백 일관화)만 `d897ee4`로 반영.

### 7.6 이번 추가분 변경 요약
- 커널: `trap.c`(clockintr 재정렬), `proc.c`(EV_CLASS 로깅·`proc_set_priors`), `sysproc.c`(`sys_setnamepriors`), `defs.h`/`syscall.{c,h}`/`usys.pl`/`user.h`(syscall #35 등록), `init.c`(부팅 자동 로드).
- 유저: `advstat.c`/`advisord.c`(static+정렬), `priors.c`(save/load), `wlagent.c`(group 필드), **신규** `setjprio.c`·`ftree.c`.
- 호스트: `tools/diagnose.py`(프롬프트), `tools/bridge.py`(그룹 방어), `tools/README.md`.
- 커밋: `196303b`(버그), `c1df7cb`(EV_CLASS), `f9f15c8`(영속화), `6aec34c`(선제방어), `a899fb6`(README), `d897ee4`(리뷰 반영).
- **PR**: philocsera/OS_JPLKJ **#1** (`feat/llm-advisor-sec04-07` → main).

### 7.7 갱신된 미완
- **Plan A — virtio-console 전용 채널** (콘솔 인터리빙 근본 해결책) → **§8에서 완료**.
- **LLM 지연 튜닝**(qwen2.5:1.5b 비교/하이브리드 기본화 등), 미적용.

---

## 8. (추가) Plan A — virtio-console 전용 채널 구현·검증 (2026-05-30)

§6/§7.7의 마지막 핵심 미완이던 **콘솔 인터리빙 근본 해결**을 완료했다. 어드바이저
프로토콜(`@@WL` 프레임 + `setcls`/`setjprio` 명령)을 UART 콘솔이 아닌 **전용
virtio-console 디바이스**로 분리해, 사람용 셸과 절대 섞이지 않게 했다.

### 8.1 가장 큰 리스크부터 스파이크로 제거
todo.md가 경고한 핵심 불확실성 = "QEMU `virtio-serial-device`+`virtconsole`가
**multiport 미협상**(control queue 없이) 모드에서 queue 0/1을 chardev에 라우팅하는가".
16개 파일을 건드리기 전에 최소 드라이버(init + 배너 1줄 TX)만 만들어 검증 →
호스트 유닉스 소켓에서 배너 수신 **PASS**. control queue 처리 불필요 확정 후 본구현 착수.

### 8.2 커널 드라이버 (`kernel/virtio_console.c`, 신규 ~290줄)
- **2번째 virtio-mmio 슬롯** `0x10002000`/IRQ 2 (qemu virt DTB로 확인). `memlayout.h`에
  `VIRTIO1`/`VIRTIO1_IRQ`, `vm.c` 커널 페이지테이블에 MMIO 매핑 추가(누락 시 scause 0xd).
- **non-multiport**: `VIRTIO_CONSOLE_F_MULTIPORT`를 협상하지 않아 디바이스가 단순
  2-큐 콘솔로 degrade → queue 0=rx(host→guest), 1=tx(guest→host), control queue 없음.
- **인터럽트 구동 양방향**: rx 버퍼 NUM개 선등록(device가 채움)→intr에서 커널 입력
  링으로 복사 후 재등록·`wakeup`; tx는 free 디스크립터에 유저 버퍼 복사·제출 후 완료
  intr까지 `sleep`. `spinlock` 1개로 직렬화, `read`는 콘솔처럼 **줄 단위**(`\n`)로 반환.
- `plic.c`(IRQ enable), `trap.c`(`VIRTIO1_IRQ`→`virtio_console_intr`), `main.c`(init),
  `defs.h` 배선. 디바이스 파일 `/advisor`(major `ADVISOR=2`)로 `devsw` 등록, `init.c`가
  부팅 시 `mknod /advisor`.

### 8.3 게스트 데몬 (`user/advd.c`, 신규)
- `/advisor`를 열고 `fork`: **writer 자식**이 poll틱마다 procstat 프레임 송신,
  **reader 부모**가 명령 줄을 읽어 `setclass`+`setpriority`/`setjobpriority` **직접
  syscall**로 적용하고 `@@OK`/`@@ERR` 한 줄 회신.
- **핵심 정확성**: xv6 유저 `printf`는 1바이트씩 `write` → 두 writer가 섞임. 그래서
  각 프레임·ack를 **버퍼에 조립해 단일 `write()`**로 방출(커널이 write() 한 번을 락으로
  원자화 → 줄 단위 무섞임 보장). exec 없이 in-process 적용이라 콘솔 출력 0.

### 8.4 호스트 브리지 (`tools/bridge.py`)
- 부팅·워크로드/`advd` 1회 기동만 pexpect(콘솔), **프로토콜 루프는 유닉스 소켓**으로 전환.
  `Channel` 줄버퍼 리더/라이터 추가, 프레임 파싱·LLM 분류·sec06 방어 로직은 **그대로**(전송만 교체).
  QEMU 인자에 virtio-serial+socket chardev 추가(`Makefile` `qemu` 타깃·브리지 양쪽,
  `server=on,wait=off`라 브리지 없이도 부팅).

### 8.5 검증 (전 경로 실측, QEMU smp3)
- **스파이크 TX**: 호스트 소켓에서 배너 수신 ✅
- **양방향 E2E**(`tools/test_advd.py`): 소켓으로 프레임 수신 → `setcls` 송신 → `@@OK
  setcls pid=5 cls=3 prio=12` ack → 다음 프레임에서 class=3 반영 ✅
- **콘솔 청정성**(근본 목표): 라이브 브리지 실행 중 UART 캡처에 `@@WL`·`@@OK`·`setcls`
  **각각 0건**, 셸엔 1회성 `spin &`/`advd 3 &` 에코만 → 인터리빙 완전 제거 **실증** ✅
- **sec06 방어 경로**: `ftree 12` 13-proc 그룹을 소켓으로 bomb 판정→`setjprio 5 19` 송신→
  `@@OK setjprio group=5 prio=19 procs=13` ✅
- **실 LLM 경로**(Ollama qwen2.5:3b): 소켓 위에서 `cc`가 NORMAL→CPU_BOUND→**BATCH**
  (이름 기반 분류) 정상 ✅
- **회귀**: `priority_test` "All tests passed!" 무손상(전용 디바이스 배선 후에도) ✅

### 8.6 이번 변경 요약
- 커널 신규: `virtio_console.c`. 수정: `memlayout.h`·`vm.c`·`virtio.h`·`plic.c`·`trap.c`·
  `main.c`·`defs.h`·`file.h`(ADVISOR major).
- 유저 신규: `advd.c`. 수정: `init.c`(mknod), `Makefile`(OBJS·UPROGS·QEMUOPTS).
- 호스트: `bridge.py`(소켓 전송), 신규 `tools/test_advd.py`, `tools/README.md`(전용 채널 절).
- 한계/남음: 큐 깊이(NUM=8)·rx 버퍼 256B는 데모 규격(프레임·명령엔 충분, 대용량 백프레셔
  미세튜닝은 미적용). LLM 지연 튜닝은 여전히 열린 개선 항목.

### 8.7 적대적 멀티에이전트 리뷰 (Plan A) + 반영
커밋 전, §7.5와 동일한 방식으로 신규 코드(드라이버·데몬·브리지)를 차원별 병렬 리뷰 →
발견마다 **2개의 서로 다른 시각(정확성/재현성) 스켑틱이 독립 반박**. 총 **16건 제기 →
13건 반박, 3건 split(한쪽 real·한쪽 refuted), confirmed 0건**. split 3건을 직접 판정:
- **(반영) `virtio_console_write` 비살해성(uninterruptible) sleep** — `virtio_console_read`·
  `consoleread`는 sleep 전에 `killed(myproc())`를 확인하나 write 경로엔 누락. 호스트
  브리지가 연결됐으나 소켓을 안 읽어 백프레셔가 걸리면(QEMU가 virtio-serial 포트
  throttle) tx가 영영 완료 안 돼 advd writer가 **kill 불가**로 멈춤. → 두 sleep 앞에
  read 경로와 동일한 `killed` 체크 추가(in-flight 디스크립터는 intr이 회수하도록 남김).
- **(반영) `advd` `emit_frame` obuf 오버플로 잠재** — 레코드 1건 최악(~202B)이 안전마진
  (128B)보다 크고 마무리 `]\n`이 무검사라, proc 64개+큰 tick값이면 `obuf[8192]` 초과 가능.
  → **레코드 쓰기 전** 256B 여유 확인(최악 레코드+종료자) 후 미달 시 조기 종료(프레임은
  여전히 유효 JSON으로 닫힘).
- **(미반영) bridge `heuristic_group` 정수나눗셈** — LLM **폴백** 휴리스틱의 초기 `make -j`
  오판 가능성(low, 한쪽 uncertain·한쪽 refuted). 데모는 LLM 경로를 쓰고 종료성 강등은
  의도된 데모 동작(코드 주석에 명시)이라, 임계값 변경은 검증된 동작을 흔들 위험 → 보류.
- 반영 2건 후 재빌드 → `test_advd.py` E2E PASS·`priority_test` "All tests passed!" 무회귀 재확인.
