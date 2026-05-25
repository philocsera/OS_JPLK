// workloadagent — periodic workload reporter + LLM-driven policy switcher.
//
// Output format (parsed by bridge.py):
//   <<WORKLOAD>>
//   process_count: N
//   processes:
//     pid  name  state  priority  run_ticks  sleep_ticks
//     ...
//   <<WORKLOAD_END>>
//
// Expected reply (one of):
//   <<POLICY>> <0-3>   # 0=balanced 1=throughput 2=interactive 3=background
//   <<NOOP>>           # bridge declined to act
//
// Startup: fork() so the parent exits (returns sh prompt) while the child
// runs as a background daemon. The child loops indefinitely:
//   proclist → emit snapshot → read policy reply → setpolicy → pause → repeat
//
// Manual test (no bridge): run workloadagent, then type "<<POLICY>> 1" on stdin.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

#define MAX_PROCS   64
#define LINEBUF     256
#define POLL_TICKS  100   // ~1 s between polls (timer fires ~100×/s in xv6)

static const char *state_name(int s) {
  switch(s) {
  case 0: return "UNUSED";
  case 1: return "USED";
  case 2: return "SLEEP";
  case 3: return "RUNBL";
  case 4: return "RUN";
  case 5: return "ZOMB";
  default: return "?";
  }
}

static const char *policy_name(int p) {
  switch(p) {
  case 0: return "balanced";
  case 1: return "throughput";
  case 2: return "interactive";
  case 3: return "background";
  default: return "?";
  }
}

// Skip leading whitespace, then parse a non-negative decimal integer.
// Returns -1 if no digit found.
static int parse_int(char *p) {
  while(*p == ' ' || *p == '\t') p++;
  if(*p < '0' || *p > '9') return -1;
  int v = 0;
  while(*p >= '0' && *p <= '9') {
    v = v * 10 + (*p - '0');
    p++;
  }
  return v;
}

static void run_loop(void) {
  static struct proc_info procs[MAX_PROCS];
  char line[LINEBUF];

  for(;;) {
    int n = proclist(procs, MAX_PROCS);
    if(n < 0) {
      fprintf(2, "workloadagent: proclist failed\n");
      pause(POLL_TICKS);
      continue;
    }

    printf("<<WORKLOAD>>\n");
    printf("process_count: %d\n", n);
    printf("processes:\n");
    for(int i = 0; i < n; i++) {
      printf("  %d %s %s %d %ld %ld\n",
             procs[i].pid,
             procs[i].name,
             state_name(procs[i].state),
             procs[i].priority,
             (long)procs[i].run_ticks,
             (long)procs[i].sleep_ticks);
    }
    printf("<<WORKLOAD_END>>\n");

    if(gets(line, LINEBUF) == 0) {
      fprintf(2, "workloadagent: stdin closed\n");
      exit(0);
    }
    int len = strlen(line);
    while(len > 0 && (line[len-1] == '\n' || line[len-1] == '\r'))
      line[--len] = 0;

    if(strcmp(line, "<<NOOP>>") == 0) {
      pause(POLL_TICKS);
      continue;
    }

    // Expect "<<POLICY>> <0-3>"
    if(memcmp(line, "<<POLICY>>", 10) != 0) {
      fprintf(2, "workloadagent: unexpected reply: %s\n", line);
      pause(POLL_TICKS);
      continue;
    }

    int new_pol = parse_int(line + 10);
    if(new_pol < 0 || new_pol > 3) {
      fprintf(2, "workloadagent: bad policy id in: %s\n", line);
      pause(POLL_TICKS);
      continue;
    }

    int old_pol = getpolicy();
    if(setpolicy(new_pol) < 0) {
      fprintf(2, "workloadagent: setpolicy(%d) failed\n", new_pol);
    } else if(new_pol != old_pol) {
      printf("workloadagent: policy %s -> %s\n",
             policy_name(old_pol), policy_name(new_pol));
    }

    pause(POLL_TICKS);
  }
}

int main(void) {
  // Fork so the parent returns the sh prompt while the child loops.
  int pid = fork();
  if(pid < 0) {
    fprintf(2, "workloadagent: fork failed\n");
    exit(1);
  }
  if(pid > 0) {
    // Parent: print the child pid so the user knows it's running, then exit.
    printf("workloadagent: started (pid %d)\n", pid);
    exit(0);
  }

  // Child: run indefinitely.
  run_loop();
  exit(0);
}
