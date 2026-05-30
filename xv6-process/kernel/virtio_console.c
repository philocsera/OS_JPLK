//
// driver for qemu's virtio-console (virtio-serial) device — the dedicated
// host<->guest advisor channel (report Plan A). Separate MMIO slot from the
// disk so the LLM-advisor protocol no longer shares the UART console.
//
// qemu ... -global virtio-mmio.force-legacy=false
//   -chardev socket,path=/tmp/xv6bridge.sock,server=on,wait=off,id=br0
//   -device virtio-serial-device,bus=virtio-mmio-bus.1
//   -device virtconsole,chardev=br0
//
// We deliberately do NOT negotiate VIRTIO_CONSOLE_F_MULTIPORT, so the device
// degrades to a single legacy console using just two virtqueues:
//   queue 0 = receiveq  (host -> guest)
//   queue 1 = transmitq (guest -> host)
// and there is no control queue to service.
//
// Exposed to user space as the device file /advisor (major ADVISOR): the advd
// daemon writes @@WL frames out the transmitq and reads back setcls/setjprio
// command lines from the receiveq. Reads are line-at-a-time, like the console.
//

#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "fs.h"
#include "file.h"
#include "proc.h"
#include "defs.h"
#include "virtio.h"

// the address of virtio-console mmio register r.
#define R(r) ((volatile uint32 *)(VIRTIO1 + (r)))

// virtio-console queue indices (non-multiport).
#define VCON_RXQ 0
#define VCON_TXQ 1

#define VCON_BUFSZ   256   // per-descriptor DMA buffer size
#define VCON_INBUF   1024  // kernel input ring drained by reads

// one transmit/receive virtqueue.
struct vcon_q {
  struct virtq_desc *desc;
  struct virtq_avail *avail;
  struct virtq_used *used;
  char free[NUM];   // is descriptor i available for the driver to use?
  uint16 used_idx;  // how far we've consumed the device's used ring
};

static struct {
  struct spinlock lock;

  struct vcon_q tx;
  struct vcon_q rx;

  char rxbuf[NUM][VCON_BUFSZ];  // device writes inbound bytes here
  char txbuf[NUM][VCON_BUFSZ];  // we stage outbound bytes here
  char txdone[NUM];             // tx descriptor i completed?

  // input ring: filled by the rx interrupt, drained by virtio_console_read.
  char in[VCON_INBUF];
  uint in_r;  // read index
  uint in_w;  // write index
} vcon;

// 0 until the device is found and its queues are live. When the virtio-console
// device is absent (a plain QEMU with no virtio-serial device, e.g.
// tools/diagnose.py), the kernel still boots and /advisor read/write just
// return -1 — the advisor channel is best-effort, never mandatory.
static int vcon_ready = 0;

// the address of virtio-console mmio register r is via R(); below configures
// one virtqueue (qidx) and allocates its in-memory rings.
static void
vcon_queue_init(int qidx, struct vcon_q *q)
{
  *R(VIRTIO_MMIO_QUEUE_SEL) = qidx;

  if(*R(VIRTIO_MMIO_QUEUE_READY))
    panic("virtio console queue should not be ready");

  uint32 max = *R(VIRTIO_MMIO_QUEUE_NUM_MAX);
  if(max == 0)
    panic("virtio console has no such queue");
  if(max < NUM)
    panic("virtio console max queue too short");

  q->desc = kalloc();
  q->avail = kalloc();
  q->used = kalloc();
  if(!q->desc || !q->avail || !q->used)
    panic("virtio console kalloc");
  memset(q->desc, 0, PGSIZE);
  memset(q->avail, 0, PGSIZE);
  memset(q->used, 0, PGSIZE);

  *R(VIRTIO_MMIO_QUEUE_NUM) = NUM;

  *R(VIRTIO_MMIO_QUEUE_DESC_LOW) = (uint64)q->desc;
  *R(VIRTIO_MMIO_QUEUE_DESC_HIGH) = (uint64)q->desc >> 32;
  *R(VIRTIO_MMIO_DRIVER_DESC_LOW) = (uint64)q->avail;
  *R(VIRTIO_MMIO_DRIVER_DESC_HIGH) = (uint64)q->avail >> 32;
  *R(VIRTIO_MMIO_DEVICE_DESC_LOW) = (uint64)q->used;
  *R(VIRTIO_MMIO_DEVICE_DESC_HIGH) = (uint64)q->used >> 32;

  *R(VIRTIO_MMIO_QUEUE_READY) = 0x1;

  for(int i = 0; i < NUM; i++)
    q->free[i] = 1;
  q->used_idx = 0;
}

