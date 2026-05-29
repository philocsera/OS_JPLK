#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "spinlock.h"
#include "proc.h"
#include "procstat.h"
#include "defs.h"

// Per-class default quantum (ticks). Interactive gets short slices for
// latency; CPU/batch gets long slices to amortize context-switch cost.
// Matches the rationale in process.md §4.3 (b).
static const int class_default_quantum[NCLASS] = {
  [CLASS_INTERACTIVE] = 1,
  [CLASS_IO_BOUND]    = 1,
  [CLASS_NORMAL]      = 1,
  [CLASS_CPU_BOUND]   = 4,
  [CLASS_BATCH]       = 8,
  [CLASS_SYSTEM]      = 2,
};

extern uint ticks;

struct cpu cpus[NCPU];

struct proc proc[NPROC];

struct proc *initproc;

int nextpid = 1;
struct spinlock pid_lock;

extern void forkret(void);
static void freeproc(struct proc *p);

extern char trampoline[]; // trampoline.S

// helps ensure that wakeups of wait()ing
// parents are not lost. helps obey the
// memory model when using p->parent.
// must be acquired before any p->lock.
struct spinlock wait_lock;

// Exit-statistics learning table (report sec 04). Keyed by program name;
// updated by proc_learn_on_exit() and read by proc_seed_from_prior() /
// the getnamepriors syscall. Guarded by its own lock so it never sits on
// the scheduler's or wait_lock's critical path.
struct spinlock prior_lock;
struct nameprior name_priors[NPRIOR];

// ----- Event ring for panic post-mortem (report sec 07) -----
// A tiny circular log of notable scheduler/lifecycle events. On panic() the
// kernel dumps it as a @@PANIC/@@EV timeline that a host LLM (tools/diagnose.py)
// turns into a natural-language diagnosis. Best-effort: the dump runs lockless
// so a panic with a held lock still prints.
#define NEVENT 32
#define EV_NOTE     0   // userspace breadcrumb (note syscall)
#define EV_EXIT     1   // process exited (detail = run, sleep)
#define EV_FORKFAIL 2   // fork denied (detail = group_id, group count)
#define EV_CLASS    3   // class changed (detail = old, new)
struct kevent {
  uint64 tick;
  int type;
  int pid;
  char name[16];
  uint64 d1, d2;
  char msg[24];
};
static struct kevent evbuf[NEVENT];
static int evhead;            // next slot to write
static int evcount;           // total events ever logged
static struct spinlock ev_lock;

// Allocate a page for each process's kernel stack.
// Map it high in memory, followed by an invalid
// guard page.
void
proc_mapstacks(pagetable_t kpgtbl)
{
  struct proc *p;
  
  for(p = proc; p < &proc[NPROC]; p++) {
    char *pa = kalloc();
    if(pa == 0)
      panic("kalloc");
    uint64 va = KSTACK((int) (p - proc));
    kvmmap(kpgtbl, va, (uint64)pa, PGSIZE, PTE_R | PTE_W);
  }
}

// initialize the proc table.
void
procinit(void)
{
  struct proc *p;
  
  initlock(&pid_lock, "nextpid");
  initlock(&wait_lock, "wait_lock");
  initlock(&prior_lock, "nameprior");
  initlock(&ev_lock, "kevent");
  for(p = proc; p < &proc[NPROC]; p++) {
      initlock(&p->lock, "proc");
      p->state = UNUSED;
      p->kstack = KSTACK((int) (p - proc));
  }
}

// Must be called with interrupts disabled,
// to prevent race with process being moved
// to a different CPU.
int
cpuid()
{
  int id = r_tp();
  return id;
}

// Return this CPU's cpu struct.
// Interrupts must be disabled.
struct cpu*
mycpu(void)
{
  int id = cpuid();
  struct cpu *c = &cpus[id];
  return c;
}

// Return the current struct proc *, or zero if none.
struct proc*
myproc(void)
{
  push_off();
  struct cpu *c = mycpu();
  struct proc *p = c->proc;
  pop_off();
  return p;
}

int
allocpid()
{
  int pid;
  
  acquire(&pid_lock);
  pid = nextpid;
  nextpid = nextpid + 1;
  release(&pid_lock);

  return pid;
}

// Look in the process table for an UNUSED proc.
// If found, initialize state required to run in the kernel,
// and return with p->lock held.
// If there are no free procs, or a memory allocation fails, return 0.
static struct proc*
allocproc(void)
{
  struct proc *p;

  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->state == UNUSED) {
      goto found;
    } else {
      release(&p->lock);
    }
  }
  return 0;

