#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

#define PAGE_SIZE 4096
#define MAX_PAGES 32

int
main(int argc, char *argv[])
{
  int npages = 8;
  int delay = 500;
  int i;
  int round;
  char *base;

  if(argc >= 2)
    npages = atoi(argv[1]);

  if(argc >= 3)
    delay = atoi(argv[2]);

  if(npages <= 0 || npages > MAX_PAGES){
    printf("usage: memhold [1-%d pages] [delay ticks]\n", MAX_PAGES);
    exit(1);
  }

  if(delay < 0)
    delay = 0;

  base = sbrk(npages * PAGE_SIZE);

  if(base == (char *)-1){
    printf("memhold: sbrk failed\n");
    exit(1);
  }

  for(i = 0; i < npages; i++)
    base[i * PAGE_SIZE] = (char)(i + 1);

  printf("memhold ready pid=%d pages=%d delay=%d\n",
    getpid(), npages, delay);

  pause(delay);

  for(i = 0; i < npages; i++){
    if(base[i * PAGE_SIZE] != (char)(i + 1)){
      printf("memhold: pattern mismatch page=%d\n", i);
      exit(1);
    }
  }

  printf("memhold touched pages pid=%d\n", getpid());

  for(round = 0; round < 100; round++)
    pause(20);

  printf("memhold done pid=%d\n", getpid());
  exit(0);
}
