#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/memstat.h"
#include "user/user.h"

static void
print_memstat(void)
{
  // MEMSTAT_MAX * sizeof(struct memstat) == 4KB == one page, which overflows
  // the single-page user stack and store-faults (scause 0xf). Keep it in BSS,
  // matching memwatch.c's own fix for the same hazard.
  static struct memstat stats[MEMSTAT_MAX];
  int n;
  int i;

  n = getmemstat(stats, MEMSTAT_MAX);

  if(n < 0){
    printf("getmemstat failed\n");
    return;
  }

  printf("pid\tstate\tsz\tquota\tname\n");

  for(i = 0; i < n; i++){
    printf("%d\t%d\t%d\t%d\t%s\n",
      stats[i].pid,
      stats[i].state,
      (int)stats[i].sz,
      (int)stats[i].mem_quota,
      stats[i].name);
  }
}

int
main(int argc, char *argv[])
{
  int pid = getpid();
  int quota = 65536;

  if(argc >= 2){
    quota = atoi(argv[1]);
  }

  printf("=== before setmemquota ===\n");
  print_memstat();

  printf("\nsetmemquota pid=%d quota=%d\n", pid, quota);

  if(setmemquota(pid, quota) < 0){
    printf("setmemquota failed\n");
    exit(1);
  }

  printf("\n=== after setmemquota ===\n");
  print_memstat();

  exit(0);
}