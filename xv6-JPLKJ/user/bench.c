// bench.c — CPU micro-benchmark for the lv0/lv1/lv2 comparison.
//
//   bench <pages> <dur_ticks> [fixed_iters]
//
// Allocates <pages> resident (swappable) pages, then runs a busy compute loop
// in one of two modes:
//
//   * throughput mode (fixed_iters omitted/0): compute for <dur_ticks> ticks
//     of wall time and report how many iterations completed:
//       @@BENCH pid=P pages=N iters=I wall=D mode=dur
//
//   * latency mode (fixed_iters > 0): do exactly <fixed_iters> iterations and
//     report how many ticks of wall time that took:
//       @@BENCH pid=P pages=N iters=F wall=W mode=fixed
//
// Run a memory-pressured hog (pages>0, swapped externally) plus a pure-CPU
// good job and compare. Under Level 2 cross-control the swapped hog is demoted,
// so a latency-mode good job finishes in fewer wall ticks (more CPU for it).

#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

#define PGSIZE 4096
#define INNER  20000      // inner compute work per outer iteration

int
main(int argc, char *argv[])
{
  int pages = 0, dur = 100, fixed = 0, startpause = 0;
  if(argc >= 2) pages = atoi(argv[1]);
  if(argc >= 3) dur   = atoi(argv[2]);
  if(argc >= 4) fixed = atoi(argv[3]);
  if(argc >= 5) startpause = atoi(argv[4]);

  if(pages > 0){
    char *base = sbrk(pages * PGSIZE);
    if(base == (char*)-1){
      printf("@@BENCH pid=%d ERROR sbrk failed\n", getpid());
      exit(1);
    }
    for(int i = 0; i < pages; i++)
      base[i * PGSIZE] = (char)(i & 0xff);
  }

  printf("@@BSTART pid=%d pages=%d tick=%d\n", getpid(), pages, uptime());

  // Optional startup pause: the process is resident (swappable) but NOT
  // CPU-monopolizing during this window, so an external controller can swap
  // and/or demote it before it starts spinning. (Used by the perf harness so
  // the advmem controller isn't itself starved under -smp 1.)
  if(startpause > 0)
    pause(startpause);   // 'sleep' syscall is named 'pause' in this kernel

  int start = uptime();
  volatile long acc = 0;
  long iters = 0;

  if(fixed > 0){
    // latency mode: fixed work, measure wall time.
    for(iters = 0; iters < fixed; iters++)
      for(int k = 0; k < INNER; k++)
        acc += k;
    int end = uptime();
    printf("@@BENCH pid=%d pages=%d iters=%ld wall=%d endtick=%d mode=fixed\n",
           getpid(), pages, iters, end - start, end);
  } else {
    // throughput mode: fixed wall time, measure work.
    while(uptime() - start < dur){
      for(int k = 0; k < INNER; k++)
        acc += k;
      iters++;
    }
    printf("@@BENCH pid=%d pages=%d iters=%ld wall=%d mode=dur\n",
           getpid(), pages, iters, dur);
  }
  exit(0);
}
