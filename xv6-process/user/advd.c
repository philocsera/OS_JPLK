// advd — guest-side advisor daemon for the DEDICATED virtio-console channel
// (report Plan A). Replaces the console-shared wlagent/setcls plumbing: the
// whole LLM-advisor protocol now runs over /advisor instead of the UART, so it
// never interleaves with the human shell.
//
//   guest -> host : @@WL [...] procstat frames   (writer child)
//   host  -> guest: setcls / setjprio command lines, applied via syscalls,
//                   each answered with a one-line @@OK/@@ERR ack (reader parent)
//
// Both directions share one fd on /advisor. fork() splits the work: the child
// periodically emits frames; the parent blocks reading command lines. Each
// frame and each ack is built in a buffer and emitted with a SINGLE write() so
// it stays atomic — the kernel serialises a whole write() under one lock, and
// user printf() writes byte-at-a-time (which would interleave the two writers).
//
//   advd [poll_ticks]      (default 5)

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/procstat.h"
#include "kernel/fcntl.h"
#include "user/user.h"

#define POLL_TICKS 5

static struct procstat ps[PROCSTAT_MAX];
static char obuf[8192];   // frame/ack staging buffer (single-write atomicity)

// --- tiny buffer formatting (we must not printf to the channel) ----------
static int
put_str(char *b, int p, const char *s)
{
  while(*s)
    b[p++] = *s++;
  return p;
}

static int
put_int(char *b, int p, long v)
{
  char tmp[24];
  int i = 0, neg = 0;
  unsigned long u;
  if(v < 0){ neg = 1; u = (unsigned long)(-v); }
  else u = (unsigned long)v;
  if(u == 0)
    tmp[i++] = '0';
  while(u){ tmp[i++] = '0' + (u % 10); u /= 10; }
  if(neg)
    b[p++] = '-';
  while(i > 0)
    b[p++] = tmp[--i];
  return p;
}

static int
class_to_priority(int cls)
{
  switch(cls){
  case CLASS_INTERACTIVE: return 4;
  case CLASS_IO_BOUND:    return 8;
  case CLASS_NORMAL:      return 10;
  case CLASS_CPU_BOUND:   return 12;
  case CLASS_BATCH:       return 15;
  case CLASS_SYSTEM:      return 6;
  default:                return 10;
  }
}

// --- guest -> host: emit one procstat frame -------------------------------
static void
emit_frame(int afd)
{
  int n = getprocstat_all(ps, PROCSTAT_MAX);
  if(n < 0)
    return;

  int p = 0;
  p = put_str(obuf, p, "@@WL [");
  int first = 1;
  for(int i = 0; i < n; i++){
    struct procstat *s = &ps[i];
    if(s->pid <= 2)                       // init + shell
      continue;
    if(s->name[0]=='a'&&s->name[1]=='d'&&s->name[2]=='v'&&s->name[3]=='d'&&
       s->name[4]==0)                     // skip both advd processes
      continue;
    if(s->state == PS_UNUSED || s->state == PS_ZOMBIE)
      continue;
    // Reserve room for one worst-case record (fixed keys + 16B name + six
    // numbers, < ~224B) plus the closing "]\n" BEFORE appending, so a full
    // table with large tick counters can never overflow obuf. If it won't
    // fit, stop early — the frame stays valid JSON (still closed below).
    if(p > (int)sizeof(obuf) - 256)
      break;
    if(!first)
      obuf[p++] = ',';
    first = 0;
    p = put_str(obuf, p, "{\"pid\":");        p = put_int(obuf, p, s->pid);
    p = put_str(obuf, p, ",\"name\":\"");      p = put_str(obuf, p, s->name);
    p = put_str(obuf, p, "\",\"run\":");       p = put_int(obuf, p, s->run_ticks);
    p = put_str(obuf, p, ",\"sleep\":");       p = put_int(obuf, p, s->sleep_ticks);
    p = put_str(obuf, p, ",\"ready\":");       p = put_int(obuf, p, s->ready_ticks);
    p = put_str(obuf, p, ",\"life\":");        p = put_int(obuf, p, s->lifetime);
    p = put_str(obuf, p, ",\"class\":");       p = put_int(obuf, p, s->class_id);
    p = put_str(obuf, p, ",\"group\":");       p = put_int(obuf, p, s->group_id);
    obuf[p++] = '}';
  }
  obuf[p++] = ']';
  obuf[p++] = '\n';
  write(afd, obuf, p);
}

