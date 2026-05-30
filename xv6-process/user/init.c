// init: The initial user-level program

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/spinlock.h"
#include "kernel/sleeplock.h"
#include "kernel/fs.h"
#include "kernel/file.h"
#include "user/user.h"
#include "kernel/fcntl.h"

char *argv[] = { "sh", 0 };

int
main(void)
{
  int pid, wpid;

  if(open("console", O_RDWR) < 0){
    mknod("console", CONSOLE, 0);
    open("console", O_RDWR);
  }
  dup(0);  // stdout
  dup(0);  // stderr

  // Create the dedicated advisor channel device node (report Plan A). advd
  // opens /advisor to talk to the host bridge over virtio-console instead of
  // the shared UART. mknod is a no-op (returns -1, ignored) if the node was
  // already persisted on the disk image, so this never wedges boot.
  mknod("advisor", ADVISOR, 0);

  // Restore scheduler priors learned before the last reboot (report sec 04).
  // Best-effort: a missing/corrupt /priors.db is a silent no-op in `priors
  // load`, so this can never wedge boot. Wait for it so the table is in place
  // before sh (and any workload) starts.
  if((pid = fork()) == 0){
    char *av[] = { "priors", "load", "/priors.db", 0 };
    exec("priors", av);
    exit(0);   // priors binary missing — continue booting regardless
  }
  if(pid > 0)
    wait((int *) 0);

  for(;;){
    printf("init: starting sh\n");
    pid = fork();
    if(pid < 0){
      printf("init: fork failed\n");
      exit(1);
    }
    if(pid == 0){
      exec("sh", argv);
      printf("init: exec sh failed\n");
      exit(1);
    }

    for(;;){
      // this call to wait() returns if the shell exits,
      // or if a parentless process exits.
      wpid = wait((int *) 0);
      if(wpid == pid){
        // the shell exited; restart it.
        break;
      } else if(wpid < 0){
        printf("init: wait returned an error\n");
        exit(1);
      } else {
        // it was a parentless process; do nothing.
      }
    }
  }
}
