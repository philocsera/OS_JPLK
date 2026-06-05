// wl — a named CPU-bound workload used to demonstrate exit-stats learning
// (report sec 04).
//
// At startup it prints the class it was *seeded* with by exec(). On the
// first ever run there is no prior, so it starts as NORMAL. It then burns
// CPU and exits, which makes the kernel learn "wl -> CPU_BOUND". On every
// subsequent run, exec() seeds it as CPU_BOUND from instruction zero — so
// the startup line flips from NORMAL to CPU_BOUND with no warm-up window.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/procstat.h"
#include "user/user.h"

static const char *
class_name(int c)
{
  switch(c) {
  case CLASS_INTERACTIVE: return "INTERACTIVE";
  case CLASS_IO_BOUND:    return "IO_BOUND";
  case CLASS_NORMAL:      return "NORMAL";
  case CLASS_CPU_BOUND:   return "CPU_BOUND";
  case CLASS_BATCH:       return "BATCH";
  case CLASS_SYSTEM:      return "SYSTEM";
  default:                return "?";
  }
}

int
main(void)
{
  struct procstat ps;
  if(getprocstat(getpid(), &ps) == 0)
    printf("wl: startup class = %s (id=%d, quantum=%d)\n",
           class_name(ps.class_id), ps.class_id, ps.quantum_ticks);
  else
    printf("wl: getprocstat(self) failed\n");

  // Burn enough CPU to dominate run_ticks over sleep_ticks so the exit
  // profile is unambiguously CPU-heavy.
  volatile long x = 0;
  for(long i = 0; i < 120000000L; i++)
    x += i;

  exit(0);
}
