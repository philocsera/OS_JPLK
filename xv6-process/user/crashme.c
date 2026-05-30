// crashme — generate a plausible incident, then panic, so the kernel emits a
// @@PANIC post-mortem timeline (report sec 07) for the host LLM to explain.
//
// Story it leaves in the event ring:
//   NOTE  "build: pipeline start"
//   EXIT  a short child finished
//   FORKFAIL x N  a runaway fork bomb kept hitting the per-job cap
//   NOTE  "fork rate exploding"
//   panic "oom: kalloc returned 0"
//
// tools/diagnose.py feeds this timeline to a local LLM, which turns the
// register/event soup into a natural-language root-cause guess.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int
main(void)
{
  note("build: pipeline start");

  // A short-lived child -> leaves an EXIT event in the ring.
  int c = fork();
  if(c == 0)
    exit(0);
  wait(0);

  // Become a new job, then over-fork: the kernel's per-job cap (sec 06)
  // rejects the excess, logging FORKFAIL events — a runaway-tree signature.
  setjob();
  for(int i = 0; i < 25; i++){
    int pid = fork();
    if(pid == 0){
      pause(500);   // parked; irrelevant once we panic
      exit(0);
    }
  }

  note("fork rate exploding");
  crash("oom: kalloc returned 0");   // panic -> dumps the timeline
  exit(0);                            // unreached
}
