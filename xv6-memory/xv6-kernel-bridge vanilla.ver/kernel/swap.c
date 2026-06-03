// kernel/swap.c — xv6 swap 서브시스템 본체
//
// 구성:
//   1) Slot pool : bitmap 기반 슬롯 할당/해제
//   2) Disk I/O  : bread/bwrite로 SWAPDEV에 직접 읽고 쓰기 (fs log 우회)
//   3) Swapout   : victim 선택 + 페이지를 디스크로 내보냄
//   4) Swapin    : page fault 시 디스크에서 다시 읽어옴
//
// 동기화:
//   - bitmap 접근은 swap_pool.lock(spinlock)으로 보호
//   - 디스크 I/O는 bread/bwrite의 자체 sleep lock 사용
//   - swapout_proc은 호출 전에 proc[]의 해당 entry lock을 잡음

#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "fs.h"
#include "buf.h"
#include "proc.h"
#include "defs.h"
#include "swap.h"


// ============================================================
// 1) Slot pool — bitmap 관리
// ============================================================

#define SWAP_BITMAP_BYTES  ((NSWAP + 7) / 8)

static struct {
  struct spinlock lock;
  uchar bitmap[SWAP_BITMAP_BYTES];
  int used;                              // 사용 중인 슬롯 수 (통계용)
  int hint;                              // 다음 할당 검색 시작 위치
} swap_pool;

void
swapinit(void)
{
  initlock(&swap_pool.lock, "swap");
  memset(swap_pool.bitmap, 0, sizeof(swap_pool.bitmap));
  swap_pool.used = 0;
  swap_pool.hint = 0;
}

// 호출자가 swap_pool.lock을 잡고 있어야 하는 bitmap 헬퍼
static int  bit_test (int s){ return (swap_pool.bitmap[s/8] >> (s%8)) & 1; }
static void bit_set  (int s){ swap_pool.bitmap[s/8] |=  (1 << (s%8)); }
static void bit_clear(int s){ swap_pool.bitmap[s/8] &= ~(1 << (s%8)); }

int
swap_alloc_slot(void)
{
  int i, slot;

  acquire(&swap_pool.lock);
  for(i = 0; i < NSWAP; i++){
    slot = (swap_pool.hint + i) % NSWAP;
    if(!bit_test(slot)){
      bit_set(slot);
      swap_pool.used++;
      swap_pool.hint = (slot + 1) % NSWAP;
      release(&swap_pool.lock);
      return slot;
    }
  }
  release(&swap_pool.lock);
  return -1;                             // swap area full
}

void
swap_free_slot(int slot)
{
  if(slot < 0 || slot >= NSWAP)
    panic("swap_free_slot: out of range");

  acquire(&swap_pool.lock);
  if(!bit_test(slot))
    panic("swap_free_slot: double free");
  bit_clear(slot);
  swap_pool.used--;
  if(slot < swap_pool.hint)
    swap_pool.hint = slot;
  release(&swap_pool.lock);
}

int
swap_used_slots(void)
{
  int n;
  acquire(&swap_pool.lock);
  n = swap_pool.used;
  release(&swap_pool.lock);
  return n;
}

int
swap_total_slots(void)
{
  return NSWAP;
}


// ============================================================
// 2) Disk I/O — 4KB 페이지를 8개 블록에 분할
// ============================================================
//
// fs log 트랜잭션 없이 직접 bread/bwrite.
// SWAPDEV는 fs.img와 별개 디바이스라 log와 무관.

int
swap_write_slot(int slot, char *page)
{
  uint blockno;
  struct buf *b;
  int i;

  if(slot < 0 || slot >= NSWAP) return -1;
  if(page == 0)                  return -1;

  blockno = slot * BLOCKS_PER_PAGE;

  for(i = 0; i < BLOCKS_PER_PAGE; i++){
    b = bread(SWAPDEV, blockno + i);
    memmove(b->data, page + i * BSIZE, BSIZE);
    bwrite(b);                           // xv6 bwrite는 동기
    brelse(b);
  }
  return 0;
}

int
swap_read_slot(int slot, char *page)
{
  uint blockno;
  struct buf *b;
  int i;

  if(slot < 0 || slot >= NSWAP) return -1;
  if(page == 0)                  return -1;

  blockno = slot * BLOCKS_PER_PAGE;

  for(i = 0; i < BLOCKS_PER_PAGE; i++){
    b = bread(SWAPDEV, blockno + i);
    memmove(page + i * BSIZE, b->data, BSIZE);
    brelse(b);
  }
  return 0;
}


// ============================================================
// 3) Swapout — victim 선택 + 페이지 내보내기
// ============================================================

