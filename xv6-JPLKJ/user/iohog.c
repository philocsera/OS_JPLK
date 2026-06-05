// iohog — a sleep/IO-dominated workload for the multi-workload LLM demo.
//
// Blocks forever on an empty pipe (write end held open, never written), so it
// sits in SLEEPING on a non-timer channel and accrues sleep_ticks. The advisor
// should see sleep >> run and classify it IO_BOUND.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int
main(void)
{
  int p[2];
  if(pipe(p) < 0){
    printf("iohog: pipe failed\n");
    exit(1);
  }
  char c;
  // No one ever writes p[1]; read() blocks (SLEEPING) indefinitely.
  read(p[0], &c, 1);
  exit(0);
}
