#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  int pid;
  int quota;

  if(argc != 3){
    printf("usage: setquota pid quota\n");
    exit(1);
  }

  pid = atoi(argv[1]);
  quota = atoi(argv[2]);

  if(setmemquota(pid, quota) < 0){
    printf("setquota failed pid=%d quota=%d\n", pid, quota);
    exit(1);
  }

  printf("setquota ok pid=%d quota=%d\n", pid, quota);
  exit(0);
}
