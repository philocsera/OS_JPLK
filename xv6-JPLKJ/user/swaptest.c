// user/swaptest.c
//
// swap 메커니즘 단독 검증 프로그램. LLM 연동 전에 swapout/swapin이
// 데이터 무결성을 지키는지 확인하는 용도.
//
// 검증 항목:
//   A. 자기 자신 swapout — 호출 프로세스의 페이지를 내보내고,
//      이후 접근 시 page fault → swapin 으로 투명 복구되는지
//   B. fork된 자식 swapout — 부모가 자식 pid를 지정해 swapout,
//      자식이 자기 메모리를 정상적으로 읽는지
//
// 사용법:
//   swaptest            기본 16 페이지
//   swaptest <npages>   페이지 수 지정 (스트레스 테스트)
//
// 핵심 아이디어:
//   각 페이지에 "페이지 번호 + 매직"으로 만든 고유 패턴을 써넣고,
//   swapout 후 다시 읽어 패턴이 그대로인지 검사한다.
//   패턴이 깨지면 swap I/O 또는 PTE 복구에 버그가 있는 것.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

#define PGSIZE      4096
#define DEF_PAGES   16
#define MAGIC       0x5741507Eu   // "SWAP~" 비슷한 임의 상수

// 페이지 p의 워드 i 에 들어갈 기대값
static uint
expected(int page, int word)
{
  return (MAGIC ^ ((uint)page << 16)) + (uint)word;
}

// buf의 모든 페이지에 고유 패턴 기록
static void
fill_pattern(char *buf, int npages)
{
  for(int p = 0; p < npages; p++){
    uint *w = (uint*)(buf + p * PGSIZE);
    for(int i = 0; i < PGSIZE / (int)sizeof(uint); i++)
      w[i] = expected(p, i);
  }
}

// buf의 패턴을 검증. 틀린 페이지 수 반환 (0이면 전부 정상).
static int
check_pattern(char *buf, int npages)
{
  int bad = 0;
  for(int p = 0; p < npages; p++){
    uint *w = (uint*)(buf + p * PGSIZE);
    int page_ok = 1;
    for(int i = 0; i < PGSIZE / (int)sizeof(uint); i++){
      if(w[i] != expected(p, i)){
        page_ok = 0;
        break;
      }
    }
    if(!page_ok){
      printf("  [FAIL] page %d 패턴 불일치\n", p);
      bad++;
    }
  }
  return bad;
}


// ----- 테스트 A: 자기 자신 swapout -----
//
// swapout(getpid())을 npages번 호출.
// victim 선택은 커널이 하므로, 우리가 만든 buf 페이지뿐 아니라
// 코드/스택 페이지가 나갈 수도 있다. 어느 쪽이든 이후 접근 시
// swapin으로 복구되어야 하고, buf 패턴은 보존되어야 한다.
static int
test_self(int npages)
{
  printf("[A] 자기 자신 swapout 테스트 (pid=%d, %d pages)\n",
         getpid(), npages);

  char *buf = sbrk(npages * PGSIZE);
  if(buf == (char*)-1){
    printf("  [FAIL] sbrk 실패\n");
    return 1;
  }

  fill_pattern(buf, npages);

  int ok = 0, fail = 0;
  for(int n = 0; n < npages; n++){
    int r = swapout(getpid());
    if(r == 0)
      ok++;
    else
      fail++;   // victim 없음/슬롯 부족 — 치명적 아님
  }
  printf("  swapout 호출: 성공 %d, 미수행 %d\n", ok, fail);

  // swapout 이후 buf를 다시 읽음 → swap된 페이지면 여기서 fault+swapin
  int bad = check_pattern(buf, npages);
  if(bad == 0){
    printf("  [PASS] 모든 페이지 패턴 보존\n");
    return 0;
  } else {
    printf("  [FAIL] %d 페이지 손상\n", bad);
    return 1;
  }
}