// --- host -> guest: parse + apply one command line ------------------------
// supported:  setcls <pid> <class>     setjprio <group> <prio>
static void
apply_cmd(int afd, char *line)
{
  char *argv[4];
  int argc = 0;
  char *s = line;
  while(*s && argc < 4){
    while(*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n')
      *s++ = 0;
    if(!*s)
      break;
    argv[argc++] = s;
    while(*s && *s != ' ' && *s != '\t' && *s != '\r' && *s != '\n')
      s++;
  }
  if(argc == 0)
    return;

  int p = 0;
  if(strcmp(argv[0], "setcls") == 0 && argc == 3){
    int pid = atoi(argv[1]), cls = atoi(argv[2]);
    if(setclass(pid, cls) < 0){
      p = put_str(obuf, p, "@@ERR setcls pid="); p = put_int(obuf, p, pid);
      p = put_str(obuf, p, " cls=");             p = put_int(obuf, p, cls);
      obuf[p++] = '\n';
    } else {
      int prio = class_to_priority(cls);
      setpriority(pid, prio);
      p = put_str(obuf, p, "@@OK setcls pid=");  p = put_int(obuf, p, pid);
      p = put_str(obuf, p, " cls=");             p = put_int(obuf, p, cls);
      p = put_str(obuf, p, " prio=");            p = put_int(obuf, p, prio);
      obuf[p++] = '\n';
    }
  } else if(strcmp(argv[0], "setjprio") == 0 && argc == 3){
    int gid = atoi(argv[1]), prio = atoi(argv[2]);
    int n = setjobpriority(gid, prio);
    if(n < 0){
      p = put_str(obuf, p, "@@ERR setjprio group="); p = put_int(obuf, p, gid);
      p = put_str(obuf, p, " prio=");                p = put_int(obuf, p, prio);
      obuf[p++] = '\n';
    } else {
      p = put_str(obuf, p, "@@OK setjprio group="); p = put_int(obuf, p, gid);
      p = put_str(obuf, p, " prio=");               p = put_int(obuf, p, prio);
      p = put_str(obuf, p, " procs=");              p = put_int(obuf, p, n);
      obuf[p++] = '\n';
    }
  } else {
    p = put_str(obuf, p, "@@ERR unknown cmd\n");
  }
  if(p > 0)
    write(afd, obuf, p);
}

int
main(int argc, char *argv[])
{
  int poll = POLL_TICKS;
  if(argc > 1)
    poll = atoi(argv[1]);
  if(poll < 1)
    poll = 1;

  int afd = open("advisor", O_RDWR);
  if(afd < 0){
    printf("advd: cannot open /advisor (mknod missing?)\n");
    exit(1);
  }

  int pid = fork();
  if(pid < 0){
    printf("advd: fork failed\n");
    exit(1);
  }

  if(pid == 0){
    // writer: emit a procstat frame every poll ticks, forever.
    for(;;){
      emit_frame(afd);
      pause(poll);
    }
    // unreachable
  }

  // reader: block on command lines from the host, apply each. A line-at-a-time
  // device read returns one '\n'-terminated command per read().
  char line[256];
  for(;;){
    int n = read(afd, line, sizeof(line) - 1);
    if(n <= 0){
      // host channel closed; keep the writer alive, stop reading.
      break;
    }
    line[n] = 0;
    apply_cmd(afd, line);
  }

  // if we ever fall out of the read loop, let the writer run on.
  wait(0);
  close(afd);
  exit(0);
}
