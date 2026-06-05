#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  int pid = getpid();
  int quota = 0;
  int step = 4096;
  int total = 0;
  int i = 0;
  char *p;

  if(argc >= 2){
    quota = atoi(argv[1]);
  }

  if(argc >= 3){
    step = atoi(argv[2]);
  }

  if(step <= 0){
    printf("step must be positive\n");
    exit(1);
  }

  printf("memstress start pid=%d quota=%d step=%d\n", pid, quota, step);

  if(quota > 0){
    if(setmemquota(pid, quota) < 0){
      printf("setmemquota failed\n");
      exit(1);
    }
  } else {
    printf("quota disabled\n");
  }

  while(1){
    p = sbrk(step);

    if(p == (char*)-1){
      printf("sbrk failed after total allocated=%d bytes\n", total);
      break;
    }

    // 실제 페이지가 할당되도록 메모리에 접근
    p[0] = 1;
    p[step - 1] = 1;

    total += step;
    i++;

    if(i % 4 == 0){
      printf("allocated=%d bytes\n", total);
    }
  }

  printf("memstress done\n");
  exit(0);
}