// ----- 테스트 B: fork된 자식 swapout -----
//
// 부모가 자식을 fork하고, 자식 pid를 지정해 swapout한다.
// 자식은 자기 메모리에 패턴을 쓴 뒤 부모 신호를 기다리고,
// swapout 이후 패턴을 검증한다.
//
// 부모-자식 동기화는 파이프로 한다 (xv6엔 세마포어 없음).
static int
test_child(int npages)
{
  printf("[B] fork된 자식 swapout 테스트 (%d pages)\n", npages);

  int p2c[2], c2p[2];   // parent→child, child→parent
  if(pipe(p2c) < 0 || pipe(c2p) < 0){
    printf("  [FAIL] pipe 실패\n");
    return 1;
  }

  int pid = fork();
  if(pid < 0){
    printf("  [FAIL] fork 실패\n");
    return 1;
  }

  if(pid == 0){
    // ===== 자식 =====
    close(p2c[1]);
    close(c2p[0]);

    char *buf = sbrk(npages * PGSIZE);
    if(buf == (char*)-1){
      char x = 'E';            // E = 에러
      write(c2p[1], &x, 1);
      exit(1);
    }
    fill_pattern(buf, npages);

    // "준비됨" 신호
    char rdy = 'R';
    write(c2p[1], &rdy, 1);

    // 부모가 swapout 끝낼 때까지 대기
    char go;
    read(p2c[0], &go, 1);

    // swapout 이후 패턴 검증 (swap된 페이지면 여기서 fault+swapin)
    int bad = check_pattern(buf, npages);

    char result = (bad == 0) ? 'P' : 'F';   // P=pass, F=fail
    write(c2p[1], &result, 1);
    exit(bad == 0 ? 0 : 1);
  }

  // ===== 부모 =====
  close(p2c[0]);
  close(c2p[1]);

  // 자식이 메모리 채울 때까지 대기
  char rdy;
  if(read(c2p[0], &rdy, 1) != 1 || rdy != 'R'){
    printf("  [FAIL] 자식 준비 신호 이상 (%c)\n", rdy);
    kill(pid);
    wait(0);
    return 1;
  }

  // 자식 pid를 swapout
  int ok = 0, fail = 0;
  for(int n = 0; n < npages; n++){
    int r = swapout(pid);
    if(r == 0) ok++;
    else       fail++;
  }
  printf("  자식 pid=%d swapout: 성공 %d, 미수행 %d\n", pid, ok, fail);

  // 자식에게 "검증해도 됨" 신호
  char go = 'G';
  write(p2c[1], &go, 1);

  // 자식 결과 수신
  char result;
  read(c2p[0], &result, 1);

  int status;
  wait(&status);

  if(result == 'P' && status == 0){
    printf("  [PASS] 자식 메모리 패턴 보존\n");
    return 0;
  } else {
    printf("  [FAIL] 자식 검증 실패 (result=%c status=%d)\n",
           result, status);
    return 1;
  }
}


// ----- 보호 규칙 확인: init/sh swapout 거부 -----
static void
test_protected(void)
{
  printf("[C] 보호 프로세스 swapout 거부 확인\n");
  int r1 = swapout(1);   // init
  int r2 = swapout(2);   // sh (관례)
  if(r1 < 0 && r2 < 0){
    printf("  [PASS] pid 1, 2 swapout 모두 거부됨\n");
  } else {
    printf("  [FAIL] 보호 프로세스가 swapout 됨 (r1=%d r2=%d)\n",
           r1, r2);
  }
}


int
main(int argc, char *argv[])
{
  int npages = DEF_PAGES;
  if(argc >= 2){
    npages = atoi(argv[1]);
    if(npages <= 0)
      npages = DEF_PAGES;
  }

  printf("=== swaptest 시작 (npages=%d) ===\n", npages);

  int fails = 0;
  fails += test_self(npages);
  fails += test_child(npages);
  test_protected();

  if(fails == 0)
    printf("=== 전체 PASS ===\n");
  else
    printf("=== %d개 테스트 FAIL ===\n", fails);

  exit(fails == 0 ? 0 : 1);
}
