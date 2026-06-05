// user/memfill.c — 목표치(target) 메모리 할당 워크로드.
//
// 통합 swap 루프의 OOM/생존 시험용. memstress(무한 성장, quota 워크로드)와 달리
// 목표 N MB 를 할당한 뒤 멈춘다 → "완주율" 신호를 만든다:
//   - 목표 도달   : "memfill done"  (완주)
//   - 막힘(일시)  : "memfill waiting (retry M/MAX)"  (sbrk 실패 → 외부 swap 대기 중)
//   - 목표 전 OOM : "memfill oom"   (retry_max 회 연속 실패 = 진짜 한도, kill 아님)
// 최종 sz(=완주 정도)는 memwatch/memstat 에 그대로 잡힌다.
//
// ★ 재시도 루프(swap 루프가 끼어들 "틈"): sbrk 가 RAM/quota 한도로 -1 을 반환해도
//   바로 OOM 으로 끝내지 않고, retry_wait 틱 자며 재시도한다. 그 사이 외부 주체
//   (정책 루프 / 손 / LLM)가 memstat 을 보고 swapctl 로 cold 페이지를 빼 RAM 을
//   비워주면 → 다음 sbrk 가 성공 → 완주. 누가 풀어주든 동작하는 수동/자동 공통 전제.
//
// swap 시나리오 의도:
//   - sbrk 는 eager(ulib.c) → 할당 즉시 물리 페이지 점유. 목표 전 RAM 고갈 시 sbrk 가
//     -1 을 깔끔히 반환(usertrap kill 아님).
//   - 할당은 앞으로만 진행하고 옛 페이지를 다시 만지지 않는다 → swap out 된 cold 페이지가
//     되돌아오지 않아 RAM 이 비고, 64MB swap 이 있으면 목표(>RAM)까지 완주 가능.
//   - 할당 후 hold 틱 동안 생존(pause) → 그 사이 memwatch 가 최종 sz 를 샘플. 이때도
//     옛 페이지 재접근 없음.
//
// usage: memfill <target_mb> [step_bytes] [hold_ticks] [retry_wait_ticks] [retry_max] [quota_mb]
//   target_mb        : 목표 할당량(MB). 0 이면 OOM 까지 무한.
//   step_bytes       : sbrk 증가 단위(기본 4096). 페이지 정렬 권장.
//   hold_ticks       : 완주/중단 후 생존 틱(기본 200) — 샘플링 창 확보용.
//   retry_wait_ticks : sbrk 실패 후 재시도까지 대기 틱(기본 10) — 외부가 swap 칠 시간.
//   retry_max        : 연속 실패 허용 횟수(기본 20). 이만큼 연속 실패하면 진짜 OOM.
//                      retry_max 까지 최대 (retry_max-1)*retry_wait 틱을 외부에 준다.
//                      0/1 이면 재시도 없이 즉시 OOM(기존 동작).
//   quota_mb         : >0 이면 시작 시 자기 pid 에 mem_quota(MB) 자가설정(기본 0=비활성).
//                      quota-on-resident 커널과 결합 시 헤드룸 보존 + swap 협력 완주 테스트용.
//                      (setquota 외부 호출의 타이밍/레이스 회피 — memstress 와 동일 패턴)

#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

#define PAGE_SIZE 4096