found:
  p->pid = allocpid();
  p->state = USED;

  // Allocate a trapframe page.
  if((p->trapframe = (struct trapframe *)kalloc()) == 0){
    freeproc(p);
    release(&p->lock);
    return 0;
  }

  // An empty user page table.
  p->pagetable = proc_pagetable(p);
  if(p->pagetable == 0){
    freeproc(p);
    release(&p->lock);
    return 0;
  }

  // Set up new context to start executing at forkret,
  // which returns to user space.
  memset(&p->context, 0, sizeof(p->context));
  p->context.ra = (uint64)forkret;
  p->context.sp = p->kstack + PGSIZE;

  // Set default priority to 10 (middle of 0-20 range)
  p->priority = 10;

  // Advisor-visible defaults. Class=NORMAL gives the legacy "all procs
  // are equal" behavior until advisord (or a test) overrides it.
  p->class_id = CLASS_NORMAL;
  p->quantum_ticks = class_default_quantum[CLASS_NORMAL];
  p->slice_used = 0;
  // Default: each proc is its own job (group_id == pid). fork() overrides
  // this with the parent's group so a subtree shares one job id; setjob()
  // lets a proc deliberately start a fresh job. (report sec 05)
  p->group_id = p->pid;
  p->ready_ticks = 0;
  p->run_ticks = 0;
  p->sleep_ticks = 0;
  p->ctxsw_count = 0;
  p->alloc_tick = ticks;

  return p;
}

// free a proc structure and the data hanging from it,
// including user pages.
// p->lock must be held.
static void
freeproc(struct proc *p)
{
  if(p->trapframe)
    kfree((void*)p->trapframe);
  p->trapframe = 0;
  if(p->pagetable)
    proc_freepagetable(p->pagetable, p->sz);
  p->pagetable = 0;
  p->sz = 0;
  p->pid = 0;
  p->parent = 0;
  p->name[0] = 0;
  p->chan = 0;
  p->killed = 0;
  p->xstate = 0;
  p->priority = 0;
  // process.md §6 keeps lifetime stats live until *after* the parent's
  // kwait reaps the ZOMBIE — that's the natural xv6 semantics: the
  // advisor's last poll catches the ZOMBIE snapshot before this clear.
  p->class_id = 0;
  p->quantum_ticks = 0;
  p->slice_used = 0;
  p->ready_ticks = 0;
  p->run_ticks = 0;
  p->sleep_ticks = 0;
  p->ctxsw_count = 0;
  p->alloc_tick = 0;
  p->state = UNUSED;
}

// Create a user page table for a given process, with no user memory,
// but with trampoline and trapframe pages.
pagetable_t
proc_pagetable(struct proc *p)
{
  pagetable_t pagetable;

  // An empty page table.
  pagetable = uvmcreate();
  if(pagetable == 0)
    return 0;

  // map the trampoline code (for system call return)
  // at the highest user virtual address.
  // only the supervisor uses it, on the way
  // to/from user space, so not PTE_U.
  if(mappages(pagetable, TRAMPOLINE, PGSIZE,
              (uint64)trampoline, PTE_R | PTE_X) < 0){
    uvmfree(pagetable, 0);
    return 0;
  }

  // map the trapframe page just below the trampoline page, for
  // trampoline.S.
  if(mappages(pagetable, TRAPFRAME, PGSIZE,
              (uint64)(p->trapframe), PTE_R | PTE_W) < 0){
    uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    uvmfree(pagetable, 0);
    return 0;
  }

  return pagetable;
}

// Free a process's page table, and free the
// physical memory it refers to.
void
proc_freepagetable(pagetable_t pagetable, uint64 sz)
{
  uvmunmap(pagetable, TRAMPOLINE, 1, 0);
  uvmunmap(pagetable, TRAPFRAME, 1, 0);
  uvmfree(pagetable, sz);
}

// Set up first user process.
void
userinit(void)
{
  struct proc *p;

  p = allocproc();
  initproc = p;
  
  p->cwd = namei("/");

  p->state = RUNNABLE;

  release(&p->lock);
}

// Grow or shrink user memory by n bytes.
// Return 0 on success, -1 on failure.
int
growproc(int n)
{
  uint64 sz;
  struct proc *p = myproc();

  sz = p->sz;
  if(n > 0){
    if(sz + n > TRAPFRAME) {
      return -1;
    }
    if((sz = uvmalloc(p->pagetable, sz, sz + n, PTE_W)) == 0) {
      return -1;
    }
  } else if(n < 0){
    sz = uvmdealloc(p->pagetable, sz, sz + n);
  }
  p->sz = sz;
  return 0;
}

