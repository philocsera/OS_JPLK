#include "types.h"
#include "riscv.h"
#include "defs.h"
#include "param.h"
#include "memlayout.h"
#include "spinlock.h"
#include "proc.h"
#include "procstat.h"
#include "vm.h"
#include "memstat.h"
#include "swapstat.h"

extern struct proc proc[];

uint64
sys_exit(void)
{
  int n;
  argint(0, &n);
  kexit(n);
  return 0;  // not reached
}

uint64
sys_getpid(void)
{
  return myproc()->pid;
}

uint64
sys_fork(void)
{
  return kfork();
}

uint64
sys_wait(void)
{
  uint64 p;
  argaddr(0, &p);
  return kwait(p);
}

uint64
sys_sbrk(void)
{
  uint64 addr;
  int t;
  int n;

  argint(0, &n);
  argint(1, &t);
  addr = myproc()->sz;

  if(t == SBRK_EAGER || n < 0) {
    if(growproc(n) < 0) {
      return -1;
    }
  } else {
    // Lazily allocate memory for this process: increase its memory
    // size but don't allocate memory. If the processes uses the
    // memory, vmfault() will allocate it.
    if(addr + n < addr)
      return -1;
    if(addr + n > TRAPFRAME)
      return -1;
    myproc()->sz += n;
  }
  return addr;
}

uint64
sys_pause(void)
{
  int n;
  uint ticks0;

  argint(0, &n);
  if(n < 0)
    n = 0;
  acquire(&tickslock);
  ticks0 = ticks;
  while(ticks - ticks0 < n){
    if(killed(myproc())){
      release(&tickslock);
      return -1;
    }
    sleep(&ticks, &tickslock);
  }
  release(&tickslock);
  return 0;
}

uint64
sys_kill(void)
{
  int pid;

  argint(0, &pid);
  return kkill(pid);
}

uint64
sys_setpriority(void)
{
  int pid, priority;

  argint(0, &pid);
  argint(1, &priority);

  // Validate priority range [0, 20]
  if(priority < 0 || priority > 20)
    return -1;

  // Find the process with the given pid and set its priority
  struct proc *p;
  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->pid == pid) {
      p->priority = priority;
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
  }
  return -1;  // pid not found
}

uint64
sys_getpriority(void)
{
  int pid;

  argint(0, &pid);

  // Find the process with the given pid and return its priority
  struct proc *p;
  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->pid == pid) {
      int prio = p->priority;
      release(&p->lock);
      return prio;
    }
    release(&p->lock);
  }
  return -1;  // pid not found
}

// ---------------------------------------------------------------------------
// LLM advisor syscalls. See report/week10/조현성/process.md.
//
// The kernel never calls the LLM; these syscalls are the *interface*
// that a userspace advisord uses to read procstat and write back
// policy state (class / quantum / priority). All five together form
// the "read snapshot, classify, write classification" loop sketched
// in process.md §3.
// ---------------------------------------------------------------------------

uint64
sys_setclass(void)
{
  int pid, class_id;
  argint(0, &pid);
  argint(1, &class_id);
  return proc_setclass(pid, class_id);
}

uint64
sys_setquantum(void)
{
  int pid, q;
  argint(0, &pid);
  argint(1, &q);
  return proc_setquantum(pid, q);
}

uint64
sys_getprocstat(void)
{
  int pid;
  uint64 uaddr;
  struct procstat ps;

  argint(0, &pid);
  argaddr(1, &uaddr);

  if(procstat_get(pid, &ps) < 0)
    return -1;
  if(copyout(myproc()->pagetable, uaddr, (char *)&ps, sizeof(ps)) < 0)
    return -1;
  return 0;
}

// Kernel stack is 2*PGSIZE = 8KB. struct procstat is ~80 bytes, so a full
// PROCSTAT_MAX (=64) buffer would consume ~5KB on stack — too close to the
// limit once trap frames and call chains are accounted for. Instead we
// scan proc[] in fixed-size chunks and copyout each chunk separately.
#define PROCSTAT_CHUNK 8

uint64
sys_getprocstat_all(void)
{
  uint64 uaddr;
  int max;
  struct procstat buf[PROCSTAT_CHUNK];
  int written = 0;

  argaddr(0, &uaddr);
  argint(1, &max);

  if(max <= 0)
    return -1;
  if(max > PROCSTAT_MAX)
    max = PROCSTAT_MAX;

  pagetable_t pt = myproc()->pagetable;

  for(int start = 0; start < NPROC && written < max; start += PROCSTAT_CHUNK) {
    int end = start + PROCSTAT_CHUNK;
    int remaining = max - written;
    int cap = remaining < PROCSTAT_CHUNK ? remaining : PROCSTAT_CHUNK;

    int n = procstat_all_range(start, end, buf, cap);
    if(n <= 0)
      continue;

    if(copyout(pt, uaddr + (uint64)written * sizeof(struct procstat),
               (char *)buf, n * sizeof(struct procstat)) < 0)
      return -1;
    written += n;
  }
  return written;
}

// Copy the exit-statistics prior table into a user buffer. Returns the
// number of valid entries. NPRIOR is small (16) so the whole table fits on
// the kernel stack in one shot — no chunking needed.
uint64
sys_getnamepriors(void)
{
  uint64 uaddr;
  int max;
  struct nameprior buf[NPRIOR];

  argaddr(0, &uaddr);
  argint(1, &max);

  if(max <= 0)
    return -1;
  if(max > NPRIOR)
    max = NPRIOR;

  int n = proc_get_priors(buf, max);
  if(n < 0)
    return -1;
  if(n > 0 && copyout(myproc()->pagetable, uaddr, (char *)buf,
                      n * sizeof(struct nameprior)) < 0)
    return -1;
  return n;
}

