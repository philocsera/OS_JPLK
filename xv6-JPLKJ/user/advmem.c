// advmem.c — Level 2 cross-control: the scheduling advisor REACTS to memory
// pressure. (discuss.md §3, scenario (a): demote a thrashing process.)
//
// The bridge between the two subsystems is the Level-1 observability fields
// now carried in struct procstat: swapout_count / swapin_count. The memory
// subsystem (swapctl / memhint / a quota policy) decides to push a process's
// pages out to the swap disk; advmem watches those counters and, when a
// process has OUTSTANDING swapped pages (swapout_count > swapin_count, i.e.
// it is currently resident-starved / paging), it DEMOTES that process in the
// CPU scheduler: priority -> low (large number) and class -> BATCH. The point
// is global-optimal behavior: stop giving CPU to a process that is stuck
// paging, so processes that actually fit in RAM make progress.
//
// To avoid the starvation that discuss.md warns about, the demotion is
// REVERSIBLE: once the process has paged everything back in (outstanding == 0)
// advmem RESTORES its original priority/class. So the controller forms a
// stable feedback loop, not a one-way ratchet.
//
//   memory side:   swapout(pid)  -->  p->swapout_count++
//        (Level-1 procstat exposes swapout_count/swapin_count)
//   scheduler side: advmem sees outstanding>0  -->  setpriority+setclass demote
//                   advmem sees outstanding==0 -->  restore
//
// usage:
//   advmem [poll_ticks]   run as a daemon, polling every poll_ticks (default 20)
//   advmem scan           do exactly one pass, print actions, and exit (for tests)

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/procstat.h"
#include "user/user.h"

#define MAX_PROCS PROCSTAT_MAX
// Hysteresis band: demote when outstanding swapped pages reach DEMOTE_HIGH,
// restore only once they fall back to DEMOTE_LOW. A gap between the two avoids
// flapping, and a non-zero LOW tolerates the reality that swapout may evict a
// page the workload never re-touches (so outstanding rarely returns to exactly
// 0) — pressure is "relieved" once almost everything is paged back in.
#define DEMOTE_HIGH   4     // outstanding swapped pages that count as "pressure"
#define DEMOTE_LOW    1     // outstanding at/below which pressure is "relieved"
#define DEMOTE_PRIO   18    // demoted scheduling priority (near lowest)
#define POLL_DEFAULT  20

// Per-pid controller state. pid is small (< NPROC) so index by pid directly.
static int   demoted[MAX_PROCS + 1];     // 1 if we have demoted this pid
static int   saved_prio[MAX_PROCS + 1];  // original priority to restore
static int   saved_class[MAX_PROCS + 1]; // original class to restore

static const char *
class_name(int c)
{
  switch(c){
  case CLASS_INTERACTIVE: return "INTERACTIVE";
  case CLASS_IO_BOUND:    return "IO_BOUND";
  case CLASS_NORMAL:      return "NORMAL";
  case CLASS_CPU_BOUND:   return "CPU_BOUND";
  case CLASS_BATCH:       return "BATCH";
  case CLASS_SYSTEM:      return "SYSTEM";
  default:                return "?";
  }
}

// One control pass over the live process table. Returns the number of
// demote/restore actions taken.
static int
control_pass(struct procstat *buf, int my_pid)
{
  int n = getprocstat_all(buf, MAX_PROCS);
  if(n < 0){
    printf("advmem: getprocstat_all failed\n");
    return -1;
  }

  int actions = 0;
  for(int i = 0; i < n; i++){
    struct procstat *ps = &buf[i];
    if(ps->pid == my_pid)   continue;   // never touch ourselves
    if(ps->pid <= 2)        continue;   // init / shell are protected
    if(ps->pid > MAX_PROCS) continue;

    // outstanding = pages currently parked on the swap disk for this proc.
    uint64 outstanding = (ps->swapout_count > ps->swapin_count)
                         ? (ps->swapout_count - ps->swapin_count) : 0;

    if(outstanding >= DEMOTE_HIGH && !demoted[ps->pid]){
      // memory pressure detected -> demote in the CPU scheduler.
      saved_prio[ps->pid]  = ps->priority;
      saved_class[ps->pid] = ps->class_id;
      if(setpriority(ps->pid, DEMOTE_PRIO) == 0 &&
         setclass(ps->pid, CLASS_BATCH) == 0){
        demoted[ps->pid] = 1;
        actions++;
        printf("[advmem] DEMOTE pid=%d name=%s outstanding=%d "
               "prio %d->%d class %s->BATCH\n",
               ps->pid, ps->name, (int)outstanding,
               saved_prio[ps->pid], DEMOTE_PRIO,
               class_name(saved_class[ps->pid]));
      }
    } else if(outstanding <= DEMOTE_LOW && demoted[ps->pid]){
      // pressure cleared (paged back in) -> restore original scheduling.
      setpriority(ps->pid, saved_prio[ps->pid]);
      setclass(ps->pid, saved_class[ps->pid]);
      demoted[ps->pid] = 0;
      actions++;
      printf("[advmem] RESTORE pid=%d name=%s prio %d->%d class BATCH->%s\n",
             ps->pid, ps->name, DEMOTE_PRIO, saved_prio[ps->pid],
             class_name(saved_class[ps->pid]));
    }
  }
  return actions;
}

int
main(int argc, char *argv[])
{
  static struct procstat buf[MAX_PROCS];   // must be static (1-page stack)
  int my_pid = getpid();

  if(argc > 1 && strcmp(argv[1], "scan") == 0){
    printf("advmem: single scan (pid=%d)\n", my_pid);
    control_pass(buf, my_pid);
    exit(0);
  }

  int poll = POLL_DEFAULT;
  if(argc > 1)
    poll = atoi(argv[1]);
  if(poll <= 0)
    poll = POLL_DEFAULT;

  printf("advmem: starting cross-control daemon (pid=%d, poll=%d ticks, "
         "demote>=%d restore<=%d pages)\n", my_pid, poll, DEMOTE_HIGH, DEMOTE_LOW);

  for(;;){
    control_pass(buf, my_pid);
    pause(poll);
  }
  return 0;
}