// Create a new process, copying the parent.
// Sets up child kernel stack to return as if from fork() system call.
int
kfork(void)
{
  int i, pid;
  struct proc *np;
  struct proc *p = myproc();

  // Fork-bomb cap (report sec 06): a child inherits the parent's job/group,
  // so a runaway tree all shares one group_id. Refuse to grow a single job
  // past GROUP_PROC_LIMIT live procs — the bomb caps itself while other jobs
  // (the shell, init, advisord) keep their slots. A legitimate large job can
  // still scale by calling setjob() in its branches. init (group 1) is exempt
  // so the system can always reparent orphans.
  if(p->group_id != 1){
    int gc = proc_group_count(p->group_id);
    if(gc >= GROUP_PROC_LIMIT){
      proc_log_event(EV_FORKFAIL, p->pid, p->name, p->group_id, gc, "cap");
      return -1;
    }
  }

  // Allocate process.
  if((np = allocproc()) == 0){
    return -1;
  }

  // Copy user memory from parent to child.
  if(uvmcopy(p->pagetable, np->pagetable, p->sz) < 0){
    freeproc(np);
    release(&np->lock);
    return -1;
  }
  np->sz = p->sz;

  // copy saved user registers.
  *(np->trapframe) = *(p->trapframe);

  // Cause fork to return 0 in the child.
  np->trapframe->a0 = 0;

  // increment reference counts on open file descriptors.
  for(i = 0; i < NOFILE; i++)
    if(p->ofile[i])
      np->ofile[i] = filedup(p->ofile[i]);
  np->cwd = idup(p->cwd);

  safestrcpy(np->name, p->name, sizeof(p->name));

  // Inherit priority and class from parent to child. The advisor is
  // expected to re-classify within ~one poll window after exec, but
  // this gives a safe default in the meantime (process.md §3.3).
  np->priority = p->priority;
  np->class_id = p->class_id;
  np->quantum_ticks = p->quantum_ticks;
  // Inherit the job/group so a whole sh->make->cc tree shares one id
  // (report sec 05). Overrides the allocproc default of group_id==pid.
  np->group_id = p->group_id;

  pid = np->pid;

  release(&np->lock);

  acquire(&wait_lock);
  np->parent = p;
  release(&wait_lock);

  acquire(&np->lock);
  np->state = RUNNABLE;
  release(&np->lock);

  return pid;
}

// Pass p's abandoned children to init.
// Caller must hold wait_lock.
void
reparent(struct proc *p)
{
  struct proc *pp;

  for(pp = proc; pp < &proc[NPROC]; pp++){
    if(pp->parent == p){
      pp->parent = initproc;
      wakeup(initproc);
    }
  }
}

// Exit the current process.  Does not return.
// An exited process remains in the zombie state
// until its parent calls wait().
void
kexit(int status)
{
  struct proc *p = myproc();

  if(p == initproc)
    panic("init exiting");

  // Fold this run's profile into the per-name prior before we tear the
  // process down, so the next exec() of this name starts pre-classified.
  proc_learn_on_exit(p);
  // Record the exit in the panic post-mortem ring (sec 07).
  proc_log_event(EV_EXIT, p->pid, p->name, p->run_ticks, p->sleep_ticks, 0);

  // Close all open files.
  for(int fd = 0; fd < NOFILE; fd++){
    if(p->ofile[fd]){
      struct file *f = p->ofile[fd];
      fileclose(f);
      p->ofile[fd] = 0;
    }
  }

  begin_op();
  iput(p->cwd);
  end_op();
  p->cwd = 0;

  acquire(&wait_lock);

  // Give any children to init.
  reparent(p);

  // Parent might be sleeping in wait().
  wakeup(p->parent);
  
  acquire(&p->lock);

  p->xstate = status;
  p->state = ZOMBIE;

  release(&wait_lock);

  // Jump into the scheduler, never to return.
  sched();
  panic("zombie exit");
}

// Wait for a child process to exit and return its pid.
// Return -1 if this process has no children.
int
kwait(uint64 addr)
{
  struct proc *pp;
  int havekids, pid;
  struct proc *p = myproc();

  acquire(&wait_lock);

  for(;;){
    // Scan through table looking for exited children.
    havekids = 0;
    for(pp = proc; pp < &proc[NPROC]; pp++){
      if(pp->parent == p){
        // make sure the child isn't still in exit() or swtch().
        acquire(&pp->lock);

        havekids = 1;
        if(pp->state == ZOMBIE){
          // Found one.
          pid = pp->pid;
          if(addr != 0 && copyout(p->pagetable, addr, (char *)&pp->xstate,
                                  sizeof(pp->xstate)) < 0) {
            release(&pp->lock);
            release(&wait_lock);
            return -1;
          }
          freeproc(pp);
          release(&pp->lock);
          release(&wait_lock);
          return pid;
        }
        release(&pp->lock);
      }
    }

    // No point waiting if we don't have any children.
    if(!havekids || killed(p)){
      release(&wait_lock);
      return -1;
    }
    
    // Wait for a child to exit.
    sleep(p, &wait_lock);  //DOC: wait-sleep
  }
}

