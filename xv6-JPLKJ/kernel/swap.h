#ifndef XV6_SWAP_H
#define XV6_SWAP_H

// ============================================================
// swap.h — xv6 swap 서브시스템 인터페이스
//
// 디스크 레이아웃 (SWAPDEV=2, virtio 두 번째 디스크):
//   slot i 는 디스크 블록 [i*BLOCKS_PER_PAGE .. (i+1)*BLOCKS_PER_PAGE) 에 저장
//   BLOCKS_PER_PAGE = PGSIZE / BSIZE = 4096 / 1024 = 8
//   NSWAP=16384 슬롯 → 16384 * 4KB = 64MB swap area (Makefile swap.img dd count=64와 일치 필수)
//
// PTE 인코딩:
//   swap된 PTE:  V=0,  U=1,  PPN자리 = swap slot 번호
//   lazy PTE:    *pte == 0
//   invalid:     그 외 V=0 PTE
//
// 호출 체인:
//   LLM JSON action="swapout"
//     → memhint.c (verifier)
//     → swapout(pid) syscall
//     → sys_swapout → swapout_proc → swapout_one_page
//     → select_victim → swap_alloc_slot → swap_write_slot → kfree
//
//   page fault on swapped page
//     → vmfault → swapin_page
//     → kalloc → swap_read_slot → swap_free_slot → PTE 복구
// ============================================================

// ---------- swap slot pool 설정 ----------
#define NSWAP            16384            // 슬롯 개수 (= 64MB swap area; Makefile dd count=64와 일치)
#define SWAPDEV          2                // virtio 두 번째 디스크
#define BLOCKS_PER_PAGE  (PGSIZE / BSIZE) // 페이지당 디스크 블록 수

// ---------- victim 선택 알고리즘 ----------
// 0 = 단순 (첫 user page),  1 = A bit Clock
// Makefile에서 -DSWAP_VICTIM_CLOCK=1 로 전환
#ifndef SWAP_VICTIM_CLOCK
#define SWAP_VICTIM_CLOCK 0
#endif

// ---------- PTE 인코딩 매크로 ----------
#define PTE_SWAP_SHIFT  10
// bit8 = RSW[0]: swap 마커 (slot 0도 구분 가능하게)
#define PTE_SWAP_MARK   (1L << 8)
#define MAKE_SWAP_PTE(slot)   (((uint64)(slot) << PTE_SWAP_SHIFT) | PTE_U | PTE_SWAP_MARK)
#define PTE_TO_SWAP_SLOT(pte) ((int)((pte) >> PTE_SWAP_SHIFT))

// 핵심 분류 매크로 — vm.c, trap.c, swap.c 모두 공통으로 사용
#define IS_SWAPPED(pte)  (((pte) & PTE_V) == 0 && ((pte) & PTE_SWAP_MARK) != 0)
#define IS_LAZY(pte)     ((pte) == 0)

// ---------- 함수 prototype ----------
struct proc;

// slot 관리
void swapinit(void);
int  swap_alloc_slot(void);
void swap_free_slot(int slot);
int  swap_write_slot(int slot, char *page);
int  swap_read_slot(int slot, char *page);
int  swap_used_slots(void);
int  swap_total_slots(void);

// swapout / swapin 상위 API
int  swapout_proc(int pid);
int  swapout_one_page(struct proc *p);
int  swapin_page(pagetable_t pt, uint64 va);

#endif
