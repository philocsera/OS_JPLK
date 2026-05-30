// setcls — apply a classification decision to a process (LLM-bridge executor).
//
//   setcls <pid> <class_id>
//
// The host bridge (tools/bridge.py) types this into the shell to apply the
// LLM's decision. It is the return path of the host bridge: the LLM advises,
// this commits the advice through the existing setclass syscall, and also
// nudges priority to match the class (mirroring advisord's class->priority).
// The kernel range-checks setclass, so a bad class is simply rejected.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/procstat.h"
#include "user/user.h"

static int
class_to_priority(int class_id)
{
  switch(class_id) {
  case CLASS_INTERACTIVE: return 4;
  case CLASS_IO_BOUND:    return 8;
  case CLASS_NORMAL:      return 10;
  case CLASS_CPU_BOUND:   return 12;
  case CLASS_BATCH:       return 15;
  case CLASS_SYSTEM:      return 6;
  default:                return 10;
  }
}

int
main(int argc, char *argv[])
{
  if(argc != 3) {
    printf("usage: setcls <pid> <class_id 0..5>\n");
    exit(1);
  }
  int pid = atoi(argv[1]);
  int cls = atoi(argv[2]);

  if(setclass(pid, cls) < 0) {
    printf("setcls: setclass(%d,%d) failed\n", pid, cls);
    exit(1);
  }
  setpriority(pid, class_to_priority(cls));
  printf("setcls: pid %d -> class %d (prio %d)\n", pid, cls, class_to_priority(cls));
  exit(0);
}