// Per-CPU process scheduler.
// Each CPU calls scheduler() after setting itself up.
// Scheduler never returns.  It loops, doing:
//  - choose a process to run.
//  - swtch to start running that process.
//  - eventually that process transfers control
//    via swtch back to the scheduler.
void
scheduler(void)
{
  struct proc *p;
  struct cpu *c = mycpu();

  c->proc = 0;
  for(;;){
    // Enable interrupts to avoid deadlock when all processes are waiting,
    // then disable before scanning to prevent races with wfi.
    intr_on();
    intr_off();

    // Priority-based scheduler: single-pass, track "best so far" candidate.
    // Lower priority number = higher priority (0 is highest, 20 is lowest).
    // Among equal priorities, the linear scan provides round-robin fairness.
    struct proc *best = 0;

    for(p = proc; p < &proc[NPROC]; p++) {
      acquire(&p->lock);
      if(p->state == RUNNABLE) {
        if(best == 0 || p->priority < best->priority) {
          // Found a higher-priority candidate; release the old best
          if(best != 0)
            release(&best->lock);
          best = p;
          // Keep best->lock held so no one changes its state
        } else {
          release(&p->lock);
        }
      } else {
        release(&p->lock);
      }
    }

    if(best != 0) {
      // Dispatch the highest-priority RUNNABLE process (lock already held)
      best->state = RUNNING;
      best->slice_used = 0;        // start a fresh quantum window
      best->ctxsw_count++;          // visible to advisord
      c->proc = best;
      swtch(&c->context, &best->context);
      // Process is done running for now.
      c->proc = 0;
      release(&best->lock);
    } else {
      // No RUNNABLE process; halt until next interrupt.
      asm volatile("wfi");
    }
  }
}

// Switch to scheduler.  Must hold only p->lock
// and have changed proc->state. Saves and restores
// intena because intena is a property of this
// kernel thread, not this CPU. It should
// be proc->intena and proc->noff, but that would
// break in the few places where a lock is held but
// there's no process.
void
sched(void)
{
  int intena;
  struct proc *p = myproc();

  if(!holding(&p->lock))
    panic("sched p->lock");
  if(mycpu()->noff != 1)
    panic("sched locks");
  if(p->state == RUNNING)
    panic("sched RUNNING");
  if(intr_get())
    panic("sched interruptible");

  intena = mycpu()->intena;
  swtch(&p->context, &mycpu()->context);
  mycpu()->intena = intena;
}

// Give up the CPU for one scheduling round.
void
yield(void)
{
  struct proc *p = myproc();
  acquire(&p->lock);
  p->state = RUNNABLE;
  sched();
  release(&p->lock);
}

// A fork child's very first scheduling by scheduler()
// will swtch to forkret.
void
forkret(void)
{
  extern char userret[];
  static int first = 1;
  struct proc *p = myproc();

  // Still holding p->lock from scheduler.
  release(&p->lock);

  if (first) {
    // File system initialization must be run in the context of a
    // regular process (e.g., because it calls sleep), and thus cannot
    // be run from main().
    fsinit(ROOTDEV);

    first = 0;
    // ensure other cores see first=0.
    __sync_synchronize();

    // We can invoke kexec() now that file system is initialized.
    // Put the return value (argc) of kexec into a0.
    p->trapframe->a0 = kexec("/init", (char *[]){ "/init", 0 });
    if (p->trapframe->a0 == -1) {
      panic("exec");
    }
  }

  // return to user space, mimicing usertrap()'s return.
  prepare_return();
  uint64 satp = MAKE_SATP(p->pagetable);
  uint64 trampoline_userret = TRAMPOLINE + (userret - trampoline);
  ((void (*)(uint64))trampoline_userret)(satp);
}

// Sleep on channel chan, releasing condition lock lk.
// Re-acquires lk when awakened.
void
sleep(void *chan, struct spinlock *lk)
{
  struct proc *p = myproc();
  
  // Must acquire p->lock in order to
  // change p->state and then call sched.
  // Once we hold p->lock, we can be
  // guaranteed that we won't miss any wakeup
  // (wakeup locks p->lock),
  // so it's okay to release lk.

  acquire(&p->lock);  //DOC: sleeplock1
  release(lk);

  // Go to sleep.
  p->chan = chan;
  p->state = SLEEPING;

  sched();

  // Tidy up.
  p->chan = 0;

  // Reacquire original lock.
  release(&p->lock);
  acquire(lk);
}