// hand receive descriptor i to the device so it can deliver inbound bytes.
// caller holds vcon.lock.
static void
vcon_post_rx(int i)
{
  struct vcon_q *q = &vcon.rx;
  q->desc[i].addr = (uint64)vcon.rxbuf[i];
  q->desc[i].len = VCON_BUFSZ;
  q->desc[i].flags = VRING_DESC_F_WRITE;  // device writes into our buffer
  q->desc[i].next = 0;
  q->free[i] = 0;  // owned by the device until it completes

  q->avail->ring[q->avail->idx % NUM] = i;
  __sync_synchronize();
  q->avail->idx += 1;
  __sync_synchronize();
  *R(VIRTIO_MMIO_QUEUE_NOTIFY) = VCON_RXQ;
}

// find a free transmit descriptor, or -1. caller holds vcon.lock.
static int
vcon_alloc_tx(void)
{
  for(int i = 0; i < NUM; i++){
    if(vcon.tx.free[i]){
      vcon.tx.free[i] = 0;
      return i;
    }
  }
  return -1;
}

int virtio_console_read(int user_dst, uint64 dst, int n);
int virtio_console_write(int user_src, uint64 src, int n);

void
virtio_console_init(void)
{
  uint32 status = 0;

  initlock(&vcon.lock, "vcon");

  // Expose /advisor up front so opening it never dereferences a null devsw
  // entry, even when the device is absent (read/write guard on vcon_ready).
  devsw[ADVISOR].read = virtio_console_read;
  devsw[ADVISOR].write = virtio_console_write;

  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
     *R(VIRTIO_MMIO_VERSION) != 2 ||
     *R(VIRTIO_MMIO_DEVICE_ID) != 3 ||      // 3 == console
     *R(VIRTIO_MMIO_VENDOR_ID) != 0x554d4551){
    // No virtio-console on this QEMU — boot anyway, channel stays disabled.
    printf("virtio console: device absent; advisor channel disabled\n");
    return;
  }

  *R(VIRTIO_MMIO_STATUS) = status;
  status |= VIRTIO_CONFIG_S_ACKNOWLEDGE;
  *R(VIRTIO_MMIO_STATUS) = status;
  status |= VIRTIO_CONFIG_S_DRIVER;
  *R(VIRTIO_MMIO_STATUS) = status;

  // negotiate features: accept NONE of the console features. In particular
  // leave MULTIPORT off so the device is a simple two-queue console.
  uint64 features = *R(VIRTIO_MMIO_DEVICE_FEATURES);
  features &= ~(1 << VIRTIO_CONSOLE_F_SIZE);
  features &= ~(1 << VIRTIO_CONSOLE_F_MULTIPORT);
  features &= ~(1 << VIRTIO_CONSOLE_F_EMERG_WRITE);
  features &= ~(1 << VIRTIO_F_ANY_LAYOUT);
  features &= ~(1 << VIRTIO_RING_F_EVENT_IDX);
  features &= ~(1 << VIRTIO_RING_F_INDIRECT_DESC);
  *R(VIRTIO_MMIO_DRIVER_FEATURES) = features;

  status |= VIRTIO_CONFIG_S_FEATURES_OK;
  *R(VIRTIO_MMIO_STATUS) = status;

  status = *R(VIRTIO_MMIO_STATUS);
  if(!(status & VIRTIO_CONFIG_S_FEATURES_OK))
    panic("virtio console FEATURES_OK unset");

  vcon_queue_init(VCON_RXQ, &vcon.rx);
  vcon_queue_init(VCON_TXQ, &vcon.tx);

  status |= VIRTIO_CONFIG_S_DRIVER_OK;
  *R(VIRTIO_MMIO_STATUS) = status;

  // pre-post all receive buffers so the device can deliver inbound bytes.
  acquire(&vcon.lock);
  for(int i = 0; i < NUM; i++)
    vcon_post_rx(i);
  release(&vcon.lock);

  vcon_ready = 1;   // queues live — /advisor read/write now operate for real
}

