#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  int pid;
  int count = 1;
  int i;
  int success = 0;

  if(argc < 2 || argc > 3){
    printf("usage: swapctl pid [count]\n");
    exit(1);
  }

  pid = atoi(argv[1]);

  if(argc == 3)
    count = atoi(argv[2]);

  if(pid <= 0 || count <= 0){
    printf("swapctl: invalid argument\n");
    exit(1);
  }

  for(i = 0; i < count; i++){
    if(swapout(pid) < 0)
      break;

    success++;
  }

  printf("swapctl pid=%d requested=%d success=%d\n",
    pid, count, success);

  exit(0);
}