// Wake up all processes sleeping on channel chan.
// Caller should hold the condition lock.
void
wakeup(void *chan)
{
  struct proc *p;

  for(p = proc; p < &proc[NPROC]; p++) {
    if(p != myproc()){
      acquire(&p->lock);
      if(p->state == SLEEPING && p->chan == chan) {
        p->state = RUNNABLE;
      }
      release(&p->lock);
    }
  }
}

// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see usertrap() in trap.c).
int
kkill(int pid)
{
  struct proc *p;

  for(p = proc; p < &proc[NPROC]; p++){
    acquire(&p->lock);
    if(p->pid == pid){
      p->killed = 1;
      if(p->state == SLEEPING){
        // Wake process from sleep().
        p->state = RUNNABLE;
      }
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
  }
  return -1;
}

void
setkilled(struct proc *p)
{
  acquire(&p->lock);
  p->killed = 1;
  release(&p->lock);
}

int
killed(struct proc *p)
{
  int k;
  
  acquire(&p->lock);
  k = p->killed;
  release(&p->lock);
  return k;
}

// Copy to either a user address, or kernel address,
// depending on usr_dst.
// Returns 0 on success, -1 on error.
int
either_copyout(int user_dst, uint64 dst, void *src, uint64 len)
{
  struct proc *p = myproc();
  if(user_dst){
    return copyout(p->pagetable, dst, src, len);
  } else {
    memmove((char *)dst, src, len);
    return 0;
  }
}

// Copy from either a user address, or kernel address,
// depending on usr_src.
// Returns 0 on success, -1 on error.
int
either_copyin(void *dst, int user_src, uint64 src, uint64 len)
{
  struct proc *p = myproc();
  if(user_src){
    return copyin(p->pagetable, dst, src, len);
  } else {
    memmove(dst, (char*)src, len);
    return 0;
  }
}

// Walk the proc table once per tick and credit one tick to each proc's
// state-specific counter. Called from clockintr() on cpu 0 only.
//
// Locking: best-effort. We *try* to acquire p->lock and skip if busy —
// missing a tick is acceptable (advisor reads are statistical), but
// blocking the clock interrupt is not. Per process.md §5: fast paths
// must not be perturbed by accounting.
void
procstat_tick(void)
{
  struct proc *p;
  for(p = proc; p < &proc[NPROC]; p++) {
    // Cheap unlocked state read to skip clearly-unused slots without
    // touching the lock at all.
    if(p->state == UNUSED)
      continue;
    // Real non-blocking try-acquire. If another CPU holds p->lock we
    // drop this tick rather than stall the clock interrupt.
    if(!try_acquire(&p->lock))
      continue;
    switch(p->state) {
    case RUNNABLE:
      p->ready_ticks++;
      break;
    case RUNNING:
      p->run_ticks++;
      p->slice_used++;
      break;
    case SLEEPING:
      p->sleep_ticks++;
      break;
    default:
      break;
    }
    release(&p->lock);
  }
}

// Look up a proc by pid and copy a procstat snapshot into *out.
// Returns 0 on success, -1 if not found. Used by sys_getprocstat for
// the single-pid form (used by sys_setclass and friends to verify).
int
procstat_get(int pid, struct procstat *out)
{
  struct proc *p;
  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->pid == pid && p->state != UNUSED) {
      out->pid = p->pid;
      out->ppid = p->parent ? p->parent->pid : 0;
      out->state = (int)p->state;
      out->priority = p->priority;
      out->class_id = p->class_id;
      out->quantum_ticks = p->quantum_ticks;
      out->group_id = p->group_id;
      out->ready_ticks = p->ready_ticks;
      out->run_ticks = p->run_ticks;
      out->sleep_ticks = p->sleep_ticks;
      out->ctxsw_count = p->ctxsw_count;
      out->lifetime = (uint64)(ticks - p->alloc_tick);
      for(int i = 0; i < 16; i++) out->name[i] = p->name[i];
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
  }
  return -1;
}

// Bulk snapshot for advisord, scoped to a proc[] index range.
// Scans proc[start..end) and fills non-UNUSED entries into dst (up to
// dst_cap entries). Returns the number of entries written.
//
// The caller (sys_getprocstat_all) chunks the scan so the syscall keeps
// its kernel stack buffer small — see process.md §6.
int
procstat_all_range(int start, int end, struct procstat *dst, int dst_cap)
{
  struct proc *p;
  int n = 0;
  if(start < 0) start = 0;
  if(end > NPROC) end = NPROC;
  for(int i = start; i < end && n < dst_cap; i++) {
    p = &proc[i];
    acquire(&p->lock);
    if(p->state != UNUSED) {
      dst[n].pid = p->pid;
      // parent read needs wait_lock for full safety, but for snapshot
      // purposes a torn read is acceptable — advisor tolerates noise.
      dst[n].ppid = p->parent ? p->parent->pid : 0;
      dst[n].state = (int)p->state;
      dst[n].priority = p->priority;
      dst[n].class_id = p->class_id;
      dst[n].quantum_ticks = p->quantum_ticks;
      dst[n].group_id = p->group_id;
      dst[n].ready_ticks = p->ready_ticks;
      dst[n].run_ticks = p->run_ticks;
      dst[n].sleep_ticks = p->sleep_ticks;
      dst[n].ctxsw_count = p->ctxsw_count;
      dst[n].lifetime = (uint64)(ticks - p->alloc_tick);
      for(uint k = 0; k < sizeof(dst[n].name); k++)
        dst[n].name[k] = p->name[k];
      n++;
    }
    release(&p->lock);
  }
  return n;
}

// Setters used by advisord. Each takes the per-proc lock to avoid
// torn reads with the scheduler. They are deliberately tiny — the
// kernel imposes no policy beyond range checks.

int
proc_setclass(int pid, int class_id)
{
  if(class_id < 0 || class_id >= NCLASS)
    return -1;
  struct proc *p;
  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->pid == pid && p->state != UNUSED) {
      int old = p->class_id;
      p->class_id = class_id;
      // class change auto-updates the recommended quantum, but the
      // advisor can override via setquantum afterward.
      p->quantum_ticks = class_default_quantum[class_id];
      char nm[16];
      safestrcpy(nm, p->name, sizeof(nm));
      release(&p->lock);
      // Record the advisor's decision in the event ring so it shows up in
      // the sec-07 @@PANIC timeline. Logged outside p->lock (order is always
      // p->lock -> ev_lock; eventlog never takes p->lock). Only on a real
      // change, to avoid flooding the 32-slot ring with no-op rewrites.
      if(old != class_id)
        proc_log_event(EV_CLASS, pid, nm, old, class_id, "set");
      return 0;
    }
    release(&p->lock);
  }
  return -1;
}

int
proc_setquantum(int pid, int q)
{
  if(q < 1 || q > 64)
    return -1;
  struct proc *p;
  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->pid == pid && p->state != UNUSED) {
      p->quantum_ticks = q;
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
  }
  return -1;
}

// ===========================================================================
// Exit-statistics learning (report sec 04).
//
// Policy mirrors the userspace advisor's classify(): sleep-heavy → IO/INT,
// run-heavy → CPU_BOUND, else NORMAL. Kept in the kernel only so that
// short-lived processes (which die between advisord polls) still contribute
// a sample and seed their successors. prior_lock guards the table; it is
// never held across a context switch.
// ===========================================================================

static int
classify_stats(uint64 run, uint64 sleep, const char *name)
{
  uint64 active = run + sleep;
  if(active == 0)
    return CLASS_NORMAL;
  if(sleep * 2 > active) {
    if(strncmp(name, "sh", 16) == 0)
      return CLASS_INTERACTIVE;
    return CLASS_IO_BOUND;
  }
  if(run * 4 > active)
    return CLASS_CPU_BOUND;
  return CLASS_NORMAL;
}

// Find the prior entry for name, or claim a free/evictable slot. Caller
// holds prior_lock. Returns 0 only if the table is full of distinct,
// already-sampled names and none match.
static struct nameprior *
prior_slot(const char *name)
{
  struct nameprior *e, *free_slot = 0, *lru = 0;
  for(e = name_priors; e < &name_priors[NPRIOR]; e++) {
    if(e->valid && strncmp(e->name, name, 16) == 0)
      return e;                         // existing entry for this name
    if(!e->valid && free_slot == 0)
      free_slot = e;                    // first empty slot
    if(e->valid && (lru == 0 || e->samples < lru->samples))
      lru = e;                          // fewest-sample entry, for eviction
  }
  if(free_slot)
    return free_slot;
  // Table full: evict the least-sampled name so a busy name can't be
  // starved out by a one-shot. (NPRIOR is small; this keeps it bounded.)
  if(lru) {
    lru->valid = 0;
    lru->samples = 0;
    lru->avg_run = lru->avg_sleep = 0;
  }
  return lru;
}