// user write() to /advisor: transmit n bytes out the transmitq. Blocks until
// the device has consumed each chunk (interrupt-driven).
int
virtio_console_write(int user_src, uint64 src, int n)
{
  int total = 0;

  if(!vcon_ready)
    return -1;   // no device — advisor channel disabled

  acquire(&vcon.lock);
  while(total < n){
    int idx;
    // wait for a tx descriptor to free up. Stay killable: tx completion is
    // driven by the EXTERNAL host peer (the bridge draining the socket), so a
    // stalled/backpressured host must not make this process unkillable —
    // mirror the killed() check virtio_console_read/consoleread use.
    while((idx = vcon_alloc_tx()) < 0){
      if(killed(myproc())){
        release(&vcon.lock);
        return total;   // nothing owned yet; safe to abandon
      }
      sleep(&vcon.tx, &vcon.lock);
    }

    int chunk = n - total;
    if(chunk > VCON_BUFSZ)
      chunk = VCON_BUFSZ;
    if(either_copyin(vcon.txbuf[idx], user_src, src + total, chunk) < 0){
      vcon.tx.free[idx] = 1;
      break;
    }

    struct vcon_q *q = &vcon.tx;
    vcon.txdone[idx] = 0;
    q->desc[idx].addr = (uint64)vcon.txbuf[idx];
    q->desc[idx].len = chunk;
    q->desc[idx].flags = 0;   // device reads our buffer (guest -> host)
    q->desc[idx].next = 0;

    q->avail->ring[q->avail->idx % NUM] = idx;
    __sync_synchronize();
    q->avail->idx += 1;
    __sync_synchronize();
    *R(VIRTIO_MMIO_QUEUE_NOTIFY) = VCON_TXQ;

    while(vcon.txdone[idx] == 0){
      if(killed(myproc())){
        // idx is in flight (device-owned); leave it for the tx interrupt to
        // free. Just stop blocking so we can return to user space and die.
        release(&vcon.lock);
        return total;
      }
      sleep(&vcon.tx, &vcon.lock);   // wait for transmit completion
    }

    total += chunk;
  }
  release(&vcon.lock);

  return total;
}

// user read() from /advisor: copy up to a whole input line to dst, like the
// console. Returns the number of bytes copied.
int
virtio_console_read(int user_dst, uint64 dst, int n)
{
  int target = n;
  char c;

  if(!vcon_ready)
    return -1;   // no device — advisor channel disabled

  acquire(&vcon.lock);
  while(n > 0){
    while(vcon.in_r == vcon.in_w){
      if(killed(myproc())){
        release(&vcon.lock);
        return -1;
      }
      sleep(&vcon.in_r, &vcon.lock);
    }

    c = vcon.in[vcon.in_r++ % VCON_INBUF];

    if(either_copyout(user_dst, dst, &c, 1) < 0)
      break;
    dst++;
    n--;

    if(c == '\n')
      break;
  }
  release(&vcon.lock);

  return target - n;
}

// device interrupt: service both rings — rx (inbound bytes) and tx (completed
// transmits). Called from devintr() for VIRTIO1_IRQ.
void
virtio_console_intr(void)
{
  if(!vcon_ready)
    return;   // spurious — device never initialized

  acquire(&vcon.lock);

  // let the device raise further interrupts.
  *R(VIRTIO_MMIO_INTERRUPT_ACK) = *R(VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;
  __sync_synchronize();

  // inbound bytes: drain completed rx descriptors into the input ring,
  // then re-post each buffer to the device.
  struct vcon_q *rxq = &vcon.rx;
  int woke_reader = 0;
  while(rxq->used_idx != rxq->used->idx){
    __sync_synchronize();
    int id = rxq->used->ring[rxq->used_idx % NUM].id;
    int len = rxq->used->ring[rxq->used_idx % NUM].len;
    if(len > VCON_BUFSZ)
      len = VCON_BUFSZ;
    for(int j = 0; j < len; j++){
      if(vcon.in_w - vcon.in_r < VCON_INBUF)
        vcon.in[vcon.in_w++ % VCON_INBUF] = vcon.rxbuf[id][j];
      // else: ring full, drop (host should not outrun a line-based reader)
    }
    rxq->used_idx += 1;
    vcon_post_rx(id);
    woke_reader = 1;
  }
  if(woke_reader)
    wakeup(&vcon.in_r);

  // outbound completions: mark transmit descriptors free and wake writers.
  struct vcon_q *txq = &vcon.tx;
  int woke_writer = 0;
  while(txq->used_idx != txq->used->idx){
    __sync_synchronize();
    int id = txq->used->ring[txq->used_idx % NUM].id;
    txq->free[id] = 1;
    vcon.txdone[id] = 1;
    txq->used_idx += 1;
    woke_writer = 1;
  }
  if(woke_writer)
    wakeup(&vcon.tx);

  release(&vcon.lock);
}
