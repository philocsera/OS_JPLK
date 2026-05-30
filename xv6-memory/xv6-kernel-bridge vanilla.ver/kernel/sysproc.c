#include "types.h"
#include "riscv.h"
#include "defs.h"
#include "param.h"
#include "memlayout.h"
#include "spinlock.h"
#include "proc.h"
#include "vm.h"
#include "memstat.h" //
extern struct proc proc[NPROC];

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

uint64
sys_trace(void)
{
  int mask;

  argint(0, &mask);
  myproc()->trace_mask = mask;
  return 0;
}
uint64
sys_setpriority(void)
{
  int pid;
  int priority;
  struct proc *p;

  argint(0, &pid);
  argint(1, &priority);

  if(priority < 0 || priority > 20)
    return -1;

  for(p = proc; p < &proc[NPROC]; p++){
    acquire(&p->lock);

    if(p->state != UNUSED && p->pid == pid){
      p->priority = priority;
      release(&p->lock);
      return 0;
    }

    release(&p->lock);
  }

  return -1;
}

uint64
sys_getpriority(void)
{
  int pid;
  struct proc *p;
  int priority;

  argint(0, &pid);

  for(p = proc; p < &proc[NPROC]; p++){
    acquire(&p->lock);

    if(p->state != UNUSED && p->pid == pid){
      priority = p->priority;
      release(&p->lock);
      return priority;
    }

    release(&p->lock);
  }

  return -1;
}

// syscall 추가
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
      // 보호 프로세스에는 quota 설정 금지
      if(strncmp(p->name, "init", 16) == 0 || strncmp(p->name, "sh", 16) == 0){
        release(&p->lock);
        return -1;
      }

      // 현재 사용량보다 작은 quota 설정 금지
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