// Fold an exiting process's profile into the per-name prior. Called from
// kexit() while the proc is still the running process (its counters are
// stable enough — accounting is statistical).
void
proc_learn_on_exit(struct proc *p)
{
  uint64 run = p->run_ticks, slp = p->sleep_ticks;
  // Ignore processes too short-lived to carry signal — avoids polluting
  // the prior with noise from instantly-exiting helpers.
  if(run + slp < 2)
    return;

  acquire(&prior_lock);
  struct nameprior *e = prior_slot(p->name);
  if(e) {
    // Running mean so repeated runs converge instead of last-write-wins.
    e->avg_run   = (e->avg_run   * e->samples + run) / (e->samples + 1);
    e->avg_sleep = (e->avg_sleep * e->samples + slp) / (e->samples + 1);
    e->samples++;
    e->class_id  = classify_stats(e->avg_run, e->avg_sleep, p->name);
    safestrcpy(e->name, p->name, sizeof(e->name));
    e->valid = 1;
  }
  release(&prior_lock);
}

// Seed a freshly-exec'd process from the learned prior for its name, so it
// runs under the right class from instruction zero. Called at the end of
// exec() (p is the current process). No-op if the name has no prior yet —
// the process keeps the class it inherited via fork (legacy behavior).
void
proc_seed_from_prior(struct proc *p)
{
  acquire(&prior_lock);
  for(struct nameprior *e = name_priors; e < &name_priors[NPRIOR]; e++) {
    if(e->valid && e->samples >= 1 && strncmp(e->name, p->name, 16) == 0) {
      p->class_id = e->class_id;
      p->quantum_ticks = class_default_quantum[e->class_id];
      break;
    }
  }
  release(&prior_lock);
}

// Copy the prior table into a user buffer for inspection/testing.
// Returns the number of valid entries written.
int
proc_get_priors(struct nameprior *dst, int max)
{
  int n = 0;
  acquire(&prior_lock);
  for(struct nameprior *e = name_priors; e < &name_priors[NPRIOR] && n < max; e++) {
    if(e->valid)
      dst[n++] = *e;
  }
  release(&prior_lock);
  return n;
}

// Install a userspace-supplied prior table (report sec 04 persistence). The
// kernel table is reboot-volatile, so `priors save` dumps it to a file before
// reboot and `priors load` (run from init at boot) restores it through here.
// Every entry is re-validated — userspace data is untrusted — and the live
// table is fully replaced. Returns the number of entries installed.
int
proc_set_priors(struct nameprior *src, int n)
{
  if(n < 0)
    n = 0;
  if(n > NPRIOR)
    n = NPRIOR;
  acquire(&prior_lock);
  for(int i = 0; i < NPRIOR; i++)        // clear, then compact valid entries in
    name_priors[i].valid = 0;
  int installed = 0;
  for(int i = 0; i < n; i++) {
    struct nameprior *s = &src[i];
    if(!s->valid || s->name[0] == '\0')
      continue;
    if(s->class_id < 0 || s->class_id >= NCLASS)
      continue;
    struct nameprior *e = &name_priors[installed];
    safestrcpy(e->name, s->name, sizeof(e->name));  // bounds + NUL-terminates
    e->valid     = 1;
    e->class_id  = s->class_id;
    e->samples   = s->samples ? s->samples : 1;  // >=1 so seeding is eligible
    e->avg_run   = s->avg_run;
    e->avg_sleep = s->avg_sleep;
    installed++;
  }
  release(&prior_lock);
  return installed;
}

// ===========================================================================
// Job / process-tree grouping (report sec 05).
//
// group_id ties a sh->make->cc tree together: it propagates on fork and is
// reset by setjob(). The point is that policy (priority/class) can then be
// applied to a whole job in one call, instead of poking each pid. The kernel
// only provides the grouping primitive; *which* trees form a job and what
// policy to apply is the advisor's (userspace) decision.
// ===========================================================================

// Make the caller the leader of a fresh job: group_id := its own pid.
// Descendants forked afterwards inherit this id. Returns the new group id.
int
proc_setjob(void)
{
  struct proc *p = myproc();
  acquire(&p->lock);
  p->group_id = p->pid;
  int g = p->group_id;
  release(&p->lock);
  return g;
}

// Return the group_id of pid (pid <= 0 means the caller). -1 if not found.
int
proc_getjob(int pid)
{
  if(pid <= 0)
    return myproc()->group_id;
  struct proc *p;
  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->pid == pid && p->state != UNUSED) {
      int g = p->group_id;
      release(&p->lock);
      return g;
    }
    release(&p->lock);
  }
  return -1;
}

