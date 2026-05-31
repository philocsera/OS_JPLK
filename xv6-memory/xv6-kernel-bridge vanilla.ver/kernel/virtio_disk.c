//
// kernel/virtio_disk.c  —  two-disk version (fs.img + swap.img)
//
// vanilla MIT xv6-riscv (VIRTIO MMIO v2) 기반.
// 변경 요지:
//   - struct disk 단일 전역  →  struct disk disk[NVIRTIO]  (배열)
//   - 모든 mmio 접근 매크로가 idx별 base 주소를 받음
//   - virtio_disk_init(void)  →  virtio_disk_init(int dev)
//   - virtio_disk_rw()가 b->dev로 disk[] 인덱스 선택
//   - virtio_disk_intr(int dev)로 디바이스별 인터럽트 처리
//
// dev 매핑:  dev=1 → idx 0 → VIRTIO0,   dev=2 → idx 1 → VIRTIO1
//
// ★ swap 디바이스(dev=2) I/O는 폴링 방식 (sleep 없음):
//   swapin/swapout은 uvmcopy, copyin/copyout 등 spinlock을 든 커널
//   경로에서 호출될 수 있다. 그 상태에서 sleep하면 noff>1 →
//   "sched locks" panic. 따라서 swap 디바이스 요청은 sleep 대신
//   used ring을 폴링해 완료를 기다린다 (virtio_disk_poll).
//   fs 디바이스(dev=1)는 기존 sleep+인터럽트 방식 유지.
//

#include "types.h"
#include "riscv.h"
#include "defs.h"
#include "param.h"
#include "memlayout.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "fs.h"
#include "buf.h"
#include "virtio.h"

#define NVIRTIO 2   // 지원하는 virtio 디스크 개수

// idx(0/1)를 mmio base 주소로 변환
static uint64
virtio_base(int idx)
{
  if(idx == 0) return VIRTIO0;
  if(idx == 1) return VIRTIO1;
  panic("virtio_base: bad idx");
  return 0;
}

// dev 번호(buf->dev: 1 또는 2)를 disk[] 인덱스(0 또는 1)로 변환
static int
dev_to_idx(int dev)
{
  if(dev == 1) return 0;   // ROOTDEV → VIRTIO0
  if(dev == 2) return 1;   // SWAPDEV → VIRTIO1
  panic("virtio dev_to_idx: bad dev");
  return -1;
}

// idx별 mmio 레지스터 접근.
// vanilla의 R(r) 매크로가 고정 base를 쓰던 것을 idx 인자 버전으로 교체.
#define R(idx, r) ((volatile uint32 *)(virtio_base(idx) + (r)))

// 디스크 한 대의 상태. vanilla의 struct disk 와 동일한 필드 구성.
static struct disk {
  // DMA 디스크립터 3종 (페이지 단위 kalloc).
  struct virtq_desc *desc;
  struct virtq_avail *avail;
  struct virtq_used *used;

  // free[i]: 디스크립터 i가 비어있는가
  char free[NUM];
  uint16 used_idx;   // used 링에서 우리가 본 위치

  // 진행 중인 작업 추적 (인터럽트 핸들러에 정보 전달)
  struct {
    struct buf *b;
    char status;
  } info[NUM];

  // virtio_blk_req 헤더 (디스크립터당 1개)
  struct virtio_blk_req ops[NUM];

  struct spinlock vdisk_lock;

  int initialized;   // 이 슬롯이 init 됐는지
} disk[NVIRTIO];