// Install a prior table from userspace (report sec 04 persistence). `priors
// load` reads a file saved before reboot and pushes it back in through here;
// proc_set_priors re-validates every entry. NPRIOR is small so the whole
// table fits the kernel stack in one copyin.
uint64
sys_setnamepriors(void)
{
  uint64 uaddr;
  int n;
  struct nameprior buf[NPRIOR];

  argaddr(0, &uaddr);
  argint(1, &n);

  if(n <= 0)
    return 0;
  if(n > NPRIOR)
    n = NPRIOR;
  if(copyin(myproc()->pagetable, (char *)buf, uaddr,
            n * sizeof(struct nameprior)) < 0)
    return -1;
  return proc_set_priors(buf, n);
}

// Job / process-tree grouping (report sec 05).
uint64
sys_setjob(void)
{
  return proc_setjob();
}

uint64
sys_getjob(void)
{
  int pid;
  argint(0, &pid);
  return proc_getjob(pid);
}

uint64
sys_setjobpriority(void)
{
  int gid, prio;
  argint(0, &gid);
  argint(1, &prio);
  return proc_setjobpriority(gid, prio);
}

uint64
sys_setjobclass(void)
{
  int gid, class_id;
  argint(0, &gid);
  argint(1, &class_id);
  return proc_setjobclass(gid, class_id);
}

// Panic post-mortem support (report sec 07).
// note(msg): userspace breadcrumb into the event ring.
uint64
sys_note(void)
{
  char msg[24];
  if(argstr(0, msg, sizeof(msg)) < 0)
    return -1;
  proc_log_event(EV_NOTE, myproc()->pid, myproc()->name, 0, 0, msg);
  return 0;
}

// crash(msg): deliberately panic, to demonstrate the post-mortem timeline.
// A debug-only hook — the real value is the @@PANIC dump panic() emits.
uint64
sys_crash(void)
{
  char msg[32];
  if(argstr(0, msg, sizeof(msg)) < 0)
    return -1;
  panic(msg);   // never returns
  return 0;
}

// return how many clock tick interrupts have occurred
// since start.
uint64
sys_uptime(void)
{
  uint xticks;

  acquire(&tickslock);
  xticks = ticks;
  release(&tickslock);
  return xticks;
}

// ============================================================
// memory subsystem syscalls (grafted in lv0 merge)
// NOTE: setpriority/getpriority are NOT redefined here — the scheduler
// subsystem already provides richer versions (class/quantum aware).
// ============================================================

uint64
sys_trace(void)
{
  int mask;
  argint(0, &mask);
  myproc()->trace_mask = mask;
  return 0;
}

// Snapshot per-process memory stats into a user array of struct memstat.
// Returns the number of entries written.
uint64
sys_getmemstat(void)
{
  uint64 uaddr;
  int max;
  int count = 0;
  struct proc *p;
  struct proc *cur = myproc();

  argaddr(0, &uaddr);
  argint(1, &max);

  if(max <= 0)
    return -1;
  if(max > NPROC)
    max = NPROC;

  for(p = proc; p < &proc[NPROC] && count < max; p++){
    struct memstat m;

    acquire(&p->lock);
    if(p->state == UNUSED){
      release(&p->lock);
      continue;
    }
    m.pid = p->pid;
    m.state = p->state;
    m.sz = p->sz;
    m.mem_quota = p->mem_quota;
    m.quota_denied_count = p->quota_denied_count;
    m.swapout_count = p->swapout_count;
    m.swapin_count = p->swapin_count;
    safestrcpy(m.name, p->name, sizeof(m.name));
    release(&p->lock);

    if(copyout(cur->pagetable,
               uaddr + count * sizeof(struct memstat),
               (char *)&m,
               sizeof(struct memstat)) < 0){
      return -1;
    }
    count++;
  }
  return count;
}

// Report swap-area usage (used/total slots).
uint64
sys_getswapstat(void)
{
  uint64 uaddr;
  struct swapstat s;
  struct proc *p = myproc();

  argaddr(0, &uaddr);

  s.used_slots = swap_used_slots();
  s.total_slots = swap_total_slots();

  if(copyout(p->pagetable, uaddr, (char *)&s, sizeof(s)) < 0)
    return -1;
  return 0;
}

// Set a process's memory quota (bytes). 0 = unlimited. Protected procs
// (init/sh) cannot be quota'd; a quota below current size is rejected.
uint64
sys_setmemquota(void)
{
  int pid;
  int quota;
  struct proc *p;

  argint(0, &pid);
  argint(1, &quota);

  if(pid <= 0)
    return -1;
  if(quota < 0)
    return -1;

  for(p = proc; p < &proc[NPROC]; p++){
    acquire(&p->lock);
    if(p->state != UNUSED && p->pid == pid){
      if(strncmp(p->name, "init", 16) == 0 || strncmp(p->name, "sh", 16) == 0){
        release(&p->lock);
        return -1;
      }
      if(quota > 0 && (uint64)quota < p->sz){
        release(&p->lock);
        return -1;
      }
      p->mem_quota = (uint64)quota;
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
  }
  return -1;
}

// Swap one resident page of the named process out to the swap disk.
uint64
sys_swapout(void)
{
  int pid;
  argint(0, &pid);

  if(pid == 1 || pid == 2)
    return -1;
  return swapout_proc(pid);
}