// Apply a priority to every member of a job in one sweep. Returns the number
// of processes updated, or -1 on a bad priority.
int
proc_setjobpriority(int group_id, int priority)
{
  if(priority < 0 || priority > 20)
    return -1;
  int count = 0;
  struct proc *p;
  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->state != UNUSED && p->group_id == group_id) {
      p->priority = priority;
      count++;
    }
    release(&p->lock);
  }
  return count;
}

// Count live processes in a job/group. Used by the fork-bomb cap (sec 06)
// and exposed for the advisor to spot a runaway tree.
int
proc_group_count(int group_id)
{
  int count = 0;
  struct proc *p;
  for(p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if(p->state != UNUSED && p->group_id == group_id)
      count++;
    release(&p->lock);
  }
  return count;
}

// Append an event to the ring (report sec 07). msg may be 0.
void
proc_log_event(int type, int pid, const char *name, uint64 d1, uint64 d2,
               const char *msg)
{
  acquire(&ev_lock);
  struct kevent *e = &evbuf[evhead];
  e->tick = ticks;
  e->type = type;
  e->pid = pid;
  e->d1 = d1;
  e->d2 = d2;
  safestrcpy(e->name, name ? name : "", sizeof(e->name));
  safestrcpy(e->msg, msg ? msg : "", sizeof(e->msg));
  evhead = (evhead + 1) % NEVENT;
  evcount++;
  release(&ev_lock);
}

static const char *
ev_type_name(int t)
{
  switch(t) {
  case EV_NOTE:     return "NOTE";
  case EV_EXIT:     return "EXIT";
  case EV_FORKFAIL: return "FORKFAIL";
  case EV_CLASS:    return "CLASS";
  default:          return "?";
  }
}

// Dump the event ring as a @@PANIC/@@EV timeline. Called from panic() — runs
// WITHOUT taking ev_lock so a panic while the lock is held still prints.
void
eventlog_dump(const char *reason)
{
  int n = evcount < NEVENT ? evcount : NEVENT;
  int start = evcount < NEVENT ? 0 : evhead;  // oldest first
  printf("@@PANIC reason=\"%s\" tick=%d events=%d\n",
         reason ? reason : "", ticks, n);
  for(int i = 0; i < n; i++) {
    struct kevent *e = &evbuf[(start + i) % NEVENT];
    printf("@@EV tick=%ld type=%s pid=%d name=%s d1=%ld d2=%ld msg=%s\n",
           e->tick, ev_type_name(e->type), e->pid, e->name,
           e->d1, e->d2, e->msg);
  }
  printf("@@PANIC_END\n");
}

// Apply a class (and its recommended quantum) to every member of a job.
// Returns the number of processes updated, or -1 on a bad class.
int
proc_setjobclass(int group_id, int class_id)
{
  if(class_id < 0 || class_id >= NCLASS)
    return -1;
  int count = 0;
  struct proc *p;
  for(p = proc; p < &proc[NPROC]; p++) {
    int old = -1, pid = -1, matched = 0;
    char nm[16];
    acquire(&p->lock);
    if(p->state != UNUSED && p->group_id == group_id) {
      old = p->class_id;
      p->class_id = class_id;
      p->quantum_ticks = class_default_quantum[class_id];
      pid = p->pid;
      safestrcpy(nm, p->name, sizeof(nm));
      matched = 1;
    }
    release(&p->lock);
    if(matched) {
      // See proc_setclass: log the whole-job decision outside p->lock.
      if(old != class_id)
        proc_log_event(EV_CLASS, pid, nm, old, class_id, "job");
      count++;
    }
  }
  return count;
}

// Print a process listing to console.  For debugging.
// Runs when user types ^P on console.
// No lock to avoid wedging a stuck machine further.
void
procdump(void)
{
  static char *states[] = {
  [UNUSED]    "unused",
  [USED]      "used",
  [SLEEPING]  "sleep ",
  [RUNNABLE]  "runble",
  [RUNNING]   "run   ",
  [ZOMBIE]    "zombie"
  };
  struct proc *p;
  char *state;

  printf("\n");
  for(p = proc; p < &proc[NPROC]; p++){
    if(p->state == UNUSED)
      continue;
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
      state = states[p->state];
    else
      state = "???";
    printf("%d %s %s prio=%d class=%d q=%d run=%ld rdy=%ld slp=%ld cs=%ld",
           p->pid, state, p->name, p->priority, p->class_id,
           p->quantum_ticks, p->run_ticks, p->ready_ticks,
           p->sleep_ticks, p->ctxsw_count);
    printf("\n");
  }
}