// ============================================================
// 초기화 — dev(1 또는 2)별로 한 번씩 호출됨
// ============================================================
void
virtio_disk_init(int dev)
{
  uint32 status = 0;
  int idx = dev_to_idx(dev);
  struct disk *d = &disk[idx];

  {
    // lock 이름은 디바이스별로 구분 (디버깅 편의)
    initlock(&d->vdisk_lock,
             idx == 0 ? "virtio_disk0" : "virtio_disk1");
  }

  if(*R(idx, VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
     *R(idx, VIRTIO_MMIO_VERSION) != 2 ||
     *R(idx, VIRTIO_MMIO_DEVICE_ID) != 2 ||
     *R(idx, VIRTIO_MMIO_VENDOR_ID) != 0x554d4551){
    panic("could not find virtio disk");
  }

  // reset device
  *R(idx, VIRTIO_MMIO_STATUS) = status;

  // set ACKNOWLEDGE status bit
  status |= VIRTIO_CONFIG_S_ACKNOWLEDGE;
  *R(idx, VIRTIO_MMIO_STATUS) = status;

  // set DRIVER status bit
  status |= VIRTIO_CONFIG_S_DRIVER;
  *R(idx, VIRTIO_MMIO_STATUS) = status;

  // negotiate features
  uint64 features = *R(idx, VIRTIO_MMIO_DEVICE_FEATURES);
  features &= ~(1 << VIRTIO_BLK_F_RO);
  features &= ~(1 << VIRTIO_BLK_F_SCSI);
  features &= ~(1 << VIRTIO_BLK_F_CONFIG_WCE);
  features &= ~(1 << VIRTIO_BLK_F_MQ);
  features &= ~(1 << VIRTIO_F_ANY_LAYOUT);
  features &= ~(1 << VIRTIO_RING_F_EVENT_IDX);
  features &= ~(1 << VIRTIO_RING_F_INDIRECT_DESC);
  *R(idx, VIRTIO_MMIO_DRIVER_FEATURES) = features;

  // tell device that feature negotiation is complete.
  status |= VIRTIO_CONFIG_S_FEATURES_OK;
  *R(idx, VIRTIO_MMIO_STATUS) = status;

  // re-read status to ensure FEATURES_OK is set.
  status = *R(idx, VIRTIO_MMIO_STATUS);
  if(!(status & VIRTIO_CONFIG_S_FEATURES_OK))
    panic("virtio disk FEATURES_OK unset");

  // initialize queue 0.
  *R(idx, VIRTIO_MMIO_QUEUE_SEL) = 0;

  // ensure queue 0 is not in use.
  if(*R(idx, VIRTIO_MMIO_QUEUE_READY))
    panic("virtio disk should not be ready");

  // check maximum queue size.
  uint32 max = *R(idx, VIRTIO_MMIO_QUEUE_NUM_MAX);
  if(max == 0)
    panic("virtio disk has no queue 0");
  if(max < NUM)
    panic("virtio disk max queue too short");

  // allocate and zero queue memory.
  d->desc  = kalloc();
  d->avail = kalloc();
  d->used  = kalloc();
  if(!d->desc || !d->avail || !d->used)
    panic("virtio disk kalloc");
  memset(d->desc,  0, PGSIZE);
  memset(d->avail, 0, PGSIZE);
  memset(d->used,  0, PGSIZE);

  // set queue size.
  *R(idx, VIRTIO_MMIO_QUEUE_NUM) = NUM;

  // write physical addresses.
  *R(idx, VIRTIO_MMIO_QUEUE_DESC_LOW)    = (uint64)d->desc;
  *R(idx, VIRTIO_MMIO_QUEUE_DESC_HIGH)   = (uint64)d->desc >> 32;
  *R(idx, VIRTIO_MMIO_DRIVER_DESC_LOW)   = (uint64)d->avail;
  *R(idx, VIRTIO_MMIO_DRIVER_DESC_HIGH)  = (uint64)d->avail >> 32;
  *R(idx, VIRTIO_MMIO_DEVICE_DESC_LOW)   = (uint64)d->used;
  *R(idx, VIRTIO_MMIO_DEVICE_DESC_HIGH)  = (uint64)d->used >> 32;

  // queue is ready.
  *R(idx, VIRTIO_MMIO_QUEUE_READY) = 0x1;

  // all NUM descriptors start out unused.
  for(int i = 0; i < NUM; i++)
    d->free[i] = 1;

  // tell device we're completely ready.
  status |= VIRTIO_CONFIG_S_DRIVER_OK;
  *R(idx, VIRTIO_MMIO_STATUS) = status;

  d->initialized = 1;
}


// ============================================================
// 디스크립터 할당/해제 — 디바이스별 disk *d 를 받음
// ============================================================

// find a free descriptor, mark it non-free, return its index.
static int
alloc_desc(struct disk *d)
{
  for(int i = 0; i < NUM; i++){
    if(d->free[i]){
      d->free[i] = 0;
      return i;
    }
  }
  return -1;
}

// mark a descriptor as free.
static void
free_desc(struct disk *d, int i)
{
  if(i >= NUM)
    panic("free_desc 1");
  if(d->free[i])
    panic("free_desc 2");
  d->desc[i].addr = 0;
  d->desc[i].len = 0;
  d->desc[i].flags = 0;
  d->desc[i].next = 0;
  d->free[i] = 1;
  wakeup(&d->free[0]);
}

// free a chain of descriptors.
static void
free_chain(struct disk *d, int i)
{
  while(1){
    int flag = d->desc[i].flags;
    int nxt = d->desc[i].next;
    free_desc(d, i);
    if(flag & VRING_DESC_F_NEXT)
      i = nxt;
    else
      break;
  }
}

// allocate three descriptors (they need not be contiguous).
// disk transfers always use three descriptors.
static int
alloc3_desc(struct disk *d, int *idx)
{
  for(int i = 0; i < 3; i++){
    idx[i] = alloc_desc(d);
    if(idx[i] < 0){
      for(int j = 0; j < i; j++)
        free_desc(d, idx[j]);
      return -1;
    }
  }
  return 0;
}


// ============================================================
// 폴링 — used ring을 직접 확인해 완료 처리 (sleep 없음)
//
// swap 디바이스 전용. virtio_disk_intr()이 인터럽트 문맥에서 하던 일을
// sleep 없이 그대로 수행한다. 호출자가 spinlock(vdisk_lock 포함)을
// 들고 있어도 안전 — sleep을 호출하지 않으므로 noff 검사에 안 걸린다.
//
// 호출자가 d->vdisk_lock 을 잡고 있어야 함.
// ============================================================
static void
virtio_disk_poll(struct disk *d, int idx)
{
  // 디바이스가 INTERRUPT_STATUS 비트를 세웠으면 ACK.
  // 폴링이라 인터럽트를 안 기다리지만, 비트를 안 지우면 디바이스가
  // 다음 인터럽트를 안 올리므로(인터럽트도 켜져 있다면) 정리해 둠.
  uint32 istat = *R(idx, VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;
  if(istat)
    *R(idx, VIRTIO_MMIO_INTERRUPT_ACK) = istat;

  __sync_synchronize();

  // 디바이스가 used ring에 완료 항목을 추가했으면 처리.
  while(d->used_idx != d->used->idx){
    __sync_synchronize();
    int id = d->used->ring[d->used_idx % NUM].id;

    if(d->info[id].status != 0)
      panic("virtio_disk_poll status");

    struct buf *b = d->info[id].b;
    b->disk = 0;   // disk is done with buf
    // wakeup 불필요 — 폴링 측이 b->disk를 직접 확인하므로.

    d->used_idx += 1;
  }
}


// ============================================================
// 디스크 읽기/쓰기 — b->dev 로 디바이스 라우팅
//
// dev=1 (fs.img)   : 기존 sleep 방식 (인터럽트가 깨움)
// dev=2 (swap.img) : 폴링 방식 (sleep 없음)
//   → swapin/swapout이 spinlock 보유 커널 경로(uvmcopy, copyout 등)에서
//     호출되어도 "sched locks" panic이 나지 않는다.
// ============================================================
void
virtio_disk_rw(struct buf *b, int write)
{
  uint64 sector = b->blockno * (BSIZE / 512);

  int idx = dev_to_idx(b->dev);
  struct disk *d = &disk[idx];

  // swap 디바이스(dev=2)는 폴링 경로 — sleep을 일절 쓰지 않는다.
  // (SWAPDEV 매크로는 swap.h에 있지만, virtio_disk.c는 swap.h를
  //  include하지 않으므로 숫자 2를 직접 사용. dev_to_idx와 같은 규약.)
  int polling = (b->dev == 2);

  if(!d->initialized)
    panic("virtio_disk_rw: device not initialized");

  acquire(&d->vdisk_lock);

  // the spec's Section 5.2 says that legacy block operations use
  // three descriptors: one for type/reserved/sector, one for the
  // data, one for a 1-byte status result.

  int desc_idx[3];
  while(1){
    if(alloc3_desc(d, desc_idx) == 0)
      break;
    if(polling){
      // 폴링 경로: 디스크립터가 빌 때까지 sleep 대신 폴링.
      // 진행 중인 요청이 완료되면 free_chain이 디스크립터를 돌려준다.
      virtio_disk_poll(d, idx);
    } else {
      sleep(&d->free[0], &d->vdisk_lock);
    }
  }

  // format the three descriptors.
  struct virtio_blk_req *buf0 = &d->ops[desc_idx[0]];

  if(write)
    buf0->type = VIRTIO_BLK_T_OUT; // write the disk
  else
    buf0->type = VIRTIO_BLK_T_IN;  // read the disk
  buf0->reserved = 0;
  buf0->sector = sector;

  d->desc[desc_idx[0]].addr = (uint64)buf0;
  d->desc[desc_idx[0]].len = sizeof(struct virtio_blk_req);
  d->desc[desc_idx[0]].flags = VRING_DESC_F_NEXT;
  d->desc[desc_idx[0]].next = desc_idx[1];

  d->desc[desc_idx[1]].addr = (uint64)b->data;
  d->desc[desc_idx[1]].len = BSIZE;
  if(write)
    d->desc[desc_idx[1]].flags = 0;           // device reads b->data
  else
    d->desc[desc_idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
  d->desc[desc_idx[1]].flags |= VRING_DESC_F_NEXT;
  d->desc[desc_idx[1]].next = desc_idx[2];

  d->info[desc_idx[0]].status = 0xff; // device writes 0 on success
  d->desc[desc_idx[2]].addr = (uint64)&d->info[desc_idx[0]].status;
  d->desc[desc_idx[2]].len = 1;
  d->desc[desc_idx[2]].flags = VRING_DESC_F_WRITE; // device writes the status
  d->desc[desc_idx[2]].next = 0;

  // record struct buf for virtio_disk_intr().
  b->disk = 1;
  d->info[desc_idx[0]].b = b;

  // tell the device the first index in our chain of descriptors.
  d->avail->ring[d->avail->idx % NUM] = desc_idx[0];

  __sync_synchronize();

  // tell the device another avail ring entry is available.
  d->avail->idx += 1;

  __sync_synchronize();

  *R(idx, VIRTIO_MMIO_QUEUE_NOTIFY) = 0; // value is queue number

  // 요청 완료 대기.
  if(polling){
    // 폴링 경로: sleep 없이 used ring을 직접 확인.
    // vdisk_lock을 든 채로 돌지만 sleep을 안 하므로 noff 문제 없음.
    while(b->disk == 1){
      virtio_disk_poll(d, idx);
    }
  } else {
    // 기존 경로: 인터럽트(virtio_disk_intr)가 깨워줄 때까지 sleep.
    while(b->disk == 1){
      sleep(b, &d->vdisk_lock);
    }
  }

  d->info[desc_idx[0]].b = 0;
  free_chain(d, desc_idx[0]);

  release(&d->vdisk_lock);
}


// ============================================================
// 인터럽트 핸들러 — dev(1 또는 2)별로 호출됨
//
// dev=1 (fs.img)  : 정상 경로. used ring 처리 + wakeup.
// dev=2 (swap.img): 폴링 경로라 보통 여기 안 옴. 하지만 PLIC에 IRQ가
//                   등록돼 있어 인터럽트가 들어올 수는 있음.
//                   그 경우 INTERRUPT_ACK만 하고, used ring 처리는
//                   virtio_disk_poll과 중복돼도 무해하도록 둠
//                   (이미 처리된 항목은 used_idx 비교에서 걸러짐).
// ============================================================
void
virtio_disk_intr(int dev)
{
  int idx = dev_to_idx(dev);
  struct disk *d = &disk[idx];

  acquire(&d->vdisk_lock);

  // the device won't raise another interrupt until we tell it
  // we've seen this interrupt, which the following line does.
  *R(idx, VIRTIO_MMIO_INTERRUPT_ACK) =
      *R(idx, VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;

  __sync_synchronize();

  // the device increments disk.used->idx when it
  // adds an entry to the used ring.
  while(d->used_idx != d->used->idx){
    __sync_synchronize();
    int id = d->used->ring[d->used_idx % NUM].id;

    if(d->info[id].status != 0)
      panic("virtio_disk_intr status");

    struct buf *b = d->info[id].b;
    b->disk = 0;   // disk is done with buf
    wakeup(b);     // sleep 경로(fs)를 위해. 폴링 경로는 b->disk만 봄.

    d->used_idx += 1;
  }

  release(&d->vdisk_lock);
}