// init/sh 보호 (절대 swap 대상에서 제외)
static int
is_protected_proc(struct proc *p)
{
  if(p->pid == 1) return 1;
  if(p->pid == 2) return 1;
  if(strncmp(p->name, "init", 5) == 0) return 1;
  if(strncmp(p->name, "sh", 3) == 0)   return 1;
  return 0;
}


// --- victim 선택: 단순 (첫 user page) ---
//
// 조건:
//   - PTE 존재 && V=1 && U=1 && W=1
//   - lazy(*pte==0) / 이미 swap된 페이지 / 손상된 PTE / 커널 페이지 제외
//   - va==0은 코드 시작점이라 회피
//   - ★ W=0(읽기전용 코드/text) 제외: swapin은 권한을 R|W|U로만 복구하고 X bit를
//     복원하지 못한다(기능 한계). 코드 페이지를 swap하면 재실행 시 instruction
//     page fault → usertrap kill. 따라서 쓰기가능(데이터/힙/스택) 페이지만 victim.
static int
select_victim_simple(struct proc *p, uint64 *va_out, pte_t **pte_out)
{
  uint64 va;
  pte_t *pte;

  for(va = 0; va < p->sz; va += PGSIZE){
    pte = walk(p->pagetable, va, 0);
    if(pte == 0)            continue;    // leaf table 없음 = lazy 영역
    if(*pte == 0)           continue;    // lazy PTE
    if(IS_SWAPPED(*pte))    continue;    // 이미 swap됨
    if((*pte & PTE_V) == 0) continue;    // 손상된 PTE
    if((*pte & PTE_U) == 0) continue;    // 커널 페이지
    if((*pte & PTE_W) == 0) continue;    // 읽기전용 코드 페이지 회피(X bit 복원 불가)
    if(va == 0)             continue;    // 코드 시작점 회피

    *va_out = va;
    *pte_out = pte;
    return 0;
  }
  return -1;
}


// --- victim 선택: A bit Clock ---
//
// 전제: struct proc에 uint64 swap_clock_hand 추가
#if SWAP_VICTIM_CLOCK
static int
select_victim_clock(struct proc *p, uint64 *va_out, pte_t **pte_out)
{
  uint64 start = p->swap_clock_hand;
  if(start >= p->sz || (start % PGSIZE) != 0)
    start = 0;

  uint64 va = start;
  pte_t *pte;
  pte_t *fallback_pte = 0;
  uint64 fallback_va = 0;
  int rounds = 0;

  while(rounds < 2){
    pte = walk(p->pagetable, va, 0);

    int eligible = (pte != 0) && (*pte != 0)
                   && !IS_SWAPPED(*pte)
                   && ((*pte & PTE_V) != 0)
                   && ((*pte & PTE_U) != 0)
                   && ((*pte & PTE_W) != 0)   // 읽기전용 코드 회피(X bit 복원 불가)
                   && (va != 0);

    if(eligible){
      if((*pte & PTE_A) == 0){
        // 최근 미접근 → victim 확정
        p->swap_clock_hand = va + PGSIZE;
        if(p->swap_clock_hand >= p->sz)
          p->swap_clock_hand = 0;
        *va_out = va;
        *pte_out = pte;
        return 0;
      } else {
        // 최근 접근됨 → A 클리어, fallback 후보로 기록
        *pte = (*pte) & ~PTE_A;
        if(fallback_pte == 0){
          fallback_pte = pte;
          fallback_va = va;
        }
      }
    }

    va += PGSIZE;
    if(va >= p->sz){
      va = 0;
      rounds++;
    }
    if(va == start && rounds == 0)
      rounds++;
  }

  // 모든 페이지가 A=1이었던 경우
  if(fallback_pte != 0){
    p->swap_clock_hand = fallback_va + PGSIZE;
    if(p->swap_clock_hand >= p->sz)
      p->swap_clock_hand = 0;
    *va_out = fallback_va;
    *pte_out = fallback_pte;
    return 0;
  }
  return -1;
}
#endif


// dispatcher
static int
select_victim(struct proc *p, uint64 *va_out, pte_t **pte_out)
{
#if SWAP_VICTIM_CLOCK
  return select_victim_clock(p, va_out, pte_out);
#else
  return select_victim_simple(p, va_out, pte_out);
#endif
}


