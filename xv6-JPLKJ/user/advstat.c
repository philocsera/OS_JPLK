// advstat — print the current procstat table once and exit.
//
// Companion to advisord. Lets a human inspect what the advisor sees,
// which is useful for verifying that the kernel counters are wired up
// before trusting any classification decisions.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/procstat.h"
#include "user/user.h"

static const char *
class_name(int c)
{
  switch(c) {
  case CLASS_INTERACTIVE: return "INT";
  case CLASS_IO_BOUND:    return "IO ";
  case CLASS_NORMAL:      return "NRM";
  case CLASS_CPU_BOUND:   return "CPU";
  case CLASS_BATCH:       return "BAT";
  case CLASS_SYSTEM:      return "SYS";
  default:                return "???";
  }
}

static const char *
state_name(int s)
{
  switch(s) {
  case PS_UNUSED:   return "unused";
  case PS_USED:     return "used  ";
  case PS_SLEEPING: return "sleep ";
  case PS_RUNNABLE: return "runble";
  case PS_RUNNING:  return "run   ";
  case PS_ZOMBIE:   return "zombie";
  default:          return "??????";
  }
}

// xv6's user printf understands no field-width flags (%3d, %-16s, %5ld are
// printed literally), so columns are aligned by hand. padnum right-aligns a
// number in a w-wide field; padstr left-aligns a string.
static void
padnum(long v, int w)
{
  long t = (v < 0) ? -v : v;
  int digits = (v < 0) ? 1 : 0;   // sign
  do { digits++; t /= 10; } while(t > 0);
  for(int i = digits; i < w; i++)
    printf(" ");
  printf("%ld", v);
}

static void
padstr(const char *s, int w)
{
  int n = strlen(s);
  printf("%s", s);
  for(int i = n; i < w; i++)
    printf(" ");
}

int
main(int argc, char *argv[])
{
  // ~5.5KB (88 B * 64) — must be static, not on the 1-page user stack.
  static struct procstat buf[PROCSTAT_MAX];
  int n = getprocstat_all(buf, PROCSTAT_MAX);
  if(n < 0) {
    printf("advstat: getprocstat_all failed\n");
    exit(1);
  }

  // Level 1: extra memory columns (qta=quota KB, swO/swI=swapout/swapin,
  // qD=quota-denied) let the advisor SEE memory pressure alongside schedule
  // state. 0/'-' means "no quota / not thrashing".
  printf("pid ppid state  name             prio cls quan   run   rdy   slp   cs life  qtaKB swO swI  qD\n");
  for(int i = 0; i < n; i++) {
    struct procstat *p = &buf[i];
    padnum(p->pid, 3);            printf(" ");
    padnum(p->ppid, 4);           printf(" ");
    printf("%s ", state_name(p->state));      // already 6 chars wide
    padstr(p->name, 16);          printf(" ");
    padnum(p->priority, 4);       printf(" ");
    printf("%s ", class_name(p->class_id));   // already 3 chars wide
    padnum(p->quantum_ticks, 4);  printf(" ");
    padnum(p->run_ticks, 5);      printf(" ");
    padnum(p->ready_ticks, 5);    printf(" ");
    padnum(p->sleep_ticks, 5);    printf(" ");
    padnum(p->ctxsw_count, 4);    printf(" ");
    padnum(p->lifetime, 4);       printf(" ");
    padnum((long)(p->mem_quota / 1024), 6);   printf(" ");  // quota in KB
    padnum((long)p->swapout_count, 3); printf(" ");
    padnum((long)p->swapin_count, 3);  printf(" ");
    padnum((long)p->quota_denied_count, 3);
    printf("\n");
  }
  exit(0);
}
