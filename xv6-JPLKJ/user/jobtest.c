// jobtest — verify job/process-tree grouping (report sec 05).
//
// Models a sh -> make -> cc tree as a chain of fork()s and checks:
//   1. group_id propagates down a fork tree.
//   2. setjob() starts a fresh job; a process forked BEFORE setjob (the
//      "outsider") keeps the old group and is therefore not part of the job.
//   3. setjobpriority() retags the WHOLE job in one call, and leaves the
//      outsider untouched — the "apply policy to the whole team" feature.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/procstat.h"
#include "user/user.h"

static int fails = 0;

#define CHECK(cond, msg) do { \
  if(cond){ printf("  ok   - %s\n", msg); } \
  else    { printf("  FAIL - %s\n", msg); fails++; } } while(0)

// Block on an empty pipe forever (until killed). Used to keep helper
// processes alive and inspectable.
static void
park(int rfd)
{
  char c;
  for(;;) read(rfd, &c, 1);
}

int
main(void)
{
  // A pipe the helpers park on (never written), and one they report pids on.
  int parkfd[2], rep[2];
  pipe(parkfd);
  pipe(rep);

  printf("=== jobtest: process-tree grouping ===\n");

  // (a) Outsider: forked BEFORE setjob, so it stays in the original job.
  int outsider = fork();
  if(outsider == 0) {
    close(rep[0]);
    int me = getpid();
    write(rep[1], &me, sizeof(me));
    park(parkfd[0]);
    exit(0);
  }

  // (b) Become a new job leader. From here, descendants share this group.
  int G = setjob();
  printf("[leader] pid=%d started job group=%d\n", getpid(), G);

  // (c) child -> grandchild chain, both inside job G.
  int child = fork();
  if(child == 0) {
    int gc = fork();
    if(gc == 0) {
      close(rep[0]);
      int me = getpid();
      write(rep[1], &me, sizeof(me));
      park(parkfd[0]);
      exit(0);
    }
    close(rep[0]);
    int me = getpid();
    write(rep[1], &me, sizeof(me));
    park(parkfd[0]);
    exit(0);
  }

  // Collect the three helper pids (order doesn't matter for the checks).
  close(rep[1]);
  int pids[3];
  for(int i = 0; i < 3; i++)
    read(rep[0], &pids[i], sizeof(pids[i]));

  // 1 & 2: group membership.
  printf("[1] group propagation\n");
  CHECK(getjob(child) == G, "child inherits leader's group");
  // grandchild is whichever helper pid is not the child and not the outsider
  int grandchild = -1;
  for(int i = 0; i < 3; i++)
    if(pids[i] != child && pids[i] != outsider)
      grandchild = pids[i];
  CHECK(grandchild > 0 && getjob(grandchild) == G,
        "grandchild inherits the same group");
  CHECK(getjob(outsider) != G, "outsider is NOT in the job");

  // 3: whole-job policy in one call.
  printf("[2] whole-job policy application\n");
  int before_out;
  struct procstat ps;
  getprocstat(outsider, &ps);
  before_out = ps.priority;

  int n = setjobpriority(G, 7);
  printf("      setjobpriority(%d, 7) retagged %d procs\n", G, n);
  CHECK(n >= 3, "at least leader+child+grandchild retagged");

  getprocstat(child, &ps);
  CHECK(ps.priority == 7, "child priority is now 7");
  getprocstat(grandchild, &ps);
  CHECK(ps.priority == 7, "grandchild priority is now 7");
  getprocstat(getpid(), &ps);
  CHECK(ps.priority == 7, "leader priority is now 7");
  getprocstat(outsider, &ps);
  CHECK(ps.priority == before_out, "outsider priority unchanged");

  // 4: whole-job class application (and quantum follows class).
  printf("[3] whole-job class application\n");
  setjobclass(G, CLASS_BATCH);
  getprocstat(grandchild, &ps);
  CHECK(ps.class_id == CLASS_BATCH && ps.quantum_ticks == 8,
        "grandchild -> BATCH with quantum 8");
  getprocstat(outsider, &ps);
  CHECK(ps.class_id != CLASS_BATCH, "outsider class unchanged");

  // cleanup: killing closes their park; reap.
  kill(child); kill(grandchild); kill(outsider);
  wait(0); wait(0); wait(0);

  printf("=== jobtest: %s (%d failures) ===\n",
         fails == 0 ? "ALL PASSED" : "FAILURES", fails);
  exit(fails == 0 ? 0 : 1);
}