// --- swapout_one_page: 한 페이지를 디스크로 내보냄 ---
//
// p->lock을 잡지 않은 상태로 호출.
// 내부에서 p->lock을 잡고 victim 탐색 후 반드시 disk I/O 전에 해제.
// (disk I/O는 sleep을 유발하므로 spinlock 보유 불가)
//
// 순서:
//   Phase1: p->lock 보유 → victim 탐색 + pa 확보
//   Phase2: p->lock 해제 → disk I/O (sleep 가능)
//   Phase3: p->lock 재보유 → PTE 변경 + sfence
//   Phase4: kfree (lock 불필요)
int
swapout_one_page(struct proc *p)
{
  uint64 va;
  pte_t *pte;
  int slot;
  uint64 pa;

  // Phase 1: victim 탐색 (p->lock 보유)
  acquire(&p->lock);
  if(select_victim(p, &va, &pte) < 0){
    release(&p->lock);
    return -1;
  }
  pa = PTE2PA(*pte);
  release(&p->lock);

  // Phase 2: slot 할당 + disk I/O (lock 없음 — sleep 가능)
  slot = swap_alloc_slot();
  if(slot < 0)
    return -1;

  if(swap_write_slot(slot, (char*)pa) < 0){
    swap_free_slot(slot);
    return -1;
  }

  // Phase 3: PTE 변경 (p->lock 재보유)
  acquire(&p->lock);

  // ★ Phase 2(락-free 디스크 I/O) 동안 대상 proc 이 exit→reap(freeproc) 되어
  //   p->pagetable 이 해제(0)됐을 수 있다. freeproc 은 p->lock 을 잡고 도므로
  //   여기 acquire 는 freeproc 완료 후를 보장 → pagetable/state 로 죽음을 감지한다.
  //   이 검사 없이 walk(p->pagetable) 하면 walk(NULL) → NULL deref → panic:kerneltrap.
  //   죽었으면 슬롯만 회수(누수 방지)하고 탈출. 이 페이지(pa)는 freeproc 의 uvmunmap
  //   이 이미 kfree 했으므로 여기서 kfree 하면 double free → Phase 4 도달 전에 return.
  if(p->pagetable == 0 || p->state == UNUSED || p->state == ZOMBIE){
    release(&p->lock);
    swap_free_slot(slot);
    return -1;
  }

  pte_t *pte2 = walk(p->pagetable, va, 0);
  if(pte2 == 0 || !(*pte2 & PTE_V) || PTE2PA(*pte2) != pa){
    // I/O 중 프로세스 상태 변경(또는 proc 재사용) — 중단
    release(&p->lock);
    swap_free_slot(slot);
    return -1;
  }
  *pte2 = MAKE_SWAP_PTE(slot);
  sfence_vma();

  // 성공한 swap-out 횟수 기록
  p->swapout_count++;

  release(&p->lock);

  // Phase 4: 물리 페이지 반환
  kfree((void*)pa);
  return 0;
}


// --- swapout_proc: pid 검증 후 1페이지 swapout ---
//
// sys_swapout이 호출. swapout_one_page가 lock을 내부 관리하므로
// 여기서는 pid 검증 후 p->lock을 해제하고 호출한다.
int
swapout_proc(int pid)
{
  struct proc *p;
  extern struct proc proc[NPROC];

  for(p = proc; p < &proc[NPROC]; p++){
    acquire(&p->lock);
    if(p->pid != pid){
      release(&p->lock);
      continue;
    }
    if(p->state == UNUSED || p->state == ZOMBIE){
      release(&p->lock);
      return -1;
    }
    if(is_protected_proc(p)){
      release(&p->lock);
      return -1;
    }
    release(&p->lock);   // swapout_one_page가 내부에서 lock 관리
    return swapout_one_page(p);
  }
  return -1;                             // pid 없음
}


// ============================================================
// 4) Swapin — 디스크에서 페이지를 다시 읽어 PTE 복구
// ============================================================
//
// vmfault()에서 IS_SWAPPED(*pte) 케이스로 진입 시 호출.
// va는 이미 PGROUNDDOWN 되어있다고 가정.
int
swapin_page(pagetable_t pt, uint64 va)
{
  pte_t *pte;
  char *mem;
  int slot;
  uint64 perm;

  // vmfault에서 walk(.., 1)로 leaf table 보장됨
  pte = walk(pt, va, 0);
  if(pte == 0)
    return -1;

  if(!IS_SWAPPED(*pte))
    return -1;

  slot = PTE_TO_SWAP_SLOT(*pte);

  // 물리 페이지 확보
  mem = kalloc();
  if(mem == 0)
    return -1;                           // 호출자가 setkilled 또는 다른 정책

  // 디스크 read
  if(swap_read_slot(slot, mem) < 0){
    kfree(mem);
    return -1;
  }

  // PTE 갱신: V=1, PPN=새 물리주소
  // (지금은 권한을 R|W|U로 고정 복구 — 코드 페이지 X bit는 미지원)
  perm = PTE_R | PTE_W | PTE_U;
  *pte = PA2PTE(mem) | perm | PTE_V;

  // 슬롯 해제
  swap_free_slot(slot);

  sfence_vma();                          // TLB flush 필수

  // 통계 (proc.h에 필드 추가했다면)
  // myproc()->swapin_count++;
  return 0;
}
