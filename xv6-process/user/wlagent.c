// wlagent — guest side of the LLM host-bridge (report sec 04/01, option-a).
//
// Runs as a background daemon. Every POLL ticks it snapshots the procstat
// table and emits ONE line to the console framed as:
//
//   @@WL [{"pid":5,"name":"spin","run":40,"sleep":0,"ready":2,"life":42,"class":2,"group":5}, ...]
//
// A host process (tools/bridge.py) reads these frames over QEMU's stdio,
// asks a local open LLM to classify each process, and writes the decision
// back by typing `setcls <pid> <class>` into the shell. The kernel never
// knows an LLM is involved — wlagent only EXPORTS data; classification is
// applied through the existing setclass syscall via the setcls helper.
//
// Buffer is static (BSS), not on the stack: a procstat[64] array is ~5KB
// and the xv6 user stack is a single 4KB page.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/procstat.h"
#include "user/user.h"

#define POLL_TICKS 5      // ~500ms at xv6's ~100ms tick

static struct procstat buf[PROCSTAT_MAX];

int
main(int argc, char *argv[])
{
  int me = getpid();
  int poll = POLL_TICKS;
  if(argc > 1)
    poll = atoi(argv[1]);
  if(poll < 1)
    poll = 1;

  for(;;) {
    int n = getprocstat_all(buf, PROCSTAT_MAX);
    if(n < 0) {
      printf("@@WL_ERR getprocstat_all failed\n");
      exit(1);
    }

    printf("@@WL [");
    int first = 1;
    for(int i = 0; i < n; i++) {
      struct procstat *p = &buf[i];
      // Skip init/shell, the agent itself, and dead/empty slots.
      if(p->pid <= 2 || p->pid == me)
        continue;
      if(p->state == PS_UNUSED || p->state == PS_ZOMBIE)
        continue;
      if(!first)
        printf(",");
      first = 0;
      printf("{\"pid\":%d,\"name\":\"%s\",\"run\":%ld,\"sleep\":%ld,"
             "\"ready\":%ld,\"life\":%ld,\"class\":%d,\"group\":%d}",
             p->pid, p->name, p->run_ticks, p->sleep_ticks,
             p->ready_ticks, p->lifetime, p->class_id, p->group_id);
    }
    printf("]\n");

    pause(poll);
  }
  return 0;
}
