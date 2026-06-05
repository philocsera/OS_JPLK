// cc — a CPU-bound workload that is NAMED like a build tool.
//
// Behaviorally identical to spin (infinite CPU), but because its name is "cc"
// the LLM advisor should classify it BATCH rather than CPU_BOUND — i.e. the
// decision uses the *name* prior, not just the run/sleep numbers. This is the
// "이름으로 분류" point of report sec 01/02 made concrete.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int
main(void)
{
  volatile long x = 0;
  for(;;)
    x++;
  exit(0);  // unreached
}