int
main(int argc, char *argv[])
{
  int target_mb = 0;
  int step = PAGE_SIZE;
  int hold = 200;
  int retry_wait = 10;   // sbrk 실패 후 재시도까지 대기할 틱 수
  int retry_max = 20;    // 연속 실패 허용 횟수(이만큼 연속 실패하면 진짜 OOM)
  int retry = 0;         // 현재 연속 실패 횟수(성공하면 0 으로 리셋)
  int quota_mb = 0;      // >0 이면 시작 시 자기 자신에게 mem_quota(MB) 설정(0=비활성)
  uint64 target_bytes;
  uint64 total = 0;
  int off;
  char *p;

  if(argc >= 2)
    target_mb = atoi(argv[1]);

  if(argc >= 3)
    step = atoi(argv[2]);

  if(argc >= 4)
    hold = atoi(argv[3]);

  if(argc >= 5)
    retry_wait = atoi(argv[4]);

  if(argc >= 6)
    retry_max = atoi(argv[5]);

  if(argc >= 7)
    quota_mb = atoi(argv[6]);

  if(target_mb < 0){
    printf("usage: memfill <target_mb> [step_bytes] [hold_ticks]"
           " [retry_wait_ticks] [retry_max] [quota_mb]\n");
    exit(1);
  }

  if(step <= 0)
    step = PAGE_SIZE;

  if(hold < 0)
    hold = 0;

  if(retry_wait < 0)
    retry_wait = 0;

  if(retry_max < 0)
    retry_max = 0;

  if(quota_mb < 0)
    quota_mb = 0;

  target_bytes = (uint64)target_mb * 1024 * 1024;

  // quota 자가설정: 시작 시(성장 전) 자기 pid 에 mem_quota 를 건다. memstress 와
  // 동일 패턴 → setquota 를 외부에서 거는 타이밍/레이스를 원천 회피한다.
  // quota-on-resident 커널과 결합하면: memfill 의 resident 가 이 quota 에 막혀
  // 헤드룸을 남기고, 외부 swapout 이 resident 를 풀어주면 target 까지 완주.
  if(quota_mb > 0){
    if(setmemquota(getpid(), quota_mb * 1024 * 1024) < 0){
      printf("memfill: setmemquota failed pid=%d quota_mb=%d\n", getpid(), quota_mb);
      exit(1);
    }
  }

  printf("memfill ready pid=%d target_mb=%d step=%d hold=%d retry_wait=%d retry_max=%d quota_mb=%d\n",
    getpid(), target_mb, step, hold, retry_wait, retry_max, quota_mb);

  while(target_mb == 0 || total < target_bytes){
    p = sbrk(step);

    if(p == (char*)-1){
      // eager sbrk 의 깔끔한 실패(RAM/quota 한도). kill 아님.
      // 즉시 포기하지 않고, 외부 주체(swap 정책 루프 / 손 / LLM)가 memstat 을 보고
      // swapctl 로 cold 페이지를 빼 RAM 을 비워줄 "틈"을 준다:
      //   1) waiting 로그를 찍어 현재 상태(완주 전 막힘)를 외부에 노출하고
      //   2) retry_wait 틱 동안 잠들었다가(폴링+swapctl 칠 시간)
      //   3) 같은 step 으로 재시도한다.
      // 외부 주체가 풀어주면 다음 sbrk 가 성공 → retry 리셋 후 계속 진행(완주).
      // retry_max 회 연속 실패하면 그제서야 진짜 OOM 으로 판정하고 종료한다.
      retry++;
      if(retry >= retry_max){
        printf("memfill oom pid=%d total=%d (gave up after %d retries)\n",
          getpid(), (int)total, retry);
        break;
      }
      printf("memfill waiting pid=%d (retry %d/%d) total=%d\n",
        getpid(), retry, retry_max, (int)total);
      {
        int start = uptime();
        while(uptime() - start < retry_wait)
          pause(1);
      }
      continue;  // 같은 step 재시도 — total 은 증가시키지 않는다.
    }

    // 성공: 외부 주체가 풀어준(또는 애초에 여유가 있던) 것 → 연속 실패 카운터 리셋.
    retry = 0;

    // step 구간의 모든 페이지를 한 번씩 터치(물리 점유 확정). 이후 재접근 안 함.
    for(off = 0; off < step; off += PAGE_SIZE)
      p[off] = (char)1;

    total += step;
  }

  if(target_mb != 0 && total >= target_bytes)
    printf("memfill done pid=%d total=%d\n", getpid(), (int)total);

  // 완주율(최종 sz)이 memstat 에 샘플되도록 hold 틱 동안 "확실히" 생존.
  // 단일 pause(hold) 는 인터럽트/이른 wakeup/구버전 커널에서 일찍 반환될 수 있어,
  // uptime() 으로 경과 틱을 직접 재며 hold 틱이 실제로 다 지날 때까지 머문다.
  //   - pause(1) 이 정상 sleep 이면 1 틱씩 양보(저전력).
  //   - pause 가 no-op 으로 즉시 반환해도 uptime() 가드 덕에 정확히 hold 틱을 채운다.
  // 옛 페이지 재접근 없음 → swap out 된 cold 페이지는 그대로 둔다.
  {
    int start = uptime();
    while(uptime() - start < hold)
      pause(1);
  }

  printf("memfill exit pid=%d total=%d\n", getpid(), (int)total);
  exit(0);
}
