// ftree — a runaway-looking fork tree that STAYS resident, to demo the host
// bridge's LLM fork-bomb pre-emption (report sec 06).
//
//   ftree [secs]      spawn a wide job that lingers ~secs seconds (default 8)
//
// Unlike fbomb (which forks to the kernel cap and immediately tears down, too
// fast for the bridge's ~500ms poll to ever see), ftree becomes its own job
// and parks a batch of children so the ballooned group is visible across
// several poll cycles. That gives tools/bridge.py time to observe the group's
// size/growth, ask the local LLM "legit parallel build vs fork bomb?", and —
// if it judges a bomb — pre-emptively demote the whole job with `setjprio`,
// before the per-job fork cap is even the deciding factor.
//
// Stays just under GROUP_PROC_LIMIT so the demo is about *pre-emption*, not the
// kernel cap firing (that path is already covered by fbomb).

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/param.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  int secs = (argc > 1) ? atoi(argv[1]) : 8;
  if(secs < 1)
    secs = 1;
  int linger = secs * 10;            // xv6 tick ~100ms → ticks for ~secs seconds
  int want = GROUP_PROC_LIMIT - 4;   // a wide-but-uncapped burst (e.g. 12)

  int g = setjob();
  int n = 0;
  for(int i = 0; i < want; i++) {
    int pid = fork();
    if(pid < 0)
      break;                         // table/cap pressure — stop early
    if(pid == 0) {
      // Child: park so it stays a live member of the group, then self-exit a
      // little after the parent so the bridge always sees the full balloon.
      pause(linger + 20);
      exit(0);
    }
    n++;
  }

  printf("ftree: job group=%d, spawned=%d, lingering ~%ds\n", g, n, secs);
  pause(linger);                     // keep the group resident for the bridge
  exit(0);
}
