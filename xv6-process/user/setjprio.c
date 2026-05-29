// setjprio — apply a whole-job priority to every process in a group
// (LLM fork-bomb pre-emption executor, report sec 06).
//
//   setjprio <group_id> <priority 0..20>
//
// The host bridge (tools/bridge.py) types this into the shell when the LLM
// judges a job-group to be a runaway fork tree (vs a legitimate parallel
// build). Demoting the whole group to a low priority throttles the bomb
// *before* it monopolises the CPU, so the kernel's per-job fork cap (sec 06)
// becomes a backstop rather than the only line of defense. setjobpriority
// applies to every live member in one kernel sweep; an out-of-range priority
// is rejected by the kernel (range-checked, like setclass).

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/procstat.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  if(argc != 3) {
    printf("usage: setjprio <group_id> <priority 0..20>\n");
    exit(1);
  }
  int gid = atoi(argv[1]);
  int prio = atoi(argv[2]);

  int n = setjobpriority(gid, prio);
  if(n < 0) {
    printf("setjprio: setjobpriority(%d,%d) failed\n", gid, prio);
    exit(1);
  }
  printf("setjprio: group %d -> prio %d (%d procs)\n", gid, prio, n);
  exit(0);
}
