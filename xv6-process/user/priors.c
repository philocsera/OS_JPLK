// priors — inspect / persist the kernel's exit-statistics learning table
// (report sec 04). Uses only the plain %d/%s/%ld conversions that xv6's
// minimal printf actually supports.
//
//   priors                  dump the live table
//   priors save [path]      write the table to a file (default /priors.db)
//   priors load [path]      read a file back into the kernel table
//
// The kernel table is reboot-volatile; `priors save` before reboot + a
// `priors load` at boot (init runs it) makes learned classes survive reboots.
// File format: int count, then count * struct nameprior (raw). Self-describing
// enough for this single-host demo; not a portable on-disk format.

#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/fcntl.h"
#include "kernel/procstat.h"
#include "user/user.h"

#define DEFAULT_PATH "/priors.db"

static const char *
class_name(int c)
{
  switch(c) {
  case CLASS_INTERACTIVE: return "INTERACTIVE";
  case CLASS_IO_BOUND:    return "IO_BOUND";
  case CLASS_NORMAL:      return "NORMAL";
  case CLASS_CPU_BOUND:   return "CPU_BOUND";
  case CLASS_BATCH:       return "BATCH";
  case CLASS_SYSTEM:      return "SYSTEM";
  default:                return "?";
  }
}

// Read exactly n bytes, looping over short reads. Returns 0 on success, -1 on
// EOF-before-n or error.
static int
read_full(int fd, void *dst, int n)
{
  char *p = dst;
  while(n > 0) {
    int r = read(fd, p, n);
    if(r <= 0)
      return -1;
    p += r;
    n -= r;
  }
  return 0;
}

// Write exactly n bytes, looping over short writes. Returns 0 on success.
static int
write_full(int fd, const void *src, int n)
{
  const char *p = src;
  while(n > 0) {
    int w = write(fd, p, n);
    if(w <= 0)
      return -1;
    p += w;
    n -= w;
  }
  return 0;
}

static int
cmd_dump(void)
{
  struct nameprior buf[NPRIOR];
  int n = getnamepriors(buf, NPRIOR);
  if(n < 0) {
    printf("priors: getnamepriors failed\n");
    return 1;
  }
  printf("learned priors: %d entries\n", n);
  printf("name / class / samples / avg_run / avg_sleep\n");
  for(int i = 0; i < n; i++) {
    struct nameprior *e = &buf[i];
    printf("  %s -> %s  samples=%ld run=%ld sleep=%ld\n",
           e->name, class_name(e->class_id),
           e->samples, e->avg_run, e->avg_sleep);
  }
  return 0;
}

static int
cmd_save(const char *path)
{
  struct nameprior buf[NPRIOR];
  int n = getnamepriors(buf, NPRIOR);
  if(n < 0) {
    printf("priors: getnamepriors failed\n");
    return 1;
  }
  int fd = open(path, O_CREATE | O_WRONLY | O_TRUNC);
  if(fd < 0) {
    printf("priors: cannot open %s for write\n", path);
    return 1;
  }
  if(write_full(fd, &n, sizeof(n)) < 0 ||
     (n > 0 && write_full(fd, buf, n * sizeof(struct nameprior)) < 0)) {
    printf("priors: write to %s failed\n", path);
    close(fd);
    return 1;
  }
  close(fd);
  printf("priors: saved %d entries to %s\n", n, path);
  return 0;
}

static int
cmd_load(const char *path)
{
  int fd = open(path, O_RDONLY);
  if(fd < 0)
    return 0;                 // no saved table yet (e.g. first boot) — fine
  int n = 0;
  if(read_full(fd, &n, sizeof(n)) < 0 || n <= 0) {
    close(fd);                // empty/garbage header — treat as nothing saved
    return 0;
  }
  if(n > NPRIOR)
    n = NPRIOR;
  struct nameprior buf[NPRIOR];
  if(read_full(fd, buf, n * sizeof(struct nameprior)) < 0) {
    close(fd);
    printf("priors: %s truncated, skipping\n", path);
    return 1;
  }
  close(fd);
  int got = setnamepriors(buf, n);
  printf("priors: loaded %d entries from %s\n", got, path);
  return 0;
}

int
main(int argc, char *argv[])
{
  if(argc >= 2 && strcmp(argv[1], "save") == 0)
    exit(cmd_save(argc >= 3 ? argv[2] : DEFAULT_PATH));
  if(argc >= 2 && strcmp(argv[1], "load") == 0)
    exit(cmd_load(argc >= 3 ? argv[2] : DEFAULT_PATH));
  if(argc >= 2) {
    printf("usage: priors [save|load] [path]\n");
    exit(1);
  }
  exit(cmd_dump());
}
