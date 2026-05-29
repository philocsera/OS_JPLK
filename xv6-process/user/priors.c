// priors — dump the kernel's exit-statistics learning table (report sec 04).
//
// Companion to wl. Shows, per program name, the learned class and the
// running mean of run/sleep ticks that produced it. Uses only the plain
// %d/%s/%ld conversions that xv6's minimal printf actually supports.

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
  struct nameprior buf[NPRIOR];
  int n = getnamepriors(buf, NPRIOR);
  if(n < 0) {
    printf("priors: getnamepriors failed\n");
    exit(1);
  }

  printf("learned priors: %d entries\n", n);
  printf("name / class / samples / avg_run / avg_sleep\n");
  for(int i = 0; i < n; i++) {
    struct nameprior *e = &buf[i];
    printf("  %s -> %s  samples=%ld run=%ld sleep=%ld\n",
           e->name, class_name(e->class_id),
           e->samples, e->avg_run, e->avg_sleep);
  }
  exit(0);
}
