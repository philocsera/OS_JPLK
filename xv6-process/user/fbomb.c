// fbomb — controlled fork-bomb to verify the per-job fork cap (report sec 06).
//
// Becomes its own job (setjob), then forks as fast as it can. Each child
// parks (so it stays live and counts against the job). With the kernel's
// GROUP_PROC_LIMIT in effect, fork() must start failing once this job fills
// its quota — while the rest of the system (shell, init) keeps running.
//
// Without the cap this loop would march to NPROC and wedge the whole machine;
// with it, the damage is contained to this one job.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/param.h"
#include "user/user.h"

int
main(void)
{
  int g = setjob();
  int kids[NPROC];
  int n = 0;

  for(;;) {
    int pid = fork();
    if(pid < 0)
      break;                  // cap reached (or table full)
    if(pid == 0) {
      pause(200);             // child parks, then self-terminates as a safety net
      exit(0);
    }
    kids[n++] = pid;
    if(n >= NPROC)            // absolute safety stop
      break;
  }

  printf("fbomb: job group=%d, forks succeeded=%d (per-job cap=%d)\n",
         g, n, GROUP_PROC_LIMIT);
  if(n < GROUP_PROC_LIMIT)
    printf("fbomb: PASS - job was capped, system not exhausted\n");
  else
    printf("fbomb: FAIL - cap not enforced (n=%d >= NPROC?)\n", n);

  // Tear the bomb down.
  for(int i = 0; i < n; i++)
    kill(kids[i]);
  for(int i = 0; i < n; i++)
    wait(0);

  exit(0);
}
