
kernel/kernel:     file format elf64-littleriscv


Disassembly of section .text:

0000000080000000 <_entry>:
_entry:
        # set up a stack for C.
        # stack0 is declared in start.c,
        # with a 4096-byte stack per CPU.
        # sp = stack0 + ((hartid + 1) * 4096)
        la sp, stack0
    80000000:	0000a117          	auipc	sp,0xa
    80000004:	48813103          	ld	sp,1160(sp) # 8000a488 <_GLOBAL_OFFSET_TABLE_+0x8>
        li a0, 1024*4
    80000008:	6505                	lui	a0,0x1
        csrr a1, mhartid
    8000000a:	f14025f3          	csrr	a1,mhartid
        addi a1, a1, 1
    8000000e:	0585                	addi	a1,a1,1
        mul a0, a0, a1
    80000010:	02b50533          	mul	a0,a0,a1
        add sp, sp, a0
    80000014:	912a                	add	sp,sp,a0
        # jump to start() in start.c
        call start
    80000016:	04a000ef          	jal	80000060 <start>

000000008000001a <spin>:
spin:
        j spin
    8000001a:	a001                	j	8000001a <spin>

000000008000001c <timerinit>:
}

// ask each hart to generate timer interrupts.
void
timerinit()
{
    8000001c:	1141                	addi	sp,sp,-16
    8000001e:	e422                	sd	s0,8(sp)
    80000020:	0800                	addi	s0,sp,16
#define MIE_STIE (1L << 5)  // supervisor timer
static inline uint64
r_mie()
{
  uint64 x;
  asm volatile("csrr %0, mie" : "=r" (x) );
    80000022:	304027f3          	csrr	a5,mie
  // enable supervisor-mode timer interrupts.
  w_mie(r_mie() | MIE_STIE);
    80000026:	0207e793          	ori	a5,a5,32
}

static inline void 
w_mie(uint64 x)
{
  asm volatile("csrw mie, %0" : : "r" (x));
    8000002a:	30479073          	csrw	mie,a5
static inline uint64
r_menvcfg()
{
  uint64 x;
  // asm volatile("csrr %0, menvcfg" : "=r" (x) );
  asm volatile("csrr %0, 0x30a" : "=r" (x) );
    8000002e:	30a027f3          	csrr	a5,0x30a
  
  // enable the sstc extension (i.e. stimecmp).
  w_menvcfg(r_menvcfg() | (1L << 63)); 
    80000032:	577d                	li	a4,-1
    80000034:	177e                	slli	a4,a4,0x3f
    80000036:	8fd9                	or	a5,a5,a4

static inline void 
w_menvcfg(uint64 x)
{
  // asm volatile("csrw menvcfg, %0" : : "r" (x));
  asm volatile("csrw 0x30a, %0" : : "r" (x));
    80000038:	30a79073          	csrw	0x30a,a5

static inline uint64
r_mcounteren()
{
  uint64 x;
  asm volatile("csrr %0, mcounteren" : "=r" (x) );
    8000003c:	306027f3          	csrr	a5,mcounteren
  
  // allow supervisor to use stimecmp and time.
  w_mcounteren(r_mcounteren() | 2);
    80000040:	0027e793          	ori	a5,a5,2
  asm volatile("csrw mcounteren, %0" : : "r" (x));
    80000044:	30679073          	csrw	mcounteren,a5
// machine-mode cycle counter
static inline uint64
r_time()
{
  uint64 x;
  asm volatile("csrr %0, time" : "=r" (x) );
    80000048:	c01027f3          	rdtime	a5
  
  // ask for the very first timer interrupt.
  w_stimecmp(r_time() + 1000000);
    8000004c:	000f4737          	lui	a4,0xf4
    80000050:	24070713          	addi	a4,a4,576 # f4240 <_entry-0x7ff0bdc0>
    80000054:	97ba                	add	a5,a5,a4
  asm volatile("csrw 0x14d, %0" : : "r" (x));
    80000056:	14d79073          	csrw	stimecmp,a5
}
    8000005a:	6422                	ld	s0,8(sp)
    8000005c:	0141                	addi	sp,sp,16
    8000005e:	8082                	ret

0000000080000060 <start>:
{
    80000060:	1141                	addi	sp,sp,-16
    80000062:	e406                	sd	ra,8(sp)
    80000064:	e022                	sd	s0,0(sp)
    80000066:	0800                	addi	s0,sp,16
  asm volatile("csrr %0, mstatus" : "=r" (x) );
    80000068:	300027f3          	csrr	a5,mstatus
  x &= ~MSTATUS_MPP_MASK;
    8000006c:	7779                	lui	a4,0xffffe
    8000006e:	7ff70713          	addi	a4,a4,2047 # ffffffffffffe7ff <end+0xffffffff7ffdac27>
    80000072:	8ff9                	and	a5,a5,a4
  x |= MSTATUS_MPP_S;
    80000074:	6705                	lui	a4,0x1
    80000076:	80070713          	addi	a4,a4,-2048 # 800 <_entry-0x7ffff800>
    8000007a:	8fd9                	or	a5,a5,a4
  asm volatile("csrw mstatus, %0" : : "r" (x));
    8000007c:	30079073          	csrw	mstatus,a5
  asm volatile("csrw mepc, %0" : : "r" (x));
    80000080:	00001797          	auipc	a5,0x1
    80000084:	dbc78793          	addi	a5,a5,-580 # 80000e3c <main>
    80000088:	34179073          	csrw	mepc,a5
  asm volatile("csrw satp, %0" : : "r" (x));
    8000008c:	4781                	li	a5,0
    8000008e:	18079073          	csrw	satp,a5
  asm volatile("csrw medeleg, %0" : : "r" (x));
    80000092:	67c1                	lui	a5,0x10
    80000094:	17fd                	addi	a5,a5,-1 # ffff <_entry-0x7fff0001>
    80000096:	30279073          	csrw	medeleg,a5
  asm volatile("csrw mideleg, %0" : : "r" (x));
    8000009a:	30379073          	csrw	mideleg,a5
  asm volatile("csrr %0, sie" : "=r" (x) );
    8000009e:	104027f3          	csrr	a5,sie
  w_sie(r_sie() | SIE_SEIE | SIE_STIE);
    800000a2:	2207e793          	ori	a5,a5,544
  asm volatile("csrw sie, %0" : : "r" (x));
    800000a6:	10479073          	csrw	sie,a5
  asm volatile("csrw pmpaddr0, %0" : : "r" (x));
    800000aa:	57fd                	li	a5,-1
    800000ac:	83a9                	srli	a5,a5,0xa
    800000ae:	3b079073          	csrw	pmpaddr0,a5
  asm volatile("csrw pmpcfg0, %0" : : "r" (x));
    800000b2:	47bd                	li	a5,15
    800000b4:	3a079073          	csrw	pmpcfg0,a5
  timerinit();
    800000b8:	f65ff0ef          	jal	8000001c <timerinit>
  asm volatile("csrr %0, mhartid" : "=r" (x) );
    800000bc:	f14027f3          	csrr	a5,mhartid
  w_tp(id);
    800000c0:	2781                	sext.w	a5,a5
}

static inline void 
w_tp(uint64 x)
{
  asm volatile("mv tp, %0" : : "r" (x));
    800000c2:	823e                	mv	tp,a5
  asm volatile("mret");
    800000c4:	30200073          	mret
}
    800000c8:	60a2                	ld	ra,8(sp)
    800000ca:	6402                	ld	s0,0(sp)
    800000cc:	0141                	addi	sp,sp,16
    800000ce:	8082                	ret

00000000800000d0 <consolewrite>:
// user write() system calls to the console go here.
// uses sleep() and UART interrupts.
//
int
consolewrite(int user_src, uint64 src, int n)
{
    800000d0:	7119                	addi	sp,sp,-128
    800000d2:	fc86                	sd	ra,120(sp)
    800000d4:	f8a2                	sd	s0,112(sp)
    800000d6:	f4a6                	sd	s1,104(sp)
    800000d8:	0100                	addi	s0,sp,128
  char buf[32]; // move batches from user space to uart.
  int i = 0;

  while(i < n){
    800000da:	06c05a63          	blez	a2,8000014e <consolewrite+0x7e>
    800000de:	f0ca                	sd	s2,96(sp)
    800000e0:	ecce                	sd	s3,88(sp)
    800000e2:	e8d2                	sd	s4,80(sp)
    800000e4:	e4d6                	sd	s5,72(sp)
    800000e6:	e0da                	sd	s6,64(sp)
    800000e8:	fc5e                	sd	s7,56(sp)
    800000ea:	f862                	sd	s8,48(sp)
    800000ec:	f466                	sd	s9,40(sp)
    800000ee:	8aaa                	mv	s5,a0
    800000f0:	8b2e                	mv	s6,a1
    800000f2:	8a32                	mv	s4,a2
  int i = 0;
    800000f4:	4481                	li	s1,0
    int nn = sizeof(buf);
    if(nn > n - i)
    800000f6:	02000c13          	li	s8,32
    800000fa:	02000c93          	li	s9,32
      nn = n - i;
    if(either_copyin(buf, user_src, src+i, nn) == -1)
    800000fe:	5bfd                	li	s7,-1
    80000100:	a035                	j	8000012c <consolewrite+0x5c>
    if(nn > n - i)
    80000102:	0009099b          	sext.w	s3,s2
    if(either_copyin(buf, user_src, src+i, nn) == -1)
    80000106:	86ce                	mv	a3,s3
    80000108:	01648633          	add	a2,s1,s6
    8000010c:	85d6                	mv	a1,s5
    8000010e:	f8040513          	addi	a0,s0,-128
    80000112:	1e6020ef          	jal	800022f8 <either_copyin>
    80000116:	03750e63          	beq	a0,s7,80000152 <consolewrite+0x82>
      break;
    uartwrite(buf, nn);
    8000011a:	85ce                	mv	a1,s3
    8000011c:	f8040513          	addi	a0,s0,-128
    80000120:	778000ef          	jal	80000898 <uartwrite>
    i += nn;
    80000124:	009904bb          	addw	s1,s2,s1
  while(i < n){
    80000128:	0144da63          	bge	s1,s4,8000013c <consolewrite+0x6c>
    if(nn > n - i)
    8000012c:	409a093b          	subw	s2,s4,s1
    80000130:	0009079b          	sext.w	a5,s2
    80000134:	fcfc57e3          	bge	s8,a5,80000102 <consolewrite+0x32>
    80000138:	8966                	mv	s2,s9
    8000013a:	b7e1                	j	80000102 <consolewrite+0x32>
    8000013c:	7906                	ld	s2,96(sp)
    8000013e:	69e6                	ld	s3,88(sp)
    80000140:	6a46                	ld	s4,80(sp)
    80000142:	6aa6                	ld	s5,72(sp)
    80000144:	6b06                	ld	s6,64(sp)
    80000146:	7be2                	ld	s7,56(sp)
    80000148:	7c42                	ld	s8,48(sp)
    8000014a:	7ca2                	ld	s9,40(sp)
    8000014c:	a819                	j	80000162 <consolewrite+0x92>
  int i = 0;
    8000014e:	4481                	li	s1,0
    80000150:	a809                	j	80000162 <consolewrite+0x92>
    80000152:	7906                	ld	s2,96(sp)
    80000154:	69e6                	ld	s3,88(sp)
    80000156:	6a46                	ld	s4,80(sp)
    80000158:	6aa6                	ld	s5,72(sp)
    8000015a:	6b06                	ld	s6,64(sp)
    8000015c:	7be2                	ld	s7,56(sp)
    8000015e:	7c42                	ld	s8,48(sp)
    80000160:	7ca2                	ld	s9,40(sp)
  }

  return i;
}
    80000162:	8526                	mv	a0,s1
    80000164:	70e6                	ld	ra,120(sp)
    80000166:	7446                	ld	s0,112(sp)
    80000168:	74a6                	ld	s1,104(sp)
    8000016a:	6109                	addi	sp,sp,128
    8000016c:	8082                	ret

000000008000016e <consoleread>:
// user_dst indicates whether dst is a user
// or kernel address.
//
int
consoleread(int user_dst, uint64 dst, int n)
{
    8000016e:	711d                	addi	sp,sp,-96
    80000170:	ec86                	sd	ra,88(sp)
    80000172:	e8a2                	sd	s0,80(sp)
    80000174:	e4a6                	sd	s1,72(sp)
    80000176:	e0ca                	sd	s2,64(sp)
    80000178:	fc4e                	sd	s3,56(sp)
    8000017a:	f852                	sd	s4,48(sp)
    8000017c:	f456                	sd	s5,40(sp)
    8000017e:	f05a                	sd	s6,32(sp)
    80000180:	1080                	addi	s0,sp,96
    80000182:	8aaa                	mv	s5,a0
    80000184:	8a2e                	mv	s4,a1
    80000186:	89b2                	mv	s3,a2
  uint target;
  int c;
  char cbuf;

  target = n;
    80000188:	00060b1b          	sext.w	s6,a2
  acquire(&cons.lock);
    8000018c:	00012517          	auipc	a0,0x12
    80000190:	34450513          	addi	a0,a0,836 # 800124d0 <cons>
    80000194:	23b000ef          	jal	80000bce <acquire>
  while(n > 0){
    // wait until interrupt handler has put some
    // input into cons.buffer.
    while(cons.r == cons.w){
    80000198:	00012497          	auipc	s1,0x12
    8000019c:	33848493          	addi	s1,s1,824 # 800124d0 <cons>
      if(killed(myproc())){
        release(&cons.lock);
        return -1;
      }
      sleep(&cons.r, &cons.lock);
    800001a0:	00012917          	auipc	s2,0x12
    800001a4:	3c890913          	addi	s2,s2,968 # 80012568 <cons+0x98>
  while(n > 0){
    800001a8:	0b305d63          	blez	s3,80000262 <consoleread+0xf4>
    while(cons.r == cons.w){
    800001ac:	0984a783          	lw	a5,152(s1)
    800001b0:	09c4a703          	lw	a4,156(s1)
    800001b4:	0af71263          	bne	a4,a5,80000258 <consoleread+0xea>
      if(killed(myproc())){
    800001b8:	716010ef          	jal	800018ce <myproc>
    800001bc:	7cf010ef          	jal	8000218a <killed>
    800001c0:	e12d                	bnez	a0,80000222 <consoleread+0xb4>
      sleep(&cons.r, &cons.lock);
    800001c2:	85a6                	mv	a1,s1
    800001c4:	854a                	mv	a0,s2
    800001c6:	58d010ef          	jal	80001f52 <sleep>
    while(cons.r == cons.w){
    800001ca:	0984a783          	lw	a5,152(s1)
    800001ce:	09c4a703          	lw	a4,156(s1)
    800001d2:	fef703e3          	beq	a4,a5,800001b8 <consoleread+0x4a>
    800001d6:	ec5e                	sd	s7,24(sp)
    }

    c = cons.buf[cons.r++ % INPUT_BUF_SIZE];
    800001d8:	00012717          	auipc	a4,0x12
    800001dc:	2f870713          	addi	a4,a4,760 # 800124d0 <cons>
    800001e0:	0017869b          	addiw	a3,a5,1
    800001e4:	08d72c23          	sw	a3,152(a4)
    800001e8:	07f7f693          	andi	a3,a5,127
    800001ec:	9736                	add	a4,a4,a3
    800001ee:	01874703          	lbu	a4,24(a4)
    800001f2:	00070b9b          	sext.w	s7,a4

    if(c == C('D')){  // end-of-file
    800001f6:	4691                	li	a3,4
    800001f8:	04db8663          	beq	s7,a3,80000244 <consoleread+0xd6>
      }
      break;
    }

    // copy the input byte to the user-space buffer.
    cbuf = c;
    800001fc:	fae407a3          	sb	a4,-81(s0)
    if(either_copyout(user_dst, dst, &cbuf, 1) == -1)
    80000200:	4685                	li	a3,1
    80000202:	faf40613          	addi	a2,s0,-81
    80000206:	85d2                	mv	a1,s4
    80000208:	8556                	mv	a0,s5
    8000020a:	0a4020ef          	jal	800022ae <either_copyout>
    8000020e:	57fd                	li	a5,-1
    80000210:	04f50863          	beq	a0,a5,80000260 <consoleread+0xf2>
      break;

    dst++;
    80000214:	0a05                	addi	s4,s4,1
    --n;
    80000216:	39fd                	addiw	s3,s3,-1

    if(c == '\n'){
    80000218:	47a9                	li	a5,10
    8000021a:	04fb8d63          	beq	s7,a5,80000274 <consoleread+0x106>
    8000021e:	6be2                	ld	s7,24(sp)
    80000220:	b761                	j	800001a8 <consoleread+0x3a>
        release(&cons.lock);
    80000222:	00012517          	auipc	a0,0x12
    80000226:	2ae50513          	addi	a0,a0,686 # 800124d0 <cons>
    8000022a:	23d000ef          	jal	80000c66 <release>
        return -1;
    8000022e:	557d                	li	a0,-1
    }
  }
  release(&cons.lock);

  return target - n;
}
    80000230:	60e6                	ld	ra,88(sp)
    80000232:	6446                	ld	s0,80(sp)
    80000234:	64a6                	ld	s1,72(sp)
    80000236:	6906                	ld	s2,64(sp)
    80000238:	79e2                	ld	s3,56(sp)
    8000023a:	7a42                	ld	s4,48(sp)
    8000023c:	7aa2                	ld	s5,40(sp)
    8000023e:	7b02                	ld	s6,32(sp)
    80000240:	6125                	addi	sp,sp,96
    80000242:	8082                	ret
      if(n < target){
    80000244:	0009871b          	sext.w	a4,s3
    80000248:	01677a63          	bgeu	a4,s6,8000025c <consoleread+0xee>
        cons.r--;
    8000024c:	00012717          	auipc	a4,0x12
    80000250:	30f72e23          	sw	a5,796(a4) # 80012568 <cons+0x98>
    80000254:	6be2                	ld	s7,24(sp)
    80000256:	a031                	j	80000262 <consoleread+0xf4>
    80000258:	ec5e                	sd	s7,24(sp)
    8000025a:	bfbd                	j	800001d8 <consoleread+0x6a>
    8000025c:	6be2                	ld	s7,24(sp)
    8000025e:	a011                	j	80000262 <consoleread+0xf4>
    80000260:	6be2                	ld	s7,24(sp)
  release(&cons.lock);
    80000262:	00012517          	auipc	a0,0x12
    80000266:	26e50513          	addi	a0,a0,622 # 800124d0 <cons>
    8000026a:	1fd000ef          	jal	80000c66 <release>
  return target - n;
    8000026e:	413b053b          	subw	a0,s6,s3
    80000272:	bf7d                	j	80000230 <consoleread+0xc2>
    80000274:	6be2                	ld	s7,24(sp)
    80000276:	b7f5                	j	80000262 <consoleread+0xf4>

0000000080000278 <consputc>:
{
    80000278:	1141                	addi	sp,sp,-16
    8000027a:	e406                	sd	ra,8(sp)
    8000027c:	e022                	sd	s0,0(sp)
    8000027e:	0800                	addi	s0,sp,16
  if(c == BACKSPACE){
    80000280:	10000793          	li	a5,256
    80000284:	00f50863          	beq	a0,a5,80000294 <consputc+0x1c>
    uartputc_sync(c);
    80000288:	6a4000ef          	jal	8000092c <uartputc_sync>
}
    8000028c:	60a2                	ld	ra,8(sp)
    8000028e:	6402                	ld	s0,0(sp)
    80000290:	0141                	addi	sp,sp,16
    80000292:	8082                	ret
    uartputc_sync('\b'); uartputc_sync(' '); uartputc_sync('\b');
    80000294:	4521                	li	a0,8
    80000296:	696000ef          	jal	8000092c <uartputc_sync>
    8000029a:	02000513          	li	a0,32
    8000029e:	68e000ef          	jal	8000092c <uartputc_sync>
    800002a2:	4521                	li	a0,8
    800002a4:	688000ef          	jal	8000092c <uartputc_sync>
    800002a8:	b7d5                	j	8000028c <consputc+0x14>

00000000800002aa <consoleintr>:
// do erase/kill processing, append to cons.buf,
// wake up consoleread() if a whole line has arrived.
//
void
consoleintr(int c)
{
    800002aa:	1101                	addi	sp,sp,-32
    800002ac:	ec06                	sd	ra,24(sp)
    800002ae:	e822                	sd	s0,16(sp)
    800002b0:	e426                	sd	s1,8(sp)
    800002b2:	1000                	addi	s0,sp,32
    800002b4:	84aa                	mv	s1,a0
  acquire(&cons.lock);
    800002b6:	00012517          	auipc	a0,0x12
    800002ba:	21a50513          	addi	a0,a0,538 # 800124d0 <cons>
    800002be:	111000ef          	jal	80000bce <acquire>

  switch(c){
    800002c2:	47d5                	li	a5,21
    800002c4:	08f48f63          	beq	s1,a5,80000362 <consoleintr+0xb8>
    800002c8:	0297c563          	blt	a5,s1,800002f2 <consoleintr+0x48>
    800002cc:	47a1                	li	a5,8
    800002ce:	0ef48463          	beq	s1,a5,800003b6 <consoleintr+0x10c>
    800002d2:	47c1                	li	a5,16
    800002d4:	10f49563          	bne	s1,a5,800003de <consoleintr+0x134>
  case C('P'):  // Print process list.
    procdump();
    800002d8:	06a020ef          	jal	80002342 <procdump>
      }
    }
    break;
  }
  
  release(&cons.lock);
    800002dc:	00012517          	auipc	a0,0x12
    800002e0:	1f450513          	addi	a0,a0,500 # 800124d0 <cons>
    800002e4:	183000ef          	jal	80000c66 <release>
}
    800002e8:	60e2                	ld	ra,24(sp)
    800002ea:	6442                	ld	s0,16(sp)
    800002ec:	64a2                	ld	s1,8(sp)
    800002ee:	6105                	addi	sp,sp,32
    800002f0:	8082                	ret
  switch(c){
    800002f2:	07f00793          	li	a5,127
    800002f6:	0cf48063          	beq	s1,a5,800003b6 <consoleintr+0x10c>
    if(c != 0 && cons.e-cons.r < INPUT_BUF_SIZE){
    800002fa:	00012717          	auipc	a4,0x12
    800002fe:	1d670713          	addi	a4,a4,470 # 800124d0 <cons>
    80000302:	0a072783          	lw	a5,160(a4)
    80000306:	09872703          	lw	a4,152(a4)
    8000030a:	9f99                	subw	a5,a5,a4
    8000030c:	07f00713          	li	a4,127
    80000310:	fcf766e3          	bltu	a4,a5,800002dc <consoleintr+0x32>
      c = (c == '\r') ? '\n' : c;
    80000314:	47b5                	li	a5,13
    80000316:	0cf48763          	beq	s1,a5,800003e4 <consoleintr+0x13a>
      consputc(c);
    8000031a:	8526                	mv	a0,s1
    8000031c:	f5dff0ef          	jal	80000278 <consputc>
      cons.buf[cons.e++ % INPUT_BUF_SIZE] = c;
    80000320:	00012797          	auipc	a5,0x12
    80000324:	1b078793          	addi	a5,a5,432 # 800124d0 <cons>
    80000328:	0a07a683          	lw	a3,160(a5)
    8000032c:	0016871b          	addiw	a4,a3,1
    80000330:	0007061b          	sext.w	a2,a4
    80000334:	0ae7a023          	sw	a4,160(a5)
    80000338:	07f6f693          	andi	a3,a3,127
    8000033c:	97b6                	add	a5,a5,a3
    8000033e:	00978c23          	sb	s1,24(a5)
      if(c == '\n' || c == C('D') || cons.e-cons.r == INPUT_BUF_SIZE){
    80000342:	47a9                	li	a5,10
    80000344:	0cf48563          	beq	s1,a5,8000040e <consoleintr+0x164>
    80000348:	4791                	li	a5,4
    8000034a:	0cf48263          	beq	s1,a5,8000040e <consoleintr+0x164>
    8000034e:	00012797          	auipc	a5,0x12
    80000352:	21a7a783          	lw	a5,538(a5) # 80012568 <cons+0x98>
    80000356:	9f1d                	subw	a4,a4,a5
    80000358:	08000793          	li	a5,128
    8000035c:	f8f710e3          	bne	a4,a5,800002dc <consoleintr+0x32>
    80000360:	a07d                	j	8000040e <consoleintr+0x164>
    80000362:	e04a                	sd	s2,0(sp)
    while(cons.e != cons.w &&
    80000364:	00012717          	auipc	a4,0x12
    80000368:	16c70713          	addi	a4,a4,364 # 800124d0 <cons>
    8000036c:	0a072783          	lw	a5,160(a4)
    80000370:	09c72703          	lw	a4,156(a4)
          cons.buf[(cons.e-1) % INPUT_BUF_SIZE] != '\n'){
    80000374:	00012497          	auipc	s1,0x12
    80000378:	15c48493          	addi	s1,s1,348 # 800124d0 <cons>
    while(cons.e != cons.w &&
    8000037c:	4929                	li	s2,10
    8000037e:	02f70863          	beq	a4,a5,800003ae <consoleintr+0x104>
          cons.buf[(cons.e-1) % INPUT_BUF_SIZE] != '\n'){
    80000382:	37fd                	addiw	a5,a5,-1
    80000384:	07f7f713          	andi	a4,a5,127
    80000388:	9726                	add	a4,a4,s1
    while(cons.e != cons.w &&
    8000038a:	01874703          	lbu	a4,24(a4)
    8000038e:	03270263          	beq	a4,s2,800003b2 <consoleintr+0x108>
      cons.e--;
    80000392:	0af4a023          	sw	a5,160(s1)
      consputc(BACKSPACE);
    80000396:	10000513          	li	a0,256
    8000039a:	edfff0ef          	jal	80000278 <consputc>
    while(cons.e != cons.w &&
    8000039e:	0a04a783          	lw	a5,160(s1)
    800003a2:	09c4a703          	lw	a4,156(s1)
    800003a6:	fcf71ee3          	bne	a4,a5,80000382 <consoleintr+0xd8>
    800003aa:	6902                	ld	s2,0(sp)
    800003ac:	bf05                	j	800002dc <consoleintr+0x32>
    800003ae:	6902                	ld	s2,0(sp)
    800003b0:	b735                	j	800002dc <consoleintr+0x32>
    800003b2:	6902                	ld	s2,0(sp)
    800003b4:	b725                	j	800002dc <consoleintr+0x32>
    if(cons.e != cons.w){
    800003b6:	00012717          	auipc	a4,0x12
    800003ba:	11a70713          	addi	a4,a4,282 # 800124d0 <cons>
    800003be:	0a072783          	lw	a5,160(a4)
    800003c2:	09c72703          	lw	a4,156(a4)
    800003c6:	f0f70be3          	beq	a4,a5,800002dc <consoleintr+0x32>
      cons.e--;
    800003ca:	37fd                	addiw	a5,a5,-1
    800003cc:	00012717          	auipc	a4,0x12
    800003d0:	1af72223          	sw	a5,420(a4) # 80012570 <cons+0xa0>
      consputc(BACKSPACE);
    800003d4:	10000513          	li	a0,256
    800003d8:	ea1ff0ef          	jal	80000278 <consputc>
    800003dc:	b701                	j	800002dc <consoleintr+0x32>
    if(c != 0 && cons.e-cons.r < INPUT_BUF_SIZE){
    800003de:	ee048fe3          	beqz	s1,800002dc <consoleintr+0x32>
    800003e2:	bf21                	j	800002fa <consoleintr+0x50>
      consputc(c);
    800003e4:	4529                	li	a0,10
    800003e6:	e93ff0ef          	jal	80000278 <consputc>
      cons.buf[cons.e++ % INPUT_BUF_SIZE] = c;
    800003ea:	00012797          	auipc	a5,0x12
    800003ee:	0e678793          	addi	a5,a5,230 # 800124d0 <cons>
    800003f2:	0a07a703          	lw	a4,160(a5)
    800003f6:	0017069b          	addiw	a3,a4,1
    800003fa:	0006861b          	sext.w	a2,a3
    800003fe:	0ad7a023          	sw	a3,160(a5)
    80000402:	07f77713          	andi	a4,a4,127
    80000406:	97ba                	add	a5,a5,a4
    80000408:	4729                	li	a4,10
    8000040a:	00e78c23          	sb	a4,24(a5)
        cons.w = cons.e;
    8000040e:	00012797          	auipc	a5,0x12
    80000412:	14c7af23          	sw	a2,350(a5) # 8001256c <cons+0x9c>
        wakeup(&cons.r);
    80000416:	00012517          	auipc	a0,0x12
    8000041a:	15250513          	addi	a0,a0,338 # 80012568 <cons+0x98>
    8000041e:	381010ef          	jal	80001f9e <wakeup>
    80000422:	bd6d                	j	800002dc <consoleintr+0x32>

0000000080000424 <consoleinit>:

void
consoleinit(void)
{
    80000424:	1141                	addi	sp,sp,-16
    80000426:	e406                	sd	ra,8(sp)
    80000428:	e022                	sd	s0,0(sp)
    8000042a:	0800                	addi	s0,sp,16
  initlock(&cons.lock, "cons");
    8000042c:	00007597          	auipc	a1,0x7
    80000430:	bd458593          	addi	a1,a1,-1068 # 80007000 <etext>
    80000434:	00012517          	auipc	a0,0x12
    80000438:	09c50513          	addi	a0,a0,156 # 800124d0 <cons>
    8000043c:	712000ef          	jal	80000b4e <initlock>

  uartinit();
    80000440:	400000ef          	jal	80000840 <uartinit>

  // connect read and write system calls
  // to consoleread and consolewrite.
  devsw[CONSOLE].read = consoleread;
    80000444:	00022797          	auipc	a5,0x22
    80000448:	5fc78793          	addi	a5,a5,1532 # 80022a40 <devsw>
    8000044c:	00000717          	auipc	a4,0x0
    80000450:	d2270713          	addi	a4,a4,-734 # 8000016e <consoleread>
    80000454:	eb98                	sd	a4,16(a5)
  devsw[CONSOLE].write = consolewrite;
    80000456:	00000717          	auipc	a4,0x0
    8000045a:	c7a70713          	addi	a4,a4,-902 # 800000d0 <consolewrite>
    8000045e:	ef98                	sd	a4,24(a5)
}
    80000460:	60a2                	ld	ra,8(sp)
    80000462:	6402                	ld	s0,0(sp)
    80000464:	0141                	addi	sp,sp,16
    80000466:	8082                	ret

0000000080000468 <printint>:

static char digits[] = "0123456789abcdef";

static void
printint(long long xx, int base, int sign)
{
    80000468:	7139                	addi	sp,sp,-64
    8000046a:	fc06                	sd	ra,56(sp)
    8000046c:	f822                	sd	s0,48(sp)
    8000046e:	0080                	addi	s0,sp,64
  char buf[20];
  int i;
  unsigned long long x;

  if(sign && (sign = (xx < 0)))
    80000470:	c219                	beqz	a2,80000476 <printint+0xe>
    80000472:	08054063          	bltz	a0,800004f2 <printint+0x8a>
    x = -xx;
  else
    x = xx;
    80000476:	4881                	li	a7,0
    80000478:	fc840693          	addi	a3,s0,-56

  i = 0;
    8000047c:	4781                	li	a5,0
  do {
    buf[i++] = digits[x % base];
    8000047e:	00007617          	auipc	a2,0x7
    80000482:	39260613          	addi	a2,a2,914 # 80007810 <digits>
    80000486:	883e                	mv	a6,a5
    80000488:	2785                	addiw	a5,a5,1
    8000048a:	02b57733          	remu	a4,a0,a1
    8000048e:	9732                	add	a4,a4,a2
    80000490:	00074703          	lbu	a4,0(a4)
    80000494:	00e68023          	sb	a4,0(a3)
  } while((x /= base) != 0);
    80000498:	872a                	mv	a4,a0
    8000049a:	02b55533          	divu	a0,a0,a1
    8000049e:	0685                	addi	a3,a3,1
    800004a0:	feb773e3          	bgeu	a4,a1,80000486 <printint+0x1e>

  if(sign)
    800004a4:	00088a63          	beqz	a7,800004b8 <printint+0x50>
    buf[i++] = '-';
    800004a8:	1781                	addi	a5,a5,-32
    800004aa:	97a2                	add	a5,a5,s0
    800004ac:	02d00713          	li	a4,45
    800004b0:	fee78423          	sb	a4,-24(a5)
    800004b4:	0028079b          	addiw	a5,a6,2

  while(--i >= 0)
    800004b8:	02f05963          	blez	a5,800004ea <printint+0x82>
    800004bc:	f426                	sd	s1,40(sp)
    800004be:	f04a                	sd	s2,32(sp)
    800004c0:	fc840713          	addi	a4,s0,-56
    800004c4:	00f704b3          	add	s1,a4,a5
    800004c8:	fff70913          	addi	s2,a4,-1
    800004cc:	993e                	add	s2,s2,a5
    800004ce:	37fd                	addiw	a5,a5,-1
    800004d0:	1782                	slli	a5,a5,0x20
    800004d2:	9381                	srli	a5,a5,0x20
    800004d4:	40f90933          	sub	s2,s2,a5
    consputc(buf[i]);
    800004d8:	fff4c503          	lbu	a0,-1(s1)
    800004dc:	d9dff0ef          	jal	80000278 <consputc>
  while(--i >= 0)
    800004e0:	14fd                	addi	s1,s1,-1
    800004e2:	ff249be3          	bne	s1,s2,800004d8 <printint+0x70>
    800004e6:	74a2                	ld	s1,40(sp)
    800004e8:	7902                	ld	s2,32(sp)
}
    800004ea:	70e2                	ld	ra,56(sp)
    800004ec:	7442                	ld	s0,48(sp)
    800004ee:	6121                	addi	sp,sp,64
    800004f0:	8082                	ret
    x = -xx;
    800004f2:	40a00533          	neg	a0,a0
  if(sign && (sign = (xx < 0)))
    800004f6:	4885                	li	a7,1
    x = -xx;
    800004f8:	b741                	j	80000478 <printint+0x10>

00000000800004fa <printf>:
}

// Print to the console.
int
printf(char *fmt, ...)
{
    800004fa:	7131                	addi	sp,sp,-192
    800004fc:	fc86                	sd	ra,120(sp)
    800004fe:	f8a2                	sd	s0,112(sp)
    80000500:	e8d2                	sd	s4,80(sp)
    80000502:	0100                	addi	s0,sp,128
    80000504:	8a2a                	mv	s4,a0
    80000506:	e40c                	sd	a1,8(s0)
    80000508:	e810                	sd	a2,16(s0)
    8000050a:	ec14                	sd	a3,24(s0)
    8000050c:	f018                	sd	a4,32(s0)
    8000050e:	f41c                	sd	a5,40(s0)
    80000510:	03043823          	sd	a6,48(s0)
    80000514:	03143c23          	sd	a7,56(s0)
  va_list ap;
  int i, cx, c0, c1, c2;
  char *s;

  if(panicking == 0)
    80000518:	0000a797          	auipc	a5,0xa
    8000051c:	f8c7a783          	lw	a5,-116(a5) # 8000a4a4 <panicking>
    80000520:	c3a1                	beqz	a5,80000560 <printf+0x66>
    acquire(&pr.lock);

  va_start(ap, fmt);
    80000522:	00840793          	addi	a5,s0,8
    80000526:	f8f43423          	sd	a5,-120(s0)
  for(i = 0; (cx = fmt[i] & 0xff) != 0; i++){
    8000052a:	000a4503          	lbu	a0,0(s4)
    8000052e:	28050763          	beqz	a0,800007bc <printf+0x2c2>
    80000532:	f4a6                	sd	s1,104(sp)
    80000534:	f0ca                	sd	s2,96(sp)
    80000536:	ecce                	sd	s3,88(sp)
    80000538:	e4d6                	sd	s5,72(sp)
    8000053a:	e0da                	sd	s6,64(sp)
    8000053c:	f862                	sd	s8,48(sp)
    8000053e:	f466                	sd	s9,40(sp)
    80000540:	f06a                	sd	s10,32(sp)
    80000542:	ec6e                	sd	s11,24(sp)
    80000544:	4981                	li	s3,0
    if(cx != '%'){
    80000546:	02500a93          	li	s5,37
    i++;
    c0 = fmt[i+0] & 0xff;
    c1 = c2 = 0;
    if(c0) c1 = fmt[i+1] & 0xff;
    if(c1) c2 = fmt[i+2] & 0xff;
    if(c0 == 'd'){
    8000054a:	06400b13          	li	s6,100
      printint(va_arg(ap, int), 10, 1);
    } else if(c0 == 'l' && c1 == 'd'){
    8000054e:	06c00c13          	li	s8,108
      printint(va_arg(ap, uint64), 10, 1);
      i += 1;
    } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
      printint(va_arg(ap, uint64), 10, 1);
      i += 2;
    } else if(c0 == 'u'){
    80000552:	07500c93          	li	s9,117
      printint(va_arg(ap, uint64), 10, 0);
      i += 1;
    } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
      printint(va_arg(ap, uint64), 10, 0);
      i += 2;
    } else if(c0 == 'x'){
    80000556:	07800d13          	li	s10,120
      printint(va_arg(ap, uint64), 16, 0);
      i += 1;
    } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
      printint(va_arg(ap, uint64), 16, 0);
      i += 2;
    } else if(c0 == 'p'){
    8000055a:	07000d93          	li	s11,112
    8000055e:	a01d                	j	80000584 <printf+0x8a>
    acquire(&pr.lock);
    80000560:	00012517          	auipc	a0,0x12
    80000564:	01850513          	addi	a0,a0,24 # 80012578 <pr>
    80000568:	666000ef          	jal	80000bce <acquire>
    8000056c:	bf5d                	j	80000522 <printf+0x28>
      consputc(cx);
    8000056e:	d0bff0ef          	jal	80000278 <consputc>
      continue;
    80000572:	84ce                	mv	s1,s3
  for(i = 0; (cx = fmt[i] & 0xff) != 0; i++){
    80000574:	0014899b          	addiw	s3,s1,1
    80000578:	013a07b3          	add	a5,s4,s3
    8000057c:	0007c503          	lbu	a0,0(a5)
    80000580:	20050b63          	beqz	a0,80000796 <printf+0x29c>
    if(cx != '%'){
    80000584:	ff5515e3          	bne	a0,s5,8000056e <printf+0x74>
    i++;
    80000588:	0019849b          	addiw	s1,s3,1
    c0 = fmt[i+0] & 0xff;
    8000058c:	009a07b3          	add	a5,s4,s1
    80000590:	0007c903          	lbu	s2,0(a5)
    if(c0) c1 = fmt[i+1] & 0xff;
    80000594:	20090b63          	beqz	s2,800007aa <printf+0x2b0>
    80000598:	0017c783          	lbu	a5,1(a5)
    c1 = c2 = 0;
    8000059c:	86be                	mv	a3,a5
    if(c1) c2 = fmt[i+2] & 0xff;
    8000059e:	c789                	beqz	a5,800005a8 <printf+0xae>
    800005a0:	009a0733          	add	a4,s4,s1
    800005a4:	00274683          	lbu	a3,2(a4)
    if(c0 == 'd'){
    800005a8:	03690963          	beq	s2,s6,800005da <printf+0xe0>
    } else if(c0 == 'l' && c1 == 'd'){
    800005ac:	05890363          	beq	s2,s8,800005f2 <printf+0xf8>
    } else if(c0 == 'u'){
    800005b0:	0d990663          	beq	s2,s9,8000067c <printf+0x182>
    } else if(c0 == 'x'){
    800005b4:	11a90d63          	beq	s2,s10,800006ce <printf+0x1d4>
    } else if(c0 == 'p'){
    800005b8:	15b90663          	beq	s2,s11,80000704 <printf+0x20a>
      printptr(va_arg(ap, uint64));
    } else if(c0 == 'c'){
    800005bc:	06300793          	li	a5,99
    800005c0:	18f90563          	beq	s2,a5,8000074a <printf+0x250>
      consputc(va_arg(ap, uint));
    } else if(c0 == 's'){
    800005c4:	07300793          	li	a5,115
    800005c8:	18f90b63          	beq	s2,a5,8000075e <printf+0x264>
      if((s = va_arg(ap, char*)) == 0)
        s = "(null)";
      for(; *s; s++)
        consputc(*s);
    } else if(c0 == '%'){
    800005cc:	03591b63          	bne	s2,s5,80000602 <printf+0x108>
      consputc('%');
    800005d0:	02500513          	li	a0,37
    800005d4:	ca5ff0ef          	jal	80000278 <consputc>
    800005d8:	bf71                	j	80000574 <printf+0x7a>
      printint(va_arg(ap, int), 10, 1);
    800005da:	f8843783          	ld	a5,-120(s0)
    800005de:	00878713          	addi	a4,a5,8
    800005e2:	f8e43423          	sd	a4,-120(s0)
    800005e6:	4605                	li	a2,1
    800005e8:	45a9                	li	a1,10
    800005ea:	4388                	lw	a0,0(a5)
    800005ec:	e7dff0ef          	jal	80000468 <printint>
    800005f0:	b751                	j	80000574 <printf+0x7a>
    } else if(c0 == 'l' && c1 == 'd'){
    800005f2:	01678f63          	beq	a5,s6,80000610 <printf+0x116>
    } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
    800005f6:	03878b63          	beq	a5,s8,8000062c <printf+0x132>
    } else if(c0 == 'l' && c1 == 'u'){
    800005fa:	09978e63          	beq	a5,s9,80000696 <printf+0x19c>
    } else if(c0 == 'l' && c1 == 'x'){
    800005fe:	0fa78563          	beq	a5,s10,800006e8 <printf+0x1ee>
    } else if(c0 == 0){
      break;
    } else {
      // Print unknown % sequence to draw attention.
      consputc('%');
    80000602:	8556                	mv	a0,s5
    80000604:	c75ff0ef          	jal	80000278 <consputc>
      consputc(c0);
    80000608:	854a                	mv	a0,s2
    8000060a:	c6fff0ef          	jal	80000278 <consputc>
    8000060e:	b79d                	j	80000574 <printf+0x7a>
      printint(va_arg(ap, uint64), 10, 1);
    80000610:	f8843783          	ld	a5,-120(s0)
    80000614:	00878713          	addi	a4,a5,8
    80000618:	f8e43423          	sd	a4,-120(s0)
    8000061c:	4605                	li	a2,1
    8000061e:	45a9                	li	a1,10
    80000620:	6388                	ld	a0,0(a5)
    80000622:	e47ff0ef          	jal	80000468 <printint>
      i += 1;
    80000626:	0029849b          	addiw	s1,s3,2
    8000062a:	b7a9                	j	80000574 <printf+0x7a>
    } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
    8000062c:	06400793          	li	a5,100
    80000630:	02f68863          	beq	a3,a5,80000660 <printf+0x166>
    } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
    80000634:	07500793          	li	a5,117
    80000638:	06f68d63          	beq	a3,a5,800006b2 <printf+0x1b8>
    } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
    8000063c:	07800793          	li	a5,120
    80000640:	fcf691e3          	bne	a3,a5,80000602 <printf+0x108>
      printint(va_arg(ap, uint64), 16, 0);
    80000644:	f8843783          	ld	a5,-120(s0)
    80000648:	00878713          	addi	a4,a5,8
    8000064c:	f8e43423          	sd	a4,-120(s0)
    80000650:	4601                	li	a2,0
    80000652:	45c1                	li	a1,16
    80000654:	6388                	ld	a0,0(a5)
    80000656:	e13ff0ef          	jal	80000468 <printint>
      i += 2;
    8000065a:	0039849b          	addiw	s1,s3,3
    8000065e:	bf19                	j	80000574 <printf+0x7a>
      printint(va_arg(ap, uint64), 10, 1);
    80000660:	f8843783          	ld	a5,-120(s0)
    80000664:	00878713          	addi	a4,a5,8
    80000668:	f8e43423          	sd	a4,-120(s0)
    8000066c:	4605                	li	a2,1
    8000066e:	45a9                	li	a1,10
    80000670:	6388                	ld	a0,0(a5)
    80000672:	df7ff0ef          	jal	80000468 <printint>
      i += 2;
    80000676:	0039849b          	addiw	s1,s3,3
    8000067a:	bded                	j	80000574 <printf+0x7a>
      printint(va_arg(ap, uint32), 10, 0);
    8000067c:	f8843783          	ld	a5,-120(s0)
    80000680:	00878713          	addi	a4,a5,8
    80000684:	f8e43423          	sd	a4,-120(s0)
    80000688:	4601                	li	a2,0
    8000068a:	45a9                	li	a1,10
    8000068c:	0007e503          	lwu	a0,0(a5)
    80000690:	dd9ff0ef          	jal	80000468 <printint>
    80000694:	b5c5                	j	80000574 <printf+0x7a>
      printint(va_arg(ap, uint64), 10, 0);
    80000696:	f8843783          	ld	a5,-120(s0)
    8000069a:	00878713          	addi	a4,a5,8
    8000069e:	f8e43423          	sd	a4,-120(s0)
    800006a2:	4601                	li	a2,0
    800006a4:	45a9                	li	a1,10
    800006a6:	6388                	ld	a0,0(a5)
    800006a8:	dc1ff0ef          	jal	80000468 <printint>
      i += 1;
    800006ac:	0029849b          	addiw	s1,s3,2
    800006b0:	b5d1                	j	80000574 <printf+0x7a>
      printint(va_arg(ap, uint64), 10, 0);
    800006b2:	f8843783          	ld	a5,-120(s0)
    800006b6:	00878713          	addi	a4,a5,8
    800006ba:	f8e43423          	sd	a4,-120(s0)
    800006be:	4601                	li	a2,0
    800006c0:	45a9                	li	a1,10
    800006c2:	6388                	ld	a0,0(a5)
    800006c4:	da5ff0ef          	jal	80000468 <printint>
      i += 2;
    800006c8:	0039849b          	addiw	s1,s3,3
    800006cc:	b565                	j	80000574 <printf+0x7a>
      printint(va_arg(ap, uint32), 16, 0);
    800006ce:	f8843783          	ld	a5,-120(s0)
    800006d2:	00878713          	addi	a4,a5,8
    800006d6:	f8e43423          	sd	a4,-120(s0)
    800006da:	4601                	li	a2,0
    800006dc:	45c1                	li	a1,16
    800006de:	0007e503          	lwu	a0,0(a5)
    800006e2:	d87ff0ef          	jal	80000468 <printint>
    800006e6:	b579                	j	80000574 <printf+0x7a>
      printint(va_arg(ap, uint64), 16, 0);
    800006e8:	f8843783          	ld	a5,-120(s0)
    800006ec:	00878713          	addi	a4,a5,8
    800006f0:	f8e43423          	sd	a4,-120(s0)
    800006f4:	4601                	li	a2,0
    800006f6:	45c1                	li	a1,16
    800006f8:	6388                	ld	a0,0(a5)
    800006fa:	d6fff0ef          	jal	80000468 <printint>
      i += 1;
    800006fe:	0029849b          	addiw	s1,s3,2
    80000702:	bd8d                	j	80000574 <printf+0x7a>
    80000704:	fc5e                	sd	s7,56(sp)
      printptr(va_arg(ap, uint64));
    80000706:	f8843783          	ld	a5,-120(s0)
    8000070a:	00878713          	addi	a4,a5,8
    8000070e:	f8e43423          	sd	a4,-120(s0)
    80000712:	0007b983          	ld	s3,0(a5)
  consputc('0');
    80000716:	03000513          	li	a0,48
    8000071a:	b5fff0ef          	jal	80000278 <consputc>
  consputc('x');
    8000071e:	07800513          	li	a0,120
    80000722:	b57ff0ef          	jal	80000278 <consputc>
    80000726:	4941                	li	s2,16
    consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    80000728:	00007b97          	auipc	s7,0x7
    8000072c:	0e8b8b93          	addi	s7,s7,232 # 80007810 <digits>
    80000730:	03c9d793          	srli	a5,s3,0x3c
    80000734:	97de                	add	a5,a5,s7
    80000736:	0007c503          	lbu	a0,0(a5)
    8000073a:	b3fff0ef          	jal	80000278 <consputc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
    8000073e:	0992                	slli	s3,s3,0x4
    80000740:	397d                	addiw	s2,s2,-1
    80000742:	fe0917e3          	bnez	s2,80000730 <printf+0x236>
    80000746:	7be2                	ld	s7,56(sp)
    80000748:	b535                	j	80000574 <printf+0x7a>
      consputc(va_arg(ap, uint));
    8000074a:	f8843783          	ld	a5,-120(s0)
    8000074e:	00878713          	addi	a4,a5,8
    80000752:	f8e43423          	sd	a4,-120(s0)
    80000756:	4388                	lw	a0,0(a5)
    80000758:	b21ff0ef          	jal	80000278 <consputc>
    8000075c:	bd21                	j	80000574 <printf+0x7a>
      if((s = va_arg(ap, char*)) == 0)
    8000075e:	f8843783          	ld	a5,-120(s0)
    80000762:	00878713          	addi	a4,a5,8
    80000766:	f8e43423          	sd	a4,-120(s0)
    8000076a:	0007b903          	ld	s2,0(a5)
    8000076e:	00090d63          	beqz	s2,80000788 <printf+0x28e>
      for(; *s; s++)
    80000772:	00094503          	lbu	a0,0(s2)
    80000776:	de050fe3          	beqz	a0,80000574 <printf+0x7a>
        consputc(*s);
    8000077a:	affff0ef          	jal	80000278 <consputc>
      for(; *s; s++)
    8000077e:	0905                	addi	s2,s2,1
    80000780:	00094503          	lbu	a0,0(s2)
    80000784:	f97d                	bnez	a0,8000077a <printf+0x280>
    80000786:	b3fd                	j	80000574 <printf+0x7a>
        s = "(null)";
    80000788:	00007917          	auipc	s2,0x7
    8000078c:	88090913          	addi	s2,s2,-1920 # 80007008 <etext+0x8>
      for(; *s; s++)
    80000790:	02800513          	li	a0,40
    80000794:	b7dd                	j	8000077a <printf+0x280>
    80000796:	74a6                	ld	s1,104(sp)
    80000798:	7906                	ld	s2,96(sp)
    8000079a:	69e6                	ld	s3,88(sp)
    8000079c:	6aa6                	ld	s5,72(sp)
    8000079e:	6b06                	ld	s6,64(sp)
    800007a0:	7c42                	ld	s8,48(sp)
    800007a2:	7ca2                	ld	s9,40(sp)
    800007a4:	7d02                	ld	s10,32(sp)
    800007a6:	6de2                	ld	s11,24(sp)
    800007a8:	a811                	j	800007bc <printf+0x2c2>
    800007aa:	74a6                	ld	s1,104(sp)
    800007ac:	7906                	ld	s2,96(sp)
    800007ae:	69e6                	ld	s3,88(sp)
    800007b0:	6aa6                	ld	s5,72(sp)
    800007b2:	6b06                	ld	s6,64(sp)
    800007b4:	7c42                	ld	s8,48(sp)
    800007b6:	7ca2                	ld	s9,40(sp)
    800007b8:	7d02                	ld	s10,32(sp)
    800007ba:	6de2                	ld	s11,24(sp)
    }

  }
  va_end(ap);

  if(panicking == 0)
    800007bc:	0000a797          	auipc	a5,0xa
    800007c0:	ce87a783          	lw	a5,-792(a5) # 8000a4a4 <panicking>
    800007c4:	c799                	beqz	a5,800007d2 <printf+0x2d8>
    release(&pr.lock);

  return 0;
}
    800007c6:	4501                	li	a0,0
    800007c8:	70e6                	ld	ra,120(sp)
    800007ca:	7446                	ld	s0,112(sp)
    800007cc:	6a46                	ld	s4,80(sp)
    800007ce:	6129                	addi	sp,sp,192
    800007d0:	8082                	ret
    release(&pr.lock);
    800007d2:	00012517          	auipc	a0,0x12
    800007d6:	da650513          	addi	a0,a0,-602 # 80012578 <pr>
    800007da:	48c000ef          	jal	80000c66 <release>
  return 0;
    800007de:	b7e5                	j	800007c6 <printf+0x2cc>

00000000800007e0 <panic>:

void
panic(char *s)
{
    800007e0:	1101                	addi	sp,sp,-32
    800007e2:	ec06                	sd	ra,24(sp)
    800007e4:	e822                	sd	s0,16(sp)
    800007e6:	e426                	sd	s1,8(sp)
    800007e8:	e04a                	sd	s2,0(sp)
    800007ea:	1000                	addi	s0,sp,32
    800007ec:	84aa                	mv	s1,a0
  panicking = 1;
    800007ee:	4905                	li	s2,1
    800007f0:	0000a797          	auipc	a5,0xa
    800007f4:	cb27aa23          	sw	s2,-844(a5) # 8000a4a4 <panicking>
  printf("panic: ");
    800007f8:	00007517          	auipc	a0,0x7
    800007fc:	82050513          	addi	a0,a0,-2016 # 80007018 <etext+0x18>
    80000800:	cfbff0ef          	jal	800004fa <printf>
  printf("%s\n", s);
    80000804:	85a6                	mv	a1,s1
    80000806:	00007517          	auipc	a0,0x7
    8000080a:	81a50513          	addi	a0,a0,-2022 # 80007020 <etext+0x20>
    8000080e:	cedff0ef          	jal	800004fa <printf>
  panicked = 1; // freeze uart output from other CPUs
    80000812:	0000a797          	auipc	a5,0xa
    80000816:	c927a723          	sw	s2,-882(a5) # 8000a4a0 <panicked>
  for(;;)
    8000081a:	a001                	j	8000081a <panic+0x3a>

000000008000081c <printfinit>:
    ;
}

void
printfinit(void)
{
    8000081c:	1141                	addi	sp,sp,-16
    8000081e:	e406                	sd	ra,8(sp)
    80000820:	e022                	sd	s0,0(sp)
    80000822:	0800                	addi	s0,sp,16
  initlock(&pr.lock, "pr");
    80000824:	00007597          	auipc	a1,0x7
    80000828:	80458593          	addi	a1,a1,-2044 # 80007028 <etext+0x28>
    8000082c:	00012517          	auipc	a0,0x12
    80000830:	d4c50513          	addi	a0,a0,-692 # 80012578 <pr>
    80000834:	31a000ef          	jal	80000b4e <initlock>
}
    80000838:	60a2                	ld	ra,8(sp)
    8000083a:	6402                	ld	s0,0(sp)
    8000083c:	0141                	addi	sp,sp,16
    8000083e:	8082                	ret

0000000080000840 <uartinit>:
extern volatile int panicking; // from printf.c
extern volatile int panicked; // from printf.c

void
uartinit(void)
{
    80000840:	1141                	addi	sp,sp,-16
    80000842:	e406                	sd	ra,8(sp)
    80000844:	e022                	sd	s0,0(sp)
    80000846:	0800                	addi	s0,sp,16
  // disable interrupts.
  WriteReg(IER, 0x00);
    80000848:	100007b7          	lui	a5,0x10000
    8000084c:	000780a3          	sb	zero,1(a5) # 10000001 <_entry-0x6fffffff>

  // special mode to set baud rate.
  WriteReg(LCR, LCR_BAUD_LATCH);
    80000850:	10000737          	lui	a4,0x10000
    80000854:	f8000693          	li	a3,-128
    80000858:	00d701a3          	sb	a3,3(a4) # 10000003 <_entry-0x6ffffffd>

  // LSB for baud rate of 38.4K.
  WriteReg(0, 0x03);
    8000085c:	468d                	li	a3,3
    8000085e:	10000637          	lui	a2,0x10000
    80000862:	00d60023          	sb	a3,0(a2) # 10000000 <_entry-0x70000000>

  // MSB for baud rate of 38.4K.
  WriteReg(1, 0x00);
    80000866:	000780a3          	sb	zero,1(a5)

  // leave set-baud mode,
  // and set word length to 8 bits, no parity.
  WriteReg(LCR, LCR_EIGHT_BITS);
    8000086a:	00d701a3          	sb	a3,3(a4)

  // reset and enable FIFOs.
  WriteReg(FCR, FCR_FIFO_ENABLE | FCR_FIFO_CLEAR);
    8000086e:	10000737          	lui	a4,0x10000
    80000872:	461d                	li	a2,7
    80000874:	00c70123          	sb	a2,2(a4) # 10000002 <_entry-0x6ffffffe>

  // enable transmit and receive interrupts.
  WriteReg(IER, IER_TX_ENABLE | IER_RX_ENABLE);
    80000878:	00d780a3          	sb	a3,1(a5)

  initlock(&tx_lock, "uart");
    8000087c:	00006597          	auipc	a1,0x6
    80000880:	7b458593          	addi	a1,a1,1972 # 80007030 <etext+0x30>
    80000884:	00012517          	auipc	a0,0x12
    80000888:	d0c50513          	addi	a0,a0,-756 # 80012590 <tx_lock>
    8000088c:	2c2000ef          	jal	80000b4e <initlock>
}
    80000890:	60a2                	ld	ra,8(sp)
    80000892:	6402                	ld	s0,0(sp)
    80000894:	0141                	addi	sp,sp,16
    80000896:	8082                	ret

0000000080000898 <uartwrite>:
// transmit buf[] to the uart. it blocks if the
// uart is busy, so it cannot be called from
// interrupts, only from write() system calls.
void
uartwrite(char buf[], int n)
{
    80000898:	715d                	addi	sp,sp,-80
    8000089a:	e486                	sd	ra,72(sp)
    8000089c:	e0a2                	sd	s0,64(sp)
    8000089e:	fc26                	sd	s1,56(sp)
    800008a0:	ec56                	sd	s5,24(sp)
    800008a2:	0880                	addi	s0,sp,80
    800008a4:	8aaa                	mv	s5,a0
    800008a6:	84ae                	mv	s1,a1
  acquire(&tx_lock);
    800008a8:	00012517          	auipc	a0,0x12
    800008ac:	ce850513          	addi	a0,a0,-792 # 80012590 <tx_lock>
    800008b0:	31e000ef          	jal	80000bce <acquire>

  int i = 0;
  while(i < n){ 
    800008b4:	06905063          	blez	s1,80000914 <uartwrite+0x7c>
    800008b8:	f84a                	sd	s2,48(sp)
    800008ba:	f44e                	sd	s3,40(sp)
    800008bc:	f052                	sd	s4,32(sp)
    800008be:	e85a                	sd	s6,16(sp)
    800008c0:	e45e                	sd	s7,8(sp)
    800008c2:	8a56                	mv	s4,s5
    800008c4:	9aa6                	add	s5,s5,s1
    while(tx_busy != 0){
    800008c6:	0000a497          	auipc	s1,0xa
    800008ca:	be648493          	addi	s1,s1,-1050 # 8000a4ac <tx_busy>
      // wait for a UART transmit-complete interrupt
      // to set tx_busy to 0.
      sleep(&tx_chan, &tx_lock);
    800008ce:	00012997          	auipc	s3,0x12
    800008d2:	cc298993          	addi	s3,s3,-830 # 80012590 <tx_lock>
    800008d6:	0000a917          	auipc	s2,0xa
    800008da:	bd290913          	addi	s2,s2,-1070 # 8000a4a8 <tx_chan>
    }   
      
    WriteReg(THR, buf[i]);
    800008de:	10000bb7          	lui	s7,0x10000
    i += 1;
    tx_busy = 1;
    800008e2:	4b05                	li	s6,1
    800008e4:	a005                	j	80000904 <uartwrite+0x6c>
      sleep(&tx_chan, &tx_lock);
    800008e6:	85ce                	mv	a1,s3
    800008e8:	854a                	mv	a0,s2
    800008ea:	668010ef          	jal	80001f52 <sleep>
    while(tx_busy != 0){
    800008ee:	409c                	lw	a5,0(s1)
    800008f0:	fbfd                	bnez	a5,800008e6 <uartwrite+0x4e>
    WriteReg(THR, buf[i]);
    800008f2:	000a4783          	lbu	a5,0(s4)
    800008f6:	00fb8023          	sb	a5,0(s7) # 10000000 <_entry-0x70000000>
    tx_busy = 1;
    800008fa:	0164a023          	sw	s6,0(s1)
  while(i < n){ 
    800008fe:	0a05                	addi	s4,s4,1
    80000900:	015a0563          	beq	s4,s5,8000090a <uartwrite+0x72>
    while(tx_busy != 0){
    80000904:	409c                	lw	a5,0(s1)
    80000906:	f3e5                	bnez	a5,800008e6 <uartwrite+0x4e>
    80000908:	b7ed                	j	800008f2 <uartwrite+0x5a>
    8000090a:	7942                	ld	s2,48(sp)
    8000090c:	79a2                	ld	s3,40(sp)
    8000090e:	7a02                	ld	s4,32(sp)
    80000910:	6b42                	ld	s6,16(sp)
    80000912:	6ba2                	ld	s7,8(sp)
  }

  release(&tx_lock);
    80000914:	00012517          	auipc	a0,0x12
    80000918:	c7c50513          	addi	a0,a0,-900 # 80012590 <tx_lock>
    8000091c:	34a000ef          	jal	80000c66 <release>
}
    80000920:	60a6                	ld	ra,72(sp)
    80000922:	6406                	ld	s0,64(sp)
    80000924:	74e2                	ld	s1,56(sp)
    80000926:	6ae2                	ld	s5,24(sp)
    80000928:	6161                	addi	sp,sp,80
    8000092a:	8082                	ret

000000008000092c <uartputc_sync>:
// interrupts, for use by kernel printf() and
// to echo characters. it spins waiting for the uart's
// output register to be empty.
void
uartputc_sync(int c)
{
    8000092c:	1101                	addi	sp,sp,-32
    8000092e:	ec06                	sd	ra,24(sp)
    80000930:	e822                	sd	s0,16(sp)
    80000932:	e426                	sd	s1,8(sp)
    80000934:	1000                	addi	s0,sp,32
    80000936:	84aa                	mv	s1,a0
  if(panicking == 0)
    80000938:	0000a797          	auipc	a5,0xa
    8000093c:	b6c7a783          	lw	a5,-1172(a5) # 8000a4a4 <panicking>
    80000940:	cf95                	beqz	a5,8000097c <uartputc_sync+0x50>
    push_off();

  if(panicked){
    80000942:	0000a797          	auipc	a5,0xa
    80000946:	b5e7a783          	lw	a5,-1186(a5) # 8000a4a0 <panicked>
    8000094a:	ef85                	bnez	a5,80000982 <uartputc_sync+0x56>
    for(;;)
      ;
  }

  // wait for UART to set Transmit Holding Empty in LSR.
  while((ReadReg(LSR) & LSR_TX_IDLE) == 0)
    8000094c:	10000737          	lui	a4,0x10000
    80000950:	0715                	addi	a4,a4,5 # 10000005 <_entry-0x6ffffffb>
    80000952:	00074783          	lbu	a5,0(a4)
    80000956:	0207f793          	andi	a5,a5,32
    8000095a:	dfe5                	beqz	a5,80000952 <uartputc_sync+0x26>
    ;
  WriteReg(THR, c);
    8000095c:	0ff4f513          	zext.b	a0,s1
    80000960:	100007b7          	lui	a5,0x10000
    80000964:	00a78023          	sb	a0,0(a5) # 10000000 <_entry-0x70000000>

  if(panicking == 0)
    80000968:	0000a797          	auipc	a5,0xa
    8000096c:	b3c7a783          	lw	a5,-1220(a5) # 8000a4a4 <panicking>
    80000970:	cb91                	beqz	a5,80000984 <uartputc_sync+0x58>
    pop_off();
}
    80000972:	60e2                	ld	ra,24(sp)
    80000974:	6442                	ld	s0,16(sp)
    80000976:	64a2                	ld	s1,8(sp)
    80000978:	6105                	addi	sp,sp,32
    8000097a:	8082                	ret
    push_off();
    8000097c:	212000ef          	jal	80000b8e <push_off>
    80000980:	b7c9                	j	80000942 <uartputc_sync+0x16>
    for(;;)
    80000982:	a001                	j	80000982 <uartputc_sync+0x56>
    pop_off();
    80000984:	28e000ef          	jal	80000c12 <pop_off>
}
    80000988:	b7ed                	j	80000972 <uartputc_sync+0x46>

000000008000098a <uartgetc>:

// try to read one input character from the UART.
// return -1 if none is waiting.
int
uartgetc(void)
{
    8000098a:	1141                	addi	sp,sp,-16
    8000098c:	e422                	sd	s0,8(sp)
    8000098e:	0800                	addi	s0,sp,16
  if(ReadReg(LSR) & LSR_RX_READY){
    80000990:	100007b7          	lui	a5,0x10000
    80000994:	0795                	addi	a5,a5,5 # 10000005 <_entry-0x6ffffffb>
    80000996:	0007c783          	lbu	a5,0(a5)
    8000099a:	8b85                	andi	a5,a5,1
    8000099c:	cb81                	beqz	a5,800009ac <uartgetc+0x22>
    // input data is ready.
    return ReadReg(RHR);
    8000099e:	100007b7          	lui	a5,0x10000
    800009a2:	0007c503          	lbu	a0,0(a5) # 10000000 <_entry-0x70000000>
  } else {
    return -1;
  }
}
    800009a6:	6422                	ld	s0,8(sp)
    800009a8:	0141                	addi	sp,sp,16
    800009aa:	8082                	ret
    return -1;
    800009ac:	557d                	li	a0,-1
    800009ae:	bfe5                	j	800009a6 <uartgetc+0x1c>

00000000800009b0 <uartintr>:
// handle a uart interrupt, raised because input has
// arrived, or the uart is ready for more output, or
// both. called from devintr().
void
uartintr(void)
{
    800009b0:	1101                	addi	sp,sp,-32
    800009b2:	ec06                	sd	ra,24(sp)
    800009b4:	e822                	sd	s0,16(sp)
    800009b6:	e426                	sd	s1,8(sp)
    800009b8:	1000                	addi	s0,sp,32
  ReadReg(ISR); // acknowledge the interrupt
    800009ba:	100007b7          	lui	a5,0x10000
    800009be:	0789                	addi	a5,a5,2 # 10000002 <_entry-0x6ffffffe>
    800009c0:	0007c783          	lbu	a5,0(a5)

  acquire(&tx_lock);
    800009c4:	00012517          	auipc	a0,0x12
    800009c8:	bcc50513          	addi	a0,a0,-1076 # 80012590 <tx_lock>
    800009cc:	202000ef          	jal	80000bce <acquire>
  if(ReadReg(LSR) & LSR_TX_IDLE){
    800009d0:	100007b7          	lui	a5,0x10000
    800009d4:	0795                	addi	a5,a5,5 # 10000005 <_entry-0x6ffffffb>
    800009d6:	0007c783          	lbu	a5,0(a5)
    800009da:	0207f793          	andi	a5,a5,32
    800009de:	eb89                	bnez	a5,800009f0 <uartintr+0x40>
    // UART finished transmitting; wake up sending thread.
    tx_busy = 0;
    wakeup(&tx_chan);
  }
  release(&tx_lock);
    800009e0:	00012517          	auipc	a0,0x12
    800009e4:	bb050513          	addi	a0,a0,-1104 # 80012590 <tx_lock>
    800009e8:	27e000ef          	jal	80000c66 <release>

  // read and process incoming characters, if any.
  while(1){
    int c = uartgetc();
    if(c == -1)
    800009ec:	54fd                	li	s1,-1
    800009ee:	a831                	j	80000a0a <uartintr+0x5a>
    tx_busy = 0;
    800009f0:	0000a797          	auipc	a5,0xa
    800009f4:	aa07ae23          	sw	zero,-1348(a5) # 8000a4ac <tx_busy>
    wakeup(&tx_chan);
    800009f8:	0000a517          	auipc	a0,0xa
    800009fc:	ab050513          	addi	a0,a0,-1360 # 8000a4a8 <tx_chan>
    80000a00:	59e010ef          	jal	80001f9e <wakeup>
    80000a04:	bff1                	j	800009e0 <uartintr+0x30>
      break;
    consoleintr(c);
    80000a06:	8a5ff0ef          	jal	800002aa <consoleintr>
    int c = uartgetc();
    80000a0a:	f81ff0ef          	jal	8000098a <uartgetc>
    if(c == -1)
    80000a0e:	fe951ce3          	bne	a0,s1,80000a06 <uartintr+0x56>
  }
}
    80000a12:	60e2                	ld	ra,24(sp)
    80000a14:	6442                	ld	s0,16(sp)
    80000a16:	64a2                	ld	s1,8(sp)
    80000a18:	6105                	addi	sp,sp,32
    80000a1a:	8082                	ret

0000000080000a1c <kfree>:
// which normally should have been returned by a
// call to kalloc().  (The exception is when
// initializing the allocator; see kinit above.)
void
kfree(void *pa)
{
    80000a1c:	1101                	addi	sp,sp,-32
    80000a1e:	ec06                	sd	ra,24(sp)
    80000a20:	e822                	sd	s0,16(sp)
    80000a22:	e426                	sd	s1,8(sp)
    80000a24:	e04a                	sd	s2,0(sp)
    80000a26:	1000                	addi	s0,sp,32
  struct run *r;

  if(((uint64)pa % PGSIZE) != 0 || (char*)pa < end || (uint64)pa >= PHYSTOP)
    80000a28:	03451793          	slli	a5,a0,0x34
    80000a2c:	e7a9                	bnez	a5,80000a76 <kfree+0x5a>
    80000a2e:	84aa                	mv	s1,a0
    80000a30:	00023797          	auipc	a5,0x23
    80000a34:	1a878793          	addi	a5,a5,424 # 80023bd8 <end>
    80000a38:	02f56f63          	bltu	a0,a5,80000a76 <kfree+0x5a>
    80000a3c:	47c5                	li	a5,17
    80000a3e:	07ee                	slli	a5,a5,0x1b
    80000a40:	02f57b63          	bgeu	a0,a5,80000a76 <kfree+0x5a>
    panic("kfree");

  // Fill with junk to catch dangling refs.
  memset(pa, 1, PGSIZE);
    80000a44:	6605                	lui	a2,0x1
    80000a46:	4585                	li	a1,1
    80000a48:	25a000ef          	jal	80000ca2 <memset>

  r = (struct run*)pa;

  acquire(&kmem.lock);
    80000a4c:	00012917          	auipc	s2,0x12
    80000a50:	b5c90913          	addi	s2,s2,-1188 # 800125a8 <kmem>
    80000a54:	854a                	mv	a0,s2
    80000a56:	178000ef          	jal	80000bce <acquire>
  r->next = kmem.freelist;
    80000a5a:	01893783          	ld	a5,24(s2)
    80000a5e:	e09c                	sd	a5,0(s1)
  kmem.freelist = r;
    80000a60:	00993c23          	sd	s1,24(s2)
  release(&kmem.lock);
    80000a64:	854a                	mv	a0,s2
    80000a66:	200000ef          	jal	80000c66 <release>
}
    80000a6a:	60e2                	ld	ra,24(sp)
    80000a6c:	6442                	ld	s0,16(sp)
    80000a6e:	64a2                	ld	s1,8(sp)
    80000a70:	6902                	ld	s2,0(sp)
    80000a72:	6105                	addi	sp,sp,32
    80000a74:	8082                	ret
    panic("kfree");
    80000a76:	00006517          	auipc	a0,0x6
    80000a7a:	5c250513          	addi	a0,a0,1474 # 80007038 <etext+0x38>
    80000a7e:	d63ff0ef          	jal	800007e0 <panic>

0000000080000a82 <freerange>:
{
    80000a82:	7179                	addi	sp,sp,-48
    80000a84:	f406                	sd	ra,40(sp)
    80000a86:	f022                	sd	s0,32(sp)
    80000a88:	ec26                	sd	s1,24(sp)
    80000a8a:	1800                	addi	s0,sp,48
  p = (char*)PGROUNDUP((uint64)pa_start);
    80000a8c:	6785                	lui	a5,0x1
    80000a8e:	fff78713          	addi	a4,a5,-1 # fff <_entry-0x7ffff001>
    80000a92:	00e504b3          	add	s1,a0,a4
    80000a96:	777d                	lui	a4,0xfffff
    80000a98:	8cf9                	and	s1,s1,a4
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000a9a:	94be                	add	s1,s1,a5
    80000a9c:	0295e263          	bltu	a1,s1,80000ac0 <freerange+0x3e>
    80000aa0:	e84a                	sd	s2,16(sp)
    80000aa2:	e44e                	sd	s3,8(sp)
    80000aa4:	e052                	sd	s4,0(sp)
    80000aa6:	892e                	mv	s2,a1
    kfree(p);
    80000aa8:	7a7d                	lui	s4,0xfffff
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000aaa:	6985                	lui	s3,0x1
    kfree(p);
    80000aac:	01448533          	add	a0,s1,s4
    80000ab0:	f6dff0ef          	jal	80000a1c <kfree>
  for(; p + PGSIZE <= (char*)pa_end; p += PGSIZE)
    80000ab4:	94ce                	add	s1,s1,s3
    80000ab6:	fe997be3          	bgeu	s2,s1,80000aac <freerange+0x2a>
    80000aba:	6942                	ld	s2,16(sp)
    80000abc:	69a2                	ld	s3,8(sp)
    80000abe:	6a02                	ld	s4,0(sp)
}
    80000ac0:	70a2                	ld	ra,40(sp)
    80000ac2:	7402                	ld	s0,32(sp)
    80000ac4:	64e2                	ld	s1,24(sp)
    80000ac6:	6145                	addi	sp,sp,48
    80000ac8:	8082                	ret

0000000080000aca <kinit>:
{
    80000aca:	1141                	addi	sp,sp,-16
    80000acc:	e406                	sd	ra,8(sp)
    80000ace:	e022                	sd	s0,0(sp)
    80000ad0:	0800                	addi	s0,sp,16
  initlock(&kmem.lock, "kmem");
    80000ad2:	00006597          	auipc	a1,0x6
    80000ad6:	56e58593          	addi	a1,a1,1390 # 80007040 <etext+0x40>
    80000ada:	00012517          	auipc	a0,0x12
    80000ade:	ace50513          	addi	a0,a0,-1330 # 800125a8 <kmem>
    80000ae2:	06c000ef          	jal	80000b4e <initlock>
  freerange(end, (void*)PHYSTOP);
    80000ae6:	45c5                	li	a1,17
    80000ae8:	05ee                	slli	a1,a1,0x1b
    80000aea:	00023517          	auipc	a0,0x23
    80000aee:	0ee50513          	addi	a0,a0,238 # 80023bd8 <end>
    80000af2:	f91ff0ef          	jal	80000a82 <freerange>
}
    80000af6:	60a2                	ld	ra,8(sp)
    80000af8:	6402                	ld	s0,0(sp)
    80000afa:	0141                	addi	sp,sp,16
    80000afc:	8082                	ret

0000000080000afe <kalloc>:
// Allocate one 4096-byte page of physical memory.
// Returns a pointer that the kernel can use.
// Returns 0 if the memory cannot be allocated.
void *
kalloc(void)
{
    80000afe:	1101                	addi	sp,sp,-32
    80000b00:	ec06                	sd	ra,24(sp)
    80000b02:	e822                	sd	s0,16(sp)
    80000b04:	e426                	sd	s1,8(sp)
    80000b06:	1000                	addi	s0,sp,32
  struct run *r;

  acquire(&kmem.lock);
    80000b08:	00012497          	auipc	s1,0x12
    80000b0c:	aa048493          	addi	s1,s1,-1376 # 800125a8 <kmem>
    80000b10:	8526                	mv	a0,s1
    80000b12:	0bc000ef          	jal	80000bce <acquire>
  r = kmem.freelist;
    80000b16:	6c84                	ld	s1,24(s1)
  if(r)
    80000b18:	c485                	beqz	s1,80000b40 <kalloc+0x42>
    kmem.freelist = r->next;
    80000b1a:	609c                	ld	a5,0(s1)
    80000b1c:	00012517          	auipc	a0,0x12
    80000b20:	a8c50513          	addi	a0,a0,-1396 # 800125a8 <kmem>
    80000b24:	ed1c                	sd	a5,24(a0)
  release(&kmem.lock);
    80000b26:	140000ef          	jal	80000c66 <release>

  if(r)
    memset((char*)r, 5, PGSIZE); // fill with junk
    80000b2a:	6605                	lui	a2,0x1
    80000b2c:	4595                	li	a1,5
    80000b2e:	8526                	mv	a0,s1
    80000b30:	172000ef          	jal	80000ca2 <memset>
  return (void*)r;
}
    80000b34:	8526                	mv	a0,s1
    80000b36:	60e2                	ld	ra,24(sp)
    80000b38:	6442                	ld	s0,16(sp)
    80000b3a:	64a2                	ld	s1,8(sp)
    80000b3c:	6105                	addi	sp,sp,32
    80000b3e:	8082                	ret
  release(&kmem.lock);
    80000b40:	00012517          	auipc	a0,0x12
    80000b44:	a6850513          	addi	a0,a0,-1432 # 800125a8 <kmem>
    80000b48:	11e000ef          	jal	80000c66 <release>
  if(r)
    80000b4c:	b7e5                	j	80000b34 <kalloc+0x36>

0000000080000b4e <initlock>:
#include "proc.h"
#include "defs.h"

void
initlock(struct spinlock *lk, char *name)
{
    80000b4e:	1141                	addi	sp,sp,-16
    80000b50:	e422                	sd	s0,8(sp)
    80000b52:	0800                	addi	s0,sp,16
  lk->name = name;
    80000b54:	e50c                	sd	a1,8(a0)
  lk->locked = 0;
    80000b56:	00052023          	sw	zero,0(a0)
  lk->cpu = 0;
    80000b5a:	00053823          	sd	zero,16(a0)
}
    80000b5e:	6422                	ld	s0,8(sp)
    80000b60:	0141                	addi	sp,sp,16
    80000b62:	8082                	ret

0000000080000b64 <holding>:
// Interrupts must be off.
int
holding(struct spinlock *lk)
{
  int r;
  r = (lk->locked && lk->cpu == mycpu());
    80000b64:	411c                	lw	a5,0(a0)
    80000b66:	e399                	bnez	a5,80000b6c <holding+0x8>
    80000b68:	4501                	li	a0,0
  return r;
}
    80000b6a:	8082                	ret
{
    80000b6c:	1101                	addi	sp,sp,-32
    80000b6e:	ec06                	sd	ra,24(sp)
    80000b70:	e822                	sd	s0,16(sp)
    80000b72:	e426                	sd	s1,8(sp)
    80000b74:	1000                	addi	s0,sp,32
  r = (lk->locked && lk->cpu == mycpu());
    80000b76:	6904                	ld	s1,16(a0)
    80000b78:	53b000ef          	jal	800018b2 <mycpu>
    80000b7c:	40a48533          	sub	a0,s1,a0
    80000b80:	00153513          	seqz	a0,a0
}
    80000b84:	60e2                	ld	ra,24(sp)
    80000b86:	6442                	ld	s0,16(sp)
    80000b88:	64a2                	ld	s1,8(sp)
    80000b8a:	6105                	addi	sp,sp,32
    80000b8c:	8082                	ret

0000000080000b8e <push_off>:
// it takes two pop_off()s to undo two push_off()s.  Also, if interrupts
// are initially off, then push_off, pop_off leaves them off.

void
push_off(void)
{
    80000b8e:	1101                	addi	sp,sp,-32
    80000b90:	ec06                	sd	ra,24(sp)
    80000b92:	e822                	sd	s0,16(sp)
    80000b94:	e426                	sd	s1,8(sp)
    80000b96:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000b98:	100024f3          	csrr	s1,sstatus
    80000b9c:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80000ba0:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000ba2:	10079073          	csrw	sstatus,a5

  // disable interrupts to prevent an involuntary context
  // switch while using mycpu().
  intr_off();

  if(mycpu()->noff == 0)
    80000ba6:	50d000ef          	jal	800018b2 <mycpu>
    80000baa:	5d3c                	lw	a5,120(a0)
    80000bac:	cb99                	beqz	a5,80000bc2 <push_off+0x34>
    mycpu()->intena = old;
  mycpu()->noff += 1;
    80000bae:	505000ef          	jal	800018b2 <mycpu>
    80000bb2:	5d3c                	lw	a5,120(a0)
    80000bb4:	2785                	addiw	a5,a5,1
    80000bb6:	dd3c                	sw	a5,120(a0)
}
    80000bb8:	60e2                	ld	ra,24(sp)
    80000bba:	6442                	ld	s0,16(sp)
    80000bbc:	64a2                	ld	s1,8(sp)
    80000bbe:	6105                	addi	sp,sp,32
    80000bc0:	8082                	ret
    mycpu()->intena = old;
    80000bc2:	4f1000ef          	jal	800018b2 <mycpu>
  return (x & SSTATUS_SIE) != 0;
    80000bc6:	8085                	srli	s1,s1,0x1
    80000bc8:	8885                	andi	s1,s1,1
    80000bca:	dd64                	sw	s1,124(a0)
    80000bcc:	b7cd                	j	80000bae <push_off+0x20>

0000000080000bce <acquire>:
{
    80000bce:	1101                	addi	sp,sp,-32
    80000bd0:	ec06                	sd	ra,24(sp)
    80000bd2:	e822                	sd	s0,16(sp)
    80000bd4:	e426                	sd	s1,8(sp)
    80000bd6:	1000                	addi	s0,sp,32
    80000bd8:	84aa                	mv	s1,a0
  push_off(); // disable interrupts to avoid deadlock.
    80000bda:	fb5ff0ef          	jal	80000b8e <push_off>
  if(holding(lk))
    80000bde:	8526                	mv	a0,s1
    80000be0:	f85ff0ef          	jal	80000b64 <holding>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000be4:	4705                	li	a4,1
  if(holding(lk))
    80000be6:	e105                	bnez	a0,80000c06 <acquire+0x38>
  while(__sync_lock_test_and_set(&lk->locked, 1) != 0)
    80000be8:	87ba                	mv	a5,a4
    80000bea:	0cf4a7af          	amoswap.w.aq	a5,a5,(s1)
    80000bee:	2781                	sext.w	a5,a5
    80000bf0:	ffe5                	bnez	a5,80000be8 <acquire+0x1a>
  __sync_synchronize();
    80000bf2:	0330000f          	fence	rw,rw
  lk->cpu = mycpu();
    80000bf6:	4bd000ef          	jal	800018b2 <mycpu>
    80000bfa:	e888                	sd	a0,16(s1)
}
    80000bfc:	60e2                	ld	ra,24(sp)
    80000bfe:	6442                	ld	s0,16(sp)
    80000c00:	64a2                	ld	s1,8(sp)
    80000c02:	6105                	addi	sp,sp,32
    80000c04:	8082                	ret
    panic("acquire");
    80000c06:	00006517          	auipc	a0,0x6
    80000c0a:	44250513          	addi	a0,a0,1090 # 80007048 <etext+0x48>
    80000c0e:	bd3ff0ef          	jal	800007e0 <panic>

0000000080000c12 <pop_off>:

void
pop_off(void)
{
    80000c12:	1141                	addi	sp,sp,-16
    80000c14:	e406                	sd	ra,8(sp)
    80000c16:	e022                	sd	s0,0(sp)
    80000c18:	0800                	addi	s0,sp,16
  struct cpu *c = mycpu();
    80000c1a:	499000ef          	jal	800018b2 <mycpu>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000c1e:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80000c22:	8b89                	andi	a5,a5,2
  if(intr_get())
    80000c24:	e78d                	bnez	a5,80000c4e <pop_off+0x3c>
    panic("pop_off - interruptible");
  if(c->noff < 1)
    80000c26:	5d3c                	lw	a5,120(a0)
    80000c28:	02f05963          	blez	a5,80000c5a <pop_off+0x48>
    panic("pop_off");
  c->noff -= 1;
    80000c2c:	37fd                	addiw	a5,a5,-1
    80000c2e:	0007871b          	sext.w	a4,a5
    80000c32:	dd3c                	sw	a5,120(a0)
  if(c->noff == 0 && c->intena)
    80000c34:	eb09                	bnez	a4,80000c46 <pop_off+0x34>
    80000c36:	5d7c                	lw	a5,124(a0)
    80000c38:	c799                	beqz	a5,80000c46 <pop_off+0x34>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80000c3a:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80000c3e:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80000c42:	10079073          	csrw	sstatus,a5
    intr_on();
}
    80000c46:	60a2                	ld	ra,8(sp)
    80000c48:	6402                	ld	s0,0(sp)
    80000c4a:	0141                	addi	sp,sp,16
    80000c4c:	8082                	ret
    panic("pop_off - interruptible");
    80000c4e:	00006517          	auipc	a0,0x6
    80000c52:	40250513          	addi	a0,a0,1026 # 80007050 <etext+0x50>
    80000c56:	b8bff0ef          	jal	800007e0 <panic>
    panic("pop_off");
    80000c5a:	00006517          	auipc	a0,0x6
    80000c5e:	40e50513          	addi	a0,a0,1038 # 80007068 <etext+0x68>
    80000c62:	b7fff0ef          	jal	800007e0 <panic>

0000000080000c66 <release>:
{
    80000c66:	1101                	addi	sp,sp,-32
    80000c68:	ec06                	sd	ra,24(sp)
    80000c6a:	e822                	sd	s0,16(sp)
    80000c6c:	e426                	sd	s1,8(sp)
    80000c6e:	1000                	addi	s0,sp,32
    80000c70:	84aa                	mv	s1,a0
  if(!holding(lk))
    80000c72:	ef3ff0ef          	jal	80000b64 <holding>
    80000c76:	c105                	beqz	a0,80000c96 <release+0x30>
  lk->cpu = 0;
    80000c78:	0004b823          	sd	zero,16(s1)
  __sync_synchronize();
    80000c7c:	0330000f          	fence	rw,rw
  __sync_lock_release(&lk->locked);
    80000c80:	0310000f          	fence	rw,w
    80000c84:	0004a023          	sw	zero,0(s1)
  pop_off();
    80000c88:	f8bff0ef          	jal	80000c12 <pop_off>
}
    80000c8c:	60e2                	ld	ra,24(sp)
    80000c8e:	6442                	ld	s0,16(sp)
    80000c90:	64a2                	ld	s1,8(sp)
    80000c92:	6105                	addi	sp,sp,32
    80000c94:	8082                	ret
    panic("release");
    80000c96:	00006517          	auipc	a0,0x6
    80000c9a:	3da50513          	addi	a0,a0,986 # 80007070 <etext+0x70>
    80000c9e:	b43ff0ef          	jal	800007e0 <panic>

0000000080000ca2 <memset>:
#include "types.h"

void*
memset(void *dst, int c, uint n)
{
    80000ca2:	1141                	addi	sp,sp,-16
    80000ca4:	e422                	sd	s0,8(sp)
    80000ca6:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
    80000ca8:	ca19                	beqz	a2,80000cbe <memset+0x1c>
    80000caa:	87aa                	mv	a5,a0
    80000cac:	1602                	slli	a2,a2,0x20
    80000cae:	9201                	srli	a2,a2,0x20
    80000cb0:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
    80000cb4:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
    80000cb8:	0785                	addi	a5,a5,1
    80000cba:	fee79de3          	bne	a5,a4,80000cb4 <memset+0x12>
  }
  return dst;
}
    80000cbe:	6422                	ld	s0,8(sp)
    80000cc0:	0141                	addi	sp,sp,16
    80000cc2:	8082                	ret

0000000080000cc4 <memcmp>:

int
memcmp(const void *v1, const void *v2, uint n)
{
    80000cc4:	1141                	addi	sp,sp,-16
    80000cc6:	e422                	sd	s0,8(sp)
    80000cc8:	0800                	addi	s0,sp,16
  const uchar *s1, *s2;

  s1 = v1;
  s2 = v2;
  while(n-- > 0){
    80000cca:	ca05                	beqz	a2,80000cfa <memcmp+0x36>
    80000ccc:	fff6069b          	addiw	a3,a2,-1 # fff <_entry-0x7ffff001>
    80000cd0:	1682                	slli	a3,a3,0x20
    80000cd2:	9281                	srli	a3,a3,0x20
    80000cd4:	0685                	addi	a3,a3,1
    80000cd6:	96aa                	add	a3,a3,a0
    if(*s1 != *s2)
    80000cd8:	00054783          	lbu	a5,0(a0)
    80000cdc:	0005c703          	lbu	a4,0(a1)
    80000ce0:	00e79863          	bne	a5,a4,80000cf0 <memcmp+0x2c>
      return *s1 - *s2;
    s1++, s2++;
    80000ce4:	0505                	addi	a0,a0,1
    80000ce6:	0585                	addi	a1,a1,1
  while(n-- > 0){
    80000ce8:	fed518e3          	bne	a0,a3,80000cd8 <memcmp+0x14>
  }

  return 0;
    80000cec:	4501                	li	a0,0
    80000cee:	a019                	j	80000cf4 <memcmp+0x30>
      return *s1 - *s2;
    80000cf0:	40e7853b          	subw	a0,a5,a4
}
    80000cf4:	6422                	ld	s0,8(sp)
    80000cf6:	0141                	addi	sp,sp,16
    80000cf8:	8082                	ret
  return 0;
    80000cfa:	4501                	li	a0,0
    80000cfc:	bfe5                	j	80000cf4 <memcmp+0x30>

0000000080000cfe <memmove>:

void*
memmove(void *dst, const void *src, uint n)
{
    80000cfe:	1141                	addi	sp,sp,-16
    80000d00:	e422                	sd	s0,8(sp)
    80000d02:	0800                	addi	s0,sp,16
  const char *s;
  char *d;

  if(n == 0)
    80000d04:	c205                	beqz	a2,80000d24 <memmove+0x26>
    return dst;
  
  s = src;
  d = dst;
  if(s < d && s + n > d){
    80000d06:	02a5e263          	bltu	a1,a0,80000d2a <memmove+0x2c>
    s += n;
    d += n;
    while(n-- > 0)
      *--d = *--s;
  } else
    while(n-- > 0)
    80000d0a:	1602                	slli	a2,a2,0x20
    80000d0c:	9201                	srli	a2,a2,0x20
    80000d0e:	00c587b3          	add	a5,a1,a2
{
    80000d12:	872a                	mv	a4,a0
      *d++ = *s++;
    80000d14:	0585                	addi	a1,a1,1
    80000d16:	0705                	addi	a4,a4,1 # fffffffffffff001 <end+0xffffffff7ffdb429>
    80000d18:	fff5c683          	lbu	a3,-1(a1)
    80000d1c:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
    80000d20:	feb79ae3          	bne	a5,a1,80000d14 <memmove+0x16>

  return dst;
}
    80000d24:	6422                	ld	s0,8(sp)
    80000d26:	0141                	addi	sp,sp,16
    80000d28:	8082                	ret
  if(s < d && s + n > d){
    80000d2a:	02061693          	slli	a3,a2,0x20
    80000d2e:	9281                	srli	a3,a3,0x20
    80000d30:	00d58733          	add	a4,a1,a3
    80000d34:	fce57be3          	bgeu	a0,a4,80000d0a <memmove+0xc>
    d += n;
    80000d38:	96aa                	add	a3,a3,a0
    while(n-- > 0)
    80000d3a:	fff6079b          	addiw	a5,a2,-1
    80000d3e:	1782                	slli	a5,a5,0x20
    80000d40:	9381                	srli	a5,a5,0x20
    80000d42:	fff7c793          	not	a5,a5
    80000d46:	97ba                	add	a5,a5,a4
      *--d = *--s;
    80000d48:	177d                	addi	a4,a4,-1
    80000d4a:	16fd                	addi	a3,a3,-1
    80000d4c:	00074603          	lbu	a2,0(a4)
    80000d50:	00c68023          	sb	a2,0(a3)
    while(n-- > 0)
    80000d54:	fef71ae3          	bne	a4,a5,80000d48 <memmove+0x4a>
    80000d58:	b7f1                	j	80000d24 <memmove+0x26>

0000000080000d5a <memcpy>:

// memcpy exists to placate GCC.  Use memmove.
void*
memcpy(void *dst, const void *src, uint n)
{
    80000d5a:	1141                	addi	sp,sp,-16
    80000d5c:	e406                	sd	ra,8(sp)
    80000d5e:	e022                	sd	s0,0(sp)
    80000d60:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
    80000d62:	f9dff0ef          	jal	80000cfe <memmove>
}
    80000d66:	60a2                	ld	ra,8(sp)
    80000d68:	6402                	ld	s0,0(sp)
    80000d6a:	0141                	addi	sp,sp,16
    80000d6c:	8082                	ret

0000000080000d6e <strncmp>:

int
strncmp(const char *p, const char *q, uint n)
{
    80000d6e:	1141                	addi	sp,sp,-16
    80000d70:	e422                	sd	s0,8(sp)
    80000d72:	0800                	addi	s0,sp,16
  while(n > 0 && *p && *p == *q)
    80000d74:	ce11                	beqz	a2,80000d90 <strncmp+0x22>
    80000d76:	00054783          	lbu	a5,0(a0)
    80000d7a:	cf89                	beqz	a5,80000d94 <strncmp+0x26>
    80000d7c:	0005c703          	lbu	a4,0(a1)
    80000d80:	00f71a63          	bne	a4,a5,80000d94 <strncmp+0x26>
    n--, p++, q++;
    80000d84:	367d                	addiw	a2,a2,-1
    80000d86:	0505                	addi	a0,a0,1
    80000d88:	0585                	addi	a1,a1,1
  while(n > 0 && *p && *p == *q)
    80000d8a:	f675                	bnez	a2,80000d76 <strncmp+0x8>
  if(n == 0)
    return 0;
    80000d8c:	4501                	li	a0,0
    80000d8e:	a801                	j	80000d9e <strncmp+0x30>
    80000d90:	4501                	li	a0,0
    80000d92:	a031                	j	80000d9e <strncmp+0x30>
  return (uchar)*p - (uchar)*q;
    80000d94:	00054503          	lbu	a0,0(a0)
    80000d98:	0005c783          	lbu	a5,0(a1)
    80000d9c:	9d1d                	subw	a0,a0,a5
}
    80000d9e:	6422                	ld	s0,8(sp)
    80000da0:	0141                	addi	sp,sp,16
    80000da2:	8082                	ret

0000000080000da4 <strncpy>:

char*
strncpy(char *s, const char *t, int n)
{
    80000da4:	1141                	addi	sp,sp,-16
    80000da6:	e422                	sd	s0,8(sp)
    80000da8:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while(n-- > 0 && (*s++ = *t++) != 0)
    80000daa:	87aa                	mv	a5,a0
    80000dac:	86b2                	mv	a3,a2
    80000dae:	367d                	addiw	a2,a2,-1
    80000db0:	02d05563          	blez	a3,80000dda <strncpy+0x36>
    80000db4:	0785                	addi	a5,a5,1
    80000db6:	0005c703          	lbu	a4,0(a1)
    80000dba:	fee78fa3          	sb	a4,-1(a5)
    80000dbe:	0585                	addi	a1,a1,1
    80000dc0:	f775                	bnez	a4,80000dac <strncpy+0x8>
    ;
  while(n-- > 0)
    80000dc2:	873e                	mv	a4,a5
    80000dc4:	9fb5                	addw	a5,a5,a3
    80000dc6:	37fd                	addiw	a5,a5,-1
    80000dc8:	00c05963          	blez	a2,80000dda <strncpy+0x36>
    *s++ = 0;
    80000dcc:	0705                	addi	a4,a4,1
    80000dce:	fe070fa3          	sb	zero,-1(a4)
  while(n-- > 0)
    80000dd2:	40e786bb          	subw	a3,a5,a4
    80000dd6:	fed04be3          	bgtz	a3,80000dcc <strncpy+0x28>
  return os;
}
    80000dda:	6422                	ld	s0,8(sp)
    80000ddc:	0141                	addi	sp,sp,16
    80000dde:	8082                	ret

0000000080000de0 <safestrcpy>:

// Like strncpy but guaranteed to NUL-terminate.
char*
safestrcpy(char *s, const char *t, int n)
{
    80000de0:	1141                	addi	sp,sp,-16
    80000de2:	e422                	sd	s0,8(sp)
    80000de4:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  if(n <= 0)
    80000de6:	02c05363          	blez	a2,80000e0c <safestrcpy+0x2c>
    80000dea:	fff6069b          	addiw	a3,a2,-1
    80000dee:	1682                	slli	a3,a3,0x20
    80000df0:	9281                	srli	a3,a3,0x20
    80000df2:	96ae                	add	a3,a3,a1
    80000df4:	87aa                	mv	a5,a0
    return os;
  while(--n > 0 && (*s++ = *t++) != 0)
    80000df6:	00d58963          	beq	a1,a3,80000e08 <safestrcpy+0x28>
    80000dfa:	0585                	addi	a1,a1,1
    80000dfc:	0785                	addi	a5,a5,1
    80000dfe:	fff5c703          	lbu	a4,-1(a1)
    80000e02:	fee78fa3          	sb	a4,-1(a5)
    80000e06:	fb65                	bnez	a4,80000df6 <safestrcpy+0x16>
    ;
  *s = 0;
    80000e08:	00078023          	sb	zero,0(a5)
  return os;
}
    80000e0c:	6422                	ld	s0,8(sp)
    80000e0e:	0141                	addi	sp,sp,16
    80000e10:	8082                	ret

0000000080000e12 <strlen>:

int
strlen(const char *s)
{
    80000e12:	1141                	addi	sp,sp,-16
    80000e14:	e422                	sd	s0,8(sp)
    80000e16:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
    80000e18:	00054783          	lbu	a5,0(a0)
    80000e1c:	cf91                	beqz	a5,80000e38 <strlen+0x26>
    80000e1e:	0505                	addi	a0,a0,1
    80000e20:	87aa                	mv	a5,a0
    80000e22:	86be                	mv	a3,a5
    80000e24:	0785                	addi	a5,a5,1
    80000e26:	fff7c703          	lbu	a4,-1(a5)
    80000e2a:	ff65                	bnez	a4,80000e22 <strlen+0x10>
    80000e2c:	40a6853b          	subw	a0,a3,a0
    80000e30:	2505                	addiw	a0,a0,1
    ;
  return n;
}
    80000e32:	6422                	ld	s0,8(sp)
    80000e34:	0141                	addi	sp,sp,16
    80000e36:	8082                	ret
  for(n = 0; s[n]; n++)
    80000e38:	4501                	li	a0,0
    80000e3a:	bfe5                	j	80000e32 <strlen+0x20>

0000000080000e3c <main>:
volatile static int started = 0;

// start() jumps here in supervisor mode on all CPUs.
void
main()
{
    80000e3c:	1141                	addi	sp,sp,-16
    80000e3e:	e406                	sd	ra,8(sp)
    80000e40:	e022                	sd	s0,0(sp)
    80000e42:	0800                	addi	s0,sp,16
  if(cpuid() == 0){
    80000e44:	25f000ef          	jal	800018a2 <cpuid>
    virtio_disk_init(); // emulated hard disk
    userinit();      // first user process
    __sync_synchronize();
    started = 1;
  } else {
    while(started == 0)
    80000e48:	00009717          	auipc	a4,0x9
    80000e4c:	66870713          	addi	a4,a4,1640 # 8000a4b0 <started>
  if(cpuid() == 0){
    80000e50:	c51d                	beqz	a0,80000e7e <main+0x42>
    while(started == 0)
    80000e52:	431c                	lw	a5,0(a4)
    80000e54:	2781                	sext.w	a5,a5
    80000e56:	dff5                	beqz	a5,80000e52 <main+0x16>
      ;
    __sync_synchronize();
    80000e58:	0330000f          	fence	rw,rw
    printf("hart %d starting\n", cpuid());
    80000e5c:	247000ef          	jal	800018a2 <cpuid>
    80000e60:	85aa                	mv	a1,a0
    80000e62:	00006517          	auipc	a0,0x6
    80000e66:	23650513          	addi	a0,a0,566 # 80007098 <etext+0x98>
    80000e6a:	e90ff0ef          	jal	800004fa <printf>
    kvminithart();    // turn on paging
    80000e6e:	080000ef          	jal	80000eee <kvminithart>
    trapinithart();   // install kernel trap vector
    80000e72:	602010ef          	jal	80002474 <trapinithart>
    plicinithart();   // ask PLIC for device interrupts
    80000e76:	0d3040ef          	jal	80005748 <plicinithart>
  }

  scheduler();        
    80000e7a:	741000ef          	jal	80001dba <scheduler>
    consoleinit();
    80000e7e:	da6ff0ef          	jal	80000424 <consoleinit>
    printfinit();
    80000e82:	99bff0ef          	jal	8000081c <printfinit>
    printf("\n");
    80000e86:	00006517          	auipc	a0,0x6
    80000e8a:	1f250513          	addi	a0,a0,498 # 80007078 <etext+0x78>
    80000e8e:	e6cff0ef          	jal	800004fa <printf>
    printf("xv6 kernel is booting\n");
    80000e92:	00006517          	auipc	a0,0x6
    80000e96:	1ee50513          	addi	a0,a0,494 # 80007080 <etext+0x80>
    80000e9a:	e60ff0ef          	jal	800004fa <printf>
    printf("\n");
    80000e9e:	00006517          	auipc	a0,0x6
    80000ea2:	1da50513          	addi	a0,a0,474 # 80007078 <etext+0x78>
    80000ea6:	e54ff0ef          	jal	800004fa <printf>
    kinit();         // physical page allocator
    80000eaa:	c21ff0ef          	jal	80000aca <kinit>
    kvminit();       // create kernel page table
    80000eae:	2ca000ef          	jal	80001178 <kvminit>
    kvminithart();   // turn on paging
    80000eb2:	03c000ef          	jal	80000eee <kvminithart>
    procinit();      // process table
    80000eb6:	137000ef          	jal	800017ec <procinit>
    trapinit();      // trap vectors
    80000eba:	596010ef          	jal	80002450 <trapinit>
    trapinithart();  // install kernel trap vector
    80000ebe:	5b6010ef          	jal	80002474 <trapinithart>
    plicinit();      // set up interrupt controller
    80000ec2:	06d040ef          	jal	8000572e <plicinit>
    plicinithart();  // ask PLIC for device interrupts
    80000ec6:	083040ef          	jal	80005748 <plicinithart>
    binit();         // buffer cache
    80000eca:	749010ef          	jal	80002e12 <binit>
    iinit();         // inode table
    80000ece:	4ce020ef          	jal	8000339c <iinit>
    fileinit();      // file table
    80000ed2:	3c0030ef          	jal	80004292 <fileinit>
    virtio_disk_init(); // emulated hard disk
    80000ed6:	163040ef          	jal	80005838 <virtio_disk_init>
    userinit();      // first user process
    80000eda:	4d1000ef          	jal	80001baa <userinit>
    __sync_synchronize();
    80000ede:	0330000f          	fence	rw,rw
    started = 1;
    80000ee2:	4785                	li	a5,1
    80000ee4:	00009717          	auipc	a4,0x9
    80000ee8:	5cf72623          	sw	a5,1484(a4) # 8000a4b0 <started>
    80000eec:	b779                	j	80000e7a <main+0x3e>

0000000080000eee <kvminithart>:

// Switch the current CPU's h/w page table register to
// the kernel's page table, and enable paging.
void
kvminithart()
{
    80000eee:	1141                	addi	sp,sp,-16
    80000ef0:	e422                	sd	s0,8(sp)
    80000ef2:	0800                	addi	s0,sp,16
// flush the TLB.
static inline void
sfence_vma()
{
  // the zero, zero means flush all TLB entries.
  asm volatile("sfence.vma zero, zero");
    80000ef4:	12000073          	sfence.vma
  // wait for any previous writes to the page table memory to finish.
  sfence_vma();

  w_satp(MAKE_SATP(kernel_pagetable));
    80000ef8:	00009797          	auipc	a5,0x9
    80000efc:	5c07b783          	ld	a5,1472(a5) # 8000a4b8 <kernel_pagetable>
    80000f00:	83b1                	srli	a5,a5,0xc
    80000f02:	577d                	li	a4,-1
    80000f04:	177e                	slli	a4,a4,0x3f
    80000f06:	8fd9                	or	a5,a5,a4
  asm volatile("csrw satp, %0" : : "r" (x));
    80000f08:	18079073          	csrw	satp,a5
  asm volatile("sfence.vma zero, zero");
    80000f0c:	12000073          	sfence.vma

  // flush stale entries from the TLB.
  sfence_vma();
}
    80000f10:	6422                	ld	s0,8(sp)
    80000f12:	0141                	addi	sp,sp,16
    80000f14:	8082                	ret

0000000080000f16 <walk>:
//   21..29 -- 9 bits of level-1 index.
//   12..20 -- 9 bits of level-0 index.
//    0..11 -- 12 bits of byte offset within the page.
pte_t *
walk(pagetable_t pagetable, uint64 va, int alloc)
{
    80000f16:	7139                	addi	sp,sp,-64
    80000f18:	fc06                	sd	ra,56(sp)
    80000f1a:	f822                	sd	s0,48(sp)
    80000f1c:	f426                	sd	s1,40(sp)
    80000f1e:	f04a                	sd	s2,32(sp)
    80000f20:	ec4e                	sd	s3,24(sp)
    80000f22:	e852                	sd	s4,16(sp)
    80000f24:	e456                	sd	s5,8(sp)
    80000f26:	e05a                	sd	s6,0(sp)
    80000f28:	0080                	addi	s0,sp,64
    80000f2a:	84aa                	mv	s1,a0
    80000f2c:	89ae                	mv	s3,a1
    80000f2e:	8ab2                	mv	s5,a2
  if(va >= MAXVA)
    80000f30:	57fd                	li	a5,-1
    80000f32:	83e9                	srli	a5,a5,0x1a
    80000f34:	4a79                	li	s4,30
    panic("walk");

  for(int level = 2; level > 0; level--) {
    80000f36:	4b31                	li	s6,12
  if(va >= MAXVA)
    80000f38:	02b7fc63          	bgeu	a5,a1,80000f70 <walk+0x5a>
    panic("walk");
    80000f3c:	00006517          	auipc	a0,0x6
    80000f40:	17450513          	addi	a0,a0,372 # 800070b0 <etext+0xb0>
    80000f44:	89dff0ef          	jal	800007e0 <panic>
    pte_t *pte = &pagetable[PX(level, va)];
    if(*pte & PTE_V) {
      pagetable = (pagetable_t)PTE2PA(*pte);
    } else {
      if(!alloc || (pagetable = (pde_t*)kalloc()) == 0)
    80000f48:	060a8263          	beqz	s5,80000fac <walk+0x96>
    80000f4c:	bb3ff0ef          	jal	80000afe <kalloc>
    80000f50:	84aa                	mv	s1,a0
    80000f52:	c139                	beqz	a0,80000f98 <walk+0x82>
        return 0;
      memset(pagetable, 0, PGSIZE);
    80000f54:	6605                	lui	a2,0x1
    80000f56:	4581                	li	a1,0
    80000f58:	d4bff0ef          	jal	80000ca2 <memset>
      *pte = PA2PTE(pagetable) | PTE_V;
    80000f5c:	00c4d793          	srli	a5,s1,0xc
    80000f60:	07aa                	slli	a5,a5,0xa
    80000f62:	0017e793          	ori	a5,a5,1
    80000f66:	00f93023          	sd	a5,0(s2)
  for(int level = 2; level > 0; level--) {
    80000f6a:	3a5d                	addiw	s4,s4,-9 # ffffffffffffeff7 <end+0xffffffff7ffdb41f>
    80000f6c:	036a0063          	beq	s4,s6,80000f8c <walk+0x76>
    pte_t *pte = &pagetable[PX(level, va)];
    80000f70:	0149d933          	srl	s2,s3,s4
    80000f74:	1ff97913          	andi	s2,s2,511
    80000f78:	090e                	slli	s2,s2,0x3
    80000f7a:	9926                	add	s2,s2,s1
    if(*pte & PTE_V) {
    80000f7c:	00093483          	ld	s1,0(s2)
    80000f80:	0014f793          	andi	a5,s1,1
    80000f84:	d3f1                	beqz	a5,80000f48 <walk+0x32>
      pagetable = (pagetable_t)PTE2PA(*pte);
    80000f86:	80a9                	srli	s1,s1,0xa
    80000f88:	04b2                	slli	s1,s1,0xc
    80000f8a:	b7c5                	j	80000f6a <walk+0x54>
    }
  }
  return &pagetable[PX(0, va)];
    80000f8c:	00c9d513          	srli	a0,s3,0xc
    80000f90:	1ff57513          	andi	a0,a0,511
    80000f94:	050e                	slli	a0,a0,0x3
    80000f96:	9526                	add	a0,a0,s1
}
    80000f98:	70e2                	ld	ra,56(sp)
    80000f9a:	7442                	ld	s0,48(sp)
    80000f9c:	74a2                	ld	s1,40(sp)
    80000f9e:	7902                	ld	s2,32(sp)
    80000fa0:	69e2                	ld	s3,24(sp)
    80000fa2:	6a42                	ld	s4,16(sp)
    80000fa4:	6aa2                	ld	s5,8(sp)
    80000fa6:	6b02                	ld	s6,0(sp)
    80000fa8:	6121                	addi	sp,sp,64
    80000faa:	8082                	ret
        return 0;
    80000fac:	4501                	li	a0,0
    80000fae:	b7ed                	j	80000f98 <walk+0x82>

0000000080000fb0 <walkaddr>:
walkaddr(pagetable_t pagetable, uint64 va)
{
  pte_t *pte;
  uint64 pa;

  if(va >= MAXVA)
    80000fb0:	57fd                	li	a5,-1
    80000fb2:	83e9                	srli	a5,a5,0x1a
    80000fb4:	00b7f463          	bgeu	a5,a1,80000fbc <walkaddr+0xc>
    return 0;
    80000fb8:	4501                	li	a0,0
    return 0;
  if((*pte & PTE_U) == 0)
    return 0;
  pa = PTE2PA(*pte);
  return pa;
}
    80000fba:	8082                	ret
{
    80000fbc:	1141                	addi	sp,sp,-16
    80000fbe:	e406                	sd	ra,8(sp)
    80000fc0:	e022                	sd	s0,0(sp)
    80000fc2:	0800                	addi	s0,sp,16
  pte = walk(pagetable, va, 0);
    80000fc4:	4601                	li	a2,0
    80000fc6:	f51ff0ef          	jal	80000f16 <walk>
  if(pte == 0)
    80000fca:	c105                	beqz	a0,80000fea <walkaddr+0x3a>
  if((*pte & PTE_V) == 0)
    80000fcc:	611c                	ld	a5,0(a0)
  if((*pte & PTE_U) == 0)
    80000fce:	0117f693          	andi	a3,a5,17
    80000fd2:	4745                	li	a4,17
    return 0;
    80000fd4:	4501                	li	a0,0
  if((*pte & PTE_U) == 0)
    80000fd6:	00e68663          	beq	a3,a4,80000fe2 <walkaddr+0x32>
}
    80000fda:	60a2                	ld	ra,8(sp)
    80000fdc:	6402                	ld	s0,0(sp)
    80000fde:	0141                	addi	sp,sp,16
    80000fe0:	8082                	ret
  pa = PTE2PA(*pte);
    80000fe2:	83a9                	srli	a5,a5,0xa
    80000fe4:	00c79513          	slli	a0,a5,0xc
  return pa;
    80000fe8:	bfcd                	j	80000fda <walkaddr+0x2a>
    return 0;
    80000fea:	4501                	li	a0,0
    80000fec:	b7fd                	j	80000fda <walkaddr+0x2a>

0000000080000fee <mappages>:
// va and size MUST be page-aligned.
// Returns 0 on success, -1 if walk() couldn't
// allocate a needed page-table page.
int
mappages(pagetable_t pagetable, uint64 va, uint64 size, uint64 pa, int perm)
{
    80000fee:	715d                	addi	sp,sp,-80
    80000ff0:	e486                	sd	ra,72(sp)
    80000ff2:	e0a2                	sd	s0,64(sp)
    80000ff4:	fc26                	sd	s1,56(sp)
    80000ff6:	f84a                	sd	s2,48(sp)
    80000ff8:	f44e                	sd	s3,40(sp)
    80000ffa:	f052                	sd	s4,32(sp)
    80000ffc:	ec56                	sd	s5,24(sp)
    80000ffe:	e85a                	sd	s6,16(sp)
    80001000:	e45e                	sd	s7,8(sp)
    80001002:	0880                	addi	s0,sp,80
  uint64 a, last;
  pte_t *pte;

  if((va % PGSIZE) != 0)
    80001004:	03459793          	slli	a5,a1,0x34
    80001008:	e7a9                	bnez	a5,80001052 <mappages+0x64>
    8000100a:	8aaa                	mv	s5,a0
    8000100c:	8b3a                	mv	s6,a4
    panic("mappages: va not aligned");

  if((size % PGSIZE) != 0)
    8000100e:	03461793          	slli	a5,a2,0x34
    80001012:	e7b1                	bnez	a5,8000105e <mappages+0x70>
    panic("mappages: size not aligned");

  if(size == 0)
    80001014:	ca39                	beqz	a2,8000106a <mappages+0x7c>
    panic("mappages: size");
  
  a = va;
  last = va + size - PGSIZE;
    80001016:	77fd                	lui	a5,0xfffff
    80001018:	963e                	add	a2,a2,a5
    8000101a:	00b609b3          	add	s3,a2,a1
  a = va;
    8000101e:	892e                	mv	s2,a1
    80001020:	40b68a33          	sub	s4,a3,a1
    if(*pte & PTE_V)
      panic("mappages: remap");
    *pte = PA2PTE(pa) | perm | PTE_V;
    if(a == last)
      break;
    a += PGSIZE;
    80001024:	6b85                	lui	s7,0x1
    80001026:	014904b3          	add	s1,s2,s4
    if((pte = walk(pagetable, a, 1)) == 0)
    8000102a:	4605                	li	a2,1
    8000102c:	85ca                	mv	a1,s2
    8000102e:	8556                	mv	a0,s5
    80001030:	ee7ff0ef          	jal	80000f16 <walk>
    80001034:	c539                	beqz	a0,80001082 <mappages+0x94>
    if(*pte & PTE_V)
    80001036:	611c                	ld	a5,0(a0)
    80001038:	8b85                	andi	a5,a5,1
    8000103a:	ef95                	bnez	a5,80001076 <mappages+0x88>
    *pte = PA2PTE(pa) | perm | PTE_V;
    8000103c:	80b1                	srli	s1,s1,0xc
    8000103e:	04aa                	slli	s1,s1,0xa
    80001040:	0164e4b3          	or	s1,s1,s6
    80001044:	0014e493          	ori	s1,s1,1
    80001048:	e104                	sd	s1,0(a0)
    if(a == last)
    8000104a:	05390863          	beq	s2,s3,8000109a <mappages+0xac>
    a += PGSIZE;
    8000104e:	995e                	add	s2,s2,s7
    if((pte = walk(pagetable, a, 1)) == 0)
    80001050:	bfd9                	j	80001026 <mappages+0x38>
    panic("mappages: va not aligned");
    80001052:	00006517          	auipc	a0,0x6
    80001056:	06650513          	addi	a0,a0,102 # 800070b8 <etext+0xb8>
    8000105a:	f86ff0ef          	jal	800007e0 <panic>
    panic("mappages: size not aligned");
    8000105e:	00006517          	auipc	a0,0x6
    80001062:	07a50513          	addi	a0,a0,122 # 800070d8 <etext+0xd8>
    80001066:	f7aff0ef          	jal	800007e0 <panic>
    panic("mappages: size");
    8000106a:	00006517          	auipc	a0,0x6
    8000106e:	08e50513          	addi	a0,a0,142 # 800070f8 <etext+0xf8>
    80001072:	f6eff0ef          	jal	800007e0 <panic>
      panic("mappages: remap");
    80001076:	00006517          	auipc	a0,0x6
    8000107a:	09250513          	addi	a0,a0,146 # 80007108 <etext+0x108>
    8000107e:	f62ff0ef          	jal	800007e0 <panic>
      return -1;
    80001082:	557d                	li	a0,-1
    pa += PGSIZE;
  }
  return 0;
}
    80001084:	60a6                	ld	ra,72(sp)
    80001086:	6406                	ld	s0,64(sp)
    80001088:	74e2                	ld	s1,56(sp)
    8000108a:	7942                	ld	s2,48(sp)
    8000108c:	79a2                	ld	s3,40(sp)
    8000108e:	7a02                	ld	s4,32(sp)
    80001090:	6ae2                	ld	s5,24(sp)
    80001092:	6b42                	ld	s6,16(sp)
    80001094:	6ba2                	ld	s7,8(sp)
    80001096:	6161                	addi	sp,sp,80
    80001098:	8082                	ret
  return 0;
    8000109a:	4501                	li	a0,0
    8000109c:	b7e5                	j	80001084 <mappages+0x96>

000000008000109e <kvmmap>:
{
    8000109e:	1141                	addi	sp,sp,-16
    800010a0:	e406                	sd	ra,8(sp)
    800010a2:	e022                	sd	s0,0(sp)
    800010a4:	0800                	addi	s0,sp,16
    800010a6:	87b6                	mv	a5,a3
  if(mappages(kpgtbl, va, sz, pa, perm) != 0)
    800010a8:	86b2                	mv	a3,a2
    800010aa:	863e                	mv	a2,a5
    800010ac:	f43ff0ef          	jal	80000fee <mappages>
    800010b0:	e509                	bnez	a0,800010ba <kvmmap+0x1c>
}
    800010b2:	60a2                	ld	ra,8(sp)
    800010b4:	6402                	ld	s0,0(sp)
    800010b6:	0141                	addi	sp,sp,16
    800010b8:	8082                	ret
    panic("kvmmap");
    800010ba:	00006517          	auipc	a0,0x6
    800010be:	05e50513          	addi	a0,a0,94 # 80007118 <etext+0x118>
    800010c2:	f1eff0ef          	jal	800007e0 <panic>

00000000800010c6 <kvmmake>:
{
    800010c6:	1101                	addi	sp,sp,-32
    800010c8:	ec06                	sd	ra,24(sp)
    800010ca:	e822                	sd	s0,16(sp)
    800010cc:	e426                	sd	s1,8(sp)
    800010ce:	e04a                	sd	s2,0(sp)
    800010d0:	1000                	addi	s0,sp,32
  kpgtbl = (pagetable_t) kalloc();
    800010d2:	a2dff0ef          	jal	80000afe <kalloc>
    800010d6:	84aa                	mv	s1,a0
  memset(kpgtbl, 0, PGSIZE);
    800010d8:	6605                	lui	a2,0x1
    800010da:	4581                	li	a1,0
    800010dc:	bc7ff0ef          	jal	80000ca2 <memset>
  kvmmap(kpgtbl, UART0, UART0, PGSIZE, PTE_R | PTE_W);
    800010e0:	4719                	li	a4,6
    800010e2:	6685                	lui	a3,0x1
    800010e4:	10000637          	lui	a2,0x10000
    800010e8:	100005b7          	lui	a1,0x10000
    800010ec:	8526                	mv	a0,s1
    800010ee:	fb1ff0ef          	jal	8000109e <kvmmap>
  kvmmap(kpgtbl, VIRTIO0, VIRTIO0, PGSIZE, PTE_R | PTE_W);
    800010f2:	4719                	li	a4,6
    800010f4:	6685                	lui	a3,0x1
    800010f6:	10001637          	lui	a2,0x10001
    800010fa:	100015b7          	lui	a1,0x10001
    800010fe:	8526                	mv	a0,s1
    80001100:	f9fff0ef          	jal	8000109e <kvmmap>
  kvmmap(kpgtbl, PLIC, PLIC, 0x4000000, PTE_R | PTE_W);
    80001104:	4719                	li	a4,6
    80001106:	040006b7          	lui	a3,0x4000
    8000110a:	0c000637          	lui	a2,0xc000
    8000110e:	0c0005b7          	lui	a1,0xc000
    80001112:	8526                	mv	a0,s1
    80001114:	f8bff0ef          	jal	8000109e <kvmmap>
  kvmmap(kpgtbl, KERNBASE, KERNBASE, (uint64)etext-KERNBASE, PTE_R | PTE_X);
    80001118:	00006917          	auipc	s2,0x6
    8000111c:	ee890913          	addi	s2,s2,-280 # 80007000 <etext>
    80001120:	4729                	li	a4,10
    80001122:	80006697          	auipc	a3,0x80006
    80001126:	ede68693          	addi	a3,a3,-290 # 7000 <_entry-0x7fff9000>
    8000112a:	4605                	li	a2,1
    8000112c:	067e                	slli	a2,a2,0x1f
    8000112e:	85b2                	mv	a1,a2
    80001130:	8526                	mv	a0,s1
    80001132:	f6dff0ef          	jal	8000109e <kvmmap>
  kvmmap(kpgtbl, (uint64)etext, (uint64)etext, PHYSTOP-(uint64)etext, PTE_R | PTE_W);
    80001136:	46c5                	li	a3,17
    80001138:	06ee                	slli	a3,a3,0x1b
    8000113a:	4719                	li	a4,6
    8000113c:	412686b3          	sub	a3,a3,s2
    80001140:	864a                	mv	a2,s2
    80001142:	85ca                	mv	a1,s2
    80001144:	8526                	mv	a0,s1
    80001146:	f59ff0ef          	jal	8000109e <kvmmap>
  kvmmap(kpgtbl, TRAMPOLINE, (uint64)trampoline, PGSIZE, PTE_R | PTE_X);
    8000114a:	4729                	li	a4,10
    8000114c:	6685                	lui	a3,0x1
    8000114e:	00005617          	auipc	a2,0x5
    80001152:	eb260613          	addi	a2,a2,-334 # 80006000 <_trampoline>
    80001156:	040005b7          	lui	a1,0x4000
    8000115a:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    8000115c:	05b2                	slli	a1,a1,0xc
    8000115e:	8526                	mv	a0,s1
    80001160:	f3fff0ef          	jal	8000109e <kvmmap>
  proc_mapstacks(kpgtbl);
    80001164:	8526                	mv	a0,s1
    80001166:	5ee000ef          	jal	80001754 <proc_mapstacks>
}
    8000116a:	8526                	mv	a0,s1
    8000116c:	60e2                	ld	ra,24(sp)
    8000116e:	6442                	ld	s0,16(sp)
    80001170:	64a2                	ld	s1,8(sp)
    80001172:	6902                	ld	s2,0(sp)
    80001174:	6105                	addi	sp,sp,32
    80001176:	8082                	ret

0000000080001178 <kvminit>:
{
    80001178:	1141                	addi	sp,sp,-16
    8000117a:	e406                	sd	ra,8(sp)
    8000117c:	e022                	sd	s0,0(sp)
    8000117e:	0800                	addi	s0,sp,16
  kernel_pagetable = kvmmake();
    80001180:	f47ff0ef          	jal	800010c6 <kvmmake>
    80001184:	00009797          	auipc	a5,0x9
    80001188:	32a7ba23          	sd	a0,820(a5) # 8000a4b8 <kernel_pagetable>
}
    8000118c:	60a2                	ld	ra,8(sp)
    8000118e:	6402                	ld	s0,0(sp)
    80001190:	0141                	addi	sp,sp,16
    80001192:	8082                	ret

0000000080001194 <uvmcreate>:

// create an empty user page table.
// returns 0 if out of memory.
pagetable_t
uvmcreate()
{
    80001194:	1101                	addi	sp,sp,-32
    80001196:	ec06                	sd	ra,24(sp)
    80001198:	e822                	sd	s0,16(sp)
    8000119a:	e426                	sd	s1,8(sp)
    8000119c:	1000                	addi	s0,sp,32
  pagetable_t pagetable;
  pagetable = (pagetable_t) kalloc();
    8000119e:	961ff0ef          	jal	80000afe <kalloc>
    800011a2:	84aa                	mv	s1,a0
  if(pagetable == 0)
    800011a4:	c509                	beqz	a0,800011ae <uvmcreate+0x1a>
    return 0;
  memset(pagetable, 0, PGSIZE);
    800011a6:	6605                	lui	a2,0x1
    800011a8:	4581                	li	a1,0
    800011aa:	af9ff0ef          	jal	80000ca2 <memset>
  return pagetable;
}
    800011ae:	8526                	mv	a0,s1
    800011b0:	60e2                	ld	ra,24(sp)
    800011b2:	6442                	ld	s0,16(sp)
    800011b4:	64a2                	ld	s1,8(sp)
    800011b6:	6105                	addi	sp,sp,32
    800011b8:	8082                	ret

00000000800011ba <uvmunmap>:
// Remove npages of mappings starting from va. va must be
// page-aligned. It's OK if the mappings don't exist.
// Optionally free the physical memory.
void
uvmunmap(pagetable_t pagetable, uint64 va, uint64 npages, int do_free)
{
    800011ba:	7139                	addi	sp,sp,-64
    800011bc:	fc06                	sd	ra,56(sp)
    800011be:	f822                	sd	s0,48(sp)
    800011c0:	0080                	addi	s0,sp,64
  uint64 a;
  pte_t *pte;

  if((va % PGSIZE) != 0)
    800011c2:	03459793          	slli	a5,a1,0x34
    800011c6:	e38d                	bnez	a5,800011e8 <uvmunmap+0x2e>
    800011c8:	f04a                	sd	s2,32(sp)
    800011ca:	ec4e                	sd	s3,24(sp)
    800011cc:	e852                	sd	s4,16(sp)
    800011ce:	e456                	sd	s5,8(sp)
    800011d0:	e05a                	sd	s6,0(sp)
    800011d2:	8a2a                	mv	s4,a0
    800011d4:	892e                	mv	s2,a1
    800011d6:	8ab6                	mv	s5,a3
    panic("uvmunmap: not aligned");

  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    800011d8:	0632                	slli	a2,a2,0xc
    800011da:	00b609b3          	add	s3,a2,a1
    800011de:	6b05                	lui	s6,0x1
    800011e0:	0535f963          	bgeu	a1,s3,80001232 <uvmunmap+0x78>
    800011e4:	f426                	sd	s1,40(sp)
    800011e6:	a015                	j	8000120a <uvmunmap+0x50>
    800011e8:	f426                	sd	s1,40(sp)
    800011ea:	f04a                	sd	s2,32(sp)
    800011ec:	ec4e                	sd	s3,24(sp)
    800011ee:	e852                	sd	s4,16(sp)
    800011f0:	e456                	sd	s5,8(sp)
    800011f2:	e05a                	sd	s6,0(sp)
    panic("uvmunmap: not aligned");
    800011f4:	00006517          	auipc	a0,0x6
    800011f8:	f2c50513          	addi	a0,a0,-212 # 80007120 <etext+0x120>
    800011fc:	de4ff0ef          	jal	800007e0 <panic>
      continue;
    if(do_free){
      uint64 pa = PTE2PA(*pte);
      kfree((void*)pa);
    }
    *pte = 0;
    80001200:	0004b023          	sd	zero,0(s1)
  for(a = va; a < va + npages*PGSIZE; a += PGSIZE){
    80001204:	995a                	add	s2,s2,s6
    80001206:	03397563          	bgeu	s2,s3,80001230 <uvmunmap+0x76>
    if((pte = walk(pagetable, a, 0)) == 0) // leaf page table entry allocated?
    8000120a:	4601                	li	a2,0
    8000120c:	85ca                	mv	a1,s2
    8000120e:	8552                	mv	a0,s4
    80001210:	d07ff0ef          	jal	80000f16 <walk>
    80001214:	84aa                	mv	s1,a0
    80001216:	d57d                	beqz	a0,80001204 <uvmunmap+0x4a>
    if((*pte & PTE_V) == 0)  // has physical page been allocated?
    80001218:	611c                	ld	a5,0(a0)
    8000121a:	0017f713          	andi	a4,a5,1
    8000121e:	d37d                	beqz	a4,80001204 <uvmunmap+0x4a>
    if(do_free){
    80001220:	fe0a80e3          	beqz	s5,80001200 <uvmunmap+0x46>
      uint64 pa = PTE2PA(*pte);
    80001224:	83a9                	srli	a5,a5,0xa
      kfree((void*)pa);
    80001226:	00c79513          	slli	a0,a5,0xc
    8000122a:	ff2ff0ef          	jal	80000a1c <kfree>
    8000122e:	bfc9                	j	80001200 <uvmunmap+0x46>
    80001230:	74a2                	ld	s1,40(sp)
    80001232:	7902                	ld	s2,32(sp)
    80001234:	69e2                	ld	s3,24(sp)
    80001236:	6a42                	ld	s4,16(sp)
    80001238:	6aa2                	ld	s5,8(sp)
    8000123a:	6b02                	ld	s6,0(sp)
  }
}
    8000123c:	70e2                	ld	ra,56(sp)
    8000123e:	7442                	ld	s0,48(sp)
    80001240:	6121                	addi	sp,sp,64
    80001242:	8082                	ret

0000000080001244 <uvmdealloc>:
// newsz.  oldsz and newsz need not be page-aligned, nor does newsz
// need to be less than oldsz.  oldsz can be larger than the actual
// process size.  Returns the new process size.
uint64
uvmdealloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz)
{
    80001244:	1101                	addi	sp,sp,-32
    80001246:	ec06                	sd	ra,24(sp)
    80001248:	e822                	sd	s0,16(sp)
    8000124a:	e426                	sd	s1,8(sp)
    8000124c:	1000                	addi	s0,sp,32
  if(newsz >= oldsz)
    return oldsz;
    8000124e:	84ae                	mv	s1,a1
  if(newsz >= oldsz)
    80001250:	00b67d63          	bgeu	a2,a1,8000126a <uvmdealloc+0x26>
    80001254:	84b2                	mv	s1,a2

  if(PGROUNDUP(newsz) < PGROUNDUP(oldsz)){
    80001256:	6785                	lui	a5,0x1
    80001258:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    8000125a:	00f60733          	add	a4,a2,a5
    8000125e:	76fd                	lui	a3,0xfffff
    80001260:	8f75                	and	a4,a4,a3
    80001262:	97ae                	add	a5,a5,a1
    80001264:	8ff5                	and	a5,a5,a3
    80001266:	00f76863          	bltu	a4,a5,80001276 <uvmdealloc+0x32>
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
  }

  return newsz;
}
    8000126a:	8526                	mv	a0,s1
    8000126c:	60e2                	ld	ra,24(sp)
    8000126e:	6442                	ld	s0,16(sp)
    80001270:	64a2                	ld	s1,8(sp)
    80001272:	6105                	addi	sp,sp,32
    80001274:	8082                	ret
    int npages = (PGROUNDUP(oldsz) - PGROUNDUP(newsz)) / PGSIZE;
    80001276:	8f99                	sub	a5,a5,a4
    80001278:	83b1                	srli	a5,a5,0xc
    uvmunmap(pagetable, PGROUNDUP(newsz), npages, 1);
    8000127a:	4685                	li	a3,1
    8000127c:	0007861b          	sext.w	a2,a5
    80001280:	85ba                	mv	a1,a4
    80001282:	f39ff0ef          	jal	800011ba <uvmunmap>
    80001286:	b7d5                	j	8000126a <uvmdealloc+0x26>

0000000080001288 <uvmalloc>:
  if(newsz < oldsz)
    80001288:	08b66f63          	bltu	a2,a1,80001326 <uvmalloc+0x9e>
{
    8000128c:	7139                	addi	sp,sp,-64
    8000128e:	fc06                	sd	ra,56(sp)
    80001290:	f822                	sd	s0,48(sp)
    80001292:	ec4e                	sd	s3,24(sp)
    80001294:	e852                	sd	s4,16(sp)
    80001296:	e456                	sd	s5,8(sp)
    80001298:	0080                	addi	s0,sp,64
    8000129a:	8aaa                	mv	s5,a0
    8000129c:	8a32                	mv	s4,a2
  oldsz = PGROUNDUP(oldsz);
    8000129e:	6785                	lui	a5,0x1
    800012a0:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    800012a2:	95be                	add	a1,a1,a5
    800012a4:	77fd                	lui	a5,0xfffff
    800012a6:	00f5f9b3          	and	s3,a1,a5
  for(a = oldsz; a < newsz; a += PGSIZE){
    800012aa:	08c9f063          	bgeu	s3,a2,8000132a <uvmalloc+0xa2>
    800012ae:	f426                	sd	s1,40(sp)
    800012b0:	f04a                	sd	s2,32(sp)
    800012b2:	e05a                	sd	s6,0(sp)
    800012b4:	894e                	mv	s2,s3
    if(mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_R|PTE_U|xperm) != 0){
    800012b6:	0126eb13          	ori	s6,a3,18
    mem = kalloc();
    800012ba:	845ff0ef          	jal	80000afe <kalloc>
    800012be:	84aa                	mv	s1,a0
    if(mem == 0){
    800012c0:	c515                	beqz	a0,800012ec <uvmalloc+0x64>
    memset(mem, 0, PGSIZE);
    800012c2:	6605                	lui	a2,0x1
    800012c4:	4581                	li	a1,0
    800012c6:	9ddff0ef          	jal	80000ca2 <memset>
    if(mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_R|PTE_U|xperm) != 0){
    800012ca:	875a                	mv	a4,s6
    800012cc:	86a6                	mv	a3,s1
    800012ce:	6605                	lui	a2,0x1
    800012d0:	85ca                	mv	a1,s2
    800012d2:	8556                	mv	a0,s5
    800012d4:	d1bff0ef          	jal	80000fee <mappages>
    800012d8:	e915                	bnez	a0,8000130c <uvmalloc+0x84>
  for(a = oldsz; a < newsz; a += PGSIZE){
    800012da:	6785                	lui	a5,0x1
    800012dc:	993e                	add	s2,s2,a5
    800012de:	fd496ee3          	bltu	s2,s4,800012ba <uvmalloc+0x32>
  return newsz;
    800012e2:	8552                	mv	a0,s4
    800012e4:	74a2                	ld	s1,40(sp)
    800012e6:	7902                	ld	s2,32(sp)
    800012e8:	6b02                	ld	s6,0(sp)
    800012ea:	a811                	j	800012fe <uvmalloc+0x76>
      uvmdealloc(pagetable, a, oldsz);
    800012ec:	864e                	mv	a2,s3
    800012ee:	85ca                	mv	a1,s2
    800012f0:	8556                	mv	a0,s5
    800012f2:	f53ff0ef          	jal	80001244 <uvmdealloc>
      return 0;
    800012f6:	4501                	li	a0,0
    800012f8:	74a2                	ld	s1,40(sp)
    800012fa:	7902                	ld	s2,32(sp)
    800012fc:	6b02                	ld	s6,0(sp)
}
    800012fe:	70e2                	ld	ra,56(sp)
    80001300:	7442                	ld	s0,48(sp)
    80001302:	69e2                	ld	s3,24(sp)
    80001304:	6a42                	ld	s4,16(sp)
    80001306:	6aa2                	ld	s5,8(sp)
    80001308:	6121                	addi	sp,sp,64
    8000130a:	8082                	ret
      kfree(mem);
    8000130c:	8526                	mv	a0,s1
    8000130e:	f0eff0ef          	jal	80000a1c <kfree>
      uvmdealloc(pagetable, a, oldsz);
    80001312:	864e                	mv	a2,s3
    80001314:	85ca                	mv	a1,s2
    80001316:	8556                	mv	a0,s5
    80001318:	f2dff0ef          	jal	80001244 <uvmdealloc>
      return 0;
    8000131c:	4501                	li	a0,0
    8000131e:	74a2                	ld	s1,40(sp)
    80001320:	7902                	ld	s2,32(sp)
    80001322:	6b02                	ld	s6,0(sp)
    80001324:	bfe9                	j	800012fe <uvmalloc+0x76>
    return oldsz;
    80001326:	852e                	mv	a0,a1
}
    80001328:	8082                	ret
  return newsz;
    8000132a:	8532                	mv	a0,a2
    8000132c:	bfc9                	j	800012fe <uvmalloc+0x76>

000000008000132e <freewalk>:

// Recursively free page-table pages.
// All leaf mappings must already have been removed.
void
freewalk(pagetable_t pagetable)
{
    8000132e:	7179                	addi	sp,sp,-48
    80001330:	f406                	sd	ra,40(sp)
    80001332:	f022                	sd	s0,32(sp)
    80001334:	ec26                	sd	s1,24(sp)
    80001336:	e84a                	sd	s2,16(sp)
    80001338:	e44e                	sd	s3,8(sp)
    8000133a:	e052                	sd	s4,0(sp)
    8000133c:	1800                	addi	s0,sp,48
    8000133e:	8a2a                	mv	s4,a0
  // there are 2^9 = 512 PTEs in a page table.
  for(int i = 0; i < 512; i++){
    80001340:	84aa                	mv	s1,a0
    80001342:	6905                	lui	s2,0x1
    80001344:	992a                	add	s2,s2,a0
    pte_t pte = pagetable[i];
    if((pte & PTE_V) && (pte & (PTE_R|PTE_W|PTE_X)) == 0){
    80001346:	4985                	li	s3,1
    80001348:	a819                	j	8000135e <freewalk+0x30>
      // this PTE points to a lower-level page table.
      uint64 child = PTE2PA(pte);
    8000134a:	83a9                	srli	a5,a5,0xa
      freewalk((pagetable_t)child);
    8000134c:	00c79513          	slli	a0,a5,0xc
    80001350:	fdfff0ef          	jal	8000132e <freewalk>
      pagetable[i] = 0;
    80001354:	0004b023          	sd	zero,0(s1)
  for(int i = 0; i < 512; i++){
    80001358:	04a1                	addi	s1,s1,8
    8000135a:	01248f63          	beq	s1,s2,80001378 <freewalk+0x4a>
    pte_t pte = pagetable[i];
    8000135e:	609c                	ld	a5,0(s1)
    if((pte & PTE_V) && (pte & (PTE_R|PTE_W|PTE_X)) == 0){
    80001360:	00f7f713          	andi	a4,a5,15
    80001364:	ff3703e3          	beq	a4,s3,8000134a <freewalk+0x1c>
    } else if(pte & PTE_V){
    80001368:	8b85                	andi	a5,a5,1
    8000136a:	d7fd                	beqz	a5,80001358 <freewalk+0x2a>
      panic("freewalk: leaf");
    8000136c:	00006517          	auipc	a0,0x6
    80001370:	dcc50513          	addi	a0,a0,-564 # 80007138 <etext+0x138>
    80001374:	c6cff0ef          	jal	800007e0 <panic>
    }
  }
  kfree((void*)pagetable);
    80001378:	8552                	mv	a0,s4
    8000137a:	ea2ff0ef          	jal	80000a1c <kfree>
}
    8000137e:	70a2                	ld	ra,40(sp)
    80001380:	7402                	ld	s0,32(sp)
    80001382:	64e2                	ld	s1,24(sp)
    80001384:	6942                	ld	s2,16(sp)
    80001386:	69a2                	ld	s3,8(sp)
    80001388:	6a02                	ld	s4,0(sp)
    8000138a:	6145                	addi	sp,sp,48
    8000138c:	8082                	ret

000000008000138e <uvmfree>:

// Free user memory pages,
// then free page-table pages.
void
uvmfree(pagetable_t pagetable, uint64 sz)
{
    8000138e:	1101                	addi	sp,sp,-32
    80001390:	ec06                	sd	ra,24(sp)
    80001392:	e822                	sd	s0,16(sp)
    80001394:	e426                	sd	s1,8(sp)
    80001396:	1000                	addi	s0,sp,32
    80001398:	84aa                	mv	s1,a0
  if(sz > 0)
    8000139a:	e989                	bnez	a1,800013ac <uvmfree+0x1e>
    uvmunmap(pagetable, 0, PGROUNDUP(sz)/PGSIZE, 1);
  freewalk(pagetable);
    8000139c:	8526                	mv	a0,s1
    8000139e:	f91ff0ef          	jal	8000132e <freewalk>
}
    800013a2:	60e2                	ld	ra,24(sp)
    800013a4:	6442                	ld	s0,16(sp)
    800013a6:	64a2                	ld	s1,8(sp)
    800013a8:	6105                	addi	sp,sp,32
    800013aa:	8082                	ret
    uvmunmap(pagetable, 0, PGROUNDUP(sz)/PGSIZE, 1);
    800013ac:	6785                	lui	a5,0x1
    800013ae:	17fd                	addi	a5,a5,-1 # fff <_entry-0x7ffff001>
    800013b0:	95be                	add	a1,a1,a5
    800013b2:	4685                	li	a3,1
    800013b4:	00c5d613          	srli	a2,a1,0xc
    800013b8:	4581                	li	a1,0
    800013ba:	e01ff0ef          	jal	800011ba <uvmunmap>
    800013be:	bff9                	j	8000139c <uvmfree+0xe>

00000000800013c0 <uvmcopy>:
  pte_t *pte;
  uint64 pa, i;
  uint flags;
  char *mem;

  for(i = 0; i < sz; i += PGSIZE){
    800013c0:	ce49                	beqz	a2,8000145a <uvmcopy+0x9a>
{
    800013c2:	715d                	addi	sp,sp,-80
    800013c4:	e486                	sd	ra,72(sp)
    800013c6:	e0a2                	sd	s0,64(sp)
    800013c8:	fc26                	sd	s1,56(sp)
    800013ca:	f84a                	sd	s2,48(sp)
    800013cc:	f44e                	sd	s3,40(sp)
    800013ce:	f052                	sd	s4,32(sp)
    800013d0:	ec56                	sd	s5,24(sp)
    800013d2:	e85a                	sd	s6,16(sp)
    800013d4:	e45e                	sd	s7,8(sp)
    800013d6:	0880                	addi	s0,sp,80
    800013d8:	8aaa                	mv	s5,a0
    800013da:	8b2e                	mv	s6,a1
    800013dc:	8a32                	mv	s4,a2
  for(i = 0; i < sz; i += PGSIZE){
    800013de:	4481                	li	s1,0
    800013e0:	a029                	j	800013ea <uvmcopy+0x2a>
    800013e2:	6785                	lui	a5,0x1
    800013e4:	94be                	add	s1,s1,a5
    800013e6:	0544fe63          	bgeu	s1,s4,80001442 <uvmcopy+0x82>
    if((pte = walk(old, i, 0)) == 0)
    800013ea:	4601                	li	a2,0
    800013ec:	85a6                	mv	a1,s1
    800013ee:	8556                	mv	a0,s5
    800013f0:	b27ff0ef          	jal	80000f16 <walk>
    800013f4:	d57d                	beqz	a0,800013e2 <uvmcopy+0x22>
      continue;   // page table entry hasn't been allocated
    if((*pte & PTE_V) == 0)
    800013f6:	6118                	ld	a4,0(a0)
    800013f8:	00177793          	andi	a5,a4,1
    800013fc:	d3fd                	beqz	a5,800013e2 <uvmcopy+0x22>
      continue;   // physical page hasn't been allocated
    pa = PTE2PA(*pte);
    800013fe:	00a75593          	srli	a1,a4,0xa
    80001402:	00c59b93          	slli	s7,a1,0xc
    flags = PTE_FLAGS(*pte);
    80001406:	3ff77913          	andi	s2,a4,1023
    if((mem = kalloc()) == 0)
    8000140a:	ef4ff0ef          	jal	80000afe <kalloc>
    8000140e:	89aa                	mv	s3,a0
    80001410:	c105                	beqz	a0,80001430 <uvmcopy+0x70>
      goto err;
    memmove(mem, (char*)pa, PGSIZE);
    80001412:	6605                	lui	a2,0x1
    80001414:	85de                	mv	a1,s7
    80001416:	8e9ff0ef          	jal	80000cfe <memmove>
    if(mappages(new, i, PGSIZE, (uint64)mem, flags) != 0){
    8000141a:	874a                	mv	a4,s2
    8000141c:	86ce                	mv	a3,s3
    8000141e:	6605                	lui	a2,0x1
    80001420:	85a6                	mv	a1,s1
    80001422:	855a                	mv	a0,s6
    80001424:	bcbff0ef          	jal	80000fee <mappages>
    80001428:	dd4d                	beqz	a0,800013e2 <uvmcopy+0x22>
      kfree(mem);
    8000142a:	854e                	mv	a0,s3
    8000142c:	df0ff0ef          	jal	80000a1c <kfree>
    }
  }
  return 0;

 err:
  uvmunmap(new, 0, i / PGSIZE, 1);
    80001430:	4685                	li	a3,1
    80001432:	00c4d613          	srli	a2,s1,0xc
    80001436:	4581                	li	a1,0
    80001438:	855a                	mv	a0,s6
    8000143a:	d81ff0ef          	jal	800011ba <uvmunmap>
  return -1;
    8000143e:	557d                	li	a0,-1
    80001440:	a011                	j	80001444 <uvmcopy+0x84>
  return 0;
    80001442:	4501                	li	a0,0
}
    80001444:	60a6                	ld	ra,72(sp)
    80001446:	6406                	ld	s0,64(sp)
    80001448:	74e2                	ld	s1,56(sp)
    8000144a:	7942                	ld	s2,48(sp)
    8000144c:	79a2                	ld	s3,40(sp)
    8000144e:	7a02                	ld	s4,32(sp)
    80001450:	6ae2                	ld	s5,24(sp)
    80001452:	6b42                	ld	s6,16(sp)
    80001454:	6ba2                	ld	s7,8(sp)
    80001456:	6161                	addi	sp,sp,80
    80001458:	8082                	ret
  return 0;
    8000145a:	4501                	li	a0,0
}
    8000145c:	8082                	ret

000000008000145e <uvmclear>:

// mark a PTE invalid for user access.
// used by exec for the user stack guard page.
void
uvmclear(pagetable_t pagetable, uint64 va)
{
    8000145e:	1141                	addi	sp,sp,-16
    80001460:	e406                	sd	ra,8(sp)
    80001462:	e022                	sd	s0,0(sp)
    80001464:	0800                	addi	s0,sp,16
  pte_t *pte;
  
  pte = walk(pagetable, va, 0);
    80001466:	4601                	li	a2,0
    80001468:	aafff0ef          	jal	80000f16 <walk>
  if(pte == 0)
    8000146c:	c901                	beqz	a0,8000147c <uvmclear+0x1e>
    panic("uvmclear");
  *pte &= ~PTE_U;
    8000146e:	611c                	ld	a5,0(a0)
    80001470:	9bbd                	andi	a5,a5,-17
    80001472:	e11c                	sd	a5,0(a0)
}
    80001474:	60a2                	ld	ra,8(sp)
    80001476:	6402                	ld	s0,0(sp)
    80001478:	0141                	addi	sp,sp,16
    8000147a:	8082                	ret
    panic("uvmclear");
    8000147c:	00006517          	auipc	a0,0x6
    80001480:	ccc50513          	addi	a0,a0,-820 # 80007148 <etext+0x148>
    80001484:	b5cff0ef          	jal	800007e0 <panic>

0000000080001488 <copyinstr>:
copyinstr(pagetable_t pagetable, char *dst, uint64 srcva, uint64 max)
{
  uint64 n, va0, pa0;
  int got_null = 0;

  while(got_null == 0 && max > 0){
    80001488:	c6dd                	beqz	a3,80001536 <copyinstr+0xae>
{
    8000148a:	715d                	addi	sp,sp,-80
    8000148c:	e486                	sd	ra,72(sp)
    8000148e:	e0a2                	sd	s0,64(sp)
    80001490:	fc26                	sd	s1,56(sp)
    80001492:	f84a                	sd	s2,48(sp)
    80001494:	f44e                	sd	s3,40(sp)
    80001496:	f052                	sd	s4,32(sp)
    80001498:	ec56                	sd	s5,24(sp)
    8000149a:	e85a                	sd	s6,16(sp)
    8000149c:	e45e                	sd	s7,8(sp)
    8000149e:	0880                	addi	s0,sp,80
    800014a0:	8a2a                	mv	s4,a0
    800014a2:	8b2e                	mv	s6,a1
    800014a4:	8bb2                	mv	s7,a2
    800014a6:	8936                	mv	s2,a3
    va0 = PGROUNDDOWN(srcva);
    800014a8:	7afd                	lui	s5,0xfffff
    pa0 = walkaddr(pagetable, va0);
    if(pa0 == 0)
      return -1;
    n = PGSIZE - (srcva - va0);
    800014aa:	6985                	lui	s3,0x1
    800014ac:	a825                	j	800014e4 <copyinstr+0x5c>
      n = max;

    char *p = (char *) (pa0 + (srcva - va0));
    while(n > 0){
      if(*p == '\0'){
        *dst = '\0';
    800014ae:	00078023          	sb	zero,0(a5) # 1000 <_entry-0x7ffff000>
    800014b2:	4785                	li	a5,1
      dst++;
    }

    srcva = va0 + PGSIZE;
  }
  if(got_null){
    800014b4:	37fd                	addiw	a5,a5,-1
    800014b6:	0007851b          	sext.w	a0,a5
    return 0;
  } else {
    return -1;
  }
}
    800014ba:	60a6                	ld	ra,72(sp)
    800014bc:	6406                	ld	s0,64(sp)
    800014be:	74e2                	ld	s1,56(sp)
    800014c0:	7942                	ld	s2,48(sp)
    800014c2:	79a2                	ld	s3,40(sp)
    800014c4:	7a02                	ld	s4,32(sp)
    800014c6:	6ae2                	ld	s5,24(sp)
    800014c8:	6b42                	ld	s6,16(sp)
    800014ca:	6ba2                	ld	s7,8(sp)
    800014cc:	6161                	addi	sp,sp,80
    800014ce:	8082                	ret
    800014d0:	fff90713          	addi	a4,s2,-1 # fff <_entry-0x7ffff001>
    800014d4:	9742                	add	a4,a4,a6
      --max;
    800014d6:	40b70933          	sub	s2,a4,a1
    srcva = va0 + PGSIZE;
    800014da:	01348bb3          	add	s7,s1,s3
  while(got_null == 0 && max > 0){
    800014de:	04e58463          	beq	a1,a4,80001526 <copyinstr+0x9e>
{
    800014e2:	8b3e                	mv	s6,a5
    va0 = PGROUNDDOWN(srcva);
    800014e4:	015bf4b3          	and	s1,s7,s5
    pa0 = walkaddr(pagetable, va0);
    800014e8:	85a6                	mv	a1,s1
    800014ea:	8552                	mv	a0,s4
    800014ec:	ac5ff0ef          	jal	80000fb0 <walkaddr>
    if(pa0 == 0)
    800014f0:	cd0d                	beqz	a0,8000152a <copyinstr+0xa2>
    n = PGSIZE - (srcva - va0);
    800014f2:	417486b3          	sub	a3,s1,s7
    800014f6:	96ce                	add	a3,a3,s3
    if(n > max)
    800014f8:	00d97363          	bgeu	s2,a3,800014fe <copyinstr+0x76>
    800014fc:	86ca                	mv	a3,s2
    char *p = (char *) (pa0 + (srcva - va0));
    800014fe:	955e                	add	a0,a0,s7
    80001500:	8d05                	sub	a0,a0,s1
    while(n > 0){
    80001502:	c695                	beqz	a3,8000152e <copyinstr+0xa6>
    80001504:	87da                	mv	a5,s6
    80001506:	885a                	mv	a6,s6
      if(*p == '\0'){
    80001508:	41650633          	sub	a2,a0,s6
    while(n > 0){
    8000150c:	96da                	add	a3,a3,s6
    8000150e:	85be                	mv	a1,a5
      if(*p == '\0'){
    80001510:	00f60733          	add	a4,a2,a5
    80001514:	00074703          	lbu	a4,0(a4)
    80001518:	db59                	beqz	a4,800014ae <copyinstr+0x26>
        *dst = *p;
    8000151a:	00e78023          	sb	a4,0(a5)
      dst++;
    8000151e:	0785                	addi	a5,a5,1
    while(n > 0){
    80001520:	fed797e3          	bne	a5,a3,8000150e <copyinstr+0x86>
    80001524:	b775                	j	800014d0 <copyinstr+0x48>
    80001526:	4781                	li	a5,0
    80001528:	b771                	j	800014b4 <copyinstr+0x2c>
      return -1;
    8000152a:	557d                	li	a0,-1
    8000152c:	b779                	j	800014ba <copyinstr+0x32>
    srcva = va0 + PGSIZE;
    8000152e:	6b85                	lui	s7,0x1
    80001530:	9ba6                	add	s7,s7,s1
    80001532:	87da                	mv	a5,s6
    80001534:	b77d                	j	800014e2 <copyinstr+0x5a>
  int got_null = 0;
    80001536:	4781                	li	a5,0
  if(got_null){
    80001538:	37fd                	addiw	a5,a5,-1
    8000153a:	0007851b          	sext.w	a0,a5
}
    8000153e:	8082                	ret

0000000080001540 <ismapped>:
  return mem;
}

int
ismapped(pagetable_t pagetable, uint64 va)
{
    80001540:	1141                	addi	sp,sp,-16
    80001542:	e406                	sd	ra,8(sp)
    80001544:	e022                	sd	s0,0(sp)
    80001546:	0800                	addi	s0,sp,16
  pte_t *pte = walk(pagetable, va, 0);
    80001548:	4601                	li	a2,0
    8000154a:	9cdff0ef          	jal	80000f16 <walk>
  if (pte == 0) {
    8000154e:	c519                	beqz	a0,8000155c <ismapped+0x1c>
    return 0;
  }
  if (*pte & PTE_V){
    80001550:	6108                	ld	a0,0(a0)
    80001552:	8905                	andi	a0,a0,1
    return 1;
  }
  return 0;
}
    80001554:	60a2                	ld	ra,8(sp)
    80001556:	6402                	ld	s0,0(sp)
    80001558:	0141                	addi	sp,sp,16
    8000155a:	8082                	ret
    return 0;
    8000155c:	4501                	li	a0,0
    8000155e:	bfdd                	j	80001554 <ismapped+0x14>

0000000080001560 <vmfault>:
{
    80001560:	7179                	addi	sp,sp,-48
    80001562:	f406                	sd	ra,40(sp)
    80001564:	f022                	sd	s0,32(sp)
    80001566:	ec26                	sd	s1,24(sp)
    80001568:	e44e                	sd	s3,8(sp)
    8000156a:	1800                	addi	s0,sp,48
    8000156c:	89aa                	mv	s3,a0
    8000156e:	84ae                	mv	s1,a1
  struct proc *p = myproc();
    80001570:	35e000ef          	jal	800018ce <myproc>
  if (va >= p->sz)
    80001574:	653c                	ld	a5,72(a0)
    80001576:	00f4ea63          	bltu	s1,a5,8000158a <vmfault+0x2a>
    return 0;
    8000157a:	4981                	li	s3,0
}
    8000157c:	854e                	mv	a0,s3
    8000157e:	70a2                	ld	ra,40(sp)
    80001580:	7402                	ld	s0,32(sp)
    80001582:	64e2                	ld	s1,24(sp)
    80001584:	69a2                	ld	s3,8(sp)
    80001586:	6145                	addi	sp,sp,48
    80001588:	8082                	ret
    8000158a:	e84a                	sd	s2,16(sp)
    8000158c:	892a                	mv	s2,a0
  va = PGROUNDDOWN(va);
    8000158e:	77fd                	lui	a5,0xfffff
    80001590:	8cfd                	and	s1,s1,a5
  if(ismapped(pagetable, va)) {
    80001592:	85a6                	mv	a1,s1
    80001594:	854e                	mv	a0,s3
    80001596:	fabff0ef          	jal	80001540 <ismapped>
    return 0;
    8000159a:	4981                	li	s3,0
  if(ismapped(pagetable, va)) {
    8000159c:	c119                	beqz	a0,800015a2 <vmfault+0x42>
    8000159e:	6942                	ld	s2,16(sp)
    800015a0:	bff1                	j	8000157c <vmfault+0x1c>
    800015a2:	e052                	sd	s4,0(sp)
  mem = (uint64) kalloc();
    800015a4:	d5aff0ef          	jal	80000afe <kalloc>
    800015a8:	8a2a                	mv	s4,a0
  if(mem == 0)
    800015aa:	c90d                	beqz	a0,800015dc <vmfault+0x7c>
  mem = (uint64) kalloc();
    800015ac:	89aa                	mv	s3,a0
  memset((void *) mem, 0, PGSIZE);
    800015ae:	6605                	lui	a2,0x1
    800015b0:	4581                	li	a1,0
    800015b2:	ef0ff0ef          	jal	80000ca2 <memset>
  if (mappages(p->pagetable, va, PGSIZE, mem, PTE_W|PTE_U|PTE_R) != 0) {
    800015b6:	4759                	li	a4,22
    800015b8:	86d2                	mv	a3,s4
    800015ba:	6605                	lui	a2,0x1
    800015bc:	85a6                	mv	a1,s1
    800015be:	05893503          	ld	a0,88(s2)
    800015c2:	a2dff0ef          	jal	80000fee <mappages>
    800015c6:	e501                	bnez	a0,800015ce <vmfault+0x6e>
    800015c8:	6942                	ld	s2,16(sp)
    800015ca:	6a02                	ld	s4,0(sp)
    800015cc:	bf45                	j	8000157c <vmfault+0x1c>
    kfree((void *)mem);
    800015ce:	8552                	mv	a0,s4
    800015d0:	c4cff0ef          	jal	80000a1c <kfree>
    return 0;
    800015d4:	4981                	li	s3,0
    800015d6:	6942                	ld	s2,16(sp)
    800015d8:	6a02                	ld	s4,0(sp)
    800015da:	b74d                	j	8000157c <vmfault+0x1c>
    800015dc:	6942                	ld	s2,16(sp)
    800015de:	6a02                	ld	s4,0(sp)
    800015e0:	bf71                	j	8000157c <vmfault+0x1c>

00000000800015e2 <copyout>:
  while(len > 0){
    800015e2:	c2cd                	beqz	a3,80001684 <copyout+0xa2>
{
    800015e4:	711d                	addi	sp,sp,-96
    800015e6:	ec86                	sd	ra,88(sp)
    800015e8:	e8a2                	sd	s0,80(sp)
    800015ea:	e4a6                	sd	s1,72(sp)
    800015ec:	f852                	sd	s4,48(sp)
    800015ee:	f05a                	sd	s6,32(sp)
    800015f0:	ec5e                	sd	s7,24(sp)
    800015f2:	e862                	sd	s8,16(sp)
    800015f4:	1080                	addi	s0,sp,96
    800015f6:	8c2a                	mv	s8,a0
    800015f8:	8b2e                	mv	s6,a1
    800015fa:	8bb2                	mv	s7,a2
    800015fc:	8a36                	mv	s4,a3
    va0 = PGROUNDDOWN(dstva);
    800015fe:	74fd                	lui	s1,0xfffff
    80001600:	8ced                	and	s1,s1,a1
    if(va0 >= MAXVA)
    80001602:	57fd                	li	a5,-1
    80001604:	83e9                	srli	a5,a5,0x1a
    80001606:	0897e163          	bltu	a5,s1,80001688 <copyout+0xa6>
    8000160a:	e0ca                	sd	s2,64(sp)
    8000160c:	fc4e                	sd	s3,56(sp)
    8000160e:	f456                	sd	s5,40(sp)
    80001610:	e466                	sd	s9,8(sp)
    80001612:	e06a                	sd	s10,0(sp)
    80001614:	6d05                	lui	s10,0x1
    80001616:	8cbe                	mv	s9,a5
    80001618:	a015                	j	8000163c <copyout+0x5a>
    memmove((void *)(pa0 + (dstva - va0)), src, n);
    8000161a:	409b0533          	sub	a0,s6,s1
    8000161e:	0009861b          	sext.w	a2,s3
    80001622:	85de                	mv	a1,s7
    80001624:	954a                	add	a0,a0,s2
    80001626:	ed8ff0ef          	jal	80000cfe <memmove>
    len -= n;
    8000162a:	413a0a33          	sub	s4,s4,s3
    src += n;
    8000162e:	9bce                	add	s7,s7,s3
  while(len > 0){
    80001630:	040a0363          	beqz	s4,80001676 <copyout+0x94>
    if(va0 >= MAXVA)
    80001634:	055cec63          	bltu	s9,s5,8000168c <copyout+0xaa>
    80001638:	84d6                	mv	s1,s5
    8000163a:	8b56                	mv	s6,s5
    pa0 = walkaddr(pagetable, va0);
    8000163c:	85a6                	mv	a1,s1
    8000163e:	8562                	mv	a0,s8
    80001640:	971ff0ef          	jal	80000fb0 <walkaddr>
    80001644:	892a                	mv	s2,a0
    if(pa0 == 0) {
    80001646:	e901                	bnez	a0,80001656 <copyout+0x74>
      if((pa0 = vmfault(pagetable, va0, 0)) == 0) {
    80001648:	4601                	li	a2,0
    8000164a:	85a6                	mv	a1,s1
    8000164c:	8562                	mv	a0,s8
    8000164e:	f13ff0ef          	jal	80001560 <vmfault>
    80001652:	892a                	mv	s2,a0
    80001654:	c139                	beqz	a0,8000169a <copyout+0xb8>
    pte = walk(pagetable, va0, 0);
    80001656:	4601                	li	a2,0
    80001658:	85a6                	mv	a1,s1
    8000165a:	8562                	mv	a0,s8
    8000165c:	8bbff0ef          	jal	80000f16 <walk>
    if((*pte & PTE_W) == 0)
    80001660:	611c                	ld	a5,0(a0)
    80001662:	8b91                	andi	a5,a5,4
    80001664:	c3b1                	beqz	a5,800016a8 <copyout+0xc6>
    n = PGSIZE - (dstva - va0);
    80001666:	01a48ab3          	add	s5,s1,s10
    8000166a:	416a89b3          	sub	s3,s5,s6
    if(n > len)
    8000166e:	fb3a76e3          	bgeu	s4,s3,8000161a <copyout+0x38>
    80001672:	89d2                	mv	s3,s4
    80001674:	b75d                	j	8000161a <copyout+0x38>
  return 0;
    80001676:	4501                	li	a0,0
    80001678:	6906                	ld	s2,64(sp)
    8000167a:	79e2                	ld	s3,56(sp)
    8000167c:	7aa2                	ld	s5,40(sp)
    8000167e:	6ca2                	ld	s9,8(sp)
    80001680:	6d02                	ld	s10,0(sp)
    80001682:	a80d                	j	800016b4 <copyout+0xd2>
    80001684:	4501                	li	a0,0
}
    80001686:	8082                	ret
      return -1;
    80001688:	557d                	li	a0,-1
    8000168a:	a02d                	j	800016b4 <copyout+0xd2>
    8000168c:	557d                	li	a0,-1
    8000168e:	6906                	ld	s2,64(sp)
    80001690:	79e2                	ld	s3,56(sp)
    80001692:	7aa2                	ld	s5,40(sp)
    80001694:	6ca2                	ld	s9,8(sp)
    80001696:	6d02                	ld	s10,0(sp)
    80001698:	a831                	j	800016b4 <copyout+0xd2>
        return -1;
    8000169a:	557d                	li	a0,-1
    8000169c:	6906                	ld	s2,64(sp)
    8000169e:	79e2                	ld	s3,56(sp)
    800016a0:	7aa2                	ld	s5,40(sp)
    800016a2:	6ca2                	ld	s9,8(sp)
    800016a4:	6d02                	ld	s10,0(sp)
    800016a6:	a039                	j	800016b4 <copyout+0xd2>
      return -1;
    800016a8:	557d                	li	a0,-1
    800016aa:	6906                	ld	s2,64(sp)
    800016ac:	79e2                	ld	s3,56(sp)
    800016ae:	7aa2                	ld	s5,40(sp)
    800016b0:	6ca2                	ld	s9,8(sp)
    800016b2:	6d02                	ld	s10,0(sp)
}
    800016b4:	60e6                	ld	ra,88(sp)
    800016b6:	6446                	ld	s0,80(sp)
    800016b8:	64a6                	ld	s1,72(sp)
    800016ba:	7a42                	ld	s4,48(sp)
    800016bc:	7b02                	ld	s6,32(sp)
    800016be:	6be2                	ld	s7,24(sp)
    800016c0:	6c42                	ld	s8,16(sp)
    800016c2:	6125                	addi	sp,sp,96
    800016c4:	8082                	ret

00000000800016c6 <copyin>:
  while(len > 0){
    800016c6:	c6c9                	beqz	a3,80001750 <copyin+0x8a>
{
    800016c8:	715d                	addi	sp,sp,-80
    800016ca:	e486                	sd	ra,72(sp)
    800016cc:	e0a2                	sd	s0,64(sp)
    800016ce:	fc26                	sd	s1,56(sp)
    800016d0:	f84a                	sd	s2,48(sp)
    800016d2:	f44e                	sd	s3,40(sp)
    800016d4:	f052                	sd	s4,32(sp)
    800016d6:	ec56                	sd	s5,24(sp)
    800016d8:	e85a                	sd	s6,16(sp)
    800016da:	e45e                	sd	s7,8(sp)
    800016dc:	e062                	sd	s8,0(sp)
    800016de:	0880                	addi	s0,sp,80
    800016e0:	8baa                	mv	s7,a0
    800016e2:	8aae                	mv	s5,a1
    800016e4:	8932                	mv	s2,a2
    800016e6:	8a36                	mv	s4,a3
    va0 = PGROUNDDOWN(srcva);
    800016e8:	7c7d                	lui	s8,0xfffff
    n = PGSIZE - (srcva - va0);
    800016ea:	6b05                	lui	s6,0x1
    800016ec:	a035                	j	80001718 <copyin+0x52>
    800016ee:	412984b3          	sub	s1,s3,s2
    800016f2:	94da                	add	s1,s1,s6
    if(n > len)
    800016f4:	009a7363          	bgeu	s4,s1,800016fa <copyin+0x34>
    800016f8:	84d2                	mv	s1,s4
    memmove(dst, (void *)(pa0 + (srcva - va0)), n);
    800016fa:	413905b3          	sub	a1,s2,s3
    800016fe:	0004861b          	sext.w	a2,s1
    80001702:	95aa                	add	a1,a1,a0
    80001704:	8556                	mv	a0,s5
    80001706:	df8ff0ef          	jal	80000cfe <memmove>
    len -= n;
    8000170a:	409a0a33          	sub	s4,s4,s1
    dst += n;
    8000170e:	9aa6                	add	s5,s5,s1
    srcva = va0 + PGSIZE;
    80001710:	01698933          	add	s2,s3,s6
  while(len > 0){
    80001714:	020a0163          	beqz	s4,80001736 <copyin+0x70>
    va0 = PGROUNDDOWN(srcva);
    80001718:	018979b3          	and	s3,s2,s8
    pa0 = walkaddr(pagetable, va0);
    8000171c:	85ce                	mv	a1,s3
    8000171e:	855e                	mv	a0,s7
    80001720:	891ff0ef          	jal	80000fb0 <walkaddr>
    if(pa0 == 0) {
    80001724:	f569                	bnez	a0,800016ee <copyin+0x28>
      if((pa0 = vmfault(pagetable, va0, 0)) == 0) {
    80001726:	4601                	li	a2,0
    80001728:	85ce                	mv	a1,s3
    8000172a:	855e                	mv	a0,s7
    8000172c:	e35ff0ef          	jal	80001560 <vmfault>
    80001730:	fd5d                	bnez	a0,800016ee <copyin+0x28>
        return -1;
    80001732:	557d                	li	a0,-1
    80001734:	a011                	j	80001738 <copyin+0x72>
  return 0;
    80001736:	4501                	li	a0,0
}
    80001738:	60a6                	ld	ra,72(sp)
    8000173a:	6406                	ld	s0,64(sp)
    8000173c:	74e2                	ld	s1,56(sp)
    8000173e:	7942                	ld	s2,48(sp)
    80001740:	79a2                	ld	s3,40(sp)
    80001742:	7a02                	ld	s4,32(sp)
    80001744:	6ae2                	ld	s5,24(sp)
    80001746:	6b42                	ld	s6,16(sp)
    80001748:	6ba2                	ld	s7,8(sp)
    8000174a:	6c02                	ld	s8,0(sp)
    8000174c:	6161                	addi	sp,sp,80
    8000174e:	8082                	ret
  return 0;
    80001750:	4501                	li	a0,0
}
    80001752:	8082                	ret

0000000080001754 <proc_mapstacks>:
// Allocate a page for each process's kernel stack.
// Map it high in memory, followed by an invalid
// guard page.
void
proc_mapstacks(pagetable_t kpgtbl)
{
    80001754:	7139                	addi	sp,sp,-64
    80001756:	fc06                	sd	ra,56(sp)
    80001758:	f822                	sd	s0,48(sp)
    8000175a:	f426                	sd	s1,40(sp)
    8000175c:	f04a                	sd	s2,32(sp)
    8000175e:	ec4e                	sd	s3,24(sp)
    80001760:	e852                	sd	s4,16(sp)
    80001762:	e456                	sd	s5,8(sp)
    80001764:	e05a                	sd	s6,0(sp)
    80001766:	0080                	addi	s0,sp,64
    80001768:	8a2a                	mv	s4,a0
  struct proc *p;
  
  for(p = proc; p < &proc[NPROC]; p++) {
    8000176a:	00011497          	auipc	s1,0x11
    8000176e:	28e48493          	addi	s1,s1,654 # 800129f8 <proc>
    char *pa = kalloc();
    if(pa == 0)
      panic("kalloc");
    uint64 va = KSTACK((int) (p - proc));
    80001772:	8b26                	mv	s6,s1
    80001774:	00a36937          	lui	s2,0xa36
    80001778:	77d90913          	addi	s2,s2,1917 # a3677d <_entry-0x7f5c9883>
    8000177c:	0932                	slli	s2,s2,0xc
    8000177e:	46d90913          	addi	s2,s2,1133
    80001782:	0936                	slli	s2,s2,0xd
    80001784:	df590913          	addi	s2,s2,-523
    80001788:	093a                	slli	s2,s2,0xe
    8000178a:	6cf90913          	addi	s2,s2,1743
    8000178e:	040009b7          	lui	s3,0x4000
    80001792:	19fd                	addi	s3,s3,-1 # 3ffffff <_entry-0x7c000001>
    80001794:	09b2                	slli	s3,s3,0xc
  for(p = proc; p < &proc[NPROC]; p++) {
    80001796:	00017a97          	auipc	s5,0x17
    8000179a:	062a8a93          	addi	s5,s5,98 # 800187f8 <tickslock>
    char *pa = kalloc();
    8000179e:	b60ff0ef          	jal	80000afe <kalloc>
    800017a2:	862a                	mv	a2,a0
    if(pa == 0)
    800017a4:	cd15                	beqz	a0,800017e0 <proc_mapstacks+0x8c>
    uint64 va = KSTACK((int) (p - proc));
    800017a6:	416485b3          	sub	a1,s1,s6
    800017aa:	858d                	srai	a1,a1,0x3
    800017ac:	032585b3          	mul	a1,a1,s2
    800017b0:	2585                	addiw	a1,a1,1
    800017b2:	00d5959b          	slliw	a1,a1,0xd
    kvmmap(kpgtbl, va, (uint64)pa, PGSIZE, PTE_R | PTE_W);
    800017b6:	4719                	li	a4,6
    800017b8:	6685                	lui	a3,0x1
    800017ba:	40b985b3          	sub	a1,s3,a1
    800017be:	8552                	mv	a0,s4
    800017c0:	8dfff0ef          	jal	8000109e <kvmmap>
  for(p = proc; p < &proc[NPROC]; p++) {
    800017c4:	17848493          	addi	s1,s1,376
    800017c8:	fd549be3          	bne	s1,s5,8000179e <proc_mapstacks+0x4a>
  }
}
    800017cc:	70e2                	ld	ra,56(sp)
    800017ce:	7442                	ld	s0,48(sp)
    800017d0:	74a2                	ld	s1,40(sp)
    800017d2:	7902                	ld	s2,32(sp)
    800017d4:	69e2                	ld	s3,24(sp)
    800017d6:	6a42                	ld	s4,16(sp)
    800017d8:	6aa2                	ld	s5,8(sp)
    800017da:	6b02                	ld	s6,0(sp)
    800017dc:	6121                	addi	sp,sp,64
    800017de:	8082                	ret
      panic("kalloc");
    800017e0:	00006517          	auipc	a0,0x6
    800017e4:	97850513          	addi	a0,a0,-1672 # 80007158 <etext+0x158>
    800017e8:	ff9fe0ef          	jal	800007e0 <panic>

00000000800017ec <procinit>:

// initialize the proc table.
void
procinit(void)
{
    800017ec:	7139                	addi	sp,sp,-64
    800017ee:	fc06                	sd	ra,56(sp)
    800017f0:	f822                	sd	s0,48(sp)
    800017f2:	f426                	sd	s1,40(sp)
    800017f4:	f04a                	sd	s2,32(sp)
    800017f6:	ec4e                	sd	s3,24(sp)
    800017f8:	e852                	sd	s4,16(sp)
    800017fa:	e456                	sd	s5,8(sp)
    800017fc:	e05a                	sd	s6,0(sp)
    800017fe:	0080                	addi	s0,sp,64
  struct proc *p;
  
  initlock(&pid_lock, "nextpid");
    80001800:	00006597          	auipc	a1,0x6
    80001804:	96058593          	addi	a1,a1,-1696 # 80007160 <etext+0x160>
    80001808:	00011517          	auipc	a0,0x11
    8000180c:	dc050513          	addi	a0,a0,-576 # 800125c8 <pid_lock>
    80001810:	b3eff0ef          	jal	80000b4e <initlock>
  initlock(&wait_lock, "wait_lock");
    80001814:	00006597          	auipc	a1,0x6
    80001818:	95458593          	addi	a1,a1,-1708 # 80007168 <etext+0x168>
    8000181c:	00011517          	auipc	a0,0x11
    80001820:	dc450513          	addi	a0,a0,-572 # 800125e0 <wait_lock>
    80001824:	b2aff0ef          	jal	80000b4e <initlock>
  for(p = proc; p < &proc[NPROC]; p++) {
    80001828:	00011497          	auipc	s1,0x11
    8000182c:	1d048493          	addi	s1,s1,464 # 800129f8 <proc>
      initlock(&p->lock, "proc");
    80001830:	00006b17          	auipc	s6,0x6
    80001834:	948b0b13          	addi	s6,s6,-1720 # 80007178 <etext+0x178>
      p->state = UNUSED;
      p->kstack = KSTACK((int) (p - proc));
    80001838:	8aa6                	mv	s5,s1
    8000183a:	00a36937          	lui	s2,0xa36
    8000183e:	77d90913          	addi	s2,s2,1917 # a3677d <_entry-0x7f5c9883>
    80001842:	0932                	slli	s2,s2,0xc
    80001844:	46d90913          	addi	s2,s2,1133
    80001848:	0936                	slli	s2,s2,0xd
    8000184a:	df590913          	addi	s2,s2,-523
    8000184e:	093a                	slli	s2,s2,0xe
    80001850:	6cf90913          	addi	s2,s2,1743
    80001854:	040009b7          	lui	s3,0x4000
    80001858:	19fd                	addi	s3,s3,-1 # 3ffffff <_entry-0x7c000001>
    8000185a:	09b2                	slli	s3,s3,0xc
  for(p = proc; p < &proc[NPROC]; p++) {
    8000185c:	00017a17          	auipc	s4,0x17
    80001860:	f9ca0a13          	addi	s4,s4,-100 # 800187f8 <tickslock>
      initlock(&p->lock, "proc");
    80001864:	85da                	mv	a1,s6
    80001866:	8526                	mv	a0,s1
    80001868:	ae6ff0ef          	jal	80000b4e <initlock>
      p->state = UNUSED;
    8000186c:	0004ac23          	sw	zero,24(s1)
      p->kstack = KSTACK((int) (p - proc));
    80001870:	415487b3          	sub	a5,s1,s5
    80001874:	878d                	srai	a5,a5,0x3
    80001876:	032787b3          	mul	a5,a5,s2
    8000187a:	2785                	addiw	a5,a5,1 # fffffffffffff001 <end+0xffffffff7ffdb429>
    8000187c:	00d7979b          	slliw	a5,a5,0xd
    80001880:	40f987b3          	sub	a5,s3,a5
    80001884:	e0bc                	sd	a5,64(s1)
  for(p = proc; p < &proc[NPROC]; p++) {
    80001886:	17848493          	addi	s1,s1,376
    8000188a:	fd449de3          	bne	s1,s4,80001864 <procinit+0x78>
  }
}
    8000188e:	70e2                	ld	ra,56(sp)
    80001890:	7442                	ld	s0,48(sp)
    80001892:	74a2                	ld	s1,40(sp)
    80001894:	7902                	ld	s2,32(sp)
    80001896:	69e2                	ld	s3,24(sp)
    80001898:	6a42                	ld	s4,16(sp)
    8000189a:	6aa2                	ld	s5,8(sp)
    8000189c:	6b02                	ld	s6,0(sp)
    8000189e:	6121                	addi	sp,sp,64
    800018a0:	8082                	ret

00000000800018a2 <cpuid>:
// Must be called with interrupts disabled,
// to prevent race with process being moved
// to a different CPU.
int
cpuid()
{
    800018a2:	1141                	addi	sp,sp,-16
    800018a4:	e422                	sd	s0,8(sp)
    800018a6:	0800                	addi	s0,sp,16
  asm volatile("mv %0, tp" : "=r" (x) );
    800018a8:	8512                	mv	a0,tp
  int id = r_tp();
  return id;
}
    800018aa:	2501                	sext.w	a0,a0
    800018ac:	6422                	ld	s0,8(sp)
    800018ae:	0141                	addi	sp,sp,16
    800018b0:	8082                	ret

00000000800018b2 <mycpu>:

// Return this CPU's cpu struct.
// Interrupts must be disabled.
struct cpu*
mycpu(void)
{
    800018b2:	1141                	addi	sp,sp,-16
    800018b4:	e422                	sd	s0,8(sp)
    800018b6:	0800                	addi	s0,sp,16
    800018b8:	8792                	mv	a5,tp
  int id = cpuid();
  struct cpu *c = &cpus[id];
    800018ba:	2781                	sext.w	a5,a5
    800018bc:	079e                	slli	a5,a5,0x7
  return c;
}
    800018be:	00011517          	auipc	a0,0x11
    800018c2:	d3a50513          	addi	a0,a0,-710 # 800125f8 <cpus>
    800018c6:	953e                	add	a0,a0,a5
    800018c8:	6422                	ld	s0,8(sp)
    800018ca:	0141                	addi	sp,sp,16
    800018cc:	8082                	ret

00000000800018ce <myproc>:

// Return the current struct proc *, or zero if none.
struct proc*
myproc(void)
{
    800018ce:	1101                	addi	sp,sp,-32
    800018d0:	ec06                	sd	ra,24(sp)
    800018d2:	e822                	sd	s0,16(sp)
    800018d4:	e426                	sd	s1,8(sp)
    800018d6:	1000                	addi	s0,sp,32
  push_off();
    800018d8:	ab6ff0ef          	jal	80000b8e <push_off>
    800018dc:	8792                	mv	a5,tp
  struct cpu *c = mycpu();
  struct proc *p = c->proc;
    800018de:	2781                	sext.w	a5,a5
    800018e0:	079e                	slli	a5,a5,0x7
    800018e2:	00011717          	auipc	a4,0x11
    800018e6:	ce670713          	addi	a4,a4,-794 # 800125c8 <pid_lock>
    800018ea:	97ba                	add	a5,a5,a4
    800018ec:	7b84                	ld	s1,48(a5)
  pop_off();
    800018ee:	b24ff0ef          	jal	80000c12 <pop_off>
  return p;
}
    800018f2:	8526                	mv	a0,s1
    800018f4:	60e2                	ld	ra,24(sp)
    800018f6:	6442                	ld	s0,16(sp)
    800018f8:	64a2                	ld	s1,8(sp)
    800018fa:	6105                	addi	sp,sp,32
    800018fc:	8082                	ret

00000000800018fe <forkret>:

// A fork child's very first scheduling by scheduler()
// will swtch to forkret.
void
forkret(void)
{
    800018fe:	7179                	addi	sp,sp,-48
    80001900:	f406                	sd	ra,40(sp)
    80001902:	f022                	sd	s0,32(sp)
    80001904:	ec26                	sd	s1,24(sp)
    80001906:	1800                	addi	s0,sp,48
  extern char userret[];
  static int first = 1;
  struct proc *p = myproc();
    80001908:	fc7ff0ef          	jal	800018ce <myproc>
    8000190c:	84aa                	mv	s1,a0

  // Still holding p->lock from scheduler.
  release(&p->lock);
    8000190e:	b58ff0ef          	jal	80000c66 <release>

  if (first) {
    80001912:	00009797          	auipc	a5,0x9
    80001916:	b5e7a783          	lw	a5,-1186(a5) # 8000a470 <first.1>
    8000191a:	cf8d                	beqz	a5,80001954 <forkret+0x56>
    // File system initialization must be run in the context of a
    // regular process (e.g., because it calls sleep), and thus cannot
    // be run from main().
    fsinit(ROOTDEV);
    8000191c:	4505                	li	a0,1
    8000191e:	73b010ef          	jal	80003858 <fsinit>

    first = 0;
    80001922:	00009797          	auipc	a5,0x9
    80001926:	b407a723          	sw	zero,-1202(a5) # 8000a470 <first.1>
    // ensure other cores see first=0.
    __sync_synchronize();
    8000192a:	0330000f          	fence	rw,rw

    // We can invoke kexec() now that file system is initialized.
    // Put the return value (argc) of kexec into a0.
    p->trapframe->a0 = kexec("/init", (char *[]){ "/init", 0 });
    8000192e:	00006517          	auipc	a0,0x6
    80001932:	85250513          	addi	a0,a0,-1966 # 80007180 <etext+0x180>
    80001936:	fca43823          	sd	a0,-48(s0)
    8000193a:	fc043c23          	sd	zero,-40(s0)
    8000193e:	fd040593          	addi	a1,s0,-48
    80001942:	020030ef          	jal	80004962 <kexec>
    80001946:	70bc                	ld	a5,96(s1)
    80001948:	fba8                	sd	a0,112(a5)
    if (p->trapframe->a0 == -1) {
    8000194a:	70bc                	ld	a5,96(s1)
    8000194c:	7bb8                	ld	a4,112(a5)
    8000194e:	57fd                	li	a5,-1
    80001950:	02f70d63          	beq	a4,a5,8000198a <forkret+0x8c>
      panic("exec");
    }
  }

  // return to user space, mimicing usertrap()'s return.
  prepare_return();
    80001954:	339000ef          	jal	8000248c <prepare_return>
  uint64 satp = MAKE_SATP(p->pagetable);
    80001958:	6ca8                	ld	a0,88(s1)
    8000195a:	8131                	srli	a0,a0,0xc
  uint64 trampoline_userret = TRAMPOLINE + (userret - trampoline);
    8000195c:	04000737          	lui	a4,0x4000
    80001960:	177d                	addi	a4,a4,-1 # 3ffffff <_entry-0x7c000001>
    80001962:	0732                	slli	a4,a4,0xc
    80001964:	00004797          	auipc	a5,0x4
    80001968:	73878793          	addi	a5,a5,1848 # 8000609c <userret>
    8000196c:	00004697          	auipc	a3,0x4
    80001970:	69468693          	addi	a3,a3,1684 # 80006000 <_trampoline>
    80001974:	8f95                	sub	a5,a5,a3
    80001976:	97ba                	add	a5,a5,a4
  ((void (*)(uint64))trampoline_userret)(satp);
    80001978:	577d                	li	a4,-1
    8000197a:	177e                	slli	a4,a4,0x3f
    8000197c:	8d59                	or	a0,a0,a4
    8000197e:	9782                	jalr	a5
}
    80001980:	70a2                	ld	ra,40(sp)
    80001982:	7402                	ld	s0,32(sp)
    80001984:	64e2                	ld	s1,24(sp)
    80001986:	6145                	addi	sp,sp,48
    80001988:	8082                	ret
      panic("exec");
    8000198a:	00005517          	auipc	a0,0x5
    8000198e:	7fe50513          	addi	a0,a0,2046 # 80007188 <etext+0x188>
    80001992:	e4ffe0ef          	jal	800007e0 <panic>

0000000080001996 <allocpid>:
{
    80001996:	1101                	addi	sp,sp,-32
    80001998:	ec06                	sd	ra,24(sp)
    8000199a:	e822                	sd	s0,16(sp)
    8000199c:	e426                	sd	s1,8(sp)
    8000199e:	e04a                	sd	s2,0(sp)
    800019a0:	1000                	addi	s0,sp,32
  acquire(&pid_lock);
    800019a2:	00011917          	auipc	s2,0x11
    800019a6:	c2690913          	addi	s2,s2,-986 # 800125c8 <pid_lock>
    800019aa:	854a                	mv	a0,s2
    800019ac:	a22ff0ef          	jal	80000bce <acquire>
  pid = nextpid;
    800019b0:	00009797          	auipc	a5,0x9
    800019b4:	ac478793          	addi	a5,a5,-1340 # 8000a474 <nextpid>
    800019b8:	4384                	lw	s1,0(a5)
  nextpid = nextpid + 1;
    800019ba:	0014871b          	addiw	a4,s1,1
    800019be:	c398                	sw	a4,0(a5)
  release(&pid_lock);
    800019c0:	854a                	mv	a0,s2
    800019c2:	aa4ff0ef          	jal	80000c66 <release>
}
    800019c6:	8526                	mv	a0,s1
    800019c8:	60e2                	ld	ra,24(sp)
    800019ca:	6442                	ld	s0,16(sp)
    800019cc:	64a2                	ld	s1,8(sp)
    800019ce:	6902                	ld	s2,0(sp)
    800019d0:	6105                	addi	sp,sp,32
    800019d2:	8082                	ret

00000000800019d4 <proc_pagetable>:
{
    800019d4:	1101                	addi	sp,sp,-32
    800019d6:	ec06                	sd	ra,24(sp)
    800019d8:	e822                	sd	s0,16(sp)
    800019da:	e426                	sd	s1,8(sp)
    800019dc:	e04a                	sd	s2,0(sp)
    800019de:	1000                	addi	s0,sp,32
    800019e0:	892a                	mv	s2,a0
  pagetable = uvmcreate();
    800019e2:	fb2ff0ef          	jal	80001194 <uvmcreate>
    800019e6:	84aa                	mv	s1,a0
  if(pagetable == 0)
    800019e8:	cd05                	beqz	a0,80001a20 <proc_pagetable+0x4c>
  if(mappages(pagetable, TRAMPOLINE, PGSIZE,
    800019ea:	4729                	li	a4,10
    800019ec:	00004697          	auipc	a3,0x4
    800019f0:	61468693          	addi	a3,a3,1556 # 80006000 <_trampoline>
    800019f4:	6605                	lui	a2,0x1
    800019f6:	040005b7          	lui	a1,0x4000
    800019fa:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    800019fc:	05b2                	slli	a1,a1,0xc
    800019fe:	df0ff0ef          	jal	80000fee <mappages>
    80001a02:	02054663          	bltz	a0,80001a2e <proc_pagetable+0x5a>
  if(mappages(pagetable, TRAPFRAME, PGSIZE,
    80001a06:	4719                	li	a4,6
    80001a08:	06093683          	ld	a3,96(s2)
    80001a0c:	6605                	lui	a2,0x1
    80001a0e:	020005b7          	lui	a1,0x2000
    80001a12:	15fd                	addi	a1,a1,-1 # 1ffffff <_entry-0x7e000001>
    80001a14:	05b6                	slli	a1,a1,0xd
    80001a16:	8526                	mv	a0,s1
    80001a18:	dd6ff0ef          	jal	80000fee <mappages>
    80001a1c:	00054f63          	bltz	a0,80001a3a <proc_pagetable+0x66>
}
    80001a20:	8526                	mv	a0,s1
    80001a22:	60e2                	ld	ra,24(sp)
    80001a24:	6442                	ld	s0,16(sp)
    80001a26:	64a2                	ld	s1,8(sp)
    80001a28:	6902                	ld	s2,0(sp)
    80001a2a:	6105                	addi	sp,sp,32
    80001a2c:	8082                	ret
    uvmfree(pagetable, 0);
    80001a2e:	4581                	li	a1,0
    80001a30:	8526                	mv	a0,s1
    80001a32:	95dff0ef          	jal	8000138e <uvmfree>
    return 0;
    80001a36:	4481                	li	s1,0
    80001a38:	b7e5                	j	80001a20 <proc_pagetable+0x4c>
    uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    80001a3a:	4681                	li	a3,0
    80001a3c:	4605                	li	a2,1
    80001a3e:	040005b7          	lui	a1,0x4000
    80001a42:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    80001a44:	05b2                	slli	a1,a1,0xc
    80001a46:	8526                	mv	a0,s1
    80001a48:	f72ff0ef          	jal	800011ba <uvmunmap>
    uvmfree(pagetable, 0);
    80001a4c:	4581                	li	a1,0
    80001a4e:	8526                	mv	a0,s1
    80001a50:	93fff0ef          	jal	8000138e <uvmfree>
    return 0;
    80001a54:	4481                	li	s1,0
    80001a56:	b7e9                	j	80001a20 <proc_pagetable+0x4c>

0000000080001a58 <proc_freepagetable>:
{
    80001a58:	1101                	addi	sp,sp,-32
    80001a5a:	ec06                	sd	ra,24(sp)
    80001a5c:	e822                	sd	s0,16(sp)
    80001a5e:	e426                	sd	s1,8(sp)
    80001a60:	e04a                	sd	s2,0(sp)
    80001a62:	1000                	addi	s0,sp,32
    80001a64:	84aa                	mv	s1,a0
    80001a66:	892e                	mv	s2,a1
  uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    80001a68:	4681                	li	a3,0
    80001a6a:	4605                	li	a2,1
    80001a6c:	040005b7          	lui	a1,0x4000
    80001a70:	15fd                	addi	a1,a1,-1 # 3ffffff <_entry-0x7c000001>
    80001a72:	05b2                	slli	a1,a1,0xc
    80001a74:	f46ff0ef          	jal	800011ba <uvmunmap>
  uvmunmap(pagetable, TRAPFRAME, 1, 0);
    80001a78:	4681                	li	a3,0
    80001a7a:	4605                	li	a2,1
    80001a7c:	020005b7          	lui	a1,0x2000
    80001a80:	15fd                	addi	a1,a1,-1 # 1ffffff <_entry-0x7e000001>
    80001a82:	05b6                	slli	a1,a1,0xd
    80001a84:	8526                	mv	a0,s1
    80001a86:	f34ff0ef          	jal	800011ba <uvmunmap>
  uvmfree(pagetable, sz);
    80001a8a:	85ca                	mv	a1,s2
    80001a8c:	8526                	mv	a0,s1
    80001a8e:	901ff0ef          	jal	8000138e <uvmfree>
}
    80001a92:	60e2                	ld	ra,24(sp)
    80001a94:	6442                	ld	s0,16(sp)
    80001a96:	64a2                	ld	s1,8(sp)
    80001a98:	6902                	ld	s2,0(sp)
    80001a9a:	6105                	addi	sp,sp,32
    80001a9c:	8082                	ret

0000000080001a9e <freeproc>:
{
    80001a9e:	1101                	addi	sp,sp,-32
    80001aa0:	ec06                	sd	ra,24(sp)
    80001aa2:	e822                	sd	s0,16(sp)
    80001aa4:	e426                	sd	s1,8(sp)
    80001aa6:	1000                	addi	s0,sp,32
    80001aa8:	84aa                	mv	s1,a0
  if(p->trapframe)
    80001aaa:	7128                	ld	a0,96(a0)
    80001aac:	c119                	beqz	a0,80001ab2 <freeproc+0x14>
    kfree((void*)p->trapframe);
    80001aae:	f6ffe0ef          	jal	80000a1c <kfree>
  p->trapframe = 0;
    80001ab2:	0604b023          	sd	zero,96(s1)
  if(p->pagetable)
    80001ab6:	6ca8                	ld	a0,88(s1)
    80001ab8:	c501                	beqz	a0,80001ac0 <freeproc+0x22>
    proc_freepagetable(p->pagetable, p->sz);
    80001aba:	64ac                	ld	a1,72(s1)
    80001abc:	f9dff0ef          	jal	80001a58 <proc_freepagetable>
  p->pagetable = 0;
    80001ac0:	0404bc23          	sd	zero,88(s1)
  p->sz = 0;
    80001ac4:	0404b423          	sd	zero,72(s1)
  p->mem_quota = 0; //
    80001ac8:	0404b823          	sd	zero,80(s1)
  p->pid = 0;
    80001acc:	0204a823          	sw	zero,48(s1)
  p->parent = 0;
    80001ad0:	0204bc23          	sd	zero,56(s1)
  p->name[0] = 0;
    80001ad4:	16048023          	sb	zero,352(s1)
  p->chan = 0;
    80001ad8:	0204b023          	sd	zero,32(s1)
  p->killed = 0;
    80001adc:	0204a423          	sw	zero,40(s1)
  p->xstate = 0;
    80001ae0:	0204a623          	sw	zero,44(s1)
  p->trace_mask = 0;
    80001ae4:	1604a823          	sw	zero,368(s1)
  p->priority = 0;
    80001ae8:	1604aa23          	sw	zero,372(s1)
  p->state = UNUSED;
    80001aec:	0004ac23          	sw	zero,24(s1)
}
    80001af0:	60e2                	ld	ra,24(sp)
    80001af2:	6442                	ld	s0,16(sp)
    80001af4:	64a2                	ld	s1,8(sp)
    80001af6:	6105                	addi	sp,sp,32
    80001af8:	8082                	ret

0000000080001afa <allocproc>:
{
    80001afa:	1101                	addi	sp,sp,-32
    80001afc:	ec06                	sd	ra,24(sp)
    80001afe:	e822                	sd	s0,16(sp)
    80001b00:	e426                	sd	s1,8(sp)
    80001b02:	e04a                	sd	s2,0(sp)
    80001b04:	1000                	addi	s0,sp,32
  for(p = proc; p < &proc[NPROC]; p++) {
    80001b06:	00011497          	auipc	s1,0x11
    80001b0a:	ef248493          	addi	s1,s1,-270 # 800129f8 <proc>
    80001b0e:	00017917          	auipc	s2,0x17
    80001b12:	cea90913          	addi	s2,s2,-790 # 800187f8 <tickslock>
    acquire(&p->lock);
    80001b16:	8526                	mv	a0,s1
    80001b18:	8b6ff0ef          	jal	80000bce <acquire>
    if(p->state == UNUSED) {
    80001b1c:	4c9c                	lw	a5,24(s1)
    80001b1e:	cb91                	beqz	a5,80001b32 <allocproc+0x38>
      release(&p->lock);
    80001b20:	8526                	mv	a0,s1
    80001b22:	944ff0ef          	jal	80000c66 <release>
  for(p = proc; p < &proc[NPROC]; p++) {
    80001b26:	17848493          	addi	s1,s1,376
    80001b2a:	ff2496e3          	bne	s1,s2,80001b16 <allocproc+0x1c>
  return 0;
    80001b2e:	4481                	li	s1,0
    80001b30:	a0b1                	j	80001b7c <allocproc+0x82>
  p->pid = allocpid();
    80001b32:	e65ff0ef          	jal	80001996 <allocpid>
    80001b36:	d888                	sw	a0,48(s1)
  p->priority = 10;
    80001b38:	47a9                	li	a5,10
    80001b3a:	16f4aa23          	sw	a5,372(s1)
  p->state = USED;
    80001b3e:	4785                	li	a5,1
    80001b40:	cc9c                	sw	a5,24(s1)
  p->mem_quota = 0;
    80001b42:	0404b823          	sd	zero,80(s1)
  if((p->trapframe = (struct trapframe *)kalloc()) == 0){
    80001b46:	fb9fe0ef          	jal	80000afe <kalloc>
    80001b4a:	892a                	mv	s2,a0
    80001b4c:	f0a8                	sd	a0,96(s1)
    80001b4e:	cd15                	beqz	a0,80001b8a <allocproc+0x90>
  p->pagetable = proc_pagetable(p);
    80001b50:	8526                	mv	a0,s1
    80001b52:	e83ff0ef          	jal	800019d4 <proc_pagetable>
    80001b56:	892a                	mv	s2,a0
    80001b58:	eca8                	sd	a0,88(s1)
  if(p->pagetable == 0){
    80001b5a:	c121                	beqz	a0,80001b9a <allocproc+0xa0>
  memset(&p->context, 0, sizeof(p->context));
    80001b5c:	07000613          	li	a2,112
    80001b60:	4581                	li	a1,0
    80001b62:	06848513          	addi	a0,s1,104
    80001b66:	93cff0ef          	jal	80000ca2 <memset>
  p->context.ra = (uint64)forkret;
    80001b6a:	00000797          	auipc	a5,0x0
    80001b6e:	d9478793          	addi	a5,a5,-620 # 800018fe <forkret>
    80001b72:	f4bc                	sd	a5,104(s1)
  p->context.sp = p->kstack + PGSIZE;
    80001b74:	60bc                	ld	a5,64(s1)
    80001b76:	6705                	lui	a4,0x1
    80001b78:	97ba                	add	a5,a5,a4
    80001b7a:	f8bc                	sd	a5,112(s1)
}
    80001b7c:	8526                	mv	a0,s1
    80001b7e:	60e2                	ld	ra,24(sp)
    80001b80:	6442                	ld	s0,16(sp)
    80001b82:	64a2                	ld	s1,8(sp)
    80001b84:	6902                	ld	s2,0(sp)
    80001b86:	6105                	addi	sp,sp,32
    80001b88:	8082                	ret
    freeproc(p);
    80001b8a:	8526                	mv	a0,s1
    80001b8c:	f13ff0ef          	jal	80001a9e <freeproc>
    release(&p->lock);
    80001b90:	8526                	mv	a0,s1
    80001b92:	8d4ff0ef          	jal	80000c66 <release>
    return 0;
    80001b96:	84ca                	mv	s1,s2
    80001b98:	b7d5                	j	80001b7c <allocproc+0x82>
    freeproc(p);
    80001b9a:	8526                	mv	a0,s1
    80001b9c:	f03ff0ef          	jal	80001a9e <freeproc>
    release(&p->lock);
    80001ba0:	8526                	mv	a0,s1
    80001ba2:	8c4ff0ef          	jal	80000c66 <release>
    return 0;
    80001ba6:	84ca                	mv	s1,s2
    80001ba8:	bfd1                	j	80001b7c <allocproc+0x82>

0000000080001baa <userinit>:
{
    80001baa:	1101                	addi	sp,sp,-32
    80001bac:	ec06                	sd	ra,24(sp)
    80001bae:	e822                	sd	s0,16(sp)
    80001bb0:	e426                	sd	s1,8(sp)
    80001bb2:	1000                	addi	s0,sp,32
  p = allocproc();
    80001bb4:	f47ff0ef          	jal	80001afa <allocproc>
    80001bb8:	84aa                	mv	s1,a0
  initproc = p;
    80001bba:	00009797          	auipc	a5,0x9
    80001bbe:	90a7b323          	sd	a0,-1786(a5) # 8000a4c0 <initproc>
  p->cwd = namei("/");
    80001bc2:	00005517          	auipc	a0,0x5
    80001bc6:	5ce50513          	addi	a0,a0,1486 # 80007190 <etext+0x190>
    80001bca:	1b0020ef          	jal	80003d7a <namei>
    80001bce:	14a4bc23          	sd	a0,344(s1)
  p->state = RUNNABLE;
    80001bd2:	478d                	li	a5,3
    80001bd4:	cc9c                	sw	a5,24(s1)
  release(&p->lock);
    80001bd6:	8526                	mv	a0,s1
    80001bd8:	88eff0ef          	jal	80000c66 <release>
}
    80001bdc:	60e2                	ld	ra,24(sp)
    80001bde:	6442                	ld	s0,16(sp)
    80001be0:	64a2                	ld	s1,8(sp)
    80001be2:	6105                	addi	sp,sp,32
    80001be4:	8082                	ret

0000000080001be6 <growproc>:
{
    80001be6:	1101                	addi	sp,sp,-32
    80001be8:	ec06                	sd	ra,24(sp)
    80001bea:	e822                	sd	s0,16(sp)
    80001bec:	e426                	sd	s1,8(sp)
    80001bee:	e04a                	sd	s2,0(sp)
    80001bf0:	1000                	addi	s0,sp,32
    80001bf2:	892a                	mv	s2,a0
  struct proc *p = myproc();
    80001bf4:	cdbff0ef          	jal	800018ce <myproc>
    80001bf8:	84aa                	mv	s1,a0
  sz = p->sz;
    80001bfa:	652c                	ld	a1,72(a0)
  if(n > 0){
    80001bfc:	05205963          	blez	s2,80001c4e <growproc+0x68>
    if(p->mem_quota > 0){
    80001c00:	693c                	ld	a5,80(a0)
    80001c02:	c799                	beqz	a5,80001c10 <growproc+0x2a>
      if(sz >= p->mem_quota || (uint64)n > p->mem_quota - sz){
    80001c04:	02f5f663          	bgeu	a1,a5,80001c30 <growproc+0x4a>
    80001c08:	40b78733          	sub	a4,a5,a1
    80001c0c:	03276263          	bltu	a4,s2,80001c30 <growproc+0x4a>
    if((sz = uvmalloc(p->pagetable, sz, sz + n, PTE_W)) == 0) {
    80001c10:	4691                	li	a3,4
    80001c12:	00b90633          	add	a2,s2,a1
    80001c16:	6ca8                	ld	a0,88(s1)
    80001c18:	e70ff0ef          	jal	80001288 <uvmalloc>
    80001c1c:	85aa                	mv	a1,a0
    80001c1e:	c129                	beqz	a0,80001c60 <growproc+0x7a>
  p->sz = sz;
    80001c20:	e4ac                	sd	a1,72(s1)
  return 0;
    80001c22:	4501                	li	a0,0
}
    80001c24:	60e2                	ld	ra,24(sp)
    80001c26:	6442                	ld	s0,16(sp)
    80001c28:	64a2                	ld	s1,8(sp)
    80001c2a:	6902                	ld	s2,0(sp)
    80001c2c:	6105                	addi	sp,sp,32
    80001c2e:	8082                	ret
        printf("[quota denied] pid=%d name=%s sz=%d request=%d quota=%d\n",
    80001c30:	2781                	sext.w	a5,a5
    80001c32:	874a                	mv	a4,s2
    80001c34:	0005869b          	sext.w	a3,a1
    80001c38:	16048613          	addi	a2,s1,352
    80001c3c:	588c                	lw	a1,48(s1)
    80001c3e:	00005517          	auipc	a0,0x5
    80001c42:	55a50513          	addi	a0,a0,1370 # 80007198 <etext+0x198>
    80001c46:	8b5fe0ef          	jal	800004fa <printf>
        return -1;
    80001c4a:	557d                	li	a0,-1
    80001c4c:	bfe1                	j	80001c24 <growproc+0x3e>
  } else if(n < 0){
    80001c4e:	fc0959e3          	bgez	s2,80001c20 <growproc+0x3a>
    sz = uvmdealloc(p->pagetable, sz, sz + n);
    80001c52:	00b90633          	add	a2,s2,a1
    80001c56:	6d28                	ld	a0,88(a0)
    80001c58:	decff0ef          	jal	80001244 <uvmdealloc>
    80001c5c:	85aa                	mv	a1,a0
    80001c5e:	b7c9                	j	80001c20 <growproc+0x3a>
      return -1;
    80001c60:	557d                	li	a0,-1
    80001c62:	b7c9                	j	80001c24 <growproc+0x3e>

0000000080001c64 <kfork>:
{
    80001c64:	7139                	addi	sp,sp,-64
    80001c66:	fc06                	sd	ra,56(sp)
    80001c68:	f822                	sd	s0,48(sp)
    80001c6a:	f04a                	sd	s2,32(sp)
    80001c6c:	e456                	sd	s5,8(sp)
    80001c6e:	0080                	addi	s0,sp,64
  struct proc *p = myproc();
    80001c70:	c5fff0ef          	jal	800018ce <myproc>
    80001c74:	8aaa                	mv	s5,a0
  if((np = allocproc()) == 0){
    80001c76:	e85ff0ef          	jal	80001afa <allocproc>
    80001c7a:	12050e63          	beqz	a0,80001db6 <kfork+0x152>
    80001c7e:	ec4e                	sd	s3,24(sp)
    80001c80:	89aa                	mv	s3,a0
  if(uvmcopy(p->pagetable, np->pagetable, p->sz) < 0){
    80001c82:	048ab603          	ld	a2,72(s5)
    80001c86:	6d2c                	ld	a1,88(a0)
    80001c88:	058ab503          	ld	a0,88(s5)
    80001c8c:	f34ff0ef          	jal	800013c0 <uvmcopy>
    80001c90:	08054163          	bltz	a0,80001d12 <kfork+0xae>
    80001c94:	f426                	sd	s1,40(sp)
    80001c96:	e852                	sd	s4,16(sp)
    80001c98:	e05a                	sd	s6,0(sp)
  np->sz = p->sz;
    80001c9a:	048ab783          	ld	a5,72(s5)
    80001c9e:	04f9b423          	sd	a5,72(s3)
  if(strncmp(p->name, "init", 16) == 0 || strncmp(p->name, "sh", 16) == 0)
    80001ca2:	160a8b13          	addi	s6,s5,352
    80001ca6:	4641                	li	a2,16
    80001ca8:	00005597          	auipc	a1,0x5
    80001cac:	53058593          	addi	a1,a1,1328 # 800071d8 <etext+0x1d8>
    80001cb0:	855a                	mv	a0,s6
    80001cb2:	8bcff0ef          	jal	80000d6e <strncmp>
    np->mem_quota = 0;
    80001cb6:	4781                	li	a5,0
  if(strncmp(p->name, "init", 16) == 0 || strncmp(p->name, "sh", 16) == 0)
    80001cb8:	e535                	bnez	a0,80001d24 <kfork+0xc0>
    80001cba:	04f9b823          	sd	a5,80(s3)
    *(np->trapframe) = *(p->trapframe);
    80001cbe:	060ab683          	ld	a3,96(s5)
    80001cc2:	87b6                	mv	a5,a3
    80001cc4:	0609b703          	ld	a4,96(s3)
    80001cc8:	12068693          	addi	a3,a3,288
    80001ccc:	0007b803          	ld	a6,0(a5)
    80001cd0:	6788                	ld	a0,8(a5)
    80001cd2:	6b8c                	ld	a1,16(a5)
    80001cd4:	6f90                	ld	a2,24(a5)
    80001cd6:	01073023          	sd	a6,0(a4) # 1000 <_entry-0x7ffff000>
    80001cda:	e708                	sd	a0,8(a4)
    80001cdc:	eb0c                	sd	a1,16(a4)
    80001cde:	ef10                	sd	a2,24(a4)
    80001ce0:	02078793          	addi	a5,a5,32
    80001ce4:	02070713          	addi	a4,a4,32
    80001ce8:	fed792e3          	bne	a5,a3,80001ccc <kfork+0x68>
  np->trapframe->a0 = 0;
    80001cec:	0609b783          	ld	a5,96(s3)
    80001cf0:	0607b823          	sd	zero,112(a5)
  np->priority = p->priority;
    80001cf4:	174aa783          	lw	a5,372(s5)
    80001cf8:	16f9aa23          	sw	a5,372(s3)
  np->trace_mask = p->trace_mask;
    80001cfc:	170aa783          	lw	a5,368(s5)
    80001d00:	16f9a823          	sw	a5,368(s3)
  for(i = 0; i < NOFILE; i++)
    80001d04:	0d8a8493          	addi	s1,s5,216
    80001d08:	0d898913          	addi	s2,s3,216
    80001d0c:	158a8a13          	addi	s4,s5,344
    80001d10:	a81d                	j	80001d46 <kfork+0xe2>
    freeproc(np);
    80001d12:	854e                	mv	a0,s3
    80001d14:	d8bff0ef          	jal	80001a9e <freeproc>
    release(&np->lock);
    80001d18:	854e                	mv	a0,s3
    80001d1a:	f4dfe0ef          	jal	80000c66 <release>
    return -1;
    80001d1e:	597d                	li	s2,-1
    80001d20:	69e2                	ld	s3,24(sp)
    80001d22:	a059                	j	80001da8 <kfork+0x144>
  if(strncmp(p->name, "init", 16) == 0 || strncmp(p->name, "sh", 16) == 0)
    80001d24:	4641                	li	a2,16
    80001d26:	00005597          	auipc	a1,0x5
    80001d2a:	4ba58593          	addi	a1,a1,1210 # 800071e0 <etext+0x1e0>
    80001d2e:	855a                	mv	a0,s6
    80001d30:	83eff0ef          	jal	80000d6e <strncmp>
    np->mem_quota = 0;
    80001d34:	4781                	li	a5,0
  if(strncmp(p->name, "init", 16) == 0 || strncmp(p->name, "sh", 16) == 0)
    80001d36:	d151                	beqz	a0,80001cba <kfork+0x56>
    np->mem_quota = p->mem_quota;
    80001d38:	050ab783          	ld	a5,80(s5)
    80001d3c:	bfbd                	j	80001cba <kfork+0x56>
  for(i = 0; i < NOFILE; i++)
    80001d3e:	04a1                	addi	s1,s1,8
    80001d40:	0921                	addi	s2,s2,8
    80001d42:	01448963          	beq	s1,s4,80001d54 <kfork+0xf0>
    if(p->ofile[i])
    80001d46:	6088                	ld	a0,0(s1)
    80001d48:	d97d                	beqz	a0,80001d3e <kfork+0xda>
      np->ofile[i] = filedup(p->ofile[i]);
    80001d4a:	5ca020ef          	jal	80004314 <filedup>
    80001d4e:	00a93023          	sd	a0,0(s2)
    80001d52:	b7f5                	j	80001d3e <kfork+0xda>
  np->cwd = idup(p->cwd);
    80001d54:	158ab503          	ld	a0,344(s5)
    80001d58:	7d6010ef          	jal	8000352e <idup>
    80001d5c:	14a9bc23          	sd	a0,344(s3)
  safestrcpy(np->name, p->name, sizeof(p->name));
    80001d60:	4641                	li	a2,16
    80001d62:	85da                	mv	a1,s6
    80001d64:	16098513          	addi	a0,s3,352
    80001d68:	878ff0ef          	jal	80000de0 <safestrcpy>
  pid = np->pid;
    80001d6c:	0309a903          	lw	s2,48(s3)
  release(&np->lock);
    80001d70:	854e                	mv	a0,s3
    80001d72:	ef5fe0ef          	jal	80000c66 <release>
  acquire(&wait_lock);
    80001d76:	00011497          	auipc	s1,0x11
    80001d7a:	86a48493          	addi	s1,s1,-1942 # 800125e0 <wait_lock>
    80001d7e:	8526                	mv	a0,s1
    80001d80:	e4ffe0ef          	jal	80000bce <acquire>
  np->parent = p;
    80001d84:	0359bc23          	sd	s5,56(s3)
  release(&wait_lock);
    80001d88:	8526                	mv	a0,s1
    80001d8a:	eddfe0ef          	jal	80000c66 <release>
  acquire(&np->lock);
    80001d8e:	854e                	mv	a0,s3
    80001d90:	e3ffe0ef          	jal	80000bce <acquire>
  np->state = RUNNABLE;
    80001d94:	478d                	li	a5,3
    80001d96:	00f9ac23          	sw	a5,24(s3)
  release(&np->lock);
    80001d9a:	854e                	mv	a0,s3
    80001d9c:	ecbfe0ef          	jal	80000c66 <release>
  return pid;
    80001da0:	74a2                	ld	s1,40(sp)
    80001da2:	69e2                	ld	s3,24(sp)
    80001da4:	6a42                	ld	s4,16(sp)
    80001da6:	6b02                	ld	s6,0(sp)
}
    80001da8:	854a                	mv	a0,s2
    80001daa:	70e2                	ld	ra,56(sp)
    80001dac:	7442                	ld	s0,48(sp)
    80001dae:	7902                	ld	s2,32(sp)
    80001db0:	6aa2                	ld	s5,8(sp)
    80001db2:	6121                	addi	sp,sp,64
    80001db4:	8082                	ret
    return -1;
    80001db6:	597d                	li	s2,-1
    80001db8:	bfc5                	j	80001da8 <kfork+0x144>

0000000080001dba <scheduler>:
{
    80001dba:	715d                	addi	sp,sp,-80
    80001dbc:	e486                	sd	ra,72(sp)
    80001dbe:	e0a2                	sd	s0,64(sp)
    80001dc0:	fc26                	sd	s1,56(sp)
    80001dc2:	f84a                	sd	s2,48(sp)
    80001dc4:	f44e                	sd	s3,40(sp)
    80001dc6:	f052                	sd	s4,32(sp)
    80001dc8:	ec56                	sd	s5,24(sp)
    80001dca:	e85a                	sd	s6,16(sp)
    80001dcc:	e45e                	sd	s7,8(sp)
    80001dce:	e062                	sd	s8,0(sp)
    80001dd0:	0880                	addi	s0,sp,80
    80001dd2:	8792                	mv	a5,tp
  int id = r_tp();
    80001dd4:	2781                	sext.w	a5,a5
  c->proc = 0;
    80001dd6:	00779b13          	slli	s6,a5,0x7
    80001dda:	00010717          	auipc	a4,0x10
    80001dde:	7ee70713          	addi	a4,a4,2030 # 800125c8 <pid_lock>
    80001de2:	975a                	add	a4,a4,s6
    80001de4:	02073823          	sd	zero,48(a4)
        swtch(&c->context, &p->context);
    80001de8:	00011717          	auipc	a4,0x11
    80001dec:	81870713          	addi	a4,a4,-2024 # 80012600 <cpus+0x8>
    80001df0:	9b3a                	add	s6,s6,a4
        p->state = RUNNING;
    80001df2:	4c11                	li	s8,4
        c->proc = p;
    80001df4:	079e                	slli	a5,a5,0x7
    80001df6:	00010a17          	auipc	s4,0x10
    80001dfa:	7d2a0a13          	addi	s4,s4,2002 # 800125c8 <pid_lock>
    80001dfe:	9a3e                	add	s4,s4,a5
        found = 1;
    80001e00:	4b85                	li	s7,1
    for(p = proc; p < &proc[NPROC]; p++) {
    80001e02:	00017997          	auipc	s3,0x17
    80001e06:	9f698993          	addi	s3,s3,-1546 # 800187f8 <tickslock>
    80001e0a:	a83d                	j	80001e48 <scheduler+0x8e>
      release(&p->lock);
    80001e0c:	8526                	mv	a0,s1
    80001e0e:	e59fe0ef          	jal	80000c66 <release>
    for(p = proc; p < &proc[NPROC]; p++) {
    80001e12:	17848493          	addi	s1,s1,376
    80001e16:	03348563          	beq	s1,s3,80001e40 <scheduler+0x86>
      acquire(&p->lock);
    80001e1a:	8526                	mv	a0,s1
    80001e1c:	db3fe0ef          	jal	80000bce <acquire>
      if(p->state == RUNNABLE) {
    80001e20:	4c9c                	lw	a5,24(s1)
    80001e22:	ff2795e3          	bne	a5,s2,80001e0c <scheduler+0x52>
        p->state = RUNNING;
    80001e26:	0184ac23          	sw	s8,24(s1)
        c->proc = p;
    80001e2a:	029a3823          	sd	s1,48(s4)
        swtch(&c->context, &p->context);
    80001e2e:	06848593          	addi	a1,s1,104
    80001e32:	855a                	mv	a0,s6
    80001e34:	5b2000ef          	jal	800023e6 <swtch>
        c->proc = 0;
    80001e38:	020a3823          	sd	zero,48(s4)
        found = 1;
    80001e3c:	8ade                	mv	s5,s7
    80001e3e:	b7f9                	j	80001e0c <scheduler+0x52>
    if(found == 0) {
    80001e40:	000a9463          	bnez	s5,80001e48 <scheduler+0x8e>
      asm volatile("wfi");
    80001e44:	10500073          	wfi
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80001e48:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80001e4c:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80001e50:	10079073          	csrw	sstatus,a5
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80001e54:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    80001e58:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80001e5a:	10079073          	csrw	sstatus,a5
    int found = 0;
    80001e5e:	4a81                	li	s5,0
    for(p = proc; p < &proc[NPROC]; p++) {
    80001e60:	00011497          	auipc	s1,0x11
    80001e64:	b9848493          	addi	s1,s1,-1128 # 800129f8 <proc>
      if(p->state == RUNNABLE) {
    80001e68:	490d                	li	s2,3
    80001e6a:	bf45                	j	80001e1a <scheduler+0x60>

0000000080001e6c <sched>:
{
    80001e6c:	7179                	addi	sp,sp,-48
    80001e6e:	f406                	sd	ra,40(sp)
    80001e70:	f022                	sd	s0,32(sp)
    80001e72:	ec26                	sd	s1,24(sp)
    80001e74:	e84a                	sd	s2,16(sp)
    80001e76:	e44e                	sd	s3,8(sp)
    80001e78:	1800                	addi	s0,sp,48
  struct proc *p = myproc();
    80001e7a:	a55ff0ef          	jal	800018ce <myproc>
    80001e7e:	84aa                	mv	s1,a0
  if(!holding(&p->lock))
    80001e80:	ce5fe0ef          	jal	80000b64 <holding>
    80001e84:	c92d                	beqz	a0,80001ef6 <sched+0x8a>
  asm volatile("mv %0, tp" : "=r" (x) );
    80001e86:	8792                	mv	a5,tp
  if(mycpu()->noff != 1)
    80001e88:	2781                	sext.w	a5,a5
    80001e8a:	079e                	slli	a5,a5,0x7
    80001e8c:	00010717          	auipc	a4,0x10
    80001e90:	73c70713          	addi	a4,a4,1852 # 800125c8 <pid_lock>
    80001e94:	97ba                	add	a5,a5,a4
    80001e96:	0a87a703          	lw	a4,168(a5)
    80001e9a:	4785                	li	a5,1
    80001e9c:	06f71363          	bne	a4,a5,80001f02 <sched+0x96>
  if(p->state == RUNNING)
    80001ea0:	4c98                	lw	a4,24(s1)
    80001ea2:	4791                	li	a5,4
    80001ea4:	06f70563          	beq	a4,a5,80001f0e <sched+0xa2>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80001ea8:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80001eac:	8b89                	andi	a5,a5,2
  if(intr_get())
    80001eae:	e7b5                	bnez	a5,80001f1a <sched+0xae>
  asm volatile("mv %0, tp" : "=r" (x) );
    80001eb0:	8792                	mv	a5,tp
  intena = mycpu()->intena;
    80001eb2:	00010917          	auipc	s2,0x10
    80001eb6:	71690913          	addi	s2,s2,1814 # 800125c8 <pid_lock>
    80001eba:	2781                	sext.w	a5,a5
    80001ebc:	079e                	slli	a5,a5,0x7
    80001ebe:	97ca                	add	a5,a5,s2
    80001ec0:	0ac7a983          	lw	s3,172(a5)
    80001ec4:	8792                	mv	a5,tp
  swtch(&p->context, &mycpu()->context);
    80001ec6:	2781                	sext.w	a5,a5
    80001ec8:	079e                	slli	a5,a5,0x7
    80001eca:	00010597          	auipc	a1,0x10
    80001ece:	73658593          	addi	a1,a1,1846 # 80012600 <cpus+0x8>
    80001ed2:	95be                	add	a1,a1,a5
    80001ed4:	06848513          	addi	a0,s1,104
    80001ed8:	50e000ef          	jal	800023e6 <swtch>
    80001edc:	8792                	mv	a5,tp
  mycpu()->intena = intena;
    80001ede:	2781                	sext.w	a5,a5
    80001ee0:	079e                	slli	a5,a5,0x7
    80001ee2:	993e                	add	s2,s2,a5
    80001ee4:	0b392623          	sw	s3,172(s2)
}
    80001ee8:	70a2                	ld	ra,40(sp)
    80001eea:	7402                	ld	s0,32(sp)
    80001eec:	64e2                	ld	s1,24(sp)
    80001eee:	6942                	ld	s2,16(sp)
    80001ef0:	69a2                	ld	s3,8(sp)
    80001ef2:	6145                	addi	sp,sp,48
    80001ef4:	8082                	ret
    panic("sched p->lock");
    80001ef6:	00005517          	auipc	a0,0x5
    80001efa:	2f250513          	addi	a0,a0,754 # 800071e8 <etext+0x1e8>
    80001efe:	8e3fe0ef          	jal	800007e0 <panic>
    panic("sched locks");
    80001f02:	00005517          	auipc	a0,0x5
    80001f06:	2f650513          	addi	a0,a0,758 # 800071f8 <etext+0x1f8>
    80001f0a:	8d7fe0ef          	jal	800007e0 <panic>
    panic("sched RUNNING");
    80001f0e:	00005517          	auipc	a0,0x5
    80001f12:	2fa50513          	addi	a0,a0,762 # 80007208 <etext+0x208>
    80001f16:	8cbfe0ef          	jal	800007e0 <panic>
    panic("sched interruptible");
    80001f1a:	00005517          	auipc	a0,0x5
    80001f1e:	2fe50513          	addi	a0,a0,766 # 80007218 <etext+0x218>
    80001f22:	8bffe0ef          	jal	800007e0 <panic>

0000000080001f26 <yield>:
{
    80001f26:	1101                	addi	sp,sp,-32
    80001f28:	ec06                	sd	ra,24(sp)
    80001f2a:	e822                	sd	s0,16(sp)
    80001f2c:	e426                	sd	s1,8(sp)
    80001f2e:	1000                	addi	s0,sp,32
  struct proc *p = myproc();
    80001f30:	99fff0ef          	jal	800018ce <myproc>
    80001f34:	84aa                	mv	s1,a0
  acquire(&p->lock);
    80001f36:	c99fe0ef          	jal	80000bce <acquire>
  p->state = RUNNABLE;
    80001f3a:	478d                	li	a5,3
    80001f3c:	cc9c                	sw	a5,24(s1)
  sched();
    80001f3e:	f2fff0ef          	jal	80001e6c <sched>
  release(&p->lock);
    80001f42:	8526                	mv	a0,s1
    80001f44:	d23fe0ef          	jal	80000c66 <release>
}
    80001f48:	60e2                	ld	ra,24(sp)
    80001f4a:	6442                	ld	s0,16(sp)
    80001f4c:	64a2                	ld	s1,8(sp)
    80001f4e:	6105                	addi	sp,sp,32
    80001f50:	8082                	ret

0000000080001f52 <sleep>:

// Sleep on channel chan, releasing condition lock lk.
// Re-acquires lk when awakened.
void
sleep(void *chan, struct spinlock *lk)
{
    80001f52:	7179                	addi	sp,sp,-48
    80001f54:	f406                	sd	ra,40(sp)
    80001f56:	f022                	sd	s0,32(sp)
    80001f58:	ec26                	sd	s1,24(sp)
    80001f5a:	e84a                	sd	s2,16(sp)
    80001f5c:	e44e                	sd	s3,8(sp)
    80001f5e:	1800                	addi	s0,sp,48
    80001f60:	89aa                	mv	s3,a0
    80001f62:	892e                	mv	s2,a1
  struct proc *p = myproc();
    80001f64:	96bff0ef          	jal	800018ce <myproc>
    80001f68:	84aa                	mv	s1,a0
  // Once we hold p->lock, we can be
  // guaranteed that we won't miss any wakeup
  // (wakeup locks p->lock),
  // so it's okay to release lk.

  acquire(&p->lock);  //DOC: sleeplock1
    80001f6a:	c65fe0ef          	jal	80000bce <acquire>
  release(lk);
    80001f6e:	854a                	mv	a0,s2
    80001f70:	cf7fe0ef          	jal	80000c66 <release>

  // Go to sleep.
  p->chan = chan;
    80001f74:	0334b023          	sd	s3,32(s1)
  p->state = SLEEPING;
    80001f78:	4789                	li	a5,2
    80001f7a:	cc9c                	sw	a5,24(s1)

  sched();
    80001f7c:	ef1ff0ef          	jal	80001e6c <sched>

  // Tidy up.
  p->chan = 0;
    80001f80:	0204b023          	sd	zero,32(s1)

  // Reacquire original lock.
  release(&p->lock);
    80001f84:	8526                	mv	a0,s1
    80001f86:	ce1fe0ef          	jal	80000c66 <release>
  acquire(lk);
    80001f8a:	854a                	mv	a0,s2
    80001f8c:	c43fe0ef          	jal	80000bce <acquire>
}
    80001f90:	70a2                	ld	ra,40(sp)
    80001f92:	7402                	ld	s0,32(sp)
    80001f94:	64e2                	ld	s1,24(sp)
    80001f96:	6942                	ld	s2,16(sp)
    80001f98:	69a2                	ld	s3,8(sp)
    80001f9a:	6145                	addi	sp,sp,48
    80001f9c:	8082                	ret

0000000080001f9e <wakeup>:

// Wake up all processes sleeping on channel chan.
// Caller should hold the condition lock.
void
wakeup(void *chan)
{
    80001f9e:	7139                	addi	sp,sp,-64
    80001fa0:	fc06                	sd	ra,56(sp)
    80001fa2:	f822                	sd	s0,48(sp)
    80001fa4:	f426                	sd	s1,40(sp)
    80001fa6:	f04a                	sd	s2,32(sp)
    80001fa8:	ec4e                	sd	s3,24(sp)
    80001faa:	e852                	sd	s4,16(sp)
    80001fac:	e456                	sd	s5,8(sp)
    80001fae:	0080                	addi	s0,sp,64
    80001fb0:	8a2a                	mv	s4,a0
  struct proc *p;

  for(p = proc; p < &proc[NPROC]; p++) {
    80001fb2:	00011497          	auipc	s1,0x11
    80001fb6:	a4648493          	addi	s1,s1,-1466 # 800129f8 <proc>
    if(p != myproc()){
      acquire(&p->lock);
      if(p->state == SLEEPING && p->chan == chan) {
    80001fba:	4989                	li	s3,2
        p->state = RUNNABLE;
    80001fbc:	4a8d                	li	s5,3
  for(p = proc; p < &proc[NPROC]; p++) {
    80001fbe:	00017917          	auipc	s2,0x17
    80001fc2:	83a90913          	addi	s2,s2,-1990 # 800187f8 <tickslock>
    80001fc6:	a801                	j	80001fd6 <wakeup+0x38>
      }
      release(&p->lock);
    80001fc8:	8526                	mv	a0,s1
    80001fca:	c9dfe0ef          	jal	80000c66 <release>
  for(p = proc; p < &proc[NPROC]; p++) {
    80001fce:	17848493          	addi	s1,s1,376
    80001fd2:	03248263          	beq	s1,s2,80001ff6 <wakeup+0x58>
    if(p != myproc()){
    80001fd6:	8f9ff0ef          	jal	800018ce <myproc>
    80001fda:	fea48ae3          	beq	s1,a0,80001fce <wakeup+0x30>
      acquire(&p->lock);
    80001fde:	8526                	mv	a0,s1
    80001fe0:	beffe0ef          	jal	80000bce <acquire>
      if(p->state == SLEEPING && p->chan == chan) {
    80001fe4:	4c9c                	lw	a5,24(s1)
    80001fe6:	ff3791e3          	bne	a5,s3,80001fc8 <wakeup+0x2a>
    80001fea:	709c                	ld	a5,32(s1)
    80001fec:	fd479ee3          	bne	a5,s4,80001fc8 <wakeup+0x2a>
        p->state = RUNNABLE;
    80001ff0:	0154ac23          	sw	s5,24(s1)
    80001ff4:	bfd1                	j	80001fc8 <wakeup+0x2a>
    }
  }
}
    80001ff6:	70e2                	ld	ra,56(sp)
    80001ff8:	7442                	ld	s0,48(sp)
    80001ffa:	74a2                	ld	s1,40(sp)
    80001ffc:	7902                	ld	s2,32(sp)
    80001ffe:	69e2                	ld	s3,24(sp)
    80002000:	6a42                	ld	s4,16(sp)
    80002002:	6aa2                	ld	s5,8(sp)
    80002004:	6121                	addi	sp,sp,64
    80002006:	8082                	ret

0000000080002008 <reparent>:
{
    80002008:	7179                	addi	sp,sp,-48
    8000200a:	f406                	sd	ra,40(sp)
    8000200c:	f022                	sd	s0,32(sp)
    8000200e:	ec26                	sd	s1,24(sp)
    80002010:	e84a                	sd	s2,16(sp)
    80002012:	e44e                	sd	s3,8(sp)
    80002014:	e052                	sd	s4,0(sp)
    80002016:	1800                	addi	s0,sp,48
    80002018:	892a                	mv	s2,a0
  for(pp = proc; pp < &proc[NPROC]; pp++){
    8000201a:	00011497          	auipc	s1,0x11
    8000201e:	9de48493          	addi	s1,s1,-1570 # 800129f8 <proc>
      pp->parent = initproc;
    80002022:	00008a17          	auipc	s4,0x8
    80002026:	49ea0a13          	addi	s4,s4,1182 # 8000a4c0 <initproc>
  for(pp = proc; pp < &proc[NPROC]; pp++){
    8000202a:	00016997          	auipc	s3,0x16
    8000202e:	7ce98993          	addi	s3,s3,1998 # 800187f8 <tickslock>
    80002032:	a029                	j	8000203c <reparent+0x34>
    80002034:	17848493          	addi	s1,s1,376
    80002038:	01348b63          	beq	s1,s3,8000204e <reparent+0x46>
    if(pp->parent == p){
    8000203c:	7c9c                	ld	a5,56(s1)
    8000203e:	ff279be3          	bne	a5,s2,80002034 <reparent+0x2c>
      pp->parent = initproc;
    80002042:	000a3503          	ld	a0,0(s4)
    80002046:	fc88                	sd	a0,56(s1)
      wakeup(initproc);
    80002048:	f57ff0ef          	jal	80001f9e <wakeup>
    8000204c:	b7e5                	j	80002034 <reparent+0x2c>
}
    8000204e:	70a2                	ld	ra,40(sp)
    80002050:	7402                	ld	s0,32(sp)
    80002052:	64e2                	ld	s1,24(sp)
    80002054:	6942                	ld	s2,16(sp)
    80002056:	69a2                	ld	s3,8(sp)
    80002058:	6a02                	ld	s4,0(sp)
    8000205a:	6145                	addi	sp,sp,48
    8000205c:	8082                	ret

000000008000205e <kexit>:
{
    8000205e:	7179                	addi	sp,sp,-48
    80002060:	f406                	sd	ra,40(sp)
    80002062:	f022                	sd	s0,32(sp)
    80002064:	ec26                	sd	s1,24(sp)
    80002066:	e84a                	sd	s2,16(sp)
    80002068:	e44e                	sd	s3,8(sp)
    8000206a:	e052                	sd	s4,0(sp)
    8000206c:	1800                	addi	s0,sp,48
    8000206e:	8a2a                	mv	s4,a0
  struct proc *p = myproc();
    80002070:	85fff0ef          	jal	800018ce <myproc>
    80002074:	89aa                	mv	s3,a0
  if(p == initproc)
    80002076:	00008797          	auipc	a5,0x8
    8000207a:	44a7b783          	ld	a5,1098(a5) # 8000a4c0 <initproc>
    8000207e:	0d850493          	addi	s1,a0,216
    80002082:	15850913          	addi	s2,a0,344
    80002086:	00a79f63          	bne	a5,a0,800020a4 <kexit+0x46>
    panic("init exiting");
    8000208a:	00005517          	auipc	a0,0x5
    8000208e:	1a650513          	addi	a0,a0,422 # 80007230 <etext+0x230>
    80002092:	f4efe0ef          	jal	800007e0 <panic>
      fileclose(f);
    80002096:	2c4020ef          	jal	8000435a <fileclose>
      p->ofile[fd] = 0;
    8000209a:	0004b023          	sd	zero,0(s1)
  for(int fd = 0; fd < NOFILE; fd++){
    8000209e:	04a1                	addi	s1,s1,8
    800020a0:	01248563          	beq	s1,s2,800020aa <kexit+0x4c>
    if(p->ofile[fd]){
    800020a4:	6088                	ld	a0,0(s1)
    800020a6:	f965                	bnez	a0,80002096 <kexit+0x38>
    800020a8:	bfdd                	j	8000209e <kexit+0x40>
  begin_op();
    800020aa:	6a5010ef          	jal	80003f4e <begin_op>
  iput(p->cwd);
    800020ae:	1589b503          	ld	a0,344(s3)
    800020b2:	634010ef          	jal	800036e6 <iput>
  end_op();
    800020b6:	703010ef          	jal	80003fb8 <end_op>
  p->cwd = 0;
    800020ba:	1409bc23          	sd	zero,344(s3)
  acquire(&wait_lock);
    800020be:	00010497          	auipc	s1,0x10
    800020c2:	52248493          	addi	s1,s1,1314 # 800125e0 <wait_lock>
    800020c6:	8526                	mv	a0,s1
    800020c8:	b07fe0ef          	jal	80000bce <acquire>
  reparent(p);
    800020cc:	854e                	mv	a0,s3
    800020ce:	f3bff0ef          	jal	80002008 <reparent>
  wakeup(p->parent);
    800020d2:	0389b503          	ld	a0,56(s3)
    800020d6:	ec9ff0ef          	jal	80001f9e <wakeup>
  acquire(&p->lock);
    800020da:	854e                	mv	a0,s3
    800020dc:	af3fe0ef          	jal	80000bce <acquire>
  p->xstate = status;
    800020e0:	0349a623          	sw	s4,44(s3)
  p->state = ZOMBIE;
    800020e4:	4795                	li	a5,5
    800020e6:	00f9ac23          	sw	a5,24(s3)
  release(&wait_lock);
    800020ea:	8526                	mv	a0,s1
    800020ec:	b7bfe0ef          	jal	80000c66 <release>
  sched();
    800020f0:	d7dff0ef          	jal	80001e6c <sched>
  panic("zombie exit");
    800020f4:	00005517          	auipc	a0,0x5
    800020f8:	14c50513          	addi	a0,a0,332 # 80007240 <etext+0x240>
    800020fc:	ee4fe0ef          	jal	800007e0 <panic>

0000000080002100 <kkill>:
// Kill the process with the given pid.
// The victim won't exit until it tries to return
// to user space (see usertrap() in trap.c).
int
kkill(int pid)
{
    80002100:	7179                	addi	sp,sp,-48
    80002102:	f406                	sd	ra,40(sp)
    80002104:	f022                	sd	s0,32(sp)
    80002106:	ec26                	sd	s1,24(sp)
    80002108:	e84a                	sd	s2,16(sp)
    8000210a:	e44e                	sd	s3,8(sp)
    8000210c:	1800                	addi	s0,sp,48
    8000210e:	892a                	mv	s2,a0
  struct proc *p;

  for(p = proc; p < &proc[NPROC]; p++){
    80002110:	00011497          	auipc	s1,0x11
    80002114:	8e848493          	addi	s1,s1,-1816 # 800129f8 <proc>
    80002118:	00016997          	auipc	s3,0x16
    8000211c:	6e098993          	addi	s3,s3,1760 # 800187f8 <tickslock>
    acquire(&p->lock);
    80002120:	8526                	mv	a0,s1
    80002122:	aadfe0ef          	jal	80000bce <acquire>
    if(p->pid == pid){
    80002126:	589c                	lw	a5,48(s1)
    80002128:	01278b63          	beq	a5,s2,8000213e <kkill+0x3e>
        p->state = RUNNABLE;
      }
      release(&p->lock);
      return 0;
    }
    release(&p->lock);
    8000212c:	8526                	mv	a0,s1
    8000212e:	b39fe0ef          	jal	80000c66 <release>
  for(p = proc; p < &proc[NPROC]; p++){
    80002132:	17848493          	addi	s1,s1,376
    80002136:	ff3495e3          	bne	s1,s3,80002120 <kkill+0x20>
  }
  return -1;
    8000213a:	557d                	li	a0,-1
    8000213c:	a819                	j	80002152 <kkill+0x52>
      p->killed = 1;
    8000213e:	4785                	li	a5,1
    80002140:	d49c                	sw	a5,40(s1)
      if(p->state == SLEEPING){
    80002142:	4c98                	lw	a4,24(s1)
    80002144:	4789                	li	a5,2
    80002146:	00f70d63          	beq	a4,a5,80002160 <kkill+0x60>
      release(&p->lock);
    8000214a:	8526                	mv	a0,s1
    8000214c:	b1bfe0ef          	jal	80000c66 <release>
      return 0;
    80002150:	4501                	li	a0,0
}
    80002152:	70a2                	ld	ra,40(sp)
    80002154:	7402                	ld	s0,32(sp)
    80002156:	64e2                	ld	s1,24(sp)
    80002158:	6942                	ld	s2,16(sp)
    8000215a:	69a2                	ld	s3,8(sp)
    8000215c:	6145                	addi	sp,sp,48
    8000215e:	8082                	ret
        p->state = RUNNABLE;
    80002160:	478d                	li	a5,3
    80002162:	cc9c                	sw	a5,24(s1)
    80002164:	b7dd                	j	8000214a <kkill+0x4a>

0000000080002166 <setkilled>:

void
setkilled(struct proc *p)
{
    80002166:	1101                	addi	sp,sp,-32
    80002168:	ec06                	sd	ra,24(sp)
    8000216a:	e822                	sd	s0,16(sp)
    8000216c:	e426                	sd	s1,8(sp)
    8000216e:	1000                	addi	s0,sp,32
    80002170:	84aa                	mv	s1,a0
  acquire(&p->lock);
    80002172:	a5dfe0ef          	jal	80000bce <acquire>
  p->killed = 1;
    80002176:	4785                	li	a5,1
    80002178:	d49c                	sw	a5,40(s1)
  release(&p->lock);
    8000217a:	8526                	mv	a0,s1
    8000217c:	aebfe0ef          	jal	80000c66 <release>
}
    80002180:	60e2                	ld	ra,24(sp)
    80002182:	6442                	ld	s0,16(sp)
    80002184:	64a2                	ld	s1,8(sp)
    80002186:	6105                	addi	sp,sp,32
    80002188:	8082                	ret

000000008000218a <killed>:

int
killed(struct proc *p)
{
    8000218a:	1101                	addi	sp,sp,-32
    8000218c:	ec06                	sd	ra,24(sp)
    8000218e:	e822                	sd	s0,16(sp)
    80002190:	e426                	sd	s1,8(sp)
    80002192:	e04a                	sd	s2,0(sp)
    80002194:	1000                	addi	s0,sp,32
    80002196:	84aa                	mv	s1,a0
  int k;
  
  acquire(&p->lock);
    80002198:	a37fe0ef          	jal	80000bce <acquire>
  k = p->killed;
    8000219c:	0284a903          	lw	s2,40(s1)
  release(&p->lock);
    800021a0:	8526                	mv	a0,s1
    800021a2:	ac5fe0ef          	jal	80000c66 <release>
  return k;
}
    800021a6:	854a                	mv	a0,s2
    800021a8:	60e2                	ld	ra,24(sp)
    800021aa:	6442                	ld	s0,16(sp)
    800021ac:	64a2                	ld	s1,8(sp)
    800021ae:	6902                	ld	s2,0(sp)
    800021b0:	6105                	addi	sp,sp,32
    800021b2:	8082                	ret

00000000800021b4 <kwait>:
{
    800021b4:	715d                	addi	sp,sp,-80
    800021b6:	e486                	sd	ra,72(sp)
    800021b8:	e0a2                	sd	s0,64(sp)
    800021ba:	fc26                	sd	s1,56(sp)
    800021bc:	f84a                	sd	s2,48(sp)
    800021be:	f44e                	sd	s3,40(sp)
    800021c0:	f052                	sd	s4,32(sp)
    800021c2:	ec56                	sd	s5,24(sp)
    800021c4:	e85a                	sd	s6,16(sp)
    800021c6:	e45e                	sd	s7,8(sp)
    800021c8:	e062                	sd	s8,0(sp)
    800021ca:	0880                	addi	s0,sp,80
    800021cc:	8b2a                	mv	s6,a0
  struct proc *p = myproc();
    800021ce:	f00ff0ef          	jal	800018ce <myproc>
    800021d2:	892a                	mv	s2,a0
  acquire(&wait_lock);
    800021d4:	00010517          	auipc	a0,0x10
    800021d8:	40c50513          	addi	a0,a0,1036 # 800125e0 <wait_lock>
    800021dc:	9f3fe0ef          	jal	80000bce <acquire>
    havekids = 0;
    800021e0:	4b81                	li	s7,0
        if(pp->state == ZOMBIE){
    800021e2:	4a15                	li	s4,5
        havekids = 1;
    800021e4:	4a85                	li	s5,1
    for(pp = proc; pp < &proc[NPROC]; pp++){
    800021e6:	00016997          	auipc	s3,0x16
    800021ea:	61298993          	addi	s3,s3,1554 # 800187f8 <tickslock>
    sleep(p, &wait_lock);  //DOC: wait-sleep
    800021ee:	00010c17          	auipc	s8,0x10
    800021f2:	3f2c0c13          	addi	s8,s8,1010 # 800125e0 <wait_lock>
    800021f6:	a871                	j	80002292 <kwait+0xde>
          pid = pp->pid;
    800021f8:	0304a983          	lw	s3,48(s1)
          if(addr != 0 && copyout(p->pagetable, addr, (char *)&pp->xstate,
    800021fc:	000b0c63          	beqz	s6,80002214 <kwait+0x60>
    80002200:	4691                	li	a3,4
    80002202:	02c48613          	addi	a2,s1,44
    80002206:	85da                	mv	a1,s6
    80002208:	05893503          	ld	a0,88(s2)
    8000220c:	bd6ff0ef          	jal	800015e2 <copyout>
    80002210:	02054b63          	bltz	a0,80002246 <kwait+0x92>
          freeproc(pp);
    80002214:	8526                	mv	a0,s1
    80002216:	889ff0ef          	jal	80001a9e <freeproc>
          release(&pp->lock);
    8000221a:	8526                	mv	a0,s1
    8000221c:	a4bfe0ef          	jal	80000c66 <release>
          release(&wait_lock);
    80002220:	00010517          	auipc	a0,0x10
    80002224:	3c050513          	addi	a0,a0,960 # 800125e0 <wait_lock>
    80002228:	a3ffe0ef          	jal	80000c66 <release>
}
    8000222c:	854e                	mv	a0,s3
    8000222e:	60a6                	ld	ra,72(sp)
    80002230:	6406                	ld	s0,64(sp)
    80002232:	74e2                	ld	s1,56(sp)
    80002234:	7942                	ld	s2,48(sp)
    80002236:	79a2                	ld	s3,40(sp)
    80002238:	7a02                	ld	s4,32(sp)
    8000223a:	6ae2                	ld	s5,24(sp)
    8000223c:	6b42                	ld	s6,16(sp)
    8000223e:	6ba2                	ld	s7,8(sp)
    80002240:	6c02                	ld	s8,0(sp)
    80002242:	6161                	addi	sp,sp,80
    80002244:	8082                	ret
            release(&pp->lock);
    80002246:	8526                	mv	a0,s1
    80002248:	a1ffe0ef          	jal	80000c66 <release>
            release(&wait_lock);
    8000224c:	00010517          	auipc	a0,0x10
    80002250:	39450513          	addi	a0,a0,916 # 800125e0 <wait_lock>
    80002254:	a13fe0ef          	jal	80000c66 <release>
            return -1;
    80002258:	59fd                	li	s3,-1
    8000225a:	bfc9                	j	8000222c <kwait+0x78>
    for(pp = proc; pp < &proc[NPROC]; pp++){
    8000225c:	17848493          	addi	s1,s1,376
    80002260:	03348063          	beq	s1,s3,80002280 <kwait+0xcc>
      if(pp->parent == p){
    80002264:	7c9c                	ld	a5,56(s1)
    80002266:	ff279be3          	bne	a5,s2,8000225c <kwait+0xa8>
        acquire(&pp->lock);
    8000226a:	8526                	mv	a0,s1
    8000226c:	963fe0ef          	jal	80000bce <acquire>
        if(pp->state == ZOMBIE){
    80002270:	4c9c                	lw	a5,24(s1)
    80002272:	f94783e3          	beq	a5,s4,800021f8 <kwait+0x44>
        release(&pp->lock);
    80002276:	8526                	mv	a0,s1
    80002278:	9effe0ef          	jal	80000c66 <release>
        havekids = 1;
    8000227c:	8756                	mv	a4,s5
    8000227e:	bff9                	j	8000225c <kwait+0xa8>
    if(!havekids || killed(p)){
    80002280:	cf19                	beqz	a4,8000229e <kwait+0xea>
    80002282:	854a                	mv	a0,s2
    80002284:	f07ff0ef          	jal	8000218a <killed>
    80002288:	e919                	bnez	a0,8000229e <kwait+0xea>
    sleep(p, &wait_lock);  //DOC: wait-sleep
    8000228a:	85e2                	mv	a1,s8
    8000228c:	854a                	mv	a0,s2
    8000228e:	cc5ff0ef          	jal	80001f52 <sleep>
    havekids = 0;
    80002292:	875e                	mv	a4,s7
    for(pp = proc; pp < &proc[NPROC]; pp++){
    80002294:	00010497          	auipc	s1,0x10
    80002298:	76448493          	addi	s1,s1,1892 # 800129f8 <proc>
    8000229c:	b7e1                	j	80002264 <kwait+0xb0>
      release(&wait_lock);
    8000229e:	00010517          	auipc	a0,0x10
    800022a2:	34250513          	addi	a0,a0,834 # 800125e0 <wait_lock>
    800022a6:	9c1fe0ef          	jal	80000c66 <release>
      return -1;
    800022aa:	59fd                	li	s3,-1
    800022ac:	b741                	j	8000222c <kwait+0x78>

00000000800022ae <either_copyout>:
// Copy to either a user address, or kernel address,
// depending on usr_dst.
// Returns 0 on success, -1 on error.
int
either_copyout(int user_dst, uint64 dst, void *src, uint64 len)
{
    800022ae:	7179                	addi	sp,sp,-48
    800022b0:	f406                	sd	ra,40(sp)
    800022b2:	f022                	sd	s0,32(sp)
    800022b4:	ec26                	sd	s1,24(sp)
    800022b6:	e84a                	sd	s2,16(sp)
    800022b8:	e44e                	sd	s3,8(sp)
    800022ba:	e052                	sd	s4,0(sp)
    800022bc:	1800                	addi	s0,sp,48
    800022be:	84aa                	mv	s1,a0
    800022c0:	892e                	mv	s2,a1
    800022c2:	89b2                	mv	s3,a2
    800022c4:	8a36                	mv	s4,a3
  struct proc *p = myproc();
    800022c6:	e08ff0ef          	jal	800018ce <myproc>
  if(user_dst){
    800022ca:	cc99                	beqz	s1,800022e8 <either_copyout+0x3a>
    return copyout(p->pagetable, dst, src, len);
    800022cc:	86d2                	mv	a3,s4
    800022ce:	864e                	mv	a2,s3
    800022d0:	85ca                	mv	a1,s2
    800022d2:	6d28                	ld	a0,88(a0)
    800022d4:	b0eff0ef          	jal	800015e2 <copyout>
  } else {
    memmove((char *)dst, src, len);
    return 0;
  }
}
    800022d8:	70a2                	ld	ra,40(sp)
    800022da:	7402                	ld	s0,32(sp)
    800022dc:	64e2                	ld	s1,24(sp)
    800022de:	6942                	ld	s2,16(sp)
    800022e0:	69a2                	ld	s3,8(sp)
    800022e2:	6a02                	ld	s4,0(sp)
    800022e4:	6145                	addi	sp,sp,48
    800022e6:	8082                	ret
    memmove((char *)dst, src, len);
    800022e8:	000a061b          	sext.w	a2,s4
    800022ec:	85ce                	mv	a1,s3
    800022ee:	854a                	mv	a0,s2
    800022f0:	a0ffe0ef          	jal	80000cfe <memmove>
    return 0;
    800022f4:	8526                	mv	a0,s1
    800022f6:	b7cd                	j	800022d8 <either_copyout+0x2a>

00000000800022f8 <either_copyin>:
// Copy from either a user address, or kernel address,
// depending on usr_src.
// Returns 0 on success, -1 on error.
int
either_copyin(void *dst, int user_src, uint64 src, uint64 len)
{
    800022f8:	7179                	addi	sp,sp,-48
    800022fa:	f406                	sd	ra,40(sp)
    800022fc:	f022                	sd	s0,32(sp)
    800022fe:	ec26                	sd	s1,24(sp)
    80002300:	e84a                	sd	s2,16(sp)
    80002302:	e44e                	sd	s3,8(sp)
    80002304:	e052                	sd	s4,0(sp)
    80002306:	1800                	addi	s0,sp,48
    80002308:	892a                	mv	s2,a0
    8000230a:	84ae                	mv	s1,a1
    8000230c:	89b2                	mv	s3,a2
    8000230e:	8a36                	mv	s4,a3
  struct proc *p = myproc();
    80002310:	dbeff0ef          	jal	800018ce <myproc>
  if(user_src){
    80002314:	cc99                	beqz	s1,80002332 <either_copyin+0x3a>
    return copyin(p->pagetable, dst, src, len);
    80002316:	86d2                	mv	a3,s4
    80002318:	864e                	mv	a2,s3
    8000231a:	85ca                	mv	a1,s2
    8000231c:	6d28                	ld	a0,88(a0)
    8000231e:	ba8ff0ef          	jal	800016c6 <copyin>
  } else {
    memmove(dst, (char*)src, len);
    return 0;
  }
}
    80002322:	70a2                	ld	ra,40(sp)
    80002324:	7402                	ld	s0,32(sp)
    80002326:	64e2                	ld	s1,24(sp)
    80002328:	6942                	ld	s2,16(sp)
    8000232a:	69a2                	ld	s3,8(sp)
    8000232c:	6a02                	ld	s4,0(sp)
    8000232e:	6145                	addi	sp,sp,48
    80002330:	8082                	ret
    memmove(dst, (char*)src, len);
    80002332:	000a061b          	sext.w	a2,s4
    80002336:	85ce                	mv	a1,s3
    80002338:	854a                	mv	a0,s2
    8000233a:	9c5fe0ef          	jal	80000cfe <memmove>
    return 0;
    8000233e:	8526                	mv	a0,s1
    80002340:	b7cd                	j	80002322 <either_copyin+0x2a>

0000000080002342 <procdump>:
// Print a process listing to console.  For debugging.
// Runs when user types ^P on console.
// No lock to avoid wedging a stuck machine further.
void
procdump(void)
{
    80002342:	715d                	addi	sp,sp,-80
    80002344:	e486                	sd	ra,72(sp)
    80002346:	e0a2                	sd	s0,64(sp)
    80002348:	fc26                	sd	s1,56(sp)
    8000234a:	f84a                	sd	s2,48(sp)
    8000234c:	f44e                	sd	s3,40(sp)
    8000234e:	f052                	sd	s4,32(sp)
    80002350:	ec56                	sd	s5,24(sp)
    80002352:	e85a                	sd	s6,16(sp)
    80002354:	e45e                	sd	s7,8(sp)
    80002356:	0880                	addi	s0,sp,80
  [ZOMBIE]    "zombie"
  };
  struct proc *p;
  char *state;

  printf("\n");
    80002358:	00005517          	auipc	a0,0x5
    8000235c:	d2050513          	addi	a0,a0,-736 # 80007078 <etext+0x78>
    80002360:	99afe0ef          	jal	800004fa <printf>
  for(p = proc; p < &proc[NPROC]; p++){
    80002364:	00010497          	auipc	s1,0x10
    80002368:	7f448493          	addi	s1,s1,2036 # 80012b58 <proc+0x160>
    8000236c:	00016917          	auipc	s2,0x16
    80002370:	5ec90913          	addi	s2,s2,1516 # 80018958 <bcache+0x148>
    if(p->state == UNUSED)
      continue;
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
    80002374:	4b15                	li	s6,5
      state = states[p->state];
    else
      state = "???";
    80002376:	00005997          	auipc	s3,0x5
    8000237a:	eda98993          	addi	s3,s3,-294 # 80007250 <etext+0x250>
    printf("%d %s %s", p->pid, state, p->name);
    8000237e:	00005a97          	auipc	s5,0x5
    80002382:	edaa8a93          	addi	s5,s5,-294 # 80007258 <etext+0x258>
    printf("\n");
    80002386:	00005a17          	auipc	s4,0x5
    8000238a:	cf2a0a13          	addi	s4,s4,-782 # 80007078 <etext+0x78>
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
    8000238e:	00005b97          	auipc	s7,0x5
    80002392:	49ab8b93          	addi	s7,s7,1178 # 80007828 <states.0>
    80002396:	a829                	j	800023b0 <procdump+0x6e>
    printf("%d %s %s", p->pid, state, p->name);
    80002398:	ed06a583          	lw	a1,-304(a3)
    8000239c:	8556                	mv	a0,s5
    8000239e:	95cfe0ef          	jal	800004fa <printf>
    printf("\n");
    800023a2:	8552                	mv	a0,s4
    800023a4:	956fe0ef          	jal	800004fa <printf>
  for(p = proc; p < &proc[NPROC]; p++){
    800023a8:	17848493          	addi	s1,s1,376
    800023ac:	03248263          	beq	s1,s2,800023d0 <procdump+0x8e>
    if(p->state == UNUSED)
    800023b0:	86a6                	mv	a3,s1
    800023b2:	eb84a783          	lw	a5,-328(s1)
    800023b6:	dbed                	beqz	a5,800023a8 <procdump+0x66>
      state = "???";
    800023b8:	864e                	mv	a2,s3
    if(p->state >= 0 && p->state < NELEM(states) && states[p->state])
    800023ba:	fcfb6fe3          	bltu	s6,a5,80002398 <procdump+0x56>
    800023be:	02079713          	slli	a4,a5,0x20
    800023c2:	01d75793          	srli	a5,a4,0x1d
    800023c6:	97de                	add	a5,a5,s7
    800023c8:	6390                	ld	a2,0(a5)
    800023ca:	f679                	bnez	a2,80002398 <procdump+0x56>
      state = "???";
    800023cc:	864e                	mv	a2,s3
    800023ce:	b7e9                	j	80002398 <procdump+0x56>
  }
}
    800023d0:	60a6                	ld	ra,72(sp)
    800023d2:	6406                	ld	s0,64(sp)
    800023d4:	74e2                	ld	s1,56(sp)
    800023d6:	7942                	ld	s2,48(sp)
    800023d8:	79a2                	ld	s3,40(sp)
    800023da:	7a02                	ld	s4,32(sp)
    800023dc:	6ae2                	ld	s5,24(sp)
    800023de:	6b42                	ld	s6,16(sp)
    800023e0:	6ba2                	ld	s7,8(sp)
    800023e2:	6161                	addi	sp,sp,80
    800023e4:	8082                	ret

00000000800023e6 <swtch>:
# Save current registers in old. Load from new.	


.globl swtch
swtch:
        sd ra, 0(a0)
    800023e6:	00153023          	sd	ra,0(a0)
        sd sp, 8(a0)
    800023ea:	00253423          	sd	sp,8(a0)
        sd s0, 16(a0)
    800023ee:	e900                	sd	s0,16(a0)
        sd s1, 24(a0)
    800023f0:	ed04                	sd	s1,24(a0)
        sd s2, 32(a0)
    800023f2:	03253023          	sd	s2,32(a0)
        sd s3, 40(a0)
    800023f6:	03353423          	sd	s3,40(a0)
        sd s4, 48(a0)
    800023fa:	03453823          	sd	s4,48(a0)
        sd s5, 56(a0)
    800023fe:	03553c23          	sd	s5,56(a0)
        sd s6, 64(a0)
    80002402:	05653023          	sd	s6,64(a0)
        sd s7, 72(a0)
    80002406:	05753423          	sd	s7,72(a0)
        sd s8, 80(a0)
    8000240a:	05853823          	sd	s8,80(a0)
        sd s9, 88(a0)
    8000240e:	05953c23          	sd	s9,88(a0)
        sd s10, 96(a0)
    80002412:	07a53023          	sd	s10,96(a0)
        sd s11, 104(a0)
    80002416:	07b53423          	sd	s11,104(a0)

        ld ra, 0(a1)
    8000241a:	0005b083          	ld	ra,0(a1)
        ld sp, 8(a1)
    8000241e:	0085b103          	ld	sp,8(a1)
        ld s0, 16(a1)
    80002422:	6980                	ld	s0,16(a1)
        ld s1, 24(a1)
    80002424:	6d84                	ld	s1,24(a1)
        ld s2, 32(a1)
    80002426:	0205b903          	ld	s2,32(a1)
        ld s3, 40(a1)
    8000242a:	0285b983          	ld	s3,40(a1)
        ld s4, 48(a1)
    8000242e:	0305ba03          	ld	s4,48(a1)
        ld s5, 56(a1)
    80002432:	0385ba83          	ld	s5,56(a1)
        ld s6, 64(a1)
    80002436:	0405bb03          	ld	s6,64(a1)
        ld s7, 72(a1)
    8000243a:	0485bb83          	ld	s7,72(a1)
        ld s8, 80(a1)
    8000243e:	0505bc03          	ld	s8,80(a1)
        ld s9, 88(a1)
    80002442:	0585bc83          	ld	s9,88(a1)
        ld s10, 96(a1)
    80002446:	0605bd03          	ld	s10,96(a1)
        ld s11, 104(a1)
    8000244a:	0685bd83          	ld	s11,104(a1)
        
        ret
    8000244e:	8082                	ret

0000000080002450 <trapinit>:

extern int devintr();

void
trapinit(void)
{
    80002450:	1141                	addi	sp,sp,-16
    80002452:	e406                	sd	ra,8(sp)
    80002454:	e022                	sd	s0,0(sp)
    80002456:	0800                	addi	s0,sp,16
  initlock(&tickslock, "time");
    80002458:	00005597          	auipc	a1,0x5
    8000245c:	e4058593          	addi	a1,a1,-448 # 80007298 <etext+0x298>
    80002460:	00016517          	auipc	a0,0x16
    80002464:	39850513          	addi	a0,a0,920 # 800187f8 <tickslock>
    80002468:	ee6fe0ef          	jal	80000b4e <initlock>
}
    8000246c:	60a2                	ld	ra,8(sp)
    8000246e:	6402                	ld	s0,0(sp)
    80002470:	0141                	addi	sp,sp,16
    80002472:	8082                	ret

0000000080002474 <trapinithart>:

// set up to take exceptions and traps while in the kernel.
void
trapinithart(void)
{
    80002474:	1141                	addi	sp,sp,-16
    80002476:	e422                	sd	s0,8(sp)
    80002478:	0800                	addi	s0,sp,16
  asm volatile("csrw stvec, %0" : : "r" (x));
    8000247a:	00003797          	auipc	a5,0x3
    8000247e:	25678793          	addi	a5,a5,598 # 800056d0 <kernelvec>
    80002482:	10579073          	csrw	stvec,a5
  w_stvec((uint64)kernelvec);
}
    80002486:	6422                	ld	s0,8(sp)
    80002488:	0141                	addi	sp,sp,16
    8000248a:	8082                	ret

000000008000248c <prepare_return>:
//
// set up trapframe and control registers for a return to user space
//
void
prepare_return(void)
{
    8000248c:	1141                	addi	sp,sp,-16
    8000248e:	e406                	sd	ra,8(sp)
    80002490:	e022                	sd	s0,0(sp)
    80002492:	0800                	addi	s0,sp,16
  struct proc *p = myproc();
    80002494:	c3aff0ef          	jal	800018ce <myproc>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    80002498:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() & ~SSTATUS_SIE);
    8000249c:	9bf5                	andi	a5,a5,-3
  asm volatile("csrw sstatus, %0" : : "r" (x));
    8000249e:	10079073          	csrw	sstatus,a5
  // kerneltrap() to usertrap(). because a trap from kernel
  // code to usertrap would be a disaster, turn off interrupts.
  intr_off();

  // send syscalls, interrupts, and exceptions to uservec in trampoline.S
  uint64 trampoline_uservec = TRAMPOLINE + (uservec - trampoline);
    800024a2:	04000737          	lui	a4,0x4000
    800024a6:	177d                	addi	a4,a4,-1 # 3ffffff <_entry-0x7c000001>
    800024a8:	0732                	slli	a4,a4,0xc
    800024aa:	00004797          	auipc	a5,0x4
    800024ae:	b5678793          	addi	a5,a5,-1194 # 80006000 <_trampoline>
    800024b2:	00004697          	auipc	a3,0x4
    800024b6:	b4e68693          	addi	a3,a3,-1202 # 80006000 <_trampoline>
    800024ba:	8f95                	sub	a5,a5,a3
    800024bc:	97ba                	add	a5,a5,a4
  asm volatile("csrw stvec, %0" : : "r" (x));
    800024be:	10579073          	csrw	stvec,a5
  w_stvec(trampoline_uservec);

  // set up trapframe values that uservec will need when
  // the process next traps into the kernel.
  p->trapframe->kernel_satp = r_satp();         // kernel page table
    800024c2:	713c                	ld	a5,96(a0)
  asm volatile("csrr %0, satp" : "=r" (x) );
    800024c4:	18002773          	csrr	a4,satp
    800024c8:	e398                	sd	a4,0(a5)
  p->trapframe->kernel_sp = p->kstack + PGSIZE; // process's kernel stack
    800024ca:	7138                	ld	a4,96(a0)
    800024cc:	613c                	ld	a5,64(a0)
    800024ce:	6685                	lui	a3,0x1
    800024d0:	97b6                	add	a5,a5,a3
    800024d2:	e71c                	sd	a5,8(a4)
  p->trapframe->kernel_trap = (uint64)usertrap;
    800024d4:	713c                	ld	a5,96(a0)
    800024d6:	00000717          	auipc	a4,0x0
    800024da:	0f870713          	addi	a4,a4,248 # 800025ce <usertrap>
    800024de:	eb98                	sd	a4,16(a5)
  p->trapframe->kernel_hartid = r_tp();         // hartid for cpuid()
    800024e0:	713c                	ld	a5,96(a0)
  asm volatile("mv %0, tp" : "=r" (x) );
    800024e2:	8712                	mv	a4,tp
    800024e4:	f398                	sd	a4,32(a5)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800024e6:	100027f3          	csrr	a5,sstatus
  // set up the registers that trampoline.S's sret will use
  // to get to user space.
  
  // set S Previous Privilege mode to User.
  unsigned long x = r_sstatus();
  x &= ~SSTATUS_SPP; // clear SPP to 0 for user mode
    800024ea:	eff7f793          	andi	a5,a5,-257
  x |= SSTATUS_SPIE; // enable interrupts in user mode
    800024ee:	0207e793          	ori	a5,a5,32
  asm volatile("csrw sstatus, %0" : : "r" (x));
    800024f2:	10079073          	csrw	sstatus,a5
  w_sstatus(x);

  // set S Exception Program Counter to the saved user pc.
  w_sepc(p->trapframe->epc);
    800024f6:	713c                	ld	a5,96(a0)
  asm volatile("csrw sepc, %0" : : "r" (x));
    800024f8:	6f9c                	ld	a5,24(a5)
    800024fa:	14179073          	csrw	sepc,a5
}
    800024fe:	60a2                	ld	ra,8(sp)
    80002500:	6402                	ld	s0,0(sp)
    80002502:	0141                	addi	sp,sp,16
    80002504:	8082                	ret

0000000080002506 <clockintr>:
  w_sstatus(sstatus);
}

void
clockintr()
{
    80002506:	1101                	addi	sp,sp,-32
    80002508:	ec06                	sd	ra,24(sp)
    8000250a:	e822                	sd	s0,16(sp)
    8000250c:	1000                	addi	s0,sp,32
  if(cpuid() == 0){
    8000250e:	b94ff0ef          	jal	800018a2 <cpuid>
    80002512:	cd11                	beqz	a0,8000252e <clockintr+0x28>
  asm volatile("csrr %0, time" : "=r" (x) );
    80002514:	c01027f3          	rdtime	a5
  }

  // ask for the next timer interrupt. this also clears
  // the interrupt request. 1000000 is about a tenth
  // of a second.
  w_stimecmp(r_time() + 1000000);
    80002518:	000f4737          	lui	a4,0xf4
    8000251c:	24070713          	addi	a4,a4,576 # f4240 <_entry-0x7ff0bdc0>
    80002520:	97ba                	add	a5,a5,a4
  asm volatile("csrw 0x14d, %0" : : "r" (x));
    80002522:	14d79073          	csrw	stimecmp,a5
}
    80002526:	60e2                	ld	ra,24(sp)
    80002528:	6442                	ld	s0,16(sp)
    8000252a:	6105                	addi	sp,sp,32
    8000252c:	8082                	ret
    8000252e:	e426                	sd	s1,8(sp)
    acquire(&tickslock);
    80002530:	00016497          	auipc	s1,0x16
    80002534:	2c848493          	addi	s1,s1,712 # 800187f8 <tickslock>
    80002538:	8526                	mv	a0,s1
    8000253a:	e94fe0ef          	jal	80000bce <acquire>
    ticks++;
    8000253e:	00008517          	auipc	a0,0x8
    80002542:	f8a50513          	addi	a0,a0,-118 # 8000a4c8 <ticks>
    80002546:	411c                	lw	a5,0(a0)
    80002548:	2785                	addiw	a5,a5,1
    8000254a:	c11c                	sw	a5,0(a0)
    wakeup(&ticks);
    8000254c:	a53ff0ef          	jal	80001f9e <wakeup>
    release(&tickslock);
    80002550:	8526                	mv	a0,s1
    80002552:	f14fe0ef          	jal	80000c66 <release>
    80002556:	64a2                	ld	s1,8(sp)
    80002558:	bf75                	j	80002514 <clockintr+0xe>

000000008000255a <devintr>:
// returns 2 if timer interrupt,
// 1 if other device,
// 0 if not recognized.
int
devintr()
{
    8000255a:	1101                	addi	sp,sp,-32
    8000255c:	ec06                	sd	ra,24(sp)
    8000255e:	e822                	sd	s0,16(sp)
    80002560:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, scause" : "=r" (x) );
    80002562:	14202773          	csrr	a4,scause
  uint64 scause = r_scause();

  if(scause == 0x8000000000000009L){
    80002566:	57fd                	li	a5,-1
    80002568:	17fe                	slli	a5,a5,0x3f
    8000256a:	07a5                	addi	a5,a5,9
    8000256c:	00f70c63          	beq	a4,a5,80002584 <devintr+0x2a>
    // now allowed to interrupt again.
    if(irq)
      plic_complete(irq);

    return 1;
  } else if(scause == 0x8000000000000005L){
    80002570:	57fd                	li	a5,-1
    80002572:	17fe                	slli	a5,a5,0x3f
    80002574:	0795                	addi	a5,a5,5
    // timer interrupt.
    clockintr();
    return 2;
  } else {
    return 0;
    80002576:	4501                	li	a0,0
  } else if(scause == 0x8000000000000005L){
    80002578:	04f70763          	beq	a4,a5,800025c6 <devintr+0x6c>
  }
}
    8000257c:	60e2                	ld	ra,24(sp)
    8000257e:	6442                	ld	s0,16(sp)
    80002580:	6105                	addi	sp,sp,32
    80002582:	8082                	ret
    80002584:	e426                	sd	s1,8(sp)
    int irq = plic_claim();
    80002586:	1f6030ef          	jal	8000577c <plic_claim>
    8000258a:	84aa                	mv	s1,a0
    if(irq == UART0_IRQ){
    8000258c:	47a9                	li	a5,10
    8000258e:	00f50963          	beq	a0,a5,800025a0 <devintr+0x46>
    } else if(irq == VIRTIO0_IRQ){
    80002592:	4785                	li	a5,1
    80002594:	00f50963          	beq	a0,a5,800025a6 <devintr+0x4c>
    return 1;
    80002598:	4505                	li	a0,1
    } else if(irq){
    8000259a:	e889                	bnez	s1,800025ac <devintr+0x52>
    8000259c:	64a2                	ld	s1,8(sp)
    8000259e:	bff9                	j	8000257c <devintr+0x22>
      uartintr();
    800025a0:	c10fe0ef          	jal	800009b0 <uartintr>
    if(irq)
    800025a4:	a819                	j	800025ba <devintr+0x60>
      virtio_disk_intr();
    800025a6:	69c030ef          	jal	80005c42 <virtio_disk_intr>
    if(irq)
    800025aa:	a801                	j	800025ba <devintr+0x60>
      printf("unexpected interrupt irq=%d\n", irq);
    800025ac:	85a6                	mv	a1,s1
    800025ae:	00005517          	auipc	a0,0x5
    800025b2:	cf250513          	addi	a0,a0,-782 # 800072a0 <etext+0x2a0>
    800025b6:	f45fd0ef          	jal	800004fa <printf>
      plic_complete(irq);
    800025ba:	8526                	mv	a0,s1
    800025bc:	1e0030ef          	jal	8000579c <plic_complete>
    return 1;
    800025c0:	4505                	li	a0,1
    800025c2:	64a2                	ld	s1,8(sp)
    800025c4:	bf65                	j	8000257c <devintr+0x22>
    clockintr();
    800025c6:	f41ff0ef          	jal	80002506 <clockintr>
    return 2;
    800025ca:	4509                	li	a0,2
    800025cc:	bf45                	j	8000257c <devintr+0x22>

00000000800025ce <usertrap>:
{
    800025ce:	1101                	addi	sp,sp,-32
    800025d0:	ec06                	sd	ra,24(sp)
    800025d2:	e822                	sd	s0,16(sp)
    800025d4:	e426                	sd	s1,8(sp)
    800025d6:	e04a                	sd	s2,0(sp)
    800025d8:	1000                	addi	s0,sp,32
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800025da:	100027f3          	csrr	a5,sstatus
  if((r_sstatus() & SSTATUS_SPP) != 0)
    800025de:	1007f793          	andi	a5,a5,256
    800025e2:	eba5                	bnez	a5,80002652 <usertrap+0x84>
  asm volatile("csrw stvec, %0" : : "r" (x));
    800025e4:	00003797          	auipc	a5,0x3
    800025e8:	0ec78793          	addi	a5,a5,236 # 800056d0 <kernelvec>
    800025ec:	10579073          	csrw	stvec,a5
  struct proc *p = myproc();
    800025f0:	adeff0ef          	jal	800018ce <myproc>
    800025f4:	84aa                	mv	s1,a0
  p->trapframe->epc = r_sepc();
    800025f6:	713c                	ld	a5,96(a0)
  asm volatile("csrr %0, sepc" : "=r" (x) );
    800025f8:	14102773          	csrr	a4,sepc
    800025fc:	ef98                	sd	a4,24(a5)
  asm volatile("csrr %0, scause" : "=r" (x) );
    800025fe:	14202773          	csrr	a4,scause
  if(r_scause() == 8){
    80002602:	47a1                	li	a5,8
    80002604:	04f70d63          	beq	a4,a5,8000265e <usertrap+0x90>
  } else if((which_dev = devintr()) != 0){
    80002608:	f53ff0ef          	jal	8000255a <devintr>
    8000260c:	892a                	mv	s2,a0
    8000260e:	e945                	bnez	a0,800026be <usertrap+0xf0>
    80002610:	14202773          	csrr	a4,scause
  } else if((r_scause() == 15 || r_scause() == 13) &&
    80002614:	47bd                	li	a5,15
    80002616:	08f70863          	beq	a4,a5,800026a6 <usertrap+0xd8>
    8000261a:	14202773          	csrr	a4,scause
    8000261e:	47b5                	li	a5,13
    80002620:	08f70363          	beq	a4,a5,800026a6 <usertrap+0xd8>
    80002624:	142025f3          	csrr	a1,scause
    printf("usertrap(): unexpected scause 0x%lx pid=%d\n", r_scause(), p->pid);
    80002628:	5890                	lw	a2,48(s1)
    8000262a:	00005517          	auipc	a0,0x5
    8000262e:	cb650513          	addi	a0,a0,-842 # 800072e0 <etext+0x2e0>
    80002632:	ec9fd0ef          	jal	800004fa <printf>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    80002636:	141025f3          	csrr	a1,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    8000263a:	14302673          	csrr	a2,stval
    printf("            sepc=0x%lx stval=0x%lx\n", r_sepc(), r_stval());
    8000263e:	00005517          	auipc	a0,0x5
    80002642:	cd250513          	addi	a0,a0,-814 # 80007310 <etext+0x310>
    80002646:	eb5fd0ef          	jal	800004fa <printf>
    setkilled(p);
    8000264a:	8526                	mv	a0,s1
    8000264c:	b1bff0ef          	jal	80002166 <setkilled>
    80002650:	a035                	j	8000267c <usertrap+0xae>
    panic("usertrap: not from user mode");
    80002652:	00005517          	auipc	a0,0x5
    80002656:	c6e50513          	addi	a0,a0,-914 # 800072c0 <etext+0x2c0>
    8000265a:	986fe0ef          	jal	800007e0 <panic>
    if(killed(p))
    8000265e:	b2dff0ef          	jal	8000218a <killed>
    80002662:	ed15                	bnez	a0,8000269e <usertrap+0xd0>
    p->trapframe->epc += 4;
    80002664:	70b8                	ld	a4,96(s1)
    80002666:	6f1c                	ld	a5,24(a4)
    80002668:	0791                	addi	a5,a5,4
    8000266a:	ef1c                	sd	a5,24(a4)
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    8000266c:	100027f3          	csrr	a5,sstatus
  w_sstatus(r_sstatus() | SSTATUS_SIE);
    80002670:	0027e793          	ori	a5,a5,2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002674:	10079073          	csrw	sstatus,a5
    syscall();
    80002678:	246000ef          	jal	800028be <syscall>
  if(killed(p))
    8000267c:	8526                	mv	a0,s1
    8000267e:	b0dff0ef          	jal	8000218a <killed>
    80002682:	e139                	bnez	a0,800026c8 <usertrap+0xfa>
  prepare_return();
    80002684:	e09ff0ef          	jal	8000248c <prepare_return>
  uint64 satp = MAKE_SATP(p->pagetable);
    80002688:	6ca8                	ld	a0,88(s1)
    8000268a:	8131                	srli	a0,a0,0xc
    8000268c:	57fd                	li	a5,-1
    8000268e:	17fe                	slli	a5,a5,0x3f
    80002690:	8d5d                	or	a0,a0,a5
}
    80002692:	60e2                	ld	ra,24(sp)
    80002694:	6442                	ld	s0,16(sp)
    80002696:	64a2                	ld	s1,8(sp)
    80002698:	6902                	ld	s2,0(sp)
    8000269a:	6105                	addi	sp,sp,32
    8000269c:	8082                	ret
      kexit(-1);
    8000269e:	557d                	li	a0,-1
    800026a0:	9bfff0ef          	jal	8000205e <kexit>
    800026a4:	b7c1                	j	80002664 <usertrap+0x96>
  asm volatile("csrr %0, stval" : "=r" (x) );
    800026a6:	143025f3          	csrr	a1,stval
  asm volatile("csrr %0, scause" : "=r" (x) );
    800026aa:	14202673          	csrr	a2,scause
            vmfault(p->pagetable, r_stval(), (r_scause() == 13)? 1 : 0) != 0) {
    800026ae:	164d                	addi	a2,a2,-13 # ff3 <_entry-0x7ffff00d>
    800026b0:	00163613          	seqz	a2,a2
    800026b4:	6ca8                	ld	a0,88(s1)
    800026b6:	eabfe0ef          	jal	80001560 <vmfault>
  } else if((r_scause() == 15 || r_scause() == 13) &&
    800026ba:	f169                	bnez	a0,8000267c <usertrap+0xae>
    800026bc:	b7a5                	j	80002624 <usertrap+0x56>
  if(killed(p))
    800026be:	8526                	mv	a0,s1
    800026c0:	acbff0ef          	jal	8000218a <killed>
    800026c4:	c511                	beqz	a0,800026d0 <usertrap+0x102>
    800026c6:	a011                	j	800026ca <usertrap+0xfc>
    800026c8:	4901                	li	s2,0
    kexit(-1);
    800026ca:	557d                	li	a0,-1
    800026cc:	993ff0ef          	jal	8000205e <kexit>
  if(which_dev == 2)
    800026d0:	4789                	li	a5,2
    800026d2:	faf919e3          	bne	s2,a5,80002684 <usertrap+0xb6>
    yield();
    800026d6:	851ff0ef          	jal	80001f26 <yield>
    800026da:	b76d                	j	80002684 <usertrap+0xb6>

00000000800026dc <kerneltrap>:
{
    800026dc:	7179                	addi	sp,sp,-48
    800026de:	f406                	sd	ra,40(sp)
    800026e0:	f022                	sd	s0,32(sp)
    800026e2:	ec26                	sd	s1,24(sp)
    800026e4:	e84a                	sd	s2,16(sp)
    800026e6:	e44e                	sd	s3,8(sp)
    800026e8:	1800                	addi	s0,sp,48
  asm volatile("csrr %0, sepc" : "=r" (x) );
    800026ea:	14102973          	csrr	s2,sepc
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800026ee:	100024f3          	csrr	s1,sstatus
  asm volatile("csrr %0, scause" : "=r" (x) );
    800026f2:	142029f3          	csrr	s3,scause
  if((sstatus & SSTATUS_SPP) == 0)
    800026f6:	1004f793          	andi	a5,s1,256
    800026fa:	c795                	beqz	a5,80002726 <kerneltrap+0x4a>
  asm volatile("csrr %0, sstatus" : "=r" (x) );
    800026fc:	100027f3          	csrr	a5,sstatus
  return (x & SSTATUS_SIE) != 0;
    80002700:	8b89                	andi	a5,a5,2
  if(intr_get() != 0)
    80002702:	eb85                	bnez	a5,80002732 <kerneltrap+0x56>
  if((which_dev = devintr()) == 0){
    80002704:	e57ff0ef          	jal	8000255a <devintr>
    80002708:	c91d                	beqz	a0,8000273e <kerneltrap+0x62>
  if(which_dev == 2 && myproc() != 0)
    8000270a:	4789                	li	a5,2
    8000270c:	04f50a63          	beq	a0,a5,80002760 <kerneltrap+0x84>
  asm volatile("csrw sepc, %0" : : "r" (x));
    80002710:	14191073          	csrw	sepc,s2
  asm volatile("csrw sstatus, %0" : : "r" (x));
    80002714:	10049073          	csrw	sstatus,s1
}
    80002718:	70a2                	ld	ra,40(sp)
    8000271a:	7402                	ld	s0,32(sp)
    8000271c:	64e2                	ld	s1,24(sp)
    8000271e:	6942                	ld	s2,16(sp)
    80002720:	69a2                	ld	s3,8(sp)
    80002722:	6145                	addi	sp,sp,48
    80002724:	8082                	ret
    panic("kerneltrap: not from supervisor mode");
    80002726:	00005517          	auipc	a0,0x5
    8000272a:	c1250513          	addi	a0,a0,-1006 # 80007338 <etext+0x338>
    8000272e:	8b2fe0ef          	jal	800007e0 <panic>
    panic("kerneltrap: interrupts enabled");
    80002732:	00005517          	auipc	a0,0x5
    80002736:	c2e50513          	addi	a0,a0,-978 # 80007360 <etext+0x360>
    8000273a:	8a6fe0ef          	jal	800007e0 <panic>
  asm volatile("csrr %0, sepc" : "=r" (x) );
    8000273e:	14102673          	csrr	a2,sepc
  asm volatile("csrr %0, stval" : "=r" (x) );
    80002742:	143026f3          	csrr	a3,stval
    printf("scause=0x%lx sepc=0x%lx stval=0x%lx\n", scause, r_sepc(), r_stval());
    80002746:	85ce                	mv	a1,s3
    80002748:	00005517          	auipc	a0,0x5
    8000274c:	c3850513          	addi	a0,a0,-968 # 80007380 <etext+0x380>
    80002750:	dabfd0ef          	jal	800004fa <printf>
    panic("kerneltrap");
    80002754:	00005517          	auipc	a0,0x5
    80002758:	c5450513          	addi	a0,a0,-940 # 800073a8 <etext+0x3a8>
    8000275c:	884fe0ef          	jal	800007e0 <panic>
  if(which_dev == 2 && myproc() != 0)
    80002760:	96eff0ef          	jal	800018ce <myproc>
    80002764:	d555                	beqz	a0,80002710 <kerneltrap+0x34>
    yield();
    80002766:	fc0ff0ef          	jal	80001f26 <yield>
    8000276a:	b75d                	j	80002710 <kerneltrap+0x34>

000000008000276c <argraw>:
  return strlen(buf);
}

static uint64
argraw(int n)
{
    8000276c:	1101                	addi	sp,sp,-32
    8000276e:	ec06                	sd	ra,24(sp)
    80002770:	e822                	sd	s0,16(sp)
    80002772:	e426                	sd	s1,8(sp)
    80002774:	1000                	addi	s0,sp,32
    80002776:	84aa                	mv	s1,a0
  struct proc *p = myproc();
    80002778:	956ff0ef          	jal	800018ce <myproc>
  switch (n) {
    8000277c:	4795                	li	a5,5
    8000277e:	0497e163          	bltu	a5,s1,800027c0 <argraw+0x54>
    80002782:	048a                	slli	s1,s1,0x2
    80002784:	00005717          	auipc	a4,0x5
    80002788:	0d470713          	addi	a4,a4,212 # 80007858 <states.0+0x30>
    8000278c:	94ba                	add	s1,s1,a4
    8000278e:	409c                	lw	a5,0(s1)
    80002790:	97ba                	add	a5,a5,a4
    80002792:	8782                	jr	a5
  case 0:
    return p->trapframe->a0;
    80002794:	713c                	ld	a5,96(a0)
    80002796:	7ba8                	ld	a0,112(a5)
  case 5:
    return p->trapframe->a5;
  }
  panic("argraw");
  return -1;
}
    80002798:	60e2                	ld	ra,24(sp)
    8000279a:	6442                	ld	s0,16(sp)
    8000279c:	64a2                	ld	s1,8(sp)
    8000279e:	6105                	addi	sp,sp,32
    800027a0:	8082                	ret
    return p->trapframe->a1;
    800027a2:	713c                	ld	a5,96(a0)
    800027a4:	7fa8                	ld	a0,120(a5)
    800027a6:	bfcd                	j	80002798 <argraw+0x2c>
    return p->trapframe->a2;
    800027a8:	713c                	ld	a5,96(a0)
    800027aa:	63c8                	ld	a0,128(a5)
    800027ac:	b7f5                	j	80002798 <argraw+0x2c>
    return p->trapframe->a3;
    800027ae:	713c                	ld	a5,96(a0)
    800027b0:	67c8                	ld	a0,136(a5)
    800027b2:	b7dd                	j	80002798 <argraw+0x2c>
    return p->trapframe->a4;
    800027b4:	713c                	ld	a5,96(a0)
    800027b6:	6bc8                	ld	a0,144(a5)
    800027b8:	b7c5                	j	80002798 <argraw+0x2c>
    return p->trapframe->a5;
    800027ba:	713c                	ld	a5,96(a0)
    800027bc:	6fc8                	ld	a0,152(a5)
    800027be:	bfe9                	j	80002798 <argraw+0x2c>
  panic("argraw");
    800027c0:	00005517          	auipc	a0,0x5
    800027c4:	bf850513          	addi	a0,a0,-1032 # 800073b8 <etext+0x3b8>
    800027c8:	818fe0ef          	jal	800007e0 <panic>

00000000800027cc <fetchaddr>:
{
    800027cc:	1101                	addi	sp,sp,-32
    800027ce:	ec06                	sd	ra,24(sp)
    800027d0:	e822                	sd	s0,16(sp)
    800027d2:	e426                	sd	s1,8(sp)
    800027d4:	e04a                	sd	s2,0(sp)
    800027d6:	1000                	addi	s0,sp,32
    800027d8:	84aa                	mv	s1,a0
    800027da:	892e                	mv	s2,a1
  struct proc *p = myproc();
    800027dc:	8f2ff0ef          	jal	800018ce <myproc>
  if(addr >= p->sz || addr+sizeof(uint64) > p->sz) // both tests needed, in case of overflow
    800027e0:	653c                	ld	a5,72(a0)
    800027e2:	02f4f663          	bgeu	s1,a5,8000280e <fetchaddr+0x42>
    800027e6:	00848713          	addi	a4,s1,8
    800027ea:	02e7e463          	bltu	a5,a4,80002812 <fetchaddr+0x46>
  if(copyin(p->pagetable, (char *)ip, addr, sizeof(*ip)) != 0)
    800027ee:	46a1                	li	a3,8
    800027f0:	8626                	mv	a2,s1
    800027f2:	85ca                	mv	a1,s2
    800027f4:	6d28                	ld	a0,88(a0)
    800027f6:	ed1fe0ef          	jal	800016c6 <copyin>
    800027fa:	00a03533          	snez	a0,a0
    800027fe:	40a00533          	neg	a0,a0
}
    80002802:	60e2                	ld	ra,24(sp)
    80002804:	6442                	ld	s0,16(sp)
    80002806:	64a2                	ld	s1,8(sp)
    80002808:	6902                	ld	s2,0(sp)
    8000280a:	6105                	addi	sp,sp,32
    8000280c:	8082                	ret
    return -1;
    8000280e:	557d                	li	a0,-1
    80002810:	bfcd                	j	80002802 <fetchaddr+0x36>
    80002812:	557d                	li	a0,-1
    80002814:	b7fd                	j	80002802 <fetchaddr+0x36>

0000000080002816 <fetchstr>:
{
    80002816:	7179                	addi	sp,sp,-48
    80002818:	f406                	sd	ra,40(sp)
    8000281a:	f022                	sd	s0,32(sp)
    8000281c:	ec26                	sd	s1,24(sp)
    8000281e:	e84a                	sd	s2,16(sp)
    80002820:	e44e                	sd	s3,8(sp)
    80002822:	1800                	addi	s0,sp,48
    80002824:	892a                	mv	s2,a0
    80002826:	84ae                	mv	s1,a1
    80002828:	89b2                	mv	s3,a2
  struct proc *p = myproc();
    8000282a:	8a4ff0ef          	jal	800018ce <myproc>
  if(copyinstr(p->pagetable, buf, addr, max) < 0)
    8000282e:	86ce                	mv	a3,s3
    80002830:	864a                	mv	a2,s2
    80002832:	85a6                	mv	a1,s1
    80002834:	6d28                	ld	a0,88(a0)
    80002836:	c53fe0ef          	jal	80001488 <copyinstr>
    8000283a:	00054c63          	bltz	a0,80002852 <fetchstr+0x3c>
  return strlen(buf);
    8000283e:	8526                	mv	a0,s1
    80002840:	dd2fe0ef          	jal	80000e12 <strlen>
}
    80002844:	70a2                	ld	ra,40(sp)
    80002846:	7402                	ld	s0,32(sp)
    80002848:	64e2                	ld	s1,24(sp)
    8000284a:	6942                	ld	s2,16(sp)
    8000284c:	69a2                	ld	s3,8(sp)
    8000284e:	6145                	addi	sp,sp,48
    80002850:	8082                	ret
    return -1;
    80002852:	557d                	li	a0,-1
    80002854:	bfc5                	j	80002844 <fetchstr+0x2e>

0000000080002856 <argint>:

// Fetch the nth 32-bit system call argument.
void
argint(int n, int *ip)
{
    80002856:	1101                	addi	sp,sp,-32
    80002858:	ec06                	sd	ra,24(sp)
    8000285a:	e822                	sd	s0,16(sp)
    8000285c:	e426                	sd	s1,8(sp)
    8000285e:	1000                	addi	s0,sp,32
    80002860:	84ae                	mv	s1,a1
  *ip = argraw(n);
    80002862:	f0bff0ef          	jal	8000276c <argraw>
    80002866:	c088                	sw	a0,0(s1)
}
    80002868:	60e2                	ld	ra,24(sp)
    8000286a:	6442                	ld	s0,16(sp)
    8000286c:	64a2                	ld	s1,8(sp)
    8000286e:	6105                	addi	sp,sp,32
    80002870:	8082                	ret

0000000080002872 <argaddr>:
// Retrieve an argument as a pointer.
// Doesn't check for legality, since
// copyin/copyout will do that.
void
argaddr(int n, uint64 *ip)
{
    80002872:	1101                	addi	sp,sp,-32
    80002874:	ec06                	sd	ra,24(sp)
    80002876:	e822                	sd	s0,16(sp)
    80002878:	e426                	sd	s1,8(sp)
    8000287a:	1000                	addi	s0,sp,32
    8000287c:	84ae                	mv	s1,a1
  *ip = argraw(n);
    8000287e:	eefff0ef          	jal	8000276c <argraw>
    80002882:	e088                	sd	a0,0(s1)
}
    80002884:	60e2                	ld	ra,24(sp)
    80002886:	6442                	ld	s0,16(sp)
    80002888:	64a2                	ld	s1,8(sp)
    8000288a:	6105                	addi	sp,sp,32
    8000288c:	8082                	ret

000000008000288e <argstr>:
// Fetch the nth word-sized system call argument as a null-terminated string.
// Copies into buf, at most max.
// Returns string length if OK (including nul), -1 if error.
int
argstr(int n, char *buf, int max)
{
    8000288e:	7179                	addi	sp,sp,-48
    80002890:	f406                	sd	ra,40(sp)
    80002892:	f022                	sd	s0,32(sp)
    80002894:	ec26                	sd	s1,24(sp)
    80002896:	e84a                	sd	s2,16(sp)
    80002898:	1800                	addi	s0,sp,48
    8000289a:	84ae                	mv	s1,a1
    8000289c:	8932                	mv	s2,a2
  uint64 addr;
  argaddr(n, &addr);
    8000289e:	fd840593          	addi	a1,s0,-40
    800028a2:	fd1ff0ef          	jal	80002872 <argaddr>
  return fetchstr(addr, buf, max);
    800028a6:	864a                	mv	a2,s2
    800028a8:	85a6                	mv	a1,s1
    800028aa:	fd843503          	ld	a0,-40(s0)
    800028ae:	f69ff0ef          	jal	80002816 <fetchstr>
}
    800028b2:	70a2                	ld	ra,40(sp)
    800028b4:	7402                	ld	s0,32(sp)
    800028b6:	64e2                	ld	s1,24(sp)
    800028b8:	6942                	ld	s2,16(sp)
    800028ba:	6145                	addi	sp,sp,48
    800028bc:	8082                	ret

00000000800028be <syscall>:
[SYS_trace]   "trace",
};

void
syscall(void)
{
    800028be:	7179                	addi	sp,sp,-48
    800028c0:	f406                	sd	ra,40(sp)
    800028c2:	f022                	sd	s0,32(sp)
    800028c4:	ec26                	sd	s1,24(sp)
    800028c6:	e84a                	sd	s2,16(sp)
    800028c8:	e44e                	sd	s3,8(sp)
    800028ca:	1800                	addi	s0,sp,48
  int num;
  struct proc *p = myproc();
    800028cc:	802ff0ef          	jal	800018ce <myproc>
    800028d0:	84aa                	mv	s1,a0

  num = p->trapframe->a7;
    800028d2:	06053903          	ld	s2,96(a0)
    800028d6:	0a893783          	ld	a5,168(s2)
    800028da:	0007899b          	sext.w	s3,a5
  if(num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    800028de:	37fd                	addiw	a5,a5,-1
    800028e0:	4765                	li	a4,25
    800028e2:	04f76663          	bltu	a4,a5,8000292e <syscall+0x70>
    800028e6:	00399713          	slli	a4,s3,0x3
    800028ea:	00005797          	auipc	a5,0x5
    800028ee:	f8678793          	addi	a5,a5,-122 # 80007870 <syscalls>
    800028f2:	97ba                	add	a5,a5,a4
    800028f4:	639c                	ld	a5,0(a5)
    800028f6:	cf85                	beqz	a5,8000292e <syscall+0x70>
    // Use num to lookup the system call function for num, call it,
    // and store its return value in p->trapframe->a0
    p->trapframe->a0 = syscalls[num]();
    800028f8:	9782                	jalr	a5
    800028fa:	06a93823          	sd	a0,112(s2)
    if((p->trace_mask & (1 << num)) && syscall_names[num]) {
    800028fe:	1704a783          	lw	a5,368(s1)
    80002902:	4137d7bb          	sraw	a5,a5,s3
    80002906:	8b85                	andi	a5,a5,1
    80002908:	c3a1                	beqz	a5,80002948 <syscall+0x8a>
    8000290a:	098e                	slli	s3,s3,0x3
    8000290c:	00005797          	auipc	a5,0x5
    80002910:	f6478793          	addi	a5,a5,-156 # 80007870 <syscalls>
    80002914:	97ce                	add	a5,a5,s3
    80002916:	6ff0                	ld	a2,216(a5)
    80002918:	ca05                	beqz	a2,80002948 <syscall+0x8a>
      printf("%d: syscall %s -> %d\n", p->pid, syscall_names[num],
             (int)p->trapframe->a0);
    8000291a:	70bc                	ld	a5,96(s1)
      printf("%d: syscall %s -> %d\n", p->pid, syscall_names[num],
    8000291c:	5bb4                	lw	a3,112(a5)
    8000291e:	588c                	lw	a1,48(s1)
    80002920:	00005517          	auipc	a0,0x5
    80002924:	aa050513          	addi	a0,a0,-1376 # 800073c0 <etext+0x3c0>
    80002928:	bd3fd0ef          	jal	800004fa <printf>
    8000292c:	a831                	j	80002948 <syscall+0x8a>
    }
  } else {
    printf("%d %s: unknown sys call %d\n",
    8000292e:	86ce                	mv	a3,s3
    80002930:	16048613          	addi	a2,s1,352
    80002934:	588c                	lw	a1,48(s1)
    80002936:	00005517          	auipc	a0,0x5
    8000293a:	aa250513          	addi	a0,a0,-1374 # 800073d8 <etext+0x3d8>
    8000293e:	bbdfd0ef          	jal	800004fa <printf>
            p->pid, p->name, num);
    p->trapframe->a0 = -1;
    80002942:	70bc                	ld	a5,96(s1)
    80002944:	577d                	li	a4,-1
    80002946:	fbb8                	sd	a4,112(a5)
  }
}
    80002948:	70a2                	ld	ra,40(sp)
    8000294a:	7402                	ld	s0,32(sp)
    8000294c:	64e2                	ld	s1,24(sp)
    8000294e:	6942                	ld	s2,16(sp)
    80002950:	69a2                	ld	s3,8(sp)
    80002952:	6145                	addi	sp,sp,48
    80002954:	8082                	ret

0000000080002956 <sys_exit>:
#include "memstat.h" //
extern struct proc proc[NPROC];

uint64
sys_exit(void)
{
    80002956:	1101                	addi	sp,sp,-32
    80002958:	ec06                	sd	ra,24(sp)
    8000295a:	e822                	sd	s0,16(sp)
    8000295c:	1000                	addi	s0,sp,32
  int n;
  argint(0, &n);
    8000295e:	fec40593          	addi	a1,s0,-20
    80002962:	4501                	li	a0,0
    80002964:	ef3ff0ef          	jal	80002856 <argint>
  kexit(n);
    80002968:	fec42503          	lw	a0,-20(s0)
    8000296c:	ef2ff0ef          	jal	8000205e <kexit>
  return 0;  // not reached
}
    80002970:	4501                	li	a0,0
    80002972:	60e2                	ld	ra,24(sp)
    80002974:	6442                	ld	s0,16(sp)
    80002976:	6105                	addi	sp,sp,32
    80002978:	8082                	ret

000000008000297a <sys_getpid>:

uint64
sys_getpid(void)
{
    8000297a:	1141                	addi	sp,sp,-16
    8000297c:	e406                	sd	ra,8(sp)
    8000297e:	e022                	sd	s0,0(sp)
    80002980:	0800                	addi	s0,sp,16
  return myproc()->pid;
    80002982:	f4dfe0ef          	jal	800018ce <myproc>
}
    80002986:	5908                	lw	a0,48(a0)
    80002988:	60a2                	ld	ra,8(sp)
    8000298a:	6402                	ld	s0,0(sp)
    8000298c:	0141                	addi	sp,sp,16
    8000298e:	8082                	ret

0000000080002990 <sys_fork>:

uint64
sys_fork(void)
{
    80002990:	1141                	addi	sp,sp,-16
    80002992:	e406                	sd	ra,8(sp)
    80002994:	e022                	sd	s0,0(sp)
    80002996:	0800                	addi	s0,sp,16
  return kfork();
    80002998:	accff0ef          	jal	80001c64 <kfork>
}
    8000299c:	60a2                	ld	ra,8(sp)
    8000299e:	6402                	ld	s0,0(sp)
    800029a0:	0141                	addi	sp,sp,16
    800029a2:	8082                	ret

00000000800029a4 <sys_wait>:

uint64
sys_wait(void)
{
    800029a4:	1101                	addi	sp,sp,-32
    800029a6:	ec06                	sd	ra,24(sp)
    800029a8:	e822                	sd	s0,16(sp)
    800029aa:	1000                	addi	s0,sp,32
  uint64 p;
  argaddr(0, &p);
    800029ac:	fe840593          	addi	a1,s0,-24
    800029b0:	4501                	li	a0,0
    800029b2:	ec1ff0ef          	jal	80002872 <argaddr>
  return kwait(p);
    800029b6:	fe843503          	ld	a0,-24(s0)
    800029ba:	ffaff0ef          	jal	800021b4 <kwait>
}
    800029be:	60e2                	ld	ra,24(sp)
    800029c0:	6442                	ld	s0,16(sp)
    800029c2:	6105                	addi	sp,sp,32
    800029c4:	8082                	ret

00000000800029c6 <sys_sbrk>:

uint64
sys_sbrk(void)
{
    800029c6:	7179                	addi	sp,sp,-48
    800029c8:	f406                	sd	ra,40(sp)
    800029ca:	f022                	sd	s0,32(sp)
    800029cc:	ec26                	sd	s1,24(sp)
    800029ce:	1800                	addi	s0,sp,48
  uint64 addr;
  int t;
  int n;

  argint(0, &n);
    800029d0:	fd840593          	addi	a1,s0,-40
    800029d4:	4501                	li	a0,0
    800029d6:	e81ff0ef          	jal	80002856 <argint>
  argint(1, &t);
    800029da:	fdc40593          	addi	a1,s0,-36
    800029de:	4505                	li	a0,1
    800029e0:	e77ff0ef          	jal	80002856 <argint>
  addr = myproc()->sz;
    800029e4:	eebfe0ef          	jal	800018ce <myproc>
    800029e8:	6524                	ld	s1,72(a0)

  if(t == SBRK_EAGER || n < 0) {
    800029ea:	fdc42703          	lw	a4,-36(s0)
    800029ee:	4785                	li	a5,1
    800029f0:	02f70763          	beq	a4,a5,80002a1e <sys_sbrk+0x58>
    800029f4:	fd842783          	lw	a5,-40(s0)
    800029f8:	0207c363          	bltz	a5,80002a1e <sys_sbrk+0x58>
    }
  } else {
    // Lazily allocate memory for this process: increase its memory
    // size but don't allocate memory. If the processes uses the
    // memory, vmfault() will allocate it.
    if(addr + n < addr)
    800029fc:	97a6                	add	a5,a5,s1
    800029fe:	0297ee63          	bltu	a5,s1,80002a3a <sys_sbrk+0x74>
      return -1;
    if(addr + n > TRAPFRAME)
    80002a02:	02000737          	lui	a4,0x2000
    80002a06:	177d                	addi	a4,a4,-1 # 1ffffff <_entry-0x7e000001>
    80002a08:	0736                	slli	a4,a4,0xd
    80002a0a:	02f76a63          	bltu	a4,a5,80002a3e <sys_sbrk+0x78>
      return -1;
    myproc()->sz += n;
    80002a0e:	ec1fe0ef          	jal	800018ce <myproc>
    80002a12:	fd842703          	lw	a4,-40(s0)
    80002a16:	653c                	ld	a5,72(a0)
    80002a18:	97ba                	add	a5,a5,a4
    80002a1a:	e53c                	sd	a5,72(a0)
    80002a1c:	a039                	j	80002a2a <sys_sbrk+0x64>
    if(growproc(n) < 0) {
    80002a1e:	fd842503          	lw	a0,-40(s0)
    80002a22:	9c4ff0ef          	jal	80001be6 <growproc>
    80002a26:	00054863          	bltz	a0,80002a36 <sys_sbrk+0x70>
  }
  return addr;
}
    80002a2a:	8526                	mv	a0,s1
    80002a2c:	70a2                	ld	ra,40(sp)
    80002a2e:	7402                	ld	s0,32(sp)
    80002a30:	64e2                	ld	s1,24(sp)
    80002a32:	6145                	addi	sp,sp,48
    80002a34:	8082                	ret
      return -1;
    80002a36:	54fd                	li	s1,-1
    80002a38:	bfcd                	j	80002a2a <sys_sbrk+0x64>
      return -1;
    80002a3a:	54fd                	li	s1,-1
    80002a3c:	b7fd                	j	80002a2a <sys_sbrk+0x64>
      return -1;
    80002a3e:	54fd                	li	s1,-1
    80002a40:	b7ed                	j	80002a2a <sys_sbrk+0x64>

0000000080002a42 <sys_pause>:

uint64
sys_pause(void)
{
    80002a42:	7139                	addi	sp,sp,-64
    80002a44:	fc06                	sd	ra,56(sp)
    80002a46:	f822                	sd	s0,48(sp)
    80002a48:	f04a                	sd	s2,32(sp)
    80002a4a:	0080                	addi	s0,sp,64
  int n;
  uint ticks0;

  argint(0, &n);
    80002a4c:	fcc40593          	addi	a1,s0,-52
    80002a50:	4501                	li	a0,0
    80002a52:	e05ff0ef          	jal	80002856 <argint>
  if(n < 0)
    80002a56:	fcc42783          	lw	a5,-52(s0)
    80002a5a:	0607c763          	bltz	a5,80002ac8 <sys_pause+0x86>
    n = 0;
  acquire(&tickslock);
    80002a5e:	00016517          	auipc	a0,0x16
    80002a62:	d9a50513          	addi	a0,a0,-614 # 800187f8 <tickslock>
    80002a66:	968fe0ef          	jal	80000bce <acquire>
  ticks0 = ticks;
    80002a6a:	00008917          	auipc	s2,0x8
    80002a6e:	a5e92903          	lw	s2,-1442(s2) # 8000a4c8 <ticks>
  while(ticks - ticks0 < n){
    80002a72:	fcc42783          	lw	a5,-52(s0)
    80002a76:	cf8d                	beqz	a5,80002ab0 <sys_pause+0x6e>
    80002a78:	f426                	sd	s1,40(sp)
    80002a7a:	ec4e                	sd	s3,24(sp)
    if(killed(myproc())){
      release(&tickslock);
      return -1;
    }
    sleep(&ticks, &tickslock);
    80002a7c:	00016997          	auipc	s3,0x16
    80002a80:	d7c98993          	addi	s3,s3,-644 # 800187f8 <tickslock>
    80002a84:	00008497          	auipc	s1,0x8
    80002a88:	a4448493          	addi	s1,s1,-1468 # 8000a4c8 <ticks>
    if(killed(myproc())){
    80002a8c:	e43fe0ef          	jal	800018ce <myproc>
    80002a90:	efaff0ef          	jal	8000218a <killed>
    80002a94:	ed0d                	bnez	a0,80002ace <sys_pause+0x8c>
    sleep(&ticks, &tickslock);
    80002a96:	85ce                	mv	a1,s3
    80002a98:	8526                	mv	a0,s1
    80002a9a:	cb8ff0ef          	jal	80001f52 <sleep>
  while(ticks - ticks0 < n){
    80002a9e:	409c                	lw	a5,0(s1)
    80002aa0:	412787bb          	subw	a5,a5,s2
    80002aa4:	fcc42703          	lw	a4,-52(s0)
    80002aa8:	fee7e2e3          	bltu	a5,a4,80002a8c <sys_pause+0x4a>
    80002aac:	74a2                	ld	s1,40(sp)
    80002aae:	69e2                	ld	s3,24(sp)
  }
  release(&tickslock);
    80002ab0:	00016517          	auipc	a0,0x16
    80002ab4:	d4850513          	addi	a0,a0,-696 # 800187f8 <tickslock>
    80002ab8:	9aefe0ef          	jal	80000c66 <release>
  return 0;
    80002abc:	4501                	li	a0,0
}
    80002abe:	70e2                	ld	ra,56(sp)
    80002ac0:	7442                	ld	s0,48(sp)
    80002ac2:	7902                	ld	s2,32(sp)
    80002ac4:	6121                	addi	sp,sp,64
    80002ac6:	8082                	ret
    n = 0;
    80002ac8:	fc042623          	sw	zero,-52(s0)
    80002acc:	bf49                	j	80002a5e <sys_pause+0x1c>
      release(&tickslock);
    80002ace:	00016517          	auipc	a0,0x16
    80002ad2:	d2a50513          	addi	a0,a0,-726 # 800187f8 <tickslock>
    80002ad6:	990fe0ef          	jal	80000c66 <release>
      return -1;
    80002ada:	557d                	li	a0,-1
    80002adc:	74a2                	ld	s1,40(sp)
    80002ade:	69e2                	ld	s3,24(sp)
    80002ae0:	bff9                	j	80002abe <sys_pause+0x7c>

0000000080002ae2 <sys_kill>:

uint64
sys_kill(void)
{
    80002ae2:	1101                	addi	sp,sp,-32
    80002ae4:	ec06                	sd	ra,24(sp)
    80002ae6:	e822                	sd	s0,16(sp)
    80002ae8:	1000                	addi	s0,sp,32
  int pid;

  argint(0, &pid);
    80002aea:	fec40593          	addi	a1,s0,-20
    80002aee:	4501                	li	a0,0
    80002af0:	d67ff0ef          	jal	80002856 <argint>
  return kkill(pid);
    80002af4:	fec42503          	lw	a0,-20(s0)
    80002af8:	e08ff0ef          	jal	80002100 <kkill>
}
    80002afc:	60e2                	ld	ra,24(sp)
    80002afe:	6442                	ld	s0,16(sp)
    80002b00:	6105                	addi	sp,sp,32
    80002b02:	8082                	ret

0000000080002b04 <sys_uptime>:

// return how many clock tick interrupts have occurred
// since start.
uint64
sys_uptime(void)
{
    80002b04:	1101                	addi	sp,sp,-32
    80002b06:	ec06                	sd	ra,24(sp)
    80002b08:	e822                	sd	s0,16(sp)
    80002b0a:	e426                	sd	s1,8(sp)
    80002b0c:	1000                	addi	s0,sp,32
  uint xticks;

  acquire(&tickslock);
    80002b0e:	00016517          	auipc	a0,0x16
    80002b12:	cea50513          	addi	a0,a0,-790 # 800187f8 <tickslock>
    80002b16:	8b8fe0ef          	jal	80000bce <acquire>
  xticks = ticks;
    80002b1a:	00008497          	auipc	s1,0x8
    80002b1e:	9ae4a483          	lw	s1,-1618(s1) # 8000a4c8 <ticks>
  release(&tickslock);
    80002b22:	00016517          	auipc	a0,0x16
    80002b26:	cd650513          	addi	a0,a0,-810 # 800187f8 <tickslock>
    80002b2a:	93cfe0ef          	jal	80000c66 <release>
  return xticks;
}
    80002b2e:	02049513          	slli	a0,s1,0x20
    80002b32:	9101                	srli	a0,a0,0x20
    80002b34:	60e2                	ld	ra,24(sp)
    80002b36:	6442                	ld	s0,16(sp)
    80002b38:	64a2                	ld	s1,8(sp)
    80002b3a:	6105                	addi	sp,sp,32
    80002b3c:	8082                	ret

0000000080002b3e <sys_trace>:

uint64
sys_trace(void)
{
    80002b3e:	1101                	addi	sp,sp,-32
    80002b40:	ec06                	sd	ra,24(sp)
    80002b42:	e822                	sd	s0,16(sp)
    80002b44:	1000                	addi	s0,sp,32
  int mask;

  argint(0, &mask);
    80002b46:	fec40593          	addi	a1,s0,-20
    80002b4a:	4501                	li	a0,0
    80002b4c:	d0bff0ef          	jal	80002856 <argint>
  myproc()->trace_mask = mask;
    80002b50:	d7ffe0ef          	jal	800018ce <myproc>
    80002b54:	fec42783          	lw	a5,-20(s0)
    80002b58:	16f52823          	sw	a5,368(a0)
  return 0;
}
    80002b5c:	4501                	li	a0,0
    80002b5e:	60e2                	ld	ra,24(sp)
    80002b60:	6442                	ld	s0,16(sp)
    80002b62:	6105                	addi	sp,sp,32
    80002b64:	8082                	ret

0000000080002b66 <sys_setpriority>:
uint64
sys_setpriority(void)
{
    80002b66:	7179                	addi	sp,sp,-48
    80002b68:	f406                	sd	ra,40(sp)
    80002b6a:	f022                	sd	s0,32(sp)
    80002b6c:	1800                	addi	s0,sp,48
  int pid;
  int priority;
  struct proc *p;

  argint(0, &pid);
    80002b6e:	fdc40593          	addi	a1,s0,-36
    80002b72:	4501                	li	a0,0
    80002b74:	ce3ff0ef          	jal	80002856 <argint>
  argint(1, &priority);
    80002b78:	fd840593          	addi	a1,s0,-40
    80002b7c:	4505                	li	a0,1
    80002b7e:	cd9ff0ef          	jal	80002856 <argint>

  if(priority < 0 || priority > 20)
    80002b82:	fd842703          	lw	a4,-40(s0)
    80002b86:	47d1                	li	a5,20
    return -1;
    80002b88:	557d                	li	a0,-1
  if(priority < 0 || priority > 20)
    80002b8a:	04e7e863          	bltu	a5,a4,80002bda <sys_setpriority+0x74>
    80002b8e:	ec26                	sd	s1,24(sp)
    80002b90:	e84a                	sd	s2,16(sp)

  for(p = proc; p < &proc[NPROC]; p++){
    80002b92:	00010497          	auipc	s1,0x10
    80002b96:	e6648493          	addi	s1,s1,-410 # 800129f8 <proc>
    80002b9a:	00016917          	auipc	s2,0x16
    80002b9e:	c5e90913          	addi	s2,s2,-930 # 800187f8 <tickslock>
    80002ba2:	a801                	j	80002bb2 <sys_setpriority+0x4c>
      p->priority = priority;
      release(&p->lock);
      return 0;
    }

    release(&p->lock);
    80002ba4:	8526                	mv	a0,s1
    80002ba6:	8c0fe0ef          	jal	80000c66 <release>
  for(p = proc; p < &proc[NPROC]; p++){
    80002baa:	17848493          	addi	s1,s1,376
    80002bae:	03248a63          	beq	s1,s2,80002be2 <sys_setpriority+0x7c>
    acquire(&p->lock);
    80002bb2:	8526                	mv	a0,s1
    80002bb4:	81afe0ef          	jal	80000bce <acquire>
    if(p->state != UNUSED && p->pid == pid){
    80002bb8:	4c9c                	lw	a5,24(s1)
    80002bba:	d7ed                	beqz	a5,80002ba4 <sys_setpriority+0x3e>
    80002bbc:	5898                	lw	a4,48(s1)
    80002bbe:	fdc42783          	lw	a5,-36(s0)
    80002bc2:	fef711e3          	bne	a4,a5,80002ba4 <sys_setpriority+0x3e>
      p->priority = priority;
    80002bc6:	fd842783          	lw	a5,-40(s0)
    80002bca:	16f4aa23          	sw	a5,372(s1)
      release(&p->lock);
    80002bce:	8526                	mv	a0,s1
    80002bd0:	896fe0ef          	jal	80000c66 <release>
      return 0;
    80002bd4:	4501                	li	a0,0
    80002bd6:	64e2                	ld	s1,24(sp)
    80002bd8:	6942                	ld	s2,16(sp)
  }

  return -1;
}
    80002bda:	70a2                	ld	ra,40(sp)
    80002bdc:	7402                	ld	s0,32(sp)
    80002bde:	6145                	addi	sp,sp,48
    80002be0:	8082                	ret
  return -1;
    80002be2:	557d                	li	a0,-1
    80002be4:	64e2                	ld	s1,24(sp)
    80002be6:	6942                	ld	s2,16(sp)
    80002be8:	bfcd                	j	80002bda <sys_setpriority+0x74>

0000000080002bea <sys_getpriority>:

uint64
sys_getpriority(void)
{
    80002bea:	7179                	addi	sp,sp,-48
    80002bec:	f406                	sd	ra,40(sp)
    80002bee:	f022                	sd	s0,32(sp)
    80002bf0:	ec26                	sd	s1,24(sp)
    80002bf2:	e84a                	sd	s2,16(sp)
    80002bf4:	1800                	addi	s0,sp,48
  int pid;
  struct proc *p;
  int priority;

  argint(0, &pid);
    80002bf6:	fdc40593          	addi	a1,s0,-36
    80002bfa:	4501                	li	a0,0
    80002bfc:	c5bff0ef          	jal	80002856 <argint>

  for(p = proc; p < &proc[NPROC]; p++){
    80002c00:	00010497          	auipc	s1,0x10
    80002c04:	df848493          	addi	s1,s1,-520 # 800129f8 <proc>
    80002c08:	00016917          	auipc	s2,0x16
    80002c0c:	bf090913          	addi	s2,s2,-1040 # 800187f8 <tickslock>
    80002c10:	a801                	j	80002c20 <sys_getpriority+0x36>
      priority = p->priority;
      release(&p->lock);
      return priority;
    }

    release(&p->lock);
    80002c12:	8526                	mv	a0,s1
    80002c14:	852fe0ef          	jal	80000c66 <release>
  for(p = proc; p < &proc[NPROC]; p++){
    80002c18:	17848493          	addi	s1,s1,376
    80002c1c:	03248863          	beq	s1,s2,80002c4c <sys_getpriority+0x62>
    acquire(&p->lock);
    80002c20:	8526                	mv	a0,s1
    80002c22:	fadfd0ef          	jal	80000bce <acquire>
    if(p->state != UNUSED && p->pid == pid){
    80002c26:	4c9c                	lw	a5,24(s1)
    80002c28:	d7ed                	beqz	a5,80002c12 <sys_getpriority+0x28>
    80002c2a:	5898                	lw	a4,48(s1)
    80002c2c:	fdc42783          	lw	a5,-36(s0)
    80002c30:	fef711e3          	bne	a4,a5,80002c12 <sys_getpriority+0x28>
      priority = p->priority;
    80002c34:	1744a903          	lw	s2,372(s1)
      release(&p->lock);
    80002c38:	8526                	mv	a0,s1
    80002c3a:	82cfe0ef          	jal	80000c66 <release>
      return priority;
    80002c3e:	854a                	mv	a0,s2
  }

  return -1;
}
    80002c40:	70a2                	ld	ra,40(sp)
    80002c42:	7402                	ld	s0,32(sp)
    80002c44:	64e2                	ld	s1,24(sp)
    80002c46:	6942                	ld	s2,16(sp)
    80002c48:	6145                	addi	sp,sp,48
    80002c4a:	8082                	ret
  return -1;
    80002c4c:	557d                	li	a0,-1
    80002c4e:	bfcd                	j	80002c40 <sys_getpriority+0x56>

0000000080002c50 <sys_getmemstat>:

// syscall 추가
uint64
sys_getmemstat(void)
{
    80002c50:	7159                	addi	sp,sp,-112
    80002c52:	f486                	sd	ra,104(sp)
    80002c54:	f0a2                	sd	s0,96(sp)
    80002c56:	e0d2                	sd	s4,64(sp)
    80002c58:	1880                	addi	s0,sp,112
  uint64 uaddr;
  int max;
  int count = 0;
  struct proc *p;
  struct proc *cur = myproc();
    80002c5a:	c75fe0ef          	jal	800018ce <myproc>
    80002c5e:	8a2a                	mv	s4,a0

  argaddr(0, &uaddr);
    80002c60:	fc840593          	addi	a1,s0,-56
    80002c64:	4501                	li	a0,0
    80002c66:	c0dff0ef          	jal	80002872 <argaddr>
  argint(1, &max);
    80002c6a:	fc440593          	addi	a1,s0,-60
    80002c6e:	4505                	li	a0,1
    80002c70:	be7ff0ef          	jal	80002856 <argint>

  if(max <= 0)
    80002c74:	fc442783          	lw	a5,-60(s0)
    80002c78:	0af05d63          	blez	a5,80002d32 <sys_getmemstat+0xe2>
    80002c7c:	eca6                	sd	s1,88(sp)
    80002c7e:	e8ca                	sd	s2,80(sp)
    80002c80:	e4ce                	sd	s3,72(sp)
    return -1;

  if(max > NPROC)
    80002c82:	04000713          	li	a4,64
    80002c86:	00f75663          	bge	a4,a5,80002c92 <sys_getmemstat+0x42>
    max = NPROC;
    80002c8a:	04000793          	li	a5,64
    80002c8e:	fcf42223          	sw	a5,-60(s0)
{
    80002c92:	00010497          	auipc	s1,0x10
    80002c96:	d6648493          	addi	s1,s1,-666 # 800129f8 <proc>
    80002c9a:	4901                	li	s2,0

  for(p = proc; p < &proc[NPROC] && count < max; p++){
    80002c9c:	00016997          	auipc	s3,0x16
    80002ca0:	b5c98993          	addi	s3,s3,-1188 # 800187f8 <tickslock>
    80002ca4:	a801                	j	80002cb4 <sys_getmemstat+0x64>
    struct memstat m;

    acquire(&p->lock);

    if(p->state == UNUSED){
      release(&p->lock);
    80002ca6:	8526                	mv	a0,s1
    80002ca8:	fbffd0ef          	jal	80000c66 <release>
  for(p = proc; p < &proc[NPROC] && count < max; p++){
    80002cac:	17848493          	addi	s1,s1,376
    80002cb0:	07348863          	beq	s1,s3,80002d20 <sys_getmemstat+0xd0>
    80002cb4:	fc442783          	lw	a5,-60(s0)
    80002cb8:	06f95463          	bge	s2,a5,80002d20 <sys_getmemstat+0xd0>
    acquire(&p->lock);
    80002cbc:	8526                	mv	a0,s1
    80002cbe:	f11fd0ef          	jal	80000bce <acquire>
    if(p->state == UNUSED){
    80002cc2:	4c9c                	lw	a5,24(s1)
    80002cc4:	d3ed                	beqz	a5,80002ca6 <sys_getmemstat+0x56>
      continue;
    }

    m.pid = p->pid;
    80002cc6:	5898                	lw	a4,48(s1)
    80002cc8:	f8e42c23          	sw	a4,-104(s0)
    m.state = p->state;
    80002ccc:	f8f42e23          	sw	a5,-100(s0)
    m.sz = p->sz;
    80002cd0:	64bc                	ld	a5,72(s1)
    80002cd2:	faf43023          	sd	a5,-96(s0)
    m.mem_quota = p->mem_quota;
    80002cd6:	68bc                	ld	a5,80(s1)
    80002cd8:	faf43423          	sd	a5,-88(s0)
    safestrcpy(m.name, p->name, sizeof(m.name));
    80002cdc:	4641                	li	a2,16
    80002cde:	16048593          	addi	a1,s1,352
    80002ce2:	fb040513          	addi	a0,s0,-80
    80002ce6:	8fafe0ef          	jal	80000de0 <safestrcpy>

    release(&p->lock);
    80002cea:	8526                	mv	a0,s1
    80002cec:	f7bfd0ef          	jal	80000c66 <release>

    if(copyout(cur->pagetable,
               uaddr + count * sizeof(struct memstat),
    80002cf0:	00291793          	slli	a5,s2,0x2
    80002cf4:	97ca                	add	a5,a5,s2
    80002cf6:	078e                	slli	a5,a5,0x3
    if(copyout(cur->pagetable,
    80002cf8:	02800693          	li	a3,40
    80002cfc:	f9840613          	addi	a2,s0,-104
    80002d00:	fc843583          	ld	a1,-56(s0)
    80002d04:	95be                	add	a1,a1,a5
    80002d06:	058a3503          	ld	a0,88(s4)
    80002d0a:	8d9fe0ef          	jal	800015e2 <copyout>
    80002d0e:	00054463          	bltz	a0,80002d16 <sys_getmemstat+0xc6>
               (char *)&m,
               sizeof(struct memstat)) < 0){
      return -1;
    }

    count++;
    80002d12:	2905                	addiw	s2,s2,1
    80002d14:	bf61                	j	80002cac <sys_getmemstat+0x5c>
      return -1;
    80002d16:	557d                	li	a0,-1
    80002d18:	64e6                	ld	s1,88(sp)
    80002d1a:	6946                	ld	s2,80(sp)
    80002d1c:	69a6                	ld	s3,72(sp)
    80002d1e:	a029                	j	80002d28 <sys_getmemstat+0xd8>
  }

  return count;
    80002d20:	854a                	mv	a0,s2
    80002d22:	64e6                	ld	s1,88(sp)
    80002d24:	6946                	ld	s2,80(sp)
    80002d26:	69a6                	ld	s3,72(sp)
}
    80002d28:	70a6                	ld	ra,104(sp)
    80002d2a:	7406                	ld	s0,96(sp)
    80002d2c:	6a06                	ld	s4,64(sp)
    80002d2e:	6165                	addi	sp,sp,112
    80002d30:	8082                	ret
    return -1;
    80002d32:	557d                	li	a0,-1
    80002d34:	bfd5                	j	80002d28 <sys_getmemstat+0xd8>

0000000080002d36 <sys_setmemquota>:

uint64
sys_setmemquota(void)
{
    80002d36:	7179                	addi	sp,sp,-48
    80002d38:	f406                	sd	ra,40(sp)
    80002d3a:	f022                	sd	s0,32(sp)
    80002d3c:	1800                	addi	s0,sp,48
  int pid;
  int quota;
  struct proc *p;

  argint(0, &pid);
    80002d3e:	fdc40593          	addi	a1,s0,-36
    80002d42:	4501                	li	a0,0
    80002d44:	b13ff0ef          	jal	80002856 <argint>
  argint(1, &quota);
    80002d48:	fd840593          	addi	a1,s0,-40
    80002d4c:	4505                	li	a0,1
    80002d4e:	b09ff0ef          	jal	80002856 <argint>

  if(pid <= 0)
    80002d52:	fdc42783          	lw	a5,-36(s0)
    80002d56:	0af05a63          	blez	a5,80002e0a <sys_setmemquota+0xd4>
    return -1;

  if(quota < 0)
    80002d5a:	fd842783          	lw	a5,-40(s0)
    80002d5e:	0a07c863          	bltz	a5,80002e0e <sys_setmemquota+0xd8>
    80002d62:	ec26                	sd	s1,24(sp)
    80002d64:	e84a                	sd	s2,16(sp)
    return -1;

  for(p = proc; p < &proc[NPROC]; p++){
    80002d66:	00010497          	auipc	s1,0x10
    80002d6a:	c9248493          	addi	s1,s1,-878 # 800129f8 <proc>
    80002d6e:	00016917          	auipc	s2,0x16
    80002d72:	a8a90913          	addi	s2,s2,-1398 # 800187f8 <tickslock>
    80002d76:	a035                	j	80002da2 <sys_setmemquota+0x6c>
    acquire(&p->lock);

    if(p->state != UNUSED && p->pid == pid){
      // 보호 프로세스에는 quota 설정 금지
      if(strncmp(p->name, "init", 16) == 0 || strncmp(p->name, "sh", 16) == 0){
        release(&p->lock);
    80002d78:	8526                	mv	a0,s1
    80002d7a:	eedfd0ef          	jal	80000c66 <release>
        return -1;
    80002d7e:	557d                	li	a0,-1
    80002d80:	64e2                	ld	s1,24(sp)
    80002d82:	6942                	ld	s2,16(sp)
    80002d84:	a89d                	j	80002dfa <sys_setmemquota+0xc4>
      }

      // 현재 사용량보다 작은 quota 설정 금지
      if(quota > 0 && (uint64)quota < p->sz){
        release(&p->lock);
    80002d86:	8526                	mv	a0,s1
    80002d88:	edffd0ef          	jal	80000c66 <release>
        return -1;
    80002d8c:	557d                	li	a0,-1
    80002d8e:	64e2                	ld	s1,24(sp)
    80002d90:	6942                	ld	s2,16(sp)
    80002d92:	a0a5                	j	80002dfa <sys_setmemquota+0xc4>
      p->mem_quota = (uint64)quota;
      release(&p->lock);
      return 0;
    }

    release(&p->lock);
    80002d94:	8526                	mv	a0,s1
    80002d96:	ed1fd0ef          	jal	80000c66 <release>
  for(p = proc; p < &proc[NPROC]; p++){
    80002d9a:	17848493          	addi	s1,s1,376
    80002d9e:	07248263          	beq	s1,s2,80002e02 <sys_setmemquota+0xcc>
    acquire(&p->lock);
    80002da2:	8526                	mv	a0,s1
    80002da4:	e2bfd0ef          	jal	80000bce <acquire>
    if(p->state != UNUSED && p->pid == pid){
    80002da8:	4c9c                	lw	a5,24(s1)
    80002daa:	d7ed                	beqz	a5,80002d94 <sys_setmemquota+0x5e>
    80002dac:	5898                	lw	a4,48(s1)
    80002dae:	fdc42783          	lw	a5,-36(s0)
    80002db2:	fef711e3          	bne	a4,a5,80002d94 <sys_setmemquota+0x5e>
      if(strncmp(p->name, "init", 16) == 0 || strncmp(p->name, "sh", 16) == 0){
    80002db6:	16048913          	addi	s2,s1,352
    80002dba:	4641                	li	a2,16
    80002dbc:	00004597          	auipc	a1,0x4
    80002dc0:	41c58593          	addi	a1,a1,1052 # 800071d8 <etext+0x1d8>
    80002dc4:	854a                	mv	a0,s2
    80002dc6:	fa9fd0ef          	jal	80000d6e <strncmp>
    80002dca:	d55d                	beqz	a0,80002d78 <sys_setmemquota+0x42>
    80002dcc:	4641                	li	a2,16
    80002dce:	00004597          	auipc	a1,0x4
    80002dd2:	41258593          	addi	a1,a1,1042 # 800071e0 <etext+0x1e0>
    80002dd6:	854a                	mv	a0,s2
    80002dd8:	f97fd0ef          	jal	80000d6e <strncmp>
    80002ddc:	dd51                	beqz	a0,80002d78 <sys_setmemquota+0x42>
      if(quota > 0 && (uint64)quota < p->sz){
    80002dde:	fd842783          	lw	a5,-40(s0)
    80002de2:	00f05563          	blez	a5,80002dec <sys_setmemquota+0xb6>
    80002de6:	64b8                	ld	a4,72(s1)
    80002de8:	f8e7efe3          	bltu	a5,a4,80002d86 <sys_setmemquota+0x50>
      p->mem_quota = (uint64)quota;
    80002dec:	e8bc                	sd	a5,80(s1)
      release(&p->lock);
    80002dee:	8526                	mv	a0,s1
    80002df0:	e77fd0ef          	jal	80000c66 <release>
      return 0;
    80002df4:	4501                	li	a0,0
    80002df6:	64e2                	ld	s1,24(sp)
    80002df8:	6942                	ld	s2,16(sp)
  }

  return -1;
    80002dfa:	70a2                	ld	ra,40(sp)
    80002dfc:	7402                	ld	s0,32(sp)
    80002dfe:	6145                	addi	sp,sp,48
    80002e00:	8082                	ret
  return -1;
    80002e02:	557d                	li	a0,-1
    80002e04:	64e2                	ld	s1,24(sp)
    80002e06:	6942                	ld	s2,16(sp)
    80002e08:	bfcd                	j	80002dfa <sys_setmemquota+0xc4>
    return -1;
    80002e0a:	557d                	li	a0,-1
    80002e0c:	b7fd                	j	80002dfa <sys_setmemquota+0xc4>
    return -1;
    80002e0e:	557d                	li	a0,-1
    80002e10:	b7ed                	j	80002dfa <sys_setmemquota+0xc4>

0000000080002e12 <binit>:
  struct buf head;
} bcache;

void
binit(void)
{
    80002e12:	7179                	addi	sp,sp,-48
    80002e14:	f406                	sd	ra,40(sp)
    80002e16:	f022                	sd	s0,32(sp)
    80002e18:	ec26                	sd	s1,24(sp)
    80002e1a:	e84a                	sd	s2,16(sp)
    80002e1c:	e44e                	sd	s3,8(sp)
    80002e1e:	e052                	sd	s4,0(sp)
    80002e20:	1800                	addi	s0,sp,48
  struct buf *b;

  initlock(&bcache.lock, "bcache");
    80002e22:	00004597          	auipc	a1,0x4
    80002e26:	67658593          	addi	a1,a1,1654 # 80007498 <etext+0x498>
    80002e2a:	00016517          	auipc	a0,0x16
    80002e2e:	9e650513          	addi	a0,a0,-1562 # 80018810 <bcache>
    80002e32:	d1dfd0ef          	jal	80000b4e <initlock>

  // Create linked list of buffers
  bcache.head.prev = &bcache.head;
    80002e36:	0001e797          	auipc	a5,0x1e
    80002e3a:	9da78793          	addi	a5,a5,-1574 # 80020810 <bcache+0x8000>
    80002e3e:	0001e717          	auipc	a4,0x1e
    80002e42:	c3a70713          	addi	a4,a4,-966 # 80020a78 <bcache+0x8268>
    80002e46:	2ae7b823          	sd	a4,688(a5)
  bcache.head.next = &bcache.head;
    80002e4a:	2ae7bc23          	sd	a4,696(a5)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    80002e4e:	00016497          	auipc	s1,0x16
    80002e52:	9da48493          	addi	s1,s1,-1574 # 80018828 <bcache+0x18>
    b->next = bcache.head.next;
    80002e56:	893e                	mv	s2,a5
    b->prev = &bcache.head;
    80002e58:	89ba                	mv	s3,a4
    initsleeplock(&b->lock, "buffer");
    80002e5a:	00004a17          	auipc	s4,0x4
    80002e5e:	646a0a13          	addi	s4,s4,1606 # 800074a0 <etext+0x4a0>
    b->next = bcache.head.next;
    80002e62:	2b893783          	ld	a5,696(s2)
    80002e66:	e8bc                	sd	a5,80(s1)
    b->prev = &bcache.head;
    80002e68:	0534b423          	sd	s3,72(s1)
    initsleeplock(&b->lock, "buffer");
    80002e6c:	85d2                	mv	a1,s4
    80002e6e:	01048513          	addi	a0,s1,16
    80002e72:	322010ef          	jal	80004194 <initsleeplock>
    bcache.head.next->prev = b;
    80002e76:	2b893783          	ld	a5,696(s2)
    80002e7a:	e7a4                	sd	s1,72(a5)
    bcache.head.next = b;
    80002e7c:	2a993c23          	sd	s1,696(s2)
  for(b = bcache.buf; b < bcache.buf+NBUF; b++){
    80002e80:	45848493          	addi	s1,s1,1112
    80002e84:	fd349fe3          	bne	s1,s3,80002e62 <binit+0x50>
  }
}
    80002e88:	70a2                	ld	ra,40(sp)
    80002e8a:	7402                	ld	s0,32(sp)
    80002e8c:	64e2                	ld	s1,24(sp)
    80002e8e:	6942                	ld	s2,16(sp)
    80002e90:	69a2                	ld	s3,8(sp)
    80002e92:	6a02                	ld	s4,0(sp)
    80002e94:	6145                	addi	sp,sp,48
    80002e96:	8082                	ret

0000000080002e98 <bread>:
}

// Return a locked buf with the contents of the indicated block.
struct buf*
bread(uint dev, uint blockno)
{
    80002e98:	7179                	addi	sp,sp,-48
    80002e9a:	f406                	sd	ra,40(sp)
    80002e9c:	f022                	sd	s0,32(sp)
    80002e9e:	ec26                	sd	s1,24(sp)
    80002ea0:	e84a                	sd	s2,16(sp)
    80002ea2:	e44e                	sd	s3,8(sp)
    80002ea4:	1800                	addi	s0,sp,48
    80002ea6:	892a                	mv	s2,a0
    80002ea8:	89ae                	mv	s3,a1
  acquire(&bcache.lock);
    80002eaa:	00016517          	auipc	a0,0x16
    80002eae:	96650513          	addi	a0,a0,-1690 # 80018810 <bcache>
    80002eb2:	d1dfd0ef          	jal	80000bce <acquire>
  for(b = bcache.head.next; b != &bcache.head; b = b->next){
    80002eb6:	0001e497          	auipc	s1,0x1e
    80002eba:	c124b483          	ld	s1,-1006(s1) # 80020ac8 <bcache+0x82b8>
    80002ebe:	0001e797          	auipc	a5,0x1e
    80002ec2:	bba78793          	addi	a5,a5,-1094 # 80020a78 <bcache+0x8268>
    80002ec6:	02f48b63          	beq	s1,a5,80002efc <bread+0x64>
    80002eca:	873e                	mv	a4,a5
    80002ecc:	a021                	j	80002ed4 <bread+0x3c>
    80002ece:	68a4                	ld	s1,80(s1)
    80002ed0:	02e48663          	beq	s1,a4,80002efc <bread+0x64>
    if(b->dev == dev && b->blockno == blockno){
    80002ed4:	449c                	lw	a5,8(s1)
    80002ed6:	ff279ce3          	bne	a5,s2,80002ece <bread+0x36>
    80002eda:	44dc                	lw	a5,12(s1)
    80002edc:	ff3799e3          	bne	a5,s3,80002ece <bread+0x36>
      b->refcnt++;
    80002ee0:	40bc                	lw	a5,64(s1)
    80002ee2:	2785                	addiw	a5,a5,1
    80002ee4:	c0bc                	sw	a5,64(s1)
      release(&bcache.lock);
    80002ee6:	00016517          	auipc	a0,0x16
    80002eea:	92a50513          	addi	a0,a0,-1750 # 80018810 <bcache>
    80002eee:	d79fd0ef          	jal	80000c66 <release>
      acquiresleep(&b->lock);
    80002ef2:	01048513          	addi	a0,s1,16
    80002ef6:	2d4010ef          	jal	800041ca <acquiresleep>
      return b;
    80002efa:	a889                	j	80002f4c <bread+0xb4>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    80002efc:	0001e497          	auipc	s1,0x1e
    80002f00:	bc44b483          	ld	s1,-1084(s1) # 80020ac0 <bcache+0x82b0>
    80002f04:	0001e797          	auipc	a5,0x1e
    80002f08:	b7478793          	addi	a5,a5,-1164 # 80020a78 <bcache+0x8268>
    80002f0c:	00f48863          	beq	s1,a5,80002f1c <bread+0x84>
    80002f10:	873e                	mv	a4,a5
    if(b->refcnt == 0) {
    80002f12:	40bc                	lw	a5,64(s1)
    80002f14:	cb91                	beqz	a5,80002f28 <bread+0x90>
  for(b = bcache.head.prev; b != &bcache.head; b = b->prev){
    80002f16:	64a4                	ld	s1,72(s1)
    80002f18:	fee49de3          	bne	s1,a4,80002f12 <bread+0x7a>
  panic("bget: no buffers");
    80002f1c:	00004517          	auipc	a0,0x4
    80002f20:	58c50513          	addi	a0,a0,1420 # 800074a8 <etext+0x4a8>
    80002f24:	8bdfd0ef          	jal	800007e0 <panic>
      b->dev = dev;
    80002f28:	0124a423          	sw	s2,8(s1)
      b->blockno = blockno;
    80002f2c:	0134a623          	sw	s3,12(s1)
      b->valid = 0;
    80002f30:	0004a023          	sw	zero,0(s1)
      b->refcnt = 1;
    80002f34:	4785                	li	a5,1
    80002f36:	c0bc                	sw	a5,64(s1)
      release(&bcache.lock);
    80002f38:	00016517          	auipc	a0,0x16
    80002f3c:	8d850513          	addi	a0,a0,-1832 # 80018810 <bcache>
    80002f40:	d27fd0ef          	jal	80000c66 <release>
      acquiresleep(&b->lock);
    80002f44:	01048513          	addi	a0,s1,16
    80002f48:	282010ef          	jal	800041ca <acquiresleep>
  struct buf *b;

  b = bget(dev, blockno);
  if(!b->valid) {
    80002f4c:	409c                	lw	a5,0(s1)
    80002f4e:	cb89                	beqz	a5,80002f60 <bread+0xc8>
    virtio_disk_rw(b, 0);
    b->valid = 1;
  }
  return b;
}
    80002f50:	8526                	mv	a0,s1
    80002f52:	70a2                	ld	ra,40(sp)
    80002f54:	7402                	ld	s0,32(sp)
    80002f56:	64e2                	ld	s1,24(sp)
    80002f58:	6942                	ld	s2,16(sp)
    80002f5a:	69a2                	ld	s3,8(sp)
    80002f5c:	6145                	addi	sp,sp,48
    80002f5e:	8082                	ret
    virtio_disk_rw(b, 0);
    80002f60:	4581                	li	a1,0
    80002f62:	8526                	mv	a0,s1
    80002f64:	2cd020ef          	jal	80005a30 <virtio_disk_rw>
    b->valid = 1;
    80002f68:	4785                	li	a5,1
    80002f6a:	c09c                	sw	a5,0(s1)
  return b;
    80002f6c:	b7d5                	j	80002f50 <bread+0xb8>

0000000080002f6e <bwrite>:

// Write b's contents to disk.  Must be locked.
void
bwrite(struct buf *b)
{
    80002f6e:	1101                	addi	sp,sp,-32
    80002f70:	ec06                	sd	ra,24(sp)
    80002f72:	e822                	sd	s0,16(sp)
    80002f74:	e426                	sd	s1,8(sp)
    80002f76:	1000                	addi	s0,sp,32
    80002f78:	84aa                	mv	s1,a0
  if(!holdingsleep(&b->lock))
    80002f7a:	0541                	addi	a0,a0,16
    80002f7c:	2cc010ef          	jal	80004248 <holdingsleep>
    80002f80:	c911                	beqz	a0,80002f94 <bwrite+0x26>
    panic("bwrite");
  virtio_disk_rw(b, 1);
    80002f82:	4585                	li	a1,1
    80002f84:	8526                	mv	a0,s1
    80002f86:	2ab020ef          	jal	80005a30 <virtio_disk_rw>
}
    80002f8a:	60e2                	ld	ra,24(sp)
    80002f8c:	6442                	ld	s0,16(sp)
    80002f8e:	64a2                	ld	s1,8(sp)
    80002f90:	6105                	addi	sp,sp,32
    80002f92:	8082                	ret
    panic("bwrite");
    80002f94:	00004517          	auipc	a0,0x4
    80002f98:	52c50513          	addi	a0,a0,1324 # 800074c0 <etext+0x4c0>
    80002f9c:	845fd0ef          	jal	800007e0 <panic>

0000000080002fa0 <brelse>:

// Release a locked buffer.
// Move to the head of the most-recently-used list.
void
brelse(struct buf *b)
{
    80002fa0:	1101                	addi	sp,sp,-32
    80002fa2:	ec06                	sd	ra,24(sp)
    80002fa4:	e822                	sd	s0,16(sp)
    80002fa6:	e426                	sd	s1,8(sp)
    80002fa8:	e04a                	sd	s2,0(sp)
    80002faa:	1000                	addi	s0,sp,32
    80002fac:	84aa                	mv	s1,a0
  if(!holdingsleep(&b->lock))
    80002fae:	01050913          	addi	s2,a0,16
    80002fb2:	854a                	mv	a0,s2
    80002fb4:	294010ef          	jal	80004248 <holdingsleep>
    80002fb8:	c135                	beqz	a0,8000301c <brelse+0x7c>
    panic("brelse");

  releasesleep(&b->lock);
    80002fba:	854a                	mv	a0,s2
    80002fbc:	254010ef          	jal	80004210 <releasesleep>

  acquire(&bcache.lock);
    80002fc0:	00016517          	auipc	a0,0x16
    80002fc4:	85050513          	addi	a0,a0,-1968 # 80018810 <bcache>
    80002fc8:	c07fd0ef          	jal	80000bce <acquire>
  b->refcnt--;
    80002fcc:	40bc                	lw	a5,64(s1)
    80002fce:	37fd                	addiw	a5,a5,-1
    80002fd0:	0007871b          	sext.w	a4,a5
    80002fd4:	c0bc                	sw	a5,64(s1)
  if (b->refcnt == 0) {
    80002fd6:	e71d                	bnez	a4,80003004 <brelse+0x64>
    // no one is waiting for it.
    b->next->prev = b->prev;
    80002fd8:	68b8                	ld	a4,80(s1)
    80002fda:	64bc                	ld	a5,72(s1)
    80002fdc:	e73c                	sd	a5,72(a4)
    b->prev->next = b->next;
    80002fde:	68b8                	ld	a4,80(s1)
    80002fe0:	ebb8                	sd	a4,80(a5)
    b->next = bcache.head.next;
    80002fe2:	0001e797          	auipc	a5,0x1e
    80002fe6:	82e78793          	addi	a5,a5,-2002 # 80020810 <bcache+0x8000>
    80002fea:	2b87b703          	ld	a4,696(a5)
    80002fee:	e8b8                	sd	a4,80(s1)
    b->prev = &bcache.head;
    80002ff0:	0001e717          	auipc	a4,0x1e
    80002ff4:	a8870713          	addi	a4,a4,-1400 # 80020a78 <bcache+0x8268>
    80002ff8:	e4b8                	sd	a4,72(s1)
    bcache.head.next->prev = b;
    80002ffa:	2b87b703          	ld	a4,696(a5)
    80002ffe:	e724                	sd	s1,72(a4)
    bcache.head.next = b;
    80003000:	2a97bc23          	sd	s1,696(a5)
  }
  
  release(&bcache.lock);
    80003004:	00016517          	auipc	a0,0x16
    80003008:	80c50513          	addi	a0,a0,-2036 # 80018810 <bcache>
    8000300c:	c5bfd0ef          	jal	80000c66 <release>
}
    80003010:	60e2                	ld	ra,24(sp)
    80003012:	6442                	ld	s0,16(sp)
    80003014:	64a2                	ld	s1,8(sp)
    80003016:	6902                	ld	s2,0(sp)
    80003018:	6105                	addi	sp,sp,32
    8000301a:	8082                	ret
    panic("brelse");
    8000301c:	00004517          	auipc	a0,0x4
    80003020:	4ac50513          	addi	a0,a0,1196 # 800074c8 <etext+0x4c8>
    80003024:	fbcfd0ef          	jal	800007e0 <panic>

0000000080003028 <bpin>:

void
bpin(struct buf *b) {
    80003028:	1101                	addi	sp,sp,-32
    8000302a:	ec06                	sd	ra,24(sp)
    8000302c:	e822                	sd	s0,16(sp)
    8000302e:	e426                	sd	s1,8(sp)
    80003030:	1000                	addi	s0,sp,32
    80003032:	84aa                	mv	s1,a0
  acquire(&bcache.lock);
    80003034:	00015517          	auipc	a0,0x15
    80003038:	7dc50513          	addi	a0,a0,2012 # 80018810 <bcache>
    8000303c:	b93fd0ef          	jal	80000bce <acquire>
  b->refcnt++;
    80003040:	40bc                	lw	a5,64(s1)
    80003042:	2785                	addiw	a5,a5,1
    80003044:	c0bc                	sw	a5,64(s1)
  release(&bcache.lock);
    80003046:	00015517          	auipc	a0,0x15
    8000304a:	7ca50513          	addi	a0,a0,1994 # 80018810 <bcache>
    8000304e:	c19fd0ef          	jal	80000c66 <release>
}
    80003052:	60e2                	ld	ra,24(sp)
    80003054:	6442                	ld	s0,16(sp)
    80003056:	64a2                	ld	s1,8(sp)
    80003058:	6105                	addi	sp,sp,32
    8000305a:	8082                	ret

000000008000305c <bunpin>:

void
bunpin(struct buf *b) {
    8000305c:	1101                	addi	sp,sp,-32
    8000305e:	ec06                	sd	ra,24(sp)
    80003060:	e822                	sd	s0,16(sp)
    80003062:	e426                	sd	s1,8(sp)
    80003064:	1000                	addi	s0,sp,32
    80003066:	84aa                	mv	s1,a0
  acquire(&bcache.lock);
    80003068:	00015517          	auipc	a0,0x15
    8000306c:	7a850513          	addi	a0,a0,1960 # 80018810 <bcache>
    80003070:	b5ffd0ef          	jal	80000bce <acquire>
  b->refcnt--;
    80003074:	40bc                	lw	a5,64(s1)
    80003076:	37fd                	addiw	a5,a5,-1
    80003078:	c0bc                	sw	a5,64(s1)
  release(&bcache.lock);
    8000307a:	00015517          	auipc	a0,0x15
    8000307e:	79650513          	addi	a0,a0,1942 # 80018810 <bcache>
    80003082:	be5fd0ef          	jal	80000c66 <release>
}
    80003086:	60e2                	ld	ra,24(sp)
    80003088:	6442                	ld	s0,16(sp)
    8000308a:	64a2                	ld	s1,8(sp)
    8000308c:	6105                	addi	sp,sp,32
    8000308e:	8082                	ret

0000000080003090 <bfree>:
}

// Free a disk block.
static void
bfree(int dev, uint b)
{
    80003090:	1101                	addi	sp,sp,-32
    80003092:	ec06                	sd	ra,24(sp)
    80003094:	e822                	sd	s0,16(sp)
    80003096:	e426                	sd	s1,8(sp)
    80003098:	e04a                	sd	s2,0(sp)
    8000309a:	1000                	addi	s0,sp,32
    8000309c:	84ae                	mv	s1,a1
  struct buf *bp;
  int bi, m;

  bp = bread(dev, BBLOCK(b, sb));
    8000309e:	00d5d59b          	srliw	a1,a1,0xd
    800030a2:	0001e797          	auipc	a5,0x1e
    800030a6:	e4a7a783          	lw	a5,-438(a5) # 80020eec <sb+0x1c>
    800030aa:	9dbd                	addw	a1,a1,a5
    800030ac:	dedff0ef          	jal	80002e98 <bread>
  bi = b % BPB;
  m = 1 << (bi % 8);
    800030b0:	0074f713          	andi	a4,s1,7
    800030b4:	4785                	li	a5,1
    800030b6:	00e797bb          	sllw	a5,a5,a4
  if((bp->data[bi/8] & m) == 0)
    800030ba:	14ce                	slli	s1,s1,0x33
    800030bc:	90d9                	srli	s1,s1,0x36
    800030be:	00950733          	add	a4,a0,s1
    800030c2:	05874703          	lbu	a4,88(a4)
    800030c6:	00e7f6b3          	and	a3,a5,a4
    800030ca:	c29d                	beqz	a3,800030f0 <bfree+0x60>
    800030cc:	892a                	mv	s2,a0
    panic("freeing free block");
  bp->data[bi/8] &= ~m;
    800030ce:	94aa                	add	s1,s1,a0
    800030d0:	fff7c793          	not	a5,a5
    800030d4:	8f7d                	and	a4,a4,a5
    800030d6:	04e48c23          	sb	a4,88(s1)
  log_write(bp);
    800030da:	7f9000ef          	jal	800040d2 <log_write>
  brelse(bp);
    800030de:	854a                	mv	a0,s2
    800030e0:	ec1ff0ef          	jal	80002fa0 <brelse>
}
    800030e4:	60e2                	ld	ra,24(sp)
    800030e6:	6442                	ld	s0,16(sp)
    800030e8:	64a2                	ld	s1,8(sp)
    800030ea:	6902                	ld	s2,0(sp)
    800030ec:	6105                	addi	sp,sp,32
    800030ee:	8082                	ret
    panic("freeing free block");
    800030f0:	00004517          	auipc	a0,0x4
    800030f4:	3e050513          	addi	a0,a0,992 # 800074d0 <etext+0x4d0>
    800030f8:	ee8fd0ef          	jal	800007e0 <panic>

00000000800030fc <balloc>:
{
    800030fc:	711d                	addi	sp,sp,-96
    800030fe:	ec86                	sd	ra,88(sp)
    80003100:	e8a2                	sd	s0,80(sp)
    80003102:	e4a6                	sd	s1,72(sp)
    80003104:	1080                	addi	s0,sp,96
  for(b = 0; b < sb.size; b += BPB){
    80003106:	0001e797          	auipc	a5,0x1e
    8000310a:	dce7a783          	lw	a5,-562(a5) # 80020ed4 <sb+0x4>
    8000310e:	0e078f63          	beqz	a5,8000320c <balloc+0x110>
    80003112:	e0ca                	sd	s2,64(sp)
    80003114:	fc4e                	sd	s3,56(sp)
    80003116:	f852                	sd	s4,48(sp)
    80003118:	f456                	sd	s5,40(sp)
    8000311a:	f05a                	sd	s6,32(sp)
    8000311c:	ec5e                	sd	s7,24(sp)
    8000311e:	e862                	sd	s8,16(sp)
    80003120:	e466                	sd	s9,8(sp)
    80003122:	8baa                	mv	s7,a0
    80003124:	4a81                	li	s5,0
    bp = bread(dev, BBLOCK(b, sb));
    80003126:	0001eb17          	auipc	s6,0x1e
    8000312a:	daab0b13          	addi	s6,s6,-598 # 80020ed0 <sb>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    8000312e:	4c01                	li	s8,0
      m = 1 << (bi % 8);
    80003130:	4985                	li	s3,1
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    80003132:	6a09                	lui	s4,0x2
  for(b = 0; b < sb.size; b += BPB){
    80003134:	6c89                	lui	s9,0x2
    80003136:	a0b5                	j	800031a2 <balloc+0xa6>
        bp->data[bi/8] |= m;  // Mark block in use.
    80003138:	97ca                	add	a5,a5,s2
    8000313a:	8e55                	or	a2,a2,a3
    8000313c:	04c78c23          	sb	a2,88(a5)
        log_write(bp);
    80003140:	854a                	mv	a0,s2
    80003142:	791000ef          	jal	800040d2 <log_write>
        brelse(bp);
    80003146:	854a                	mv	a0,s2
    80003148:	e59ff0ef          	jal	80002fa0 <brelse>
  bp = bread(dev, bno);
    8000314c:	85a6                	mv	a1,s1
    8000314e:	855e                	mv	a0,s7
    80003150:	d49ff0ef          	jal	80002e98 <bread>
    80003154:	892a                	mv	s2,a0
  memset(bp->data, 0, BSIZE);
    80003156:	40000613          	li	a2,1024
    8000315a:	4581                	li	a1,0
    8000315c:	05850513          	addi	a0,a0,88
    80003160:	b43fd0ef          	jal	80000ca2 <memset>
  log_write(bp);
    80003164:	854a                	mv	a0,s2
    80003166:	76d000ef          	jal	800040d2 <log_write>
  brelse(bp);
    8000316a:	854a                	mv	a0,s2
    8000316c:	e35ff0ef          	jal	80002fa0 <brelse>
}
    80003170:	6906                	ld	s2,64(sp)
    80003172:	79e2                	ld	s3,56(sp)
    80003174:	7a42                	ld	s4,48(sp)
    80003176:	7aa2                	ld	s5,40(sp)
    80003178:	7b02                	ld	s6,32(sp)
    8000317a:	6be2                	ld	s7,24(sp)
    8000317c:	6c42                	ld	s8,16(sp)
    8000317e:	6ca2                	ld	s9,8(sp)
}
    80003180:	8526                	mv	a0,s1
    80003182:	60e6                	ld	ra,88(sp)
    80003184:	6446                	ld	s0,80(sp)
    80003186:	64a6                	ld	s1,72(sp)
    80003188:	6125                	addi	sp,sp,96
    8000318a:	8082                	ret
    brelse(bp);
    8000318c:	854a                	mv	a0,s2
    8000318e:	e13ff0ef          	jal	80002fa0 <brelse>
  for(b = 0; b < sb.size; b += BPB){
    80003192:	015c87bb          	addw	a5,s9,s5
    80003196:	00078a9b          	sext.w	s5,a5
    8000319a:	004b2703          	lw	a4,4(s6)
    8000319e:	04eaff63          	bgeu	s5,a4,800031fc <balloc+0x100>
    bp = bread(dev, BBLOCK(b, sb));
    800031a2:	41fad79b          	sraiw	a5,s5,0x1f
    800031a6:	0137d79b          	srliw	a5,a5,0x13
    800031aa:	015787bb          	addw	a5,a5,s5
    800031ae:	40d7d79b          	sraiw	a5,a5,0xd
    800031b2:	01cb2583          	lw	a1,28(s6)
    800031b6:	9dbd                	addw	a1,a1,a5
    800031b8:	855e                	mv	a0,s7
    800031ba:	cdfff0ef          	jal	80002e98 <bread>
    800031be:	892a                	mv	s2,a0
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800031c0:	004b2503          	lw	a0,4(s6)
    800031c4:	000a849b          	sext.w	s1,s5
    800031c8:	8762                	mv	a4,s8
    800031ca:	fca4f1e3          	bgeu	s1,a0,8000318c <balloc+0x90>
      m = 1 << (bi % 8);
    800031ce:	00777693          	andi	a3,a4,7
    800031d2:	00d996bb          	sllw	a3,s3,a3
      if((bp->data[bi/8] & m) == 0){  // Is block free?
    800031d6:	41f7579b          	sraiw	a5,a4,0x1f
    800031da:	01d7d79b          	srliw	a5,a5,0x1d
    800031de:	9fb9                	addw	a5,a5,a4
    800031e0:	4037d79b          	sraiw	a5,a5,0x3
    800031e4:	00f90633          	add	a2,s2,a5
    800031e8:	05864603          	lbu	a2,88(a2)
    800031ec:	00c6f5b3          	and	a1,a3,a2
    800031f0:	d5a1                	beqz	a1,80003138 <balloc+0x3c>
    for(bi = 0; bi < BPB && b + bi < sb.size; bi++){
    800031f2:	2705                	addiw	a4,a4,1
    800031f4:	2485                	addiw	s1,s1,1
    800031f6:	fd471ae3          	bne	a4,s4,800031ca <balloc+0xce>
    800031fa:	bf49                	j	8000318c <balloc+0x90>
    800031fc:	6906                	ld	s2,64(sp)
    800031fe:	79e2                	ld	s3,56(sp)
    80003200:	7a42                	ld	s4,48(sp)
    80003202:	7aa2                	ld	s5,40(sp)
    80003204:	7b02                	ld	s6,32(sp)
    80003206:	6be2                	ld	s7,24(sp)
    80003208:	6c42                	ld	s8,16(sp)
    8000320a:	6ca2                	ld	s9,8(sp)
  printf("balloc: out of blocks\n");
    8000320c:	00004517          	auipc	a0,0x4
    80003210:	2dc50513          	addi	a0,a0,732 # 800074e8 <etext+0x4e8>
    80003214:	ae6fd0ef          	jal	800004fa <printf>
  return 0;
    80003218:	4481                	li	s1,0
    8000321a:	b79d                	j	80003180 <balloc+0x84>

000000008000321c <bmap>:
// Return the disk block address of the nth block in inode ip.
// If there is no such block, bmap allocates one.
// returns 0 if out of disk space.
static uint
bmap(struct inode *ip, uint bn)
{
    8000321c:	7179                	addi	sp,sp,-48
    8000321e:	f406                	sd	ra,40(sp)
    80003220:	f022                	sd	s0,32(sp)
    80003222:	ec26                	sd	s1,24(sp)
    80003224:	e84a                	sd	s2,16(sp)
    80003226:	e44e                	sd	s3,8(sp)
    80003228:	1800                	addi	s0,sp,48
    8000322a:	89aa                	mv	s3,a0
  uint addr, *a;
  struct buf *bp;

  if(bn < NDIRECT){
    8000322c:	47ad                	li	a5,11
    8000322e:	02b7e663          	bltu	a5,a1,8000325a <bmap+0x3e>
    if((addr = ip->addrs[bn]) == 0){
    80003232:	02059793          	slli	a5,a1,0x20
    80003236:	01e7d593          	srli	a1,a5,0x1e
    8000323a:	00b504b3          	add	s1,a0,a1
    8000323e:	0504a903          	lw	s2,80(s1)
    80003242:	06091a63          	bnez	s2,800032b6 <bmap+0x9a>
      addr = balloc(ip->dev);
    80003246:	4108                	lw	a0,0(a0)
    80003248:	eb5ff0ef          	jal	800030fc <balloc>
    8000324c:	0005091b          	sext.w	s2,a0
      if(addr == 0)
    80003250:	06090363          	beqz	s2,800032b6 <bmap+0x9a>
        return 0;
      ip->addrs[bn] = addr;
    80003254:	0524a823          	sw	s2,80(s1)
    80003258:	a8b9                	j	800032b6 <bmap+0x9a>
    }
    return addr;
  }
  bn -= NDIRECT;
    8000325a:	ff45849b          	addiw	s1,a1,-12
    8000325e:	0004871b          	sext.w	a4,s1

  if(bn < NINDIRECT){
    80003262:	0ff00793          	li	a5,255
    80003266:	06e7ee63          	bltu	a5,a4,800032e2 <bmap+0xc6>
    // Load indirect block, allocating if necessary.
    if((addr = ip->addrs[NDIRECT]) == 0){
    8000326a:	08052903          	lw	s2,128(a0)
    8000326e:	00091d63          	bnez	s2,80003288 <bmap+0x6c>
      addr = balloc(ip->dev);
    80003272:	4108                	lw	a0,0(a0)
    80003274:	e89ff0ef          	jal	800030fc <balloc>
    80003278:	0005091b          	sext.w	s2,a0
      if(addr == 0)
    8000327c:	02090d63          	beqz	s2,800032b6 <bmap+0x9a>
    80003280:	e052                	sd	s4,0(sp)
        return 0;
      ip->addrs[NDIRECT] = addr;
    80003282:	0929a023          	sw	s2,128(s3)
    80003286:	a011                	j	8000328a <bmap+0x6e>
    80003288:	e052                	sd	s4,0(sp)
    }
    bp = bread(ip->dev, addr);
    8000328a:	85ca                	mv	a1,s2
    8000328c:	0009a503          	lw	a0,0(s3)
    80003290:	c09ff0ef          	jal	80002e98 <bread>
    80003294:	8a2a                	mv	s4,a0
    a = (uint*)bp->data;
    80003296:	05850793          	addi	a5,a0,88
    if((addr = a[bn]) == 0){
    8000329a:	02049713          	slli	a4,s1,0x20
    8000329e:	01e75593          	srli	a1,a4,0x1e
    800032a2:	00b784b3          	add	s1,a5,a1
    800032a6:	0004a903          	lw	s2,0(s1)
    800032aa:	00090e63          	beqz	s2,800032c6 <bmap+0xaa>
      if(addr){
        a[bn] = addr;
        log_write(bp);
      }
    }
    brelse(bp);
    800032ae:	8552                	mv	a0,s4
    800032b0:	cf1ff0ef          	jal	80002fa0 <brelse>
    return addr;
    800032b4:	6a02                	ld	s4,0(sp)
  }

  panic("bmap: out of range");
}
    800032b6:	854a                	mv	a0,s2
    800032b8:	70a2                	ld	ra,40(sp)
    800032ba:	7402                	ld	s0,32(sp)
    800032bc:	64e2                	ld	s1,24(sp)
    800032be:	6942                	ld	s2,16(sp)
    800032c0:	69a2                	ld	s3,8(sp)
    800032c2:	6145                	addi	sp,sp,48
    800032c4:	8082                	ret
      addr = balloc(ip->dev);
    800032c6:	0009a503          	lw	a0,0(s3)
    800032ca:	e33ff0ef          	jal	800030fc <balloc>
    800032ce:	0005091b          	sext.w	s2,a0
      if(addr){
    800032d2:	fc090ee3          	beqz	s2,800032ae <bmap+0x92>
        a[bn] = addr;
    800032d6:	0124a023          	sw	s2,0(s1)
        log_write(bp);
    800032da:	8552                	mv	a0,s4
    800032dc:	5f7000ef          	jal	800040d2 <log_write>
    800032e0:	b7f9                	j	800032ae <bmap+0x92>
    800032e2:	e052                	sd	s4,0(sp)
  panic("bmap: out of range");
    800032e4:	00004517          	auipc	a0,0x4
    800032e8:	21c50513          	addi	a0,a0,540 # 80007500 <etext+0x500>
    800032ec:	cf4fd0ef          	jal	800007e0 <panic>

00000000800032f0 <iget>:
{
    800032f0:	7179                	addi	sp,sp,-48
    800032f2:	f406                	sd	ra,40(sp)
    800032f4:	f022                	sd	s0,32(sp)
    800032f6:	ec26                	sd	s1,24(sp)
    800032f8:	e84a                	sd	s2,16(sp)
    800032fa:	e44e                	sd	s3,8(sp)
    800032fc:	e052                	sd	s4,0(sp)
    800032fe:	1800                	addi	s0,sp,48
    80003300:	89aa                	mv	s3,a0
    80003302:	8a2e                	mv	s4,a1
  acquire(&itable.lock);
    80003304:	0001e517          	auipc	a0,0x1e
    80003308:	bec50513          	addi	a0,a0,-1044 # 80020ef0 <itable>
    8000330c:	8c3fd0ef          	jal	80000bce <acquire>
  empty = 0;
    80003310:	4901                	li	s2,0
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    80003312:	0001e497          	auipc	s1,0x1e
    80003316:	bf648493          	addi	s1,s1,-1034 # 80020f08 <itable+0x18>
    8000331a:	0001f697          	auipc	a3,0x1f
    8000331e:	67e68693          	addi	a3,a3,1662 # 80022998 <log>
    80003322:	a039                	j	80003330 <iget+0x40>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    80003324:	02090963          	beqz	s2,80003356 <iget+0x66>
  for(ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++){
    80003328:	08848493          	addi	s1,s1,136
    8000332c:	02d48863          	beq	s1,a3,8000335c <iget+0x6c>
    if(ip->ref > 0 && ip->dev == dev && ip->inum == inum){
    80003330:	449c                	lw	a5,8(s1)
    80003332:	fef059e3          	blez	a5,80003324 <iget+0x34>
    80003336:	4098                	lw	a4,0(s1)
    80003338:	ff3716e3          	bne	a4,s3,80003324 <iget+0x34>
    8000333c:	40d8                	lw	a4,4(s1)
    8000333e:	ff4713e3          	bne	a4,s4,80003324 <iget+0x34>
      ip->ref++;
    80003342:	2785                	addiw	a5,a5,1
    80003344:	c49c                	sw	a5,8(s1)
      release(&itable.lock);
    80003346:	0001e517          	auipc	a0,0x1e
    8000334a:	baa50513          	addi	a0,a0,-1110 # 80020ef0 <itable>
    8000334e:	919fd0ef          	jal	80000c66 <release>
      return ip;
    80003352:	8926                	mv	s2,s1
    80003354:	a02d                	j	8000337e <iget+0x8e>
    if(empty == 0 && ip->ref == 0)    // Remember empty slot.
    80003356:	fbe9                	bnez	a5,80003328 <iget+0x38>
      empty = ip;
    80003358:	8926                	mv	s2,s1
    8000335a:	b7f9                	j	80003328 <iget+0x38>
  if(empty == 0)
    8000335c:	02090a63          	beqz	s2,80003390 <iget+0xa0>
  ip->dev = dev;
    80003360:	01392023          	sw	s3,0(s2)
  ip->inum = inum;
    80003364:	01492223          	sw	s4,4(s2)
  ip->ref = 1;
    80003368:	4785                	li	a5,1
    8000336a:	00f92423          	sw	a5,8(s2)
  ip->valid = 0;
    8000336e:	04092023          	sw	zero,64(s2)
  release(&itable.lock);
    80003372:	0001e517          	auipc	a0,0x1e
    80003376:	b7e50513          	addi	a0,a0,-1154 # 80020ef0 <itable>
    8000337a:	8edfd0ef          	jal	80000c66 <release>
}
    8000337e:	854a                	mv	a0,s2
    80003380:	70a2                	ld	ra,40(sp)
    80003382:	7402                	ld	s0,32(sp)
    80003384:	64e2                	ld	s1,24(sp)
    80003386:	6942                	ld	s2,16(sp)
    80003388:	69a2                	ld	s3,8(sp)
    8000338a:	6a02                	ld	s4,0(sp)
    8000338c:	6145                	addi	sp,sp,48
    8000338e:	8082                	ret
    panic("iget: no inodes");
    80003390:	00004517          	auipc	a0,0x4
    80003394:	18850513          	addi	a0,a0,392 # 80007518 <etext+0x518>
    80003398:	c48fd0ef          	jal	800007e0 <panic>

000000008000339c <iinit>:
{
    8000339c:	7179                	addi	sp,sp,-48
    8000339e:	f406                	sd	ra,40(sp)
    800033a0:	f022                	sd	s0,32(sp)
    800033a2:	ec26                	sd	s1,24(sp)
    800033a4:	e84a                	sd	s2,16(sp)
    800033a6:	e44e                	sd	s3,8(sp)
    800033a8:	1800                	addi	s0,sp,48
  initlock(&itable.lock, "itable");
    800033aa:	00004597          	auipc	a1,0x4
    800033ae:	17e58593          	addi	a1,a1,382 # 80007528 <etext+0x528>
    800033b2:	0001e517          	auipc	a0,0x1e
    800033b6:	b3e50513          	addi	a0,a0,-1218 # 80020ef0 <itable>
    800033ba:	f94fd0ef          	jal	80000b4e <initlock>
  for(i = 0; i < NINODE; i++) {
    800033be:	0001e497          	auipc	s1,0x1e
    800033c2:	b5a48493          	addi	s1,s1,-1190 # 80020f18 <itable+0x28>
    800033c6:	0001f997          	auipc	s3,0x1f
    800033ca:	5e298993          	addi	s3,s3,1506 # 800229a8 <log+0x10>
    initsleeplock(&itable.inode[i].lock, "inode");
    800033ce:	00004917          	auipc	s2,0x4
    800033d2:	16290913          	addi	s2,s2,354 # 80007530 <etext+0x530>
    800033d6:	85ca                	mv	a1,s2
    800033d8:	8526                	mv	a0,s1
    800033da:	5bb000ef          	jal	80004194 <initsleeplock>
  for(i = 0; i < NINODE; i++) {
    800033de:	08848493          	addi	s1,s1,136
    800033e2:	ff349ae3          	bne	s1,s3,800033d6 <iinit+0x3a>
}
    800033e6:	70a2                	ld	ra,40(sp)
    800033e8:	7402                	ld	s0,32(sp)
    800033ea:	64e2                	ld	s1,24(sp)
    800033ec:	6942                	ld	s2,16(sp)
    800033ee:	69a2                	ld	s3,8(sp)
    800033f0:	6145                	addi	sp,sp,48
    800033f2:	8082                	ret

00000000800033f4 <ialloc>:
{
    800033f4:	7139                	addi	sp,sp,-64
    800033f6:	fc06                	sd	ra,56(sp)
    800033f8:	f822                	sd	s0,48(sp)
    800033fa:	0080                	addi	s0,sp,64
  for(inum = 1; inum < sb.ninodes; inum++){
    800033fc:	0001e717          	auipc	a4,0x1e
    80003400:	ae072703          	lw	a4,-1312(a4) # 80020edc <sb+0xc>
    80003404:	4785                	li	a5,1
    80003406:	06e7f063          	bgeu	a5,a4,80003466 <ialloc+0x72>
    8000340a:	f426                	sd	s1,40(sp)
    8000340c:	f04a                	sd	s2,32(sp)
    8000340e:	ec4e                	sd	s3,24(sp)
    80003410:	e852                	sd	s4,16(sp)
    80003412:	e456                	sd	s5,8(sp)
    80003414:	e05a                	sd	s6,0(sp)
    80003416:	8aaa                	mv	s5,a0
    80003418:	8b2e                	mv	s6,a1
    8000341a:	4905                	li	s2,1
    bp = bread(dev, IBLOCK(inum, sb));
    8000341c:	0001ea17          	auipc	s4,0x1e
    80003420:	ab4a0a13          	addi	s4,s4,-1356 # 80020ed0 <sb>
    80003424:	00495593          	srli	a1,s2,0x4
    80003428:	018a2783          	lw	a5,24(s4)
    8000342c:	9dbd                	addw	a1,a1,a5
    8000342e:	8556                	mv	a0,s5
    80003430:	a69ff0ef          	jal	80002e98 <bread>
    80003434:	84aa                	mv	s1,a0
    dip = (struct dinode*)bp->data + inum%IPB;
    80003436:	05850993          	addi	s3,a0,88
    8000343a:	00f97793          	andi	a5,s2,15
    8000343e:	079a                	slli	a5,a5,0x6
    80003440:	99be                	add	s3,s3,a5
    if(dip->type == 0){  // a free inode
    80003442:	00099783          	lh	a5,0(s3)
    80003446:	cb9d                	beqz	a5,8000347c <ialloc+0x88>
    brelse(bp);
    80003448:	b59ff0ef          	jal	80002fa0 <brelse>
  for(inum = 1; inum < sb.ninodes; inum++){
    8000344c:	0905                	addi	s2,s2,1
    8000344e:	00ca2703          	lw	a4,12(s4)
    80003452:	0009079b          	sext.w	a5,s2
    80003456:	fce7e7e3          	bltu	a5,a4,80003424 <ialloc+0x30>
    8000345a:	74a2                	ld	s1,40(sp)
    8000345c:	7902                	ld	s2,32(sp)
    8000345e:	69e2                	ld	s3,24(sp)
    80003460:	6a42                	ld	s4,16(sp)
    80003462:	6aa2                	ld	s5,8(sp)
    80003464:	6b02                	ld	s6,0(sp)
  printf("ialloc: no inodes\n");
    80003466:	00004517          	auipc	a0,0x4
    8000346a:	0d250513          	addi	a0,a0,210 # 80007538 <etext+0x538>
    8000346e:	88cfd0ef          	jal	800004fa <printf>
  return 0;
    80003472:	4501                	li	a0,0
}
    80003474:	70e2                	ld	ra,56(sp)
    80003476:	7442                	ld	s0,48(sp)
    80003478:	6121                	addi	sp,sp,64
    8000347a:	8082                	ret
      memset(dip, 0, sizeof(*dip));
    8000347c:	04000613          	li	a2,64
    80003480:	4581                	li	a1,0
    80003482:	854e                	mv	a0,s3
    80003484:	81ffd0ef          	jal	80000ca2 <memset>
      dip->type = type;
    80003488:	01699023          	sh	s6,0(s3)
      log_write(bp);   // mark it allocated on the disk
    8000348c:	8526                	mv	a0,s1
    8000348e:	445000ef          	jal	800040d2 <log_write>
      brelse(bp);
    80003492:	8526                	mv	a0,s1
    80003494:	b0dff0ef          	jal	80002fa0 <brelse>
      return iget(dev, inum);
    80003498:	0009059b          	sext.w	a1,s2
    8000349c:	8556                	mv	a0,s5
    8000349e:	e53ff0ef          	jal	800032f0 <iget>
    800034a2:	74a2                	ld	s1,40(sp)
    800034a4:	7902                	ld	s2,32(sp)
    800034a6:	69e2                	ld	s3,24(sp)
    800034a8:	6a42                	ld	s4,16(sp)
    800034aa:	6aa2                	ld	s5,8(sp)
    800034ac:	6b02                	ld	s6,0(sp)
    800034ae:	b7d9                	j	80003474 <ialloc+0x80>

00000000800034b0 <iupdate>:
{
    800034b0:	1101                	addi	sp,sp,-32
    800034b2:	ec06                	sd	ra,24(sp)
    800034b4:	e822                	sd	s0,16(sp)
    800034b6:	e426                	sd	s1,8(sp)
    800034b8:	e04a                	sd	s2,0(sp)
    800034ba:	1000                	addi	s0,sp,32
    800034bc:	84aa                	mv	s1,a0
  bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    800034be:	415c                	lw	a5,4(a0)
    800034c0:	0047d79b          	srliw	a5,a5,0x4
    800034c4:	0001e597          	auipc	a1,0x1e
    800034c8:	a245a583          	lw	a1,-1500(a1) # 80020ee8 <sb+0x18>
    800034cc:	9dbd                	addw	a1,a1,a5
    800034ce:	4108                	lw	a0,0(a0)
    800034d0:	9c9ff0ef          	jal	80002e98 <bread>
    800034d4:	892a                	mv	s2,a0
  dip = (struct dinode*)bp->data + ip->inum%IPB;
    800034d6:	05850793          	addi	a5,a0,88
    800034da:	40d8                	lw	a4,4(s1)
    800034dc:	8b3d                	andi	a4,a4,15
    800034de:	071a                	slli	a4,a4,0x6
    800034e0:	97ba                	add	a5,a5,a4
  dip->type = ip->type;
    800034e2:	04449703          	lh	a4,68(s1)
    800034e6:	00e79023          	sh	a4,0(a5)
  dip->major = ip->major;
    800034ea:	04649703          	lh	a4,70(s1)
    800034ee:	00e79123          	sh	a4,2(a5)
  dip->minor = ip->minor;
    800034f2:	04849703          	lh	a4,72(s1)
    800034f6:	00e79223          	sh	a4,4(a5)
  dip->nlink = ip->nlink;
    800034fa:	04a49703          	lh	a4,74(s1)
    800034fe:	00e79323          	sh	a4,6(a5)
  dip->size = ip->size;
    80003502:	44f8                	lw	a4,76(s1)
    80003504:	c798                	sw	a4,8(a5)
  memmove(dip->addrs, ip->addrs, sizeof(ip->addrs));
    80003506:	03400613          	li	a2,52
    8000350a:	05048593          	addi	a1,s1,80
    8000350e:	00c78513          	addi	a0,a5,12
    80003512:	fecfd0ef          	jal	80000cfe <memmove>
  log_write(bp);
    80003516:	854a                	mv	a0,s2
    80003518:	3bb000ef          	jal	800040d2 <log_write>
  brelse(bp);
    8000351c:	854a                	mv	a0,s2
    8000351e:	a83ff0ef          	jal	80002fa0 <brelse>
}
    80003522:	60e2                	ld	ra,24(sp)
    80003524:	6442                	ld	s0,16(sp)
    80003526:	64a2                	ld	s1,8(sp)
    80003528:	6902                	ld	s2,0(sp)
    8000352a:	6105                	addi	sp,sp,32
    8000352c:	8082                	ret

000000008000352e <idup>:
{
    8000352e:	1101                	addi	sp,sp,-32
    80003530:	ec06                	sd	ra,24(sp)
    80003532:	e822                	sd	s0,16(sp)
    80003534:	e426                	sd	s1,8(sp)
    80003536:	1000                	addi	s0,sp,32
    80003538:	84aa                	mv	s1,a0
  acquire(&itable.lock);
    8000353a:	0001e517          	auipc	a0,0x1e
    8000353e:	9b650513          	addi	a0,a0,-1610 # 80020ef0 <itable>
    80003542:	e8cfd0ef          	jal	80000bce <acquire>
  ip->ref++;
    80003546:	449c                	lw	a5,8(s1)
    80003548:	2785                	addiw	a5,a5,1
    8000354a:	c49c                	sw	a5,8(s1)
  release(&itable.lock);
    8000354c:	0001e517          	auipc	a0,0x1e
    80003550:	9a450513          	addi	a0,a0,-1628 # 80020ef0 <itable>
    80003554:	f12fd0ef          	jal	80000c66 <release>
}
    80003558:	8526                	mv	a0,s1
    8000355a:	60e2                	ld	ra,24(sp)
    8000355c:	6442                	ld	s0,16(sp)
    8000355e:	64a2                	ld	s1,8(sp)
    80003560:	6105                	addi	sp,sp,32
    80003562:	8082                	ret

0000000080003564 <ilock>:
{
    80003564:	1101                	addi	sp,sp,-32
    80003566:	ec06                	sd	ra,24(sp)
    80003568:	e822                	sd	s0,16(sp)
    8000356a:	e426                	sd	s1,8(sp)
    8000356c:	1000                	addi	s0,sp,32
  if(ip == 0 || ip->ref < 1)
    8000356e:	cd19                	beqz	a0,8000358c <ilock+0x28>
    80003570:	84aa                	mv	s1,a0
    80003572:	451c                	lw	a5,8(a0)
    80003574:	00f05c63          	blez	a5,8000358c <ilock+0x28>
  acquiresleep(&ip->lock);
    80003578:	0541                	addi	a0,a0,16
    8000357a:	451000ef          	jal	800041ca <acquiresleep>
  if(ip->valid == 0){
    8000357e:	40bc                	lw	a5,64(s1)
    80003580:	cf89                	beqz	a5,8000359a <ilock+0x36>
}
    80003582:	60e2                	ld	ra,24(sp)
    80003584:	6442                	ld	s0,16(sp)
    80003586:	64a2                	ld	s1,8(sp)
    80003588:	6105                	addi	sp,sp,32
    8000358a:	8082                	ret
    8000358c:	e04a                	sd	s2,0(sp)
    panic("ilock");
    8000358e:	00004517          	auipc	a0,0x4
    80003592:	fc250513          	addi	a0,a0,-62 # 80007550 <etext+0x550>
    80003596:	a4afd0ef          	jal	800007e0 <panic>
    8000359a:	e04a                	sd	s2,0(sp)
    bp = bread(ip->dev, IBLOCK(ip->inum, sb));
    8000359c:	40dc                	lw	a5,4(s1)
    8000359e:	0047d79b          	srliw	a5,a5,0x4
    800035a2:	0001e597          	auipc	a1,0x1e
    800035a6:	9465a583          	lw	a1,-1722(a1) # 80020ee8 <sb+0x18>
    800035aa:	9dbd                	addw	a1,a1,a5
    800035ac:	4088                	lw	a0,0(s1)
    800035ae:	8ebff0ef          	jal	80002e98 <bread>
    800035b2:	892a                	mv	s2,a0
    dip = (struct dinode*)bp->data + ip->inum%IPB;
    800035b4:	05850593          	addi	a1,a0,88
    800035b8:	40dc                	lw	a5,4(s1)
    800035ba:	8bbd                	andi	a5,a5,15
    800035bc:	079a                	slli	a5,a5,0x6
    800035be:	95be                	add	a1,a1,a5
    ip->type = dip->type;
    800035c0:	00059783          	lh	a5,0(a1)
    800035c4:	04f49223          	sh	a5,68(s1)
    ip->major = dip->major;
    800035c8:	00259783          	lh	a5,2(a1)
    800035cc:	04f49323          	sh	a5,70(s1)
    ip->minor = dip->minor;
    800035d0:	00459783          	lh	a5,4(a1)
    800035d4:	04f49423          	sh	a5,72(s1)
    ip->nlink = dip->nlink;
    800035d8:	00659783          	lh	a5,6(a1)
    800035dc:	04f49523          	sh	a5,74(s1)
    ip->size = dip->size;
    800035e0:	459c                	lw	a5,8(a1)
    800035e2:	c4fc                	sw	a5,76(s1)
    memmove(ip->addrs, dip->addrs, sizeof(ip->addrs));
    800035e4:	03400613          	li	a2,52
    800035e8:	05b1                	addi	a1,a1,12
    800035ea:	05048513          	addi	a0,s1,80
    800035ee:	f10fd0ef          	jal	80000cfe <memmove>
    brelse(bp);
    800035f2:	854a                	mv	a0,s2
    800035f4:	9adff0ef          	jal	80002fa0 <brelse>
    ip->valid = 1;
    800035f8:	4785                	li	a5,1
    800035fa:	c0bc                	sw	a5,64(s1)
    if(ip->type == 0)
    800035fc:	04449783          	lh	a5,68(s1)
    80003600:	c399                	beqz	a5,80003606 <ilock+0xa2>
    80003602:	6902                	ld	s2,0(sp)
    80003604:	bfbd                	j	80003582 <ilock+0x1e>
      panic("ilock: no type");
    80003606:	00004517          	auipc	a0,0x4
    8000360a:	f5250513          	addi	a0,a0,-174 # 80007558 <etext+0x558>
    8000360e:	9d2fd0ef          	jal	800007e0 <panic>

0000000080003612 <iunlock>:
{
    80003612:	1101                	addi	sp,sp,-32
    80003614:	ec06                	sd	ra,24(sp)
    80003616:	e822                	sd	s0,16(sp)
    80003618:	e426                	sd	s1,8(sp)
    8000361a:	e04a                	sd	s2,0(sp)
    8000361c:	1000                	addi	s0,sp,32
  if(ip == 0 || !holdingsleep(&ip->lock) || ip->ref < 1)
    8000361e:	c505                	beqz	a0,80003646 <iunlock+0x34>
    80003620:	84aa                	mv	s1,a0
    80003622:	01050913          	addi	s2,a0,16
    80003626:	854a                	mv	a0,s2
    80003628:	421000ef          	jal	80004248 <holdingsleep>
    8000362c:	cd09                	beqz	a0,80003646 <iunlock+0x34>
    8000362e:	449c                	lw	a5,8(s1)
    80003630:	00f05b63          	blez	a5,80003646 <iunlock+0x34>
  releasesleep(&ip->lock);
    80003634:	854a                	mv	a0,s2
    80003636:	3db000ef          	jal	80004210 <releasesleep>
}
    8000363a:	60e2                	ld	ra,24(sp)
    8000363c:	6442                	ld	s0,16(sp)
    8000363e:	64a2                	ld	s1,8(sp)
    80003640:	6902                	ld	s2,0(sp)
    80003642:	6105                	addi	sp,sp,32
    80003644:	8082                	ret
    panic("iunlock");
    80003646:	00004517          	auipc	a0,0x4
    8000364a:	f2250513          	addi	a0,a0,-222 # 80007568 <etext+0x568>
    8000364e:	992fd0ef          	jal	800007e0 <panic>

0000000080003652 <itrunc>:

// Truncate inode (discard contents).
// Caller must hold ip->lock.
void
itrunc(struct inode *ip)
{
    80003652:	7179                	addi	sp,sp,-48
    80003654:	f406                	sd	ra,40(sp)
    80003656:	f022                	sd	s0,32(sp)
    80003658:	ec26                	sd	s1,24(sp)
    8000365a:	e84a                	sd	s2,16(sp)
    8000365c:	e44e                	sd	s3,8(sp)
    8000365e:	1800                	addi	s0,sp,48
    80003660:	89aa                	mv	s3,a0
  int i, j;
  struct buf *bp;
  uint *a;

  for(i = 0; i < NDIRECT; i++){
    80003662:	05050493          	addi	s1,a0,80
    80003666:	08050913          	addi	s2,a0,128
    8000366a:	a021                	j	80003672 <itrunc+0x20>
    8000366c:	0491                	addi	s1,s1,4
    8000366e:	01248b63          	beq	s1,s2,80003684 <itrunc+0x32>
    if(ip->addrs[i]){
    80003672:	408c                	lw	a1,0(s1)
    80003674:	dde5                	beqz	a1,8000366c <itrunc+0x1a>
      bfree(ip->dev, ip->addrs[i]);
    80003676:	0009a503          	lw	a0,0(s3)
    8000367a:	a17ff0ef          	jal	80003090 <bfree>
      ip->addrs[i] = 0;
    8000367e:	0004a023          	sw	zero,0(s1)
    80003682:	b7ed                	j	8000366c <itrunc+0x1a>
    }
  }

  if(ip->addrs[NDIRECT]){
    80003684:	0809a583          	lw	a1,128(s3)
    80003688:	ed89                	bnez	a1,800036a2 <itrunc+0x50>
    brelse(bp);
    bfree(ip->dev, ip->addrs[NDIRECT]);
    ip->addrs[NDIRECT] = 0;
  }

  ip->size = 0;
    8000368a:	0409a623          	sw	zero,76(s3)
  iupdate(ip);
    8000368e:	854e                	mv	a0,s3
    80003690:	e21ff0ef          	jal	800034b0 <iupdate>
}
    80003694:	70a2                	ld	ra,40(sp)
    80003696:	7402                	ld	s0,32(sp)
    80003698:	64e2                	ld	s1,24(sp)
    8000369a:	6942                	ld	s2,16(sp)
    8000369c:	69a2                	ld	s3,8(sp)
    8000369e:	6145                	addi	sp,sp,48
    800036a0:	8082                	ret
    800036a2:	e052                	sd	s4,0(sp)
    bp = bread(ip->dev, ip->addrs[NDIRECT]);
    800036a4:	0009a503          	lw	a0,0(s3)
    800036a8:	ff0ff0ef          	jal	80002e98 <bread>
    800036ac:	8a2a                	mv	s4,a0
    for(j = 0; j < NINDIRECT; j++){
    800036ae:	05850493          	addi	s1,a0,88
    800036b2:	45850913          	addi	s2,a0,1112
    800036b6:	a021                	j	800036be <itrunc+0x6c>
    800036b8:	0491                	addi	s1,s1,4
    800036ba:	01248963          	beq	s1,s2,800036cc <itrunc+0x7a>
      if(a[j])
    800036be:	408c                	lw	a1,0(s1)
    800036c0:	dde5                	beqz	a1,800036b8 <itrunc+0x66>
        bfree(ip->dev, a[j]);
    800036c2:	0009a503          	lw	a0,0(s3)
    800036c6:	9cbff0ef          	jal	80003090 <bfree>
    800036ca:	b7fd                	j	800036b8 <itrunc+0x66>
    brelse(bp);
    800036cc:	8552                	mv	a0,s4
    800036ce:	8d3ff0ef          	jal	80002fa0 <brelse>
    bfree(ip->dev, ip->addrs[NDIRECT]);
    800036d2:	0809a583          	lw	a1,128(s3)
    800036d6:	0009a503          	lw	a0,0(s3)
    800036da:	9b7ff0ef          	jal	80003090 <bfree>
    ip->addrs[NDIRECT] = 0;
    800036de:	0809a023          	sw	zero,128(s3)
    800036e2:	6a02                	ld	s4,0(sp)
    800036e4:	b75d                	j	8000368a <itrunc+0x38>

00000000800036e6 <iput>:
{
    800036e6:	1101                	addi	sp,sp,-32
    800036e8:	ec06                	sd	ra,24(sp)
    800036ea:	e822                	sd	s0,16(sp)
    800036ec:	e426                	sd	s1,8(sp)
    800036ee:	1000                	addi	s0,sp,32
    800036f0:	84aa                	mv	s1,a0
  acquire(&itable.lock);
    800036f2:	0001d517          	auipc	a0,0x1d
    800036f6:	7fe50513          	addi	a0,a0,2046 # 80020ef0 <itable>
    800036fa:	cd4fd0ef          	jal	80000bce <acquire>
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    800036fe:	4498                	lw	a4,8(s1)
    80003700:	4785                	li	a5,1
    80003702:	02f70063          	beq	a4,a5,80003722 <iput+0x3c>
  ip->ref--;
    80003706:	449c                	lw	a5,8(s1)
    80003708:	37fd                	addiw	a5,a5,-1
    8000370a:	c49c                	sw	a5,8(s1)
  release(&itable.lock);
    8000370c:	0001d517          	auipc	a0,0x1d
    80003710:	7e450513          	addi	a0,a0,2020 # 80020ef0 <itable>
    80003714:	d52fd0ef          	jal	80000c66 <release>
}
    80003718:	60e2                	ld	ra,24(sp)
    8000371a:	6442                	ld	s0,16(sp)
    8000371c:	64a2                	ld	s1,8(sp)
    8000371e:	6105                	addi	sp,sp,32
    80003720:	8082                	ret
  if(ip->ref == 1 && ip->valid && ip->nlink == 0){
    80003722:	40bc                	lw	a5,64(s1)
    80003724:	d3ed                	beqz	a5,80003706 <iput+0x20>
    80003726:	04a49783          	lh	a5,74(s1)
    8000372a:	fff1                	bnez	a5,80003706 <iput+0x20>
    8000372c:	e04a                	sd	s2,0(sp)
    acquiresleep(&ip->lock);
    8000372e:	01048913          	addi	s2,s1,16
    80003732:	854a                	mv	a0,s2
    80003734:	297000ef          	jal	800041ca <acquiresleep>
    release(&itable.lock);
    80003738:	0001d517          	auipc	a0,0x1d
    8000373c:	7b850513          	addi	a0,a0,1976 # 80020ef0 <itable>
    80003740:	d26fd0ef          	jal	80000c66 <release>
    itrunc(ip);
    80003744:	8526                	mv	a0,s1
    80003746:	f0dff0ef          	jal	80003652 <itrunc>
    ip->type = 0;
    8000374a:	04049223          	sh	zero,68(s1)
    iupdate(ip);
    8000374e:	8526                	mv	a0,s1
    80003750:	d61ff0ef          	jal	800034b0 <iupdate>
    ip->valid = 0;
    80003754:	0404a023          	sw	zero,64(s1)
    releasesleep(&ip->lock);
    80003758:	854a                	mv	a0,s2
    8000375a:	2b7000ef          	jal	80004210 <releasesleep>
    acquire(&itable.lock);
    8000375e:	0001d517          	auipc	a0,0x1d
    80003762:	79250513          	addi	a0,a0,1938 # 80020ef0 <itable>
    80003766:	c68fd0ef          	jal	80000bce <acquire>
    8000376a:	6902                	ld	s2,0(sp)
    8000376c:	bf69                	j	80003706 <iput+0x20>

000000008000376e <iunlockput>:
{
    8000376e:	1101                	addi	sp,sp,-32
    80003770:	ec06                	sd	ra,24(sp)
    80003772:	e822                	sd	s0,16(sp)
    80003774:	e426                	sd	s1,8(sp)
    80003776:	1000                	addi	s0,sp,32
    80003778:	84aa                	mv	s1,a0
  iunlock(ip);
    8000377a:	e99ff0ef          	jal	80003612 <iunlock>
  iput(ip);
    8000377e:	8526                	mv	a0,s1
    80003780:	f67ff0ef          	jal	800036e6 <iput>
}
    80003784:	60e2                	ld	ra,24(sp)
    80003786:	6442                	ld	s0,16(sp)
    80003788:	64a2                	ld	s1,8(sp)
    8000378a:	6105                	addi	sp,sp,32
    8000378c:	8082                	ret

000000008000378e <ireclaim>:
  for (int inum = 1; inum < sb.ninodes; inum++) {
    8000378e:	0001d717          	auipc	a4,0x1d
    80003792:	74e72703          	lw	a4,1870(a4) # 80020edc <sb+0xc>
    80003796:	4785                	li	a5,1
    80003798:	0ae7ff63          	bgeu	a5,a4,80003856 <ireclaim+0xc8>
{
    8000379c:	7139                	addi	sp,sp,-64
    8000379e:	fc06                	sd	ra,56(sp)
    800037a0:	f822                	sd	s0,48(sp)
    800037a2:	f426                	sd	s1,40(sp)
    800037a4:	f04a                	sd	s2,32(sp)
    800037a6:	ec4e                	sd	s3,24(sp)
    800037a8:	e852                	sd	s4,16(sp)
    800037aa:	e456                	sd	s5,8(sp)
    800037ac:	e05a                	sd	s6,0(sp)
    800037ae:	0080                	addi	s0,sp,64
  for (int inum = 1; inum < sb.ninodes; inum++) {
    800037b0:	4485                	li	s1,1
    struct buf *bp = bread(dev, IBLOCK(inum, sb));
    800037b2:	00050a1b          	sext.w	s4,a0
    800037b6:	0001da97          	auipc	s5,0x1d
    800037ba:	71aa8a93          	addi	s5,s5,1818 # 80020ed0 <sb>
      printf("ireclaim: orphaned inode %d\n", inum);
    800037be:	00004b17          	auipc	s6,0x4
    800037c2:	db2b0b13          	addi	s6,s6,-590 # 80007570 <etext+0x570>
    800037c6:	a099                	j	8000380c <ireclaim+0x7e>
    800037c8:	85ce                	mv	a1,s3
    800037ca:	855a                	mv	a0,s6
    800037cc:	d2ffc0ef          	jal	800004fa <printf>
      ip = iget(dev, inum);
    800037d0:	85ce                	mv	a1,s3
    800037d2:	8552                	mv	a0,s4
    800037d4:	b1dff0ef          	jal	800032f0 <iget>
    800037d8:	89aa                	mv	s3,a0
    brelse(bp);
    800037da:	854a                	mv	a0,s2
    800037dc:	fc4ff0ef          	jal	80002fa0 <brelse>
    if (ip) {
    800037e0:	00098f63          	beqz	s3,800037fe <ireclaim+0x70>
      begin_op();
    800037e4:	76a000ef          	jal	80003f4e <begin_op>
      ilock(ip);
    800037e8:	854e                	mv	a0,s3
    800037ea:	d7bff0ef          	jal	80003564 <ilock>
      iunlock(ip);
    800037ee:	854e                	mv	a0,s3
    800037f0:	e23ff0ef          	jal	80003612 <iunlock>
      iput(ip);
    800037f4:	854e                	mv	a0,s3
    800037f6:	ef1ff0ef          	jal	800036e6 <iput>
      end_op();
    800037fa:	7be000ef          	jal	80003fb8 <end_op>
  for (int inum = 1; inum < sb.ninodes; inum++) {
    800037fe:	0485                	addi	s1,s1,1
    80003800:	00caa703          	lw	a4,12(s5)
    80003804:	0004879b          	sext.w	a5,s1
    80003808:	02e7fd63          	bgeu	a5,a4,80003842 <ireclaim+0xb4>
    8000380c:	0004899b          	sext.w	s3,s1
    struct buf *bp = bread(dev, IBLOCK(inum, sb));
    80003810:	0044d593          	srli	a1,s1,0x4
    80003814:	018aa783          	lw	a5,24(s5)
    80003818:	9dbd                	addw	a1,a1,a5
    8000381a:	8552                	mv	a0,s4
    8000381c:	e7cff0ef          	jal	80002e98 <bread>
    80003820:	892a                	mv	s2,a0
    struct dinode *dip = (struct dinode *)bp->data + inum % IPB;
    80003822:	05850793          	addi	a5,a0,88
    80003826:	00f9f713          	andi	a4,s3,15
    8000382a:	071a                	slli	a4,a4,0x6
    8000382c:	97ba                	add	a5,a5,a4
    if (dip->type != 0 && dip->nlink == 0) {  // is an orphaned inode
    8000382e:	00079703          	lh	a4,0(a5)
    80003832:	c701                	beqz	a4,8000383a <ireclaim+0xac>
    80003834:	00679783          	lh	a5,6(a5)
    80003838:	dbc1                	beqz	a5,800037c8 <ireclaim+0x3a>
    brelse(bp);
    8000383a:	854a                	mv	a0,s2
    8000383c:	f64ff0ef          	jal	80002fa0 <brelse>
    if (ip) {
    80003840:	bf7d                	j	800037fe <ireclaim+0x70>
}
    80003842:	70e2                	ld	ra,56(sp)
    80003844:	7442                	ld	s0,48(sp)
    80003846:	74a2                	ld	s1,40(sp)
    80003848:	7902                	ld	s2,32(sp)
    8000384a:	69e2                	ld	s3,24(sp)
    8000384c:	6a42                	ld	s4,16(sp)
    8000384e:	6aa2                	ld	s5,8(sp)
    80003850:	6b02                	ld	s6,0(sp)
    80003852:	6121                	addi	sp,sp,64
    80003854:	8082                	ret
    80003856:	8082                	ret

0000000080003858 <fsinit>:
fsinit(int dev) {
    80003858:	7179                	addi	sp,sp,-48
    8000385a:	f406                	sd	ra,40(sp)
    8000385c:	f022                	sd	s0,32(sp)
    8000385e:	ec26                	sd	s1,24(sp)
    80003860:	e84a                	sd	s2,16(sp)
    80003862:	e44e                	sd	s3,8(sp)
    80003864:	1800                	addi	s0,sp,48
    80003866:	84aa                	mv	s1,a0
  bp = bread(dev, 1);
    80003868:	4585                	li	a1,1
    8000386a:	e2eff0ef          	jal	80002e98 <bread>
    8000386e:	892a                	mv	s2,a0
  memmove(sb, bp->data, sizeof(*sb));
    80003870:	0001d997          	auipc	s3,0x1d
    80003874:	66098993          	addi	s3,s3,1632 # 80020ed0 <sb>
    80003878:	02000613          	li	a2,32
    8000387c:	05850593          	addi	a1,a0,88
    80003880:	854e                	mv	a0,s3
    80003882:	c7cfd0ef          	jal	80000cfe <memmove>
  brelse(bp);
    80003886:	854a                	mv	a0,s2
    80003888:	f18ff0ef          	jal	80002fa0 <brelse>
  if(sb.magic != FSMAGIC)
    8000388c:	0009a703          	lw	a4,0(s3)
    80003890:	102037b7          	lui	a5,0x10203
    80003894:	04078793          	addi	a5,a5,64 # 10203040 <_entry-0x6fdfcfc0>
    80003898:	02f71363          	bne	a4,a5,800038be <fsinit+0x66>
  initlog(dev, &sb);
    8000389c:	0001d597          	auipc	a1,0x1d
    800038a0:	63458593          	addi	a1,a1,1588 # 80020ed0 <sb>
    800038a4:	8526                	mv	a0,s1
    800038a6:	62a000ef          	jal	80003ed0 <initlog>
  ireclaim(dev);
    800038aa:	8526                	mv	a0,s1
    800038ac:	ee3ff0ef          	jal	8000378e <ireclaim>
}
    800038b0:	70a2                	ld	ra,40(sp)
    800038b2:	7402                	ld	s0,32(sp)
    800038b4:	64e2                	ld	s1,24(sp)
    800038b6:	6942                	ld	s2,16(sp)
    800038b8:	69a2                	ld	s3,8(sp)
    800038ba:	6145                	addi	sp,sp,48
    800038bc:	8082                	ret
    panic("invalid file system");
    800038be:	00004517          	auipc	a0,0x4
    800038c2:	cd250513          	addi	a0,a0,-814 # 80007590 <etext+0x590>
    800038c6:	f1bfc0ef          	jal	800007e0 <panic>

00000000800038ca <stati>:

// Copy stat information from inode.
// Caller must hold ip->lock.
void
stati(struct inode *ip, struct stat *st)
{
    800038ca:	1141                	addi	sp,sp,-16
    800038cc:	e422                	sd	s0,8(sp)
    800038ce:	0800                	addi	s0,sp,16
  st->dev = ip->dev;
    800038d0:	411c                	lw	a5,0(a0)
    800038d2:	c19c                	sw	a5,0(a1)
  st->ino = ip->inum;
    800038d4:	415c                	lw	a5,4(a0)
    800038d6:	c1dc                	sw	a5,4(a1)
  st->type = ip->type;
    800038d8:	04451783          	lh	a5,68(a0)
    800038dc:	00f59423          	sh	a5,8(a1)
  st->nlink = ip->nlink;
    800038e0:	04a51783          	lh	a5,74(a0)
    800038e4:	00f59523          	sh	a5,10(a1)
  st->size = ip->size;
    800038e8:	04c56783          	lwu	a5,76(a0)
    800038ec:	e99c                	sd	a5,16(a1)
}
    800038ee:	6422                	ld	s0,8(sp)
    800038f0:	0141                	addi	sp,sp,16
    800038f2:	8082                	ret

00000000800038f4 <readi>:
readi(struct inode *ip, int user_dst, uint64 dst, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    800038f4:	457c                	lw	a5,76(a0)
    800038f6:	0ed7eb63          	bltu	a5,a3,800039ec <readi+0xf8>
{
    800038fa:	7159                	addi	sp,sp,-112
    800038fc:	f486                	sd	ra,104(sp)
    800038fe:	f0a2                	sd	s0,96(sp)
    80003900:	eca6                	sd	s1,88(sp)
    80003902:	e0d2                	sd	s4,64(sp)
    80003904:	fc56                	sd	s5,56(sp)
    80003906:	f85a                	sd	s6,48(sp)
    80003908:	f45e                	sd	s7,40(sp)
    8000390a:	1880                	addi	s0,sp,112
    8000390c:	8b2a                	mv	s6,a0
    8000390e:	8bae                	mv	s7,a1
    80003910:	8a32                	mv	s4,a2
    80003912:	84b6                	mv	s1,a3
    80003914:	8aba                	mv	s5,a4
  if(off > ip->size || off + n < off)
    80003916:	9f35                	addw	a4,a4,a3
    return 0;
    80003918:	4501                	li	a0,0
  if(off > ip->size || off + n < off)
    8000391a:	0cd76063          	bltu	a4,a3,800039da <readi+0xe6>
    8000391e:	e4ce                	sd	s3,72(sp)
  if(off + n > ip->size)
    80003920:	00e7f463          	bgeu	a5,a4,80003928 <readi+0x34>
    n = ip->size - off;
    80003924:	40d78abb          	subw	s5,a5,a3

  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    80003928:	080a8f63          	beqz	s5,800039c6 <readi+0xd2>
    8000392c:	e8ca                	sd	s2,80(sp)
    8000392e:	f062                	sd	s8,32(sp)
    80003930:	ec66                	sd	s9,24(sp)
    80003932:	e86a                	sd	s10,16(sp)
    80003934:	e46e                	sd	s11,8(sp)
    80003936:	4981                	li	s3,0
    uint addr = bmap(ip, off/BSIZE);
    if(addr == 0)
      break;
    bp = bread(ip->dev, addr);
    m = min(n - tot, BSIZE - off%BSIZE);
    80003938:	40000c93          	li	s9,1024
    if(either_copyout(user_dst, dst, bp->data + (off % BSIZE), m) == -1) {
    8000393c:	5c7d                	li	s8,-1
    8000393e:	a80d                	j	80003970 <readi+0x7c>
    80003940:	020d1d93          	slli	s11,s10,0x20
    80003944:	020ddd93          	srli	s11,s11,0x20
    80003948:	05890613          	addi	a2,s2,88
    8000394c:	86ee                	mv	a3,s11
    8000394e:	963a                	add	a2,a2,a4
    80003950:	85d2                	mv	a1,s4
    80003952:	855e                	mv	a0,s7
    80003954:	95bfe0ef          	jal	800022ae <either_copyout>
    80003958:	05850763          	beq	a0,s8,800039a6 <readi+0xb2>
      brelse(bp);
      tot = -1;
      break;
    }
    brelse(bp);
    8000395c:	854a                	mv	a0,s2
    8000395e:	e42ff0ef          	jal	80002fa0 <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    80003962:	013d09bb          	addw	s3,s10,s3
    80003966:	009d04bb          	addw	s1,s10,s1
    8000396a:	9a6e                	add	s4,s4,s11
    8000396c:	0559f763          	bgeu	s3,s5,800039ba <readi+0xc6>
    uint addr = bmap(ip, off/BSIZE);
    80003970:	00a4d59b          	srliw	a1,s1,0xa
    80003974:	855a                	mv	a0,s6
    80003976:	8a7ff0ef          	jal	8000321c <bmap>
    8000397a:	0005059b          	sext.w	a1,a0
    if(addr == 0)
    8000397e:	c5b1                	beqz	a1,800039ca <readi+0xd6>
    bp = bread(ip->dev, addr);
    80003980:	000b2503          	lw	a0,0(s6)
    80003984:	d14ff0ef          	jal	80002e98 <bread>
    80003988:	892a                	mv	s2,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    8000398a:	3ff4f713          	andi	a4,s1,1023
    8000398e:	40ec87bb          	subw	a5,s9,a4
    80003992:	413a86bb          	subw	a3,s5,s3
    80003996:	8d3e                	mv	s10,a5
    80003998:	2781                	sext.w	a5,a5
    8000399a:	0006861b          	sext.w	a2,a3
    8000399e:	faf671e3          	bgeu	a2,a5,80003940 <readi+0x4c>
    800039a2:	8d36                	mv	s10,a3
    800039a4:	bf71                	j	80003940 <readi+0x4c>
      brelse(bp);
    800039a6:	854a                	mv	a0,s2
    800039a8:	df8ff0ef          	jal	80002fa0 <brelse>
      tot = -1;
    800039ac:	59fd                	li	s3,-1
      break;
    800039ae:	6946                	ld	s2,80(sp)
    800039b0:	7c02                	ld	s8,32(sp)
    800039b2:	6ce2                	ld	s9,24(sp)
    800039b4:	6d42                	ld	s10,16(sp)
    800039b6:	6da2                	ld	s11,8(sp)
    800039b8:	a831                	j	800039d4 <readi+0xe0>
    800039ba:	6946                	ld	s2,80(sp)
    800039bc:	7c02                	ld	s8,32(sp)
    800039be:	6ce2                	ld	s9,24(sp)
    800039c0:	6d42                	ld	s10,16(sp)
    800039c2:	6da2                	ld	s11,8(sp)
    800039c4:	a801                	j	800039d4 <readi+0xe0>
  for(tot=0; tot<n; tot+=m, off+=m, dst+=m){
    800039c6:	89d6                	mv	s3,s5
    800039c8:	a031                	j	800039d4 <readi+0xe0>
    800039ca:	6946                	ld	s2,80(sp)
    800039cc:	7c02                	ld	s8,32(sp)
    800039ce:	6ce2                	ld	s9,24(sp)
    800039d0:	6d42                	ld	s10,16(sp)
    800039d2:	6da2                	ld	s11,8(sp)
  }
  return tot;
    800039d4:	0009851b          	sext.w	a0,s3
    800039d8:	69a6                	ld	s3,72(sp)
}
    800039da:	70a6                	ld	ra,104(sp)
    800039dc:	7406                	ld	s0,96(sp)
    800039de:	64e6                	ld	s1,88(sp)
    800039e0:	6a06                	ld	s4,64(sp)
    800039e2:	7ae2                	ld	s5,56(sp)
    800039e4:	7b42                	ld	s6,48(sp)
    800039e6:	7ba2                	ld	s7,40(sp)
    800039e8:	6165                	addi	sp,sp,112
    800039ea:	8082                	ret
    return 0;
    800039ec:	4501                	li	a0,0
}
    800039ee:	8082                	ret

00000000800039f0 <writei>:
writei(struct inode *ip, int user_src, uint64 src, uint off, uint n)
{
  uint tot, m;
  struct buf *bp;

  if(off > ip->size || off + n < off)
    800039f0:	457c                	lw	a5,76(a0)
    800039f2:	10d7e063          	bltu	a5,a3,80003af2 <writei+0x102>
{
    800039f6:	7159                	addi	sp,sp,-112
    800039f8:	f486                	sd	ra,104(sp)
    800039fa:	f0a2                	sd	s0,96(sp)
    800039fc:	e8ca                	sd	s2,80(sp)
    800039fe:	e0d2                	sd	s4,64(sp)
    80003a00:	fc56                	sd	s5,56(sp)
    80003a02:	f85a                	sd	s6,48(sp)
    80003a04:	f45e                	sd	s7,40(sp)
    80003a06:	1880                	addi	s0,sp,112
    80003a08:	8aaa                	mv	s5,a0
    80003a0a:	8bae                	mv	s7,a1
    80003a0c:	8a32                	mv	s4,a2
    80003a0e:	8936                	mv	s2,a3
    80003a10:	8b3a                	mv	s6,a4
  if(off > ip->size || off + n < off)
    80003a12:	00e687bb          	addw	a5,a3,a4
    80003a16:	0ed7e063          	bltu	a5,a3,80003af6 <writei+0x106>
    return -1;
  if(off + n > MAXFILE*BSIZE)
    80003a1a:	00043737          	lui	a4,0x43
    80003a1e:	0cf76e63          	bltu	a4,a5,80003afa <writei+0x10a>
    80003a22:	e4ce                	sd	s3,72(sp)
    return -1;

  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80003a24:	0a0b0f63          	beqz	s6,80003ae2 <writei+0xf2>
    80003a28:	eca6                	sd	s1,88(sp)
    80003a2a:	f062                	sd	s8,32(sp)
    80003a2c:	ec66                	sd	s9,24(sp)
    80003a2e:	e86a                	sd	s10,16(sp)
    80003a30:	e46e                	sd	s11,8(sp)
    80003a32:	4981                	li	s3,0
    uint addr = bmap(ip, off/BSIZE);
    if(addr == 0)
      break;
    bp = bread(ip->dev, addr);
    m = min(n - tot, BSIZE - off%BSIZE);
    80003a34:	40000c93          	li	s9,1024
    if(either_copyin(bp->data + (off % BSIZE), user_src, src, m) == -1) {
    80003a38:	5c7d                	li	s8,-1
    80003a3a:	a825                	j	80003a72 <writei+0x82>
    80003a3c:	020d1d93          	slli	s11,s10,0x20
    80003a40:	020ddd93          	srli	s11,s11,0x20
    80003a44:	05848513          	addi	a0,s1,88
    80003a48:	86ee                	mv	a3,s11
    80003a4a:	8652                	mv	a2,s4
    80003a4c:	85de                	mv	a1,s7
    80003a4e:	953a                	add	a0,a0,a4
    80003a50:	8a9fe0ef          	jal	800022f8 <either_copyin>
    80003a54:	05850a63          	beq	a0,s8,80003aa8 <writei+0xb8>
      brelse(bp);
      break;
    }
    log_write(bp);
    80003a58:	8526                	mv	a0,s1
    80003a5a:	678000ef          	jal	800040d2 <log_write>
    brelse(bp);
    80003a5e:	8526                	mv	a0,s1
    80003a60:	d40ff0ef          	jal	80002fa0 <brelse>
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80003a64:	013d09bb          	addw	s3,s10,s3
    80003a68:	012d093b          	addw	s2,s10,s2
    80003a6c:	9a6e                	add	s4,s4,s11
    80003a6e:	0569f063          	bgeu	s3,s6,80003aae <writei+0xbe>
    uint addr = bmap(ip, off/BSIZE);
    80003a72:	00a9559b          	srliw	a1,s2,0xa
    80003a76:	8556                	mv	a0,s5
    80003a78:	fa4ff0ef          	jal	8000321c <bmap>
    80003a7c:	0005059b          	sext.w	a1,a0
    if(addr == 0)
    80003a80:	c59d                	beqz	a1,80003aae <writei+0xbe>
    bp = bread(ip->dev, addr);
    80003a82:	000aa503          	lw	a0,0(s5)
    80003a86:	c12ff0ef          	jal	80002e98 <bread>
    80003a8a:	84aa                	mv	s1,a0
    m = min(n - tot, BSIZE - off%BSIZE);
    80003a8c:	3ff97713          	andi	a4,s2,1023
    80003a90:	40ec87bb          	subw	a5,s9,a4
    80003a94:	413b06bb          	subw	a3,s6,s3
    80003a98:	8d3e                	mv	s10,a5
    80003a9a:	2781                	sext.w	a5,a5
    80003a9c:	0006861b          	sext.w	a2,a3
    80003aa0:	f8f67ee3          	bgeu	a2,a5,80003a3c <writei+0x4c>
    80003aa4:	8d36                	mv	s10,a3
    80003aa6:	bf59                	j	80003a3c <writei+0x4c>
      brelse(bp);
    80003aa8:	8526                	mv	a0,s1
    80003aaa:	cf6ff0ef          	jal	80002fa0 <brelse>
  }

  if(off > ip->size)
    80003aae:	04caa783          	lw	a5,76(s5)
    80003ab2:	0327fa63          	bgeu	a5,s2,80003ae6 <writei+0xf6>
    ip->size = off;
    80003ab6:	052aa623          	sw	s2,76(s5)
    80003aba:	64e6                	ld	s1,88(sp)
    80003abc:	7c02                	ld	s8,32(sp)
    80003abe:	6ce2                	ld	s9,24(sp)
    80003ac0:	6d42                	ld	s10,16(sp)
    80003ac2:	6da2                	ld	s11,8(sp)

  // write the i-node back to disk even if the size didn't change
  // because the loop above might have called bmap() and added a new
  // block to ip->addrs[].
  iupdate(ip);
    80003ac4:	8556                	mv	a0,s5
    80003ac6:	9ebff0ef          	jal	800034b0 <iupdate>

  return tot;
    80003aca:	0009851b          	sext.w	a0,s3
    80003ace:	69a6                	ld	s3,72(sp)
}
    80003ad0:	70a6                	ld	ra,104(sp)
    80003ad2:	7406                	ld	s0,96(sp)
    80003ad4:	6946                	ld	s2,80(sp)
    80003ad6:	6a06                	ld	s4,64(sp)
    80003ad8:	7ae2                	ld	s5,56(sp)
    80003ada:	7b42                	ld	s6,48(sp)
    80003adc:	7ba2                	ld	s7,40(sp)
    80003ade:	6165                	addi	sp,sp,112
    80003ae0:	8082                	ret
  for(tot=0; tot<n; tot+=m, off+=m, src+=m){
    80003ae2:	89da                	mv	s3,s6
    80003ae4:	b7c5                	j	80003ac4 <writei+0xd4>
    80003ae6:	64e6                	ld	s1,88(sp)
    80003ae8:	7c02                	ld	s8,32(sp)
    80003aea:	6ce2                	ld	s9,24(sp)
    80003aec:	6d42                	ld	s10,16(sp)
    80003aee:	6da2                	ld	s11,8(sp)
    80003af0:	bfd1                	j	80003ac4 <writei+0xd4>
    return -1;
    80003af2:	557d                	li	a0,-1
}
    80003af4:	8082                	ret
    return -1;
    80003af6:	557d                	li	a0,-1
    80003af8:	bfe1                	j	80003ad0 <writei+0xe0>
    return -1;
    80003afa:	557d                	li	a0,-1
    80003afc:	bfd1                	j	80003ad0 <writei+0xe0>

0000000080003afe <namecmp>:

// Directories

int
namecmp(const char *s, const char *t)
{
    80003afe:	1141                	addi	sp,sp,-16
    80003b00:	e406                	sd	ra,8(sp)
    80003b02:	e022                	sd	s0,0(sp)
    80003b04:	0800                	addi	s0,sp,16
  return strncmp(s, t, DIRSIZ);
    80003b06:	4639                	li	a2,14
    80003b08:	a66fd0ef          	jal	80000d6e <strncmp>
}
    80003b0c:	60a2                	ld	ra,8(sp)
    80003b0e:	6402                	ld	s0,0(sp)
    80003b10:	0141                	addi	sp,sp,16
    80003b12:	8082                	ret

0000000080003b14 <dirlookup>:

// Look for a directory entry in a directory.
// If found, set *poff to byte offset of entry.
struct inode*
dirlookup(struct inode *dp, char *name, uint *poff)
{
    80003b14:	7139                	addi	sp,sp,-64
    80003b16:	fc06                	sd	ra,56(sp)
    80003b18:	f822                	sd	s0,48(sp)
    80003b1a:	f426                	sd	s1,40(sp)
    80003b1c:	f04a                	sd	s2,32(sp)
    80003b1e:	ec4e                	sd	s3,24(sp)
    80003b20:	e852                	sd	s4,16(sp)
    80003b22:	0080                	addi	s0,sp,64
  uint off, inum;
  struct dirent de;

  if(dp->type != T_DIR)
    80003b24:	04451703          	lh	a4,68(a0)
    80003b28:	4785                	li	a5,1
    80003b2a:	00f71a63          	bne	a4,a5,80003b3e <dirlookup+0x2a>
    80003b2e:	892a                	mv	s2,a0
    80003b30:	89ae                	mv	s3,a1
    80003b32:	8a32                	mv	s4,a2
    panic("dirlookup not DIR");

  for(off = 0; off < dp->size; off += sizeof(de)){
    80003b34:	457c                	lw	a5,76(a0)
    80003b36:	4481                	li	s1,0
      inum = de.inum;
      return iget(dp->dev, inum);
    }
  }

  return 0;
    80003b38:	4501                	li	a0,0
  for(off = 0; off < dp->size; off += sizeof(de)){
    80003b3a:	e39d                	bnez	a5,80003b60 <dirlookup+0x4c>
    80003b3c:	a095                	j	80003ba0 <dirlookup+0x8c>
    panic("dirlookup not DIR");
    80003b3e:	00004517          	auipc	a0,0x4
    80003b42:	a6a50513          	addi	a0,a0,-1430 # 800075a8 <etext+0x5a8>
    80003b46:	c9bfc0ef          	jal	800007e0 <panic>
      panic("dirlookup read");
    80003b4a:	00004517          	auipc	a0,0x4
    80003b4e:	a7650513          	addi	a0,a0,-1418 # 800075c0 <etext+0x5c0>
    80003b52:	c8ffc0ef          	jal	800007e0 <panic>
  for(off = 0; off < dp->size; off += sizeof(de)){
    80003b56:	24c1                	addiw	s1,s1,16
    80003b58:	04c92783          	lw	a5,76(s2)
    80003b5c:	04f4f163          	bgeu	s1,a5,80003b9e <dirlookup+0x8a>
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80003b60:	4741                	li	a4,16
    80003b62:	86a6                	mv	a3,s1
    80003b64:	fc040613          	addi	a2,s0,-64
    80003b68:	4581                	li	a1,0
    80003b6a:	854a                	mv	a0,s2
    80003b6c:	d89ff0ef          	jal	800038f4 <readi>
    80003b70:	47c1                	li	a5,16
    80003b72:	fcf51ce3          	bne	a0,a5,80003b4a <dirlookup+0x36>
    if(de.inum == 0)
    80003b76:	fc045783          	lhu	a5,-64(s0)
    80003b7a:	dff1                	beqz	a5,80003b56 <dirlookup+0x42>
    if(namecmp(name, de.name) == 0){
    80003b7c:	fc240593          	addi	a1,s0,-62
    80003b80:	854e                	mv	a0,s3
    80003b82:	f7dff0ef          	jal	80003afe <namecmp>
    80003b86:	f961                	bnez	a0,80003b56 <dirlookup+0x42>
      if(poff)
    80003b88:	000a0463          	beqz	s4,80003b90 <dirlookup+0x7c>
        *poff = off;
    80003b8c:	009a2023          	sw	s1,0(s4)
      return iget(dp->dev, inum);
    80003b90:	fc045583          	lhu	a1,-64(s0)
    80003b94:	00092503          	lw	a0,0(s2)
    80003b98:	f58ff0ef          	jal	800032f0 <iget>
    80003b9c:	a011                	j	80003ba0 <dirlookup+0x8c>
  return 0;
    80003b9e:	4501                	li	a0,0
}
    80003ba0:	70e2                	ld	ra,56(sp)
    80003ba2:	7442                	ld	s0,48(sp)
    80003ba4:	74a2                	ld	s1,40(sp)
    80003ba6:	7902                	ld	s2,32(sp)
    80003ba8:	69e2                	ld	s3,24(sp)
    80003baa:	6a42                	ld	s4,16(sp)
    80003bac:	6121                	addi	sp,sp,64
    80003bae:	8082                	ret

0000000080003bb0 <namex>:
// If parent != 0, return the inode for the parent and copy the final
// path element into name, which must have room for DIRSIZ bytes.
// Must be called inside a transaction since it calls iput().
static struct inode*
namex(char *path, int nameiparent, char *name)
{
    80003bb0:	711d                	addi	sp,sp,-96
    80003bb2:	ec86                	sd	ra,88(sp)
    80003bb4:	e8a2                	sd	s0,80(sp)
    80003bb6:	e4a6                	sd	s1,72(sp)
    80003bb8:	e0ca                	sd	s2,64(sp)
    80003bba:	fc4e                	sd	s3,56(sp)
    80003bbc:	f852                	sd	s4,48(sp)
    80003bbe:	f456                	sd	s5,40(sp)
    80003bc0:	f05a                	sd	s6,32(sp)
    80003bc2:	ec5e                	sd	s7,24(sp)
    80003bc4:	e862                	sd	s8,16(sp)
    80003bc6:	e466                	sd	s9,8(sp)
    80003bc8:	1080                	addi	s0,sp,96
    80003bca:	84aa                	mv	s1,a0
    80003bcc:	8b2e                	mv	s6,a1
    80003bce:	8ab2                	mv	s5,a2
  struct inode *ip, *next;

  if(*path == '/')
    80003bd0:	00054703          	lbu	a4,0(a0)
    80003bd4:	02f00793          	li	a5,47
    80003bd8:	00f70e63          	beq	a4,a5,80003bf4 <namex+0x44>
    ip = iget(ROOTDEV, ROOTINO);
  else
    ip = idup(myproc()->cwd);
    80003bdc:	cf3fd0ef          	jal	800018ce <myproc>
    80003be0:	15853503          	ld	a0,344(a0)
    80003be4:	94bff0ef          	jal	8000352e <idup>
    80003be8:	8a2a                	mv	s4,a0
  while(*path == '/')
    80003bea:	02f00913          	li	s2,47
  if(len >= DIRSIZ)
    80003bee:	4c35                	li	s8,13

  while((path = skipelem(path, name)) != 0){
    ilock(ip);
    if(ip->type != T_DIR){
    80003bf0:	4b85                	li	s7,1
    80003bf2:	a871                	j	80003c8e <namex+0xde>
    ip = iget(ROOTDEV, ROOTINO);
    80003bf4:	4585                	li	a1,1
    80003bf6:	4505                	li	a0,1
    80003bf8:	ef8ff0ef          	jal	800032f0 <iget>
    80003bfc:	8a2a                	mv	s4,a0
    80003bfe:	b7f5                	j	80003bea <namex+0x3a>
      iunlockput(ip);
    80003c00:	8552                	mv	a0,s4
    80003c02:	b6dff0ef          	jal	8000376e <iunlockput>
      return 0;
    80003c06:	4a01                	li	s4,0
  if(nameiparent){
    iput(ip);
    return 0;
  }
  return ip;
}
    80003c08:	8552                	mv	a0,s4
    80003c0a:	60e6                	ld	ra,88(sp)
    80003c0c:	6446                	ld	s0,80(sp)
    80003c0e:	64a6                	ld	s1,72(sp)
    80003c10:	6906                	ld	s2,64(sp)
    80003c12:	79e2                	ld	s3,56(sp)
    80003c14:	7a42                	ld	s4,48(sp)
    80003c16:	7aa2                	ld	s5,40(sp)
    80003c18:	7b02                	ld	s6,32(sp)
    80003c1a:	6be2                	ld	s7,24(sp)
    80003c1c:	6c42                	ld	s8,16(sp)
    80003c1e:	6ca2                	ld	s9,8(sp)
    80003c20:	6125                	addi	sp,sp,96
    80003c22:	8082                	ret
      iunlock(ip);
    80003c24:	8552                	mv	a0,s4
    80003c26:	9edff0ef          	jal	80003612 <iunlock>
      return ip;
    80003c2a:	bff9                	j	80003c08 <namex+0x58>
      iunlockput(ip);
    80003c2c:	8552                	mv	a0,s4
    80003c2e:	b41ff0ef          	jal	8000376e <iunlockput>
      return 0;
    80003c32:	8a4e                	mv	s4,s3
    80003c34:	bfd1                	j	80003c08 <namex+0x58>
  len = path - s;
    80003c36:	40998633          	sub	a2,s3,s1
    80003c3a:	00060c9b          	sext.w	s9,a2
  if(len >= DIRSIZ)
    80003c3e:	099c5063          	bge	s8,s9,80003cbe <namex+0x10e>
    memmove(name, s, DIRSIZ);
    80003c42:	4639                	li	a2,14
    80003c44:	85a6                	mv	a1,s1
    80003c46:	8556                	mv	a0,s5
    80003c48:	8b6fd0ef          	jal	80000cfe <memmove>
    80003c4c:	84ce                	mv	s1,s3
  while(*path == '/')
    80003c4e:	0004c783          	lbu	a5,0(s1)
    80003c52:	01279763          	bne	a5,s2,80003c60 <namex+0xb0>
    path++;
    80003c56:	0485                	addi	s1,s1,1
  while(*path == '/')
    80003c58:	0004c783          	lbu	a5,0(s1)
    80003c5c:	ff278de3          	beq	a5,s2,80003c56 <namex+0xa6>
    ilock(ip);
    80003c60:	8552                	mv	a0,s4
    80003c62:	903ff0ef          	jal	80003564 <ilock>
    if(ip->type != T_DIR){
    80003c66:	044a1783          	lh	a5,68(s4)
    80003c6a:	f9779be3          	bne	a5,s7,80003c00 <namex+0x50>
    if(nameiparent && *path == '\0'){
    80003c6e:	000b0563          	beqz	s6,80003c78 <namex+0xc8>
    80003c72:	0004c783          	lbu	a5,0(s1)
    80003c76:	d7dd                	beqz	a5,80003c24 <namex+0x74>
    if((next = dirlookup(ip, name, 0)) == 0){
    80003c78:	4601                	li	a2,0
    80003c7a:	85d6                	mv	a1,s5
    80003c7c:	8552                	mv	a0,s4
    80003c7e:	e97ff0ef          	jal	80003b14 <dirlookup>
    80003c82:	89aa                	mv	s3,a0
    80003c84:	d545                	beqz	a0,80003c2c <namex+0x7c>
    iunlockput(ip);
    80003c86:	8552                	mv	a0,s4
    80003c88:	ae7ff0ef          	jal	8000376e <iunlockput>
    ip = next;
    80003c8c:	8a4e                	mv	s4,s3
  while(*path == '/')
    80003c8e:	0004c783          	lbu	a5,0(s1)
    80003c92:	01279763          	bne	a5,s2,80003ca0 <namex+0xf0>
    path++;
    80003c96:	0485                	addi	s1,s1,1
  while(*path == '/')
    80003c98:	0004c783          	lbu	a5,0(s1)
    80003c9c:	ff278de3          	beq	a5,s2,80003c96 <namex+0xe6>
  if(*path == 0)
    80003ca0:	cb8d                	beqz	a5,80003cd2 <namex+0x122>
  while(*path != '/' && *path != 0)
    80003ca2:	0004c783          	lbu	a5,0(s1)
    80003ca6:	89a6                	mv	s3,s1
  len = path - s;
    80003ca8:	4c81                	li	s9,0
    80003caa:	4601                	li	a2,0
  while(*path != '/' && *path != 0)
    80003cac:	01278963          	beq	a5,s2,80003cbe <namex+0x10e>
    80003cb0:	d3d9                	beqz	a5,80003c36 <namex+0x86>
    path++;
    80003cb2:	0985                	addi	s3,s3,1
  while(*path != '/' && *path != 0)
    80003cb4:	0009c783          	lbu	a5,0(s3)
    80003cb8:	ff279ce3          	bne	a5,s2,80003cb0 <namex+0x100>
    80003cbc:	bfad                	j	80003c36 <namex+0x86>
    memmove(name, s, len);
    80003cbe:	2601                	sext.w	a2,a2
    80003cc0:	85a6                	mv	a1,s1
    80003cc2:	8556                	mv	a0,s5
    80003cc4:	83afd0ef          	jal	80000cfe <memmove>
    name[len] = 0;
    80003cc8:	9cd6                	add	s9,s9,s5
    80003cca:	000c8023          	sb	zero,0(s9) # 2000 <_entry-0x7fffe000>
    80003cce:	84ce                	mv	s1,s3
    80003cd0:	bfbd                	j	80003c4e <namex+0x9e>
  if(nameiparent){
    80003cd2:	f20b0be3          	beqz	s6,80003c08 <namex+0x58>
    iput(ip);
    80003cd6:	8552                	mv	a0,s4
    80003cd8:	a0fff0ef          	jal	800036e6 <iput>
    return 0;
    80003cdc:	4a01                	li	s4,0
    80003cde:	b72d                	j	80003c08 <namex+0x58>

0000000080003ce0 <dirlink>:
{
    80003ce0:	7139                	addi	sp,sp,-64
    80003ce2:	fc06                	sd	ra,56(sp)
    80003ce4:	f822                	sd	s0,48(sp)
    80003ce6:	f04a                	sd	s2,32(sp)
    80003ce8:	ec4e                	sd	s3,24(sp)
    80003cea:	e852                	sd	s4,16(sp)
    80003cec:	0080                	addi	s0,sp,64
    80003cee:	892a                	mv	s2,a0
    80003cf0:	8a2e                	mv	s4,a1
    80003cf2:	89b2                	mv	s3,a2
  if((ip = dirlookup(dp, name, 0)) != 0){
    80003cf4:	4601                	li	a2,0
    80003cf6:	e1fff0ef          	jal	80003b14 <dirlookup>
    80003cfa:	e535                	bnez	a0,80003d66 <dirlink+0x86>
    80003cfc:	f426                	sd	s1,40(sp)
  for(off = 0; off < dp->size; off += sizeof(de)){
    80003cfe:	04c92483          	lw	s1,76(s2)
    80003d02:	c48d                	beqz	s1,80003d2c <dirlink+0x4c>
    80003d04:	4481                	li	s1,0
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80003d06:	4741                	li	a4,16
    80003d08:	86a6                	mv	a3,s1
    80003d0a:	fc040613          	addi	a2,s0,-64
    80003d0e:	4581                	li	a1,0
    80003d10:	854a                	mv	a0,s2
    80003d12:	be3ff0ef          	jal	800038f4 <readi>
    80003d16:	47c1                	li	a5,16
    80003d18:	04f51b63          	bne	a0,a5,80003d6e <dirlink+0x8e>
    if(de.inum == 0)
    80003d1c:	fc045783          	lhu	a5,-64(s0)
    80003d20:	c791                	beqz	a5,80003d2c <dirlink+0x4c>
  for(off = 0; off < dp->size; off += sizeof(de)){
    80003d22:	24c1                	addiw	s1,s1,16
    80003d24:	04c92783          	lw	a5,76(s2)
    80003d28:	fcf4efe3          	bltu	s1,a5,80003d06 <dirlink+0x26>
  strncpy(de.name, name, DIRSIZ);
    80003d2c:	4639                	li	a2,14
    80003d2e:	85d2                	mv	a1,s4
    80003d30:	fc240513          	addi	a0,s0,-62
    80003d34:	870fd0ef          	jal	80000da4 <strncpy>
  de.inum = inum;
    80003d38:	fd341023          	sh	s3,-64(s0)
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80003d3c:	4741                	li	a4,16
    80003d3e:	86a6                	mv	a3,s1
    80003d40:	fc040613          	addi	a2,s0,-64
    80003d44:	4581                	li	a1,0
    80003d46:	854a                	mv	a0,s2
    80003d48:	ca9ff0ef          	jal	800039f0 <writei>
    80003d4c:	1541                	addi	a0,a0,-16
    80003d4e:	00a03533          	snez	a0,a0
    80003d52:	40a00533          	neg	a0,a0
    80003d56:	74a2                	ld	s1,40(sp)
}
    80003d58:	70e2                	ld	ra,56(sp)
    80003d5a:	7442                	ld	s0,48(sp)
    80003d5c:	7902                	ld	s2,32(sp)
    80003d5e:	69e2                	ld	s3,24(sp)
    80003d60:	6a42                	ld	s4,16(sp)
    80003d62:	6121                	addi	sp,sp,64
    80003d64:	8082                	ret
    iput(ip);
    80003d66:	981ff0ef          	jal	800036e6 <iput>
    return -1;
    80003d6a:	557d                	li	a0,-1
    80003d6c:	b7f5                	j	80003d58 <dirlink+0x78>
      panic("dirlink read");
    80003d6e:	00004517          	auipc	a0,0x4
    80003d72:	86250513          	addi	a0,a0,-1950 # 800075d0 <etext+0x5d0>
    80003d76:	a6bfc0ef          	jal	800007e0 <panic>

0000000080003d7a <namei>:

struct inode*
namei(char *path)
{
    80003d7a:	1101                	addi	sp,sp,-32
    80003d7c:	ec06                	sd	ra,24(sp)
    80003d7e:	e822                	sd	s0,16(sp)
    80003d80:	1000                	addi	s0,sp,32
  char name[DIRSIZ];
  return namex(path, 0, name);
    80003d82:	fe040613          	addi	a2,s0,-32
    80003d86:	4581                	li	a1,0
    80003d88:	e29ff0ef          	jal	80003bb0 <namex>
}
    80003d8c:	60e2                	ld	ra,24(sp)
    80003d8e:	6442                	ld	s0,16(sp)
    80003d90:	6105                	addi	sp,sp,32
    80003d92:	8082                	ret

0000000080003d94 <nameiparent>:

struct inode*
nameiparent(char *path, char *name)
{
    80003d94:	1141                	addi	sp,sp,-16
    80003d96:	e406                	sd	ra,8(sp)
    80003d98:	e022                	sd	s0,0(sp)
    80003d9a:	0800                	addi	s0,sp,16
    80003d9c:	862e                	mv	a2,a1
  return namex(path, 1, name);
    80003d9e:	4585                	li	a1,1
    80003da0:	e11ff0ef          	jal	80003bb0 <namex>
}
    80003da4:	60a2                	ld	ra,8(sp)
    80003da6:	6402                	ld	s0,0(sp)
    80003da8:	0141                	addi	sp,sp,16
    80003daa:	8082                	ret

0000000080003dac <write_head>:
// Write in-memory log header to disk.
// This is the true point at which the
// current transaction commits.
static void
write_head(void)
{
    80003dac:	1101                	addi	sp,sp,-32
    80003dae:	ec06                	sd	ra,24(sp)
    80003db0:	e822                	sd	s0,16(sp)
    80003db2:	e426                	sd	s1,8(sp)
    80003db4:	e04a                	sd	s2,0(sp)
    80003db6:	1000                	addi	s0,sp,32
  struct buf *buf = bread(log.dev, log.start);
    80003db8:	0001f917          	auipc	s2,0x1f
    80003dbc:	be090913          	addi	s2,s2,-1056 # 80022998 <log>
    80003dc0:	01892583          	lw	a1,24(s2)
    80003dc4:	02492503          	lw	a0,36(s2)
    80003dc8:	8d0ff0ef          	jal	80002e98 <bread>
    80003dcc:	84aa                	mv	s1,a0
  struct logheader *hb = (struct logheader *) (buf->data);
  int i;
  hb->n = log.lh.n;
    80003dce:	02892603          	lw	a2,40(s2)
    80003dd2:	cd30                	sw	a2,88(a0)
  for (i = 0; i < log.lh.n; i++) {
    80003dd4:	00c05f63          	blez	a2,80003df2 <write_head+0x46>
    80003dd8:	0001f717          	auipc	a4,0x1f
    80003ddc:	bec70713          	addi	a4,a4,-1044 # 800229c4 <log+0x2c>
    80003de0:	87aa                	mv	a5,a0
    80003de2:	060a                	slli	a2,a2,0x2
    80003de4:	962a                	add	a2,a2,a0
    hb->block[i] = log.lh.block[i];
    80003de6:	4314                	lw	a3,0(a4)
    80003de8:	cff4                	sw	a3,92(a5)
  for (i = 0; i < log.lh.n; i++) {
    80003dea:	0711                	addi	a4,a4,4
    80003dec:	0791                	addi	a5,a5,4
    80003dee:	fec79ce3          	bne	a5,a2,80003de6 <write_head+0x3a>
  }
  bwrite(buf);
    80003df2:	8526                	mv	a0,s1
    80003df4:	97aff0ef          	jal	80002f6e <bwrite>
  brelse(buf);
    80003df8:	8526                	mv	a0,s1
    80003dfa:	9a6ff0ef          	jal	80002fa0 <brelse>
}
    80003dfe:	60e2                	ld	ra,24(sp)
    80003e00:	6442                	ld	s0,16(sp)
    80003e02:	64a2                	ld	s1,8(sp)
    80003e04:	6902                	ld	s2,0(sp)
    80003e06:	6105                	addi	sp,sp,32
    80003e08:	8082                	ret

0000000080003e0a <install_trans>:
  for (tail = 0; tail < log.lh.n; tail++) {
    80003e0a:	0001f797          	auipc	a5,0x1f
    80003e0e:	bb67a783          	lw	a5,-1098(a5) # 800229c0 <log+0x28>
    80003e12:	0af05e63          	blez	a5,80003ece <install_trans+0xc4>
{
    80003e16:	715d                	addi	sp,sp,-80
    80003e18:	e486                	sd	ra,72(sp)
    80003e1a:	e0a2                	sd	s0,64(sp)
    80003e1c:	fc26                	sd	s1,56(sp)
    80003e1e:	f84a                	sd	s2,48(sp)
    80003e20:	f44e                	sd	s3,40(sp)
    80003e22:	f052                	sd	s4,32(sp)
    80003e24:	ec56                	sd	s5,24(sp)
    80003e26:	e85a                	sd	s6,16(sp)
    80003e28:	e45e                	sd	s7,8(sp)
    80003e2a:	0880                	addi	s0,sp,80
    80003e2c:	8b2a                	mv	s6,a0
    80003e2e:	0001fa97          	auipc	s5,0x1f
    80003e32:	b96a8a93          	addi	s5,s5,-1130 # 800229c4 <log+0x2c>
  for (tail = 0; tail < log.lh.n; tail++) {
    80003e36:	4981                	li	s3,0
      printf("recovering tail %d dst %d\n", tail, log.lh.block[tail]);
    80003e38:	00003b97          	auipc	s7,0x3
    80003e3c:	7a8b8b93          	addi	s7,s7,1960 # 800075e0 <etext+0x5e0>
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    80003e40:	0001fa17          	auipc	s4,0x1f
    80003e44:	b58a0a13          	addi	s4,s4,-1192 # 80022998 <log>
    80003e48:	a025                	j	80003e70 <install_trans+0x66>
      printf("recovering tail %d dst %d\n", tail, log.lh.block[tail]);
    80003e4a:	000aa603          	lw	a2,0(s5)
    80003e4e:	85ce                	mv	a1,s3
    80003e50:	855e                	mv	a0,s7
    80003e52:	ea8fc0ef          	jal	800004fa <printf>
    80003e56:	a839                	j	80003e74 <install_trans+0x6a>
    brelse(lbuf);
    80003e58:	854a                	mv	a0,s2
    80003e5a:	946ff0ef          	jal	80002fa0 <brelse>
    brelse(dbuf);
    80003e5e:	8526                	mv	a0,s1
    80003e60:	940ff0ef          	jal	80002fa0 <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    80003e64:	2985                	addiw	s3,s3,1
    80003e66:	0a91                	addi	s5,s5,4
    80003e68:	028a2783          	lw	a5,40(s4)
    80003e6c:	04f9d663          	bge	s3,a5,80003eb8 <install_trans+0xae>
    if(recovering) {
    80003e70:	fc0b1de3          	bnez	s6,80003e4a <install_trans+0x40>
    struct buf *lbuf = bread(log.dev, log.start+tail+1); // read log block
    80003e74:	018a2583          	lw	a1,24(s4)
    80003e78:	013585bb          	addw	a1,a1,s3
    80003e7c:	2585                	addiw	a1,a1,1
    80003e7e:	024a2503          	lw	a0,36(s4)
    80003e82:	816ff0ef          	jal	80002e98 <bread>
    80003e86:	892a                	mv	s2,a0
    struct buf *dbuf = bread(log.dev, log.lh.block[tail]); // read dst
    80003e88:	000aa583          	lw	a1,0(s5)
    80003e8c:	024a2503          	lw	a0,36(s4)
    80003e90:	808ff0ef          	jal	80002e98 <bread>
    80003e94:	84aa                	mv	s1,a0
    memmove(dbuf->data, lbuf->data, BSIZE);  // copy block to dst
    80003e96:	40000613          	li	a2,1024
    80003e9a:	05890593          	addi	a1,s2,88
    80003e9e:	05850513          	addi	a0,a0,88
    80003ea2:	e5dfc0ef          	jal	80000cfe <memmove>
    bwrite(dbuf);  // write dst to disk
    80003ea6:	8526                	mv	a0,s1
    80003ea8:	8c6ff0ef          	jal	80002f6e <bwrite>
    if(recovering == 0)
    80003eac:	fa0b16e3          	bnez	s6,80003e58 <install_trans+0x4e>
      bunpin(dbuf);
    80003eb0:	8526                	mv	a0,s1
    80003eb2:	9aaff0ef          	jal	8000305c <bunpin>
    80003eb6:	b74d                	j	80003e58 <install_trans+0x4e>
}
    80003eb8:	60a6                	ld	ra,72(sp)
    80003eba:	6406                	ld	s0,64(sp)
    80003ebc:	74e2                	ld	s1,56(sp)
    80003ebe:	7942                	ld	s2,48(sp)
    80003ec0:	79a2                	ld	s3,40(sp)
    80003ec2:	7a02                	ld	s4,32(sp)
    80003ec4:	6ae2                	ld	s5,24(sp)
    80003ec6:	6b42                	ld	s6,16(sp)
    80003ec8:	6ba2                	ld	s7,8(sp)
    80003eca:	6161                	addi	sp,sp,80
    80003ecc:	8082                	ret
    80003ece:	8082                	ret

0000000080003ed0 <initlog>:
{
    80003ed0:	7179                	addi	sp,sp,-48
    80003ed2:	f406                	sd	ra,40(sp)
    80003ed4:	f022                	sd	s0,32(sp)
    80003ed6:	ec26                	sd	s1,24(sp)
    80003ed8:	e84a                	sd	s2,16(sp)
    80003eda:	e44e                	sd	s3,8(sp)
    80003edc:	1800                	addi	s0,sp,48
    80003ede:	892a                	mv	s2,a0
    80003ee0:	89ae                	mv	s3,a1
  initlock(&log.lock, "log");
    80003ee2:	0001f497          	auipc	s1,0x1f
    80003ee6:	ab648493          	addi	s1,s1,-1354 # 80022998 <log>
    80003eea:	00003597          	auipc	a1,0x3
    80003eee:	71658593          	addi	a1,a1,1814 # 80007600 <etext+0x600>
    80003ef2:	8526                	mv	a0,s1
    80003ef4:	c5bfc0ef          	jal	80000b4e <initlock>
  log.start = sb->logstart;
    80003ef8:	0149a583          	lw	a1,20(s3)
    80003efc:	cc8c                	sw	a1,24(s1)
  log.dev = dev;
    80003efe:	0324a223          	sw	s2,36(s1)
  struct buf *buf = bread(log.dev, log.start);
    80003f02:	854a                	mv	a0,s2
    80003f04:	f95fe0ef          	jal	80002e98 <bread>
  log.lh.n = lh->n;
    80003f08:	4d30                	lw	a2,88(a0)
    80003f0a:	d490                	sw	a2,40(s1)
  for (i = 0; i < log.lh.n; i++) {
    80003f0c:	00c05f63          	blez	a2,80003f2a <initlog+0x5a>
    80003f10:	87aa                	mv	a5,a0
    80003f12:	0001f717          	auipc	a4,0x1f
    80003f16:	ab270713          	addi	a4,a4,-1358 # 800229c4 <log+0x2c>
    80003f1a:	060a                	slli	a2,a2,0x2
    80003f1c:	962a                	add	a2,a2,a0
    log.lh.block[i] = lh->block[i];
    80003f1e:	4ff4                	lw	a3,92(a5)
    80003f20:	c314                	sw	a3,0(a4)
  for (i = 0; i < log.lh.n; i++) {
    80003f22:	0791                	addi	a5,a5,4
    80003f24:	0711                	addi	a4,a4,4
    80003f26:	fec79ce3          	bne	a5,a2,80003f1e <initlog+0x4e>
  brelse(buf);
    80003f2a:	876ff0ef          	jal	80002fa0 <brelse>

static void
recover_from_log(void)
{
  read_head();
  install_trans(1); // if committed, copy from log to disk
    80003f2e:	4505                	li	a0,1
    80003f30:	edbff0ef          	jal	80003e0a <install_trans>
  log.lh.n = 0;
    80003f34:	0001f797          	auipc	a5,0x1f
    80003f38:	a807a623          	sw	zero,-1396(a5) # 800229c0 <log+0x28>
  write_head(); // clear the log
    80003f3c:	e71ff0ef          	jal	80003dac <write_head>
}
    80003f40:	70a2                	ld	ra,40(sp)
    80003f42:	7402                	ld	s0,32(sp)
    80003f44:	64e2                	ld	s1,24(sp)
    80003f46:	6942                	ld	s2,16(sp)
    80003f48:	69a2                	ld	s3,8(sp)
    80003f4a:	6145                	addi	sp,sp,48
    80003f4c:	8082                	ret

0000000080003f4e <begin_op>:
}

// called at the start of each FS system call.
void
begin_op(void)
{
    80003f4e:	1101                	addi	sp,sp,-32
    80003f50:	ec06                	sd	ra,24(sp)
    80003f52:	e822                	sd	s0,16(sp)
    80003f54:	e426                	sd	s1,8(sp)
    80003f56:	e04a                	sd	s2,0(sp)
    80003f58:	1000                	addi	s0,sp,32
  acquire(&log.lock);
    80003f5a:	0001f517          	auipc	a0,0x1f
    80003f5e:	a3e50513          	addi	a0,a0,-1474 # 80022998 <log>
    80003f62:	c6dfc0ef          	jal	80000bce <acquire>
  while(1){
    if(log.committing){
    80003f66:	0001f497          	auipc	s1,0x1f
    80003f6a:	a3248493          	addi	s1,s1,-1486 # 80022998 <log>
      sleep(&log, &log.lock);
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGBLOCKS){
    80003f6e:	4979                	li	s2,30
    80003f70:	a029                	j	80003f7a <begin_op+0x2c>
      sleep(&log, &log.lock);
    80003f72:	85a6                	mv	a1,s1
    80003f74:	8526                	mv	a0,s1
    80003f76:	fddfd0ef          	jal	80001f52 <sleep>
    if(log.committing){
    80003f7a:	509c                	lw	a5,32(s1)
    80003f7c:	fbfd                	bnez	a5,80003f72 <begin_op+0x24>
    } else if(log.lh.n + (log.outstanding+1)*MAXOPBLOCKS > LOGBLOCKS){
    80003f7e:	4cd8                	lw	a4,28(s1)
    80003f80:	2705                	addiw	a4,a4,1
    80003f82:	0027179b          	slliw	a5,a4,0x2
    80003f86:	9fb9                	addw	a5,a5,a4
    80003f88:	0017979b          	slliw	a5,a5,0x1
    80003f8c:	5494                	lw	a3,40(s1)
    80003f8e:	9fb5                	addw	a5,a5,a3
    80003f90:	00f95763          	bge	s2,a5,80003f9e <begin_op+0x50>
      // this op might exhaust log space; wait for commit.
      sleep(&log, &log.lock);
    80003f94:	85a6                	mv	a1,s1
    80003f96:	8526                	mv	a0,s1
    80003f98:	fbbfd0ef          	jal	80001f52 <sleep>
    80003f9c:	bff9                	j	80003f7a <begin_op+0x2c>
    } else {
      log.outstanding += 1;
    80003f9e:	0001f517          	auipc	a0,0x1f
    80003fa2:	9fa50513          	addi	a0,a0,-1542 # 80022998 <log>
    80003fa6:	cd58                	sw	a4,28(a0)
      release(&log.lock);
    80003fa8:	cbffc0ef          	jal	80000c66 <release>
      break;
    }
  }
}
    80003fac:	60e2                	ld	ra,24(sp)
    80003fae:	6442                	ld	s0,16(sp)
    80003fb0:	64a2                	ld	s1,8(sp)
    80003fb2:	6902                	ld	s2,0(sp)
    80003fb4:	6105                	addi	sp,sp,32
    80003fb6:	8082                	ret

0000000080003fb8 <end_op>:

// called at the end of each FS system call.
// commits if this was the last outstanding operation.
void
end_op(void)
{
    80003fb8:	7139                	addi	sp,sp,-64
    80003fba:	fc06                	sd	ra,56(sp)
    80003fbc:	f822                	sd	s0,48(sp)
    80003fbe:	f426                	sd	s1,40(sp)
    80003fc0:	f04a                	sd	s2,32(sp)
    80003fc2:	0080                	addi	s0,sp,64
  int do_commit = 0;

  acquire(&log.lock);
    80003fc4:	0001f497          	auipc	s1,0x1f
    80003fc8:	9d448493          	addi	s1,s1,-1580 # 80022998 <log>
    80003fcc:	8526                	mv	a0,s1
    80003fce:	c01fc0ef          	jal	80000bce <acquire>
  log.outstanding -= 1;
    80003fd2:	4cdc                	lw	a5,28(s1)
    80003fd4:	37fd                	addiw	a5,a5,-1
    80003fd6:	0007891b          	sext.w	s2,a5
    80003fda:	ccdc                	sw	a5,28(s1)
  if(log.committing)
    80003fdc:	509c                	lw	a5,32(s1)
    80003fde:	ef9d                	bnez	a5,8000401c <end_op+0x64>
    panic("log.committing");
  if(log.outstanding == 0){
    80003fe0:	04091763          	bnez	s2,8000402e <end_op+0x76>
    do_commit = 1;
    log.committing = 1;
    80003fe4:	0001f497          	auipc	s1,0x1f
    80003fe8:	9b448493          	addi	s1,s1,-1612 # 80022998 <log>
    80003fec:	4785                	li	a5,1
    80003fee:	d09c                	sw	a5,32(s1)
    // begin_op() may be waiting for log space,
    // and decrementing log.outstanding has decreased
    // the amount of reserved space.
    wakeup(&log);
  }
  release(&log.lock);
    80003ff0:	8526                	mv	a0,s1
    80003ff2:	c75fc0ef          	jal	80000c66 <release>
}

static void
commit()
{
  if (log.lh.n > 0) {
    80003ff6:	549c                	lw	a5,40(s1)
    80003ff8:	04f04b63          	bgtz	a5,8000404e <end_op+0x96>
    acquire(&log.lock);
    80003ffc:	0001f497          	auipc	s1,0x1f
    80004000:	99c48493          	addi	s1,s1,-1636 # 80022998 <log>
    80004004:	8526                	mv	a0,s1
    80004006:	bc9fc0ef          	jal	80000bce <acquire>
    log.committing = 0;
    8000400a:	0204a023          	sw	zero,32(s1)
    wakeup(&log);
    8000400e:	8526                	mv	a0,s1
    80004010:	f8ffd0ef          	jal	80001f9e <wakeup>
    release(&log.lock);
    80004014:	8526                	mv	a0,s1
    80004016:	c51fc0ef          	jal	80000c66 <release>
}
    8000401a:	a025                	j	80004042 <end_op+0x8a>
    8000401c:	ec4e                	sd	s3,24(sp)
    8000401e:	e852                	sd	s4,16(sp)
    80004020:	e456                	sd	s5,8(sp)
    panic("log.committing");
    80004022:	00003517          	auipc	a0,0x3
    80004026:	5e650513          	addi	a0,a0,1510 # 80007608 <etext+0x608>
    8000402a:	fb6fc0ef          	jal	800007e0 <panic>
    wakeup(&log);
    8000402e:	0001f497          	auipc	s1,0x1f
    80004032:	96a48493          	addi	s1,s1,-1686 # 80022998 <log>
    80004036:	8526                	mv	a0,s1
    80004038:	f67fd0ef          	jal	80001f9e <wakeup>
  release(&log.lock);
    8000403c:	8526                	mv	a0,s1
    8000403e:	c29fc0ef          	jal	80000c66 <release>
}
    80004042:	70e2                	ld	ra,56(sp)
    80004044:	7442                	ld	s0,48(sp)
    80004046:	74a2                	ld	s1,40(sp)
    80004048:	7902                	ld	s2,32(sp)
    8000404a:	6121                	addi	sp,sp,64
    8000404c:	8082                	ret
    8000404e:	ec4e                	sd	s3,24(sp)
    80004050:	e852                	sd	s4,16(sp)
    80004052:	e456                	sd	s5,8(sp)
  for (tail = 0; tail < log.lh.n; tail++) {
    80004054:	0001fa97          	auipc	s5,0x1f
    80004058:	970a8a93          	addi	s5,s5,-1680 # 800229c4 <log+0x2c>
    struct buf *to = bread(log.dev, log.start+tail+1); // log block
    8000405c:	0001fa17          	auipc	s4,0x1f
    80004060:	93ca0a13          	addi	s4,s4,-1732 # 80022998 <log>
    80004064:	018a2583          	lw	a1,24(s4)
    80004068:	012585bb          	addw	a1,a1,s2
    8000406c:	2585                	addiw	a1,a1,1
    8000406e:	024a2503          	lw	a0,36(s4)
    80004072:	e27fe0ef          	jal	80002e98 <bread>
    80004076:	84aa                	mv	s1,a0
    struct buf *from = bread(log.dev, log.lh.block[tail]); // cache block
    80004078:	000aa583          	lw	a1,0(s5)
    8000407c:	024a2503          	lw	a0,36(s4)
    80004080:	e19fe0ef          	jal	80002e98 <bread>
    80004084:	89aa                	mv	s3,a0
    memmove(to->data, from->data, BSIZE);
    80004086:	40000613          	li	a2,1024
    8000408a:	05850593          	addi	a1,a0,88
    8000408e:	05848513          	addi	a0,s1,88
    80004092:	c6dfc0ef          	jal	80000cfe <memmove>
    bwrite(to);  // write the log
    80004096:	8526                	mv	a0,s1
    80004098:	ed7fe0ef          	jal	80002f6e <bwrite>
    brelse(from);
    8000409c:	854e                	mv	a0,s3
    8000409e:	f03fe0ef          	jal	80002fa0 <brelse>
    brelse(to);
    800040a2:	8526                	mv	a0,s1
    800040a4:	efdfe0ef          	jal	80002fa0 <brelse>
  for (tail = 0; tail < log.lh.n; tail++) {
    800040a8:	2905                	addiw	s2,s2,1
    800040aa:	0a91                	addi	s5,s5,4
    800040ac:	028a2783          	lw	a5,40(s4)
    800040b0:	faf94ae3          	blt	s2,a5,80004064 <end_op+0xac>
    write_log();     // Write modified blocks from cache to log
    write_head();    // Write header to disk -- the real commit
    800040b4:	cf9ff0ef          	jal	80003dac <write_head>
    install_trans(0); // Now install writes to home locations
    800040b8:	4501                	li	a0,0
    800040ba:	d51ff0ef          	jal	80003e0a <install_trans>
    log.lh.n = 0;
    800040be:	0001f797          	auipc	a5,0x1f
    800040c2:	9007a123          	sw	zero,-1790(a5) # 800229c0 <log+0x28>
    write_head();    // Erase the transaction from the log
    800040c6:	ce7ff0ef          	jal	80003dac <write_head>
    800040ca:	69e2                	ld	s3,24(sp)
    800040cc:	6a42                	ld	s4,16(sp)
    800040ce:	6aa2                	ld	s5,8(sp)
    800040d0:	b735                	j	80003ffc <end_op+0x44>

00000000800040d2 <log_write>:
//   modify bp->data[]
//   log_write(bp)
//   brelse(bp)
void
log_write(struct buf *b)
{
    800040d2:	1101                	addi	sp,sp,-32
    800040d4:	ec06                	sd	ra,24(sp)
    800040d6:	e822                	sd	s0,16(sp)
    800040d8:	e426                	sd	s1,8(sp)
    800040da:	e04a                	sd	s2,0(sp)
    800040dc:	1000                	addi	s0,sp,32
    800040de:	84aa                	mv	s1,a0
  int i;

  acquire(&log.lock);
    800040e0:	0001f917          	auipc	s2,0x1f
    800040e4:	8b890913          	addi	s2,s2,-1864 # 80022998 <log>
    800040e8:	854a                	mv	a0,s2
    800040ea:	ae5fc0ef          	jal	80000bce <acquire>
  if (log.lh.n >= LOGBLOCKS)
    800040ee:	02892603          	lw	a2,40(s2)
    800040f2:	47f5                	li	a5,29
    800040f4:	04c7cc63          	blt	a5,a2,8000414c <log_write+0x7a>
    panic("too big a transaction");
  if (log.outstanding < 1)
    800040f8:	0001f797          	auipc	a5,0x1f
    800040fc:	8bc7a783          	lw	a5,-1860(a5) # 800229b4 <log+0x1c>
    80004100:	04f05c63          	blez	a5,80004158 <log_write+0x86>
    panic("log_write outside of trans");

  for (i = 0; i < log.lh.n; i++) {
    80004104:	4781                	li	a5,0
    80004106:	04c05f63          	blez	a2,80004164 <log_write+0x92>
    if (log.lh.block[i] == b->blockno)   // log absorption
    8000410a:	44cc                	lw	a1,12(s1)
    8000410c:	0001f717          	auipc	a4,0x1f
    80004110:	8b870713          	addi	a4,a4,-1864 # 800229c4 <log+0x2c>
  for (i = 0; i < log.lh.n; i++) {
    80004114:	4781                	li	a5,0
    if (log.lh.block[i] == b->blockno)   // log absorption
    80004116:	4314                	lw	a3,0(a4)
    80004118:	04b68663          	beq	a3,a1,80004164 <log_write+0x92>
  for (i = 0; i < log.lh.n; i++) {
    8000411c:	2785                	addiw	a5,a5,1
    8000411e:	0711                	addi	a4,a4,4
    80004120:	fef61be3          	bne	a2,a5,80004116 <log_write+0x44>
      break;
  }
  log.lh.block[i] = b->blockno;
    80004124:	0621                	addi	a2,a2,8
    80004126:	060a                	slli	a2,a2,0x2
    80004128:	0001f797          	auipc	a5,0x1f
    8000412c:	87078793          	addi	a5,a5,-1936 # 80022998 <log>
    80004130:	97b2                	add	a5,a5,a2
    80004132:	44d8                	lw	a4,12(s1)
    80004134:	c7d8                	sw	a4,12(a5)
  if (i == log.lh.n) {  // Add new block to log?
    bpin(b);
    80004136:	8526                	mv	a0,s1
    80004138:	ef1fe0ef          	jal	80003028 <bpin>
    log.lh.n++;
    8000413c:	0001f717          	auipc	a4,0x1f
    80004140:	85c70713          	addi	a4,a4,-1956 # 80022998 <log>
    80004144:	571c                	lw	a5,40(a4)
    80004146:	2785                	addiw	a5,a5,1
    80004148:	d71c                	sw	a5,40(a4)
    8000414a:	a80d                	j	8000417c <log_write+0xaa>
    panic("too big a transaction");
    8000414c:	00003517          	auipc	a0,0x3
    80004150:	4cc50513          	addi	a0,a0,1228 # 80007618 <etext+0x618>
    80004154:	e8cfc0ef          	jal	800007e0 <panic>
    panic("log_write outside of trans");
    80004158:	00003517          	auipc	a0,0x3
    8000415c:	4d850513          	addi	a0,a0,1240 # 80007630 <etext+0x630>
    80004160:	e80fc0ef          	jal	800007e0 <panic>
  log.lh.block[i] = b->blockno;
    80004164:	00878693          	addi	a3,a5,8
    80004168:	068a                	slli	a3,a3,0x2
    8000416a:	0001f717          	auipc	a4,0x1f
    8000416e:	82e70713          	addi	a4,a4,-2002 # 80022998 <log>
    80004172:	9736                	add	a4,a4,a3
    80004174:	44d4                	lw	a3,12(s1)
    80004176:	c754                	sw	a3,12(a4)
  if (i == log.lh.n) {  // Add new block to log?
    80004178:	faf60fe3          	beq	a2,a5,80004136 <log_write+0x64>
  }
  release(&log.lock);
    8000417c:	0001f517          	auipc	a0,0x1f
    80004180:	81c50513          	addi	a0,a0,-2020 # 80022998 <log>
    80004184:	ae3fc0ef          	jal	80000c66 <release>
}
    80004188:	60e2                	ld	ra,24(sp)
    8000418a:	6442                	ld	s0,16(sp)
    8000418c:	64a2                	ld	s1,8(sp)
    8000418e:	6902                	ld	s2,0(sp)
    80004190:	6105                	addi	sp,sp,32
    80004192:	8082                	ret

0000000080004194 <initsleeplock>:
#include "proc.h"
#include "sleeplock.h"

void
initsleeplock(struct sleeplock *lk, char *name)
{
    80004194:	1101                	addi	sp,sp,-32
    80004196:	ec06                	sd	ra,24(sp)
    80004198:	e822                	sd	s0,16(sp)
    8000419a:	e426                	sd	s1,8(sp)
    8000419c:	e04a                	sd	s2,0(sp)
    8000419e:	1000                	addi	s0,sp,32
    800041a0:	84aa                	mv	s1,a0
    800041a2:	892e                	mv	s2,a1
  initlock(&lk->lk, "sleep lock");
    800041a4:	00003597          	auipc	a1,0x3
    800041a8:	4ac58593          	addi	a1,a1,1196 # 80007650 <etext+0x650>
    800041ac:	0521                	addi	a0,a0,8
    800041ae:	9a1fc0ef          	jal	80000b4e <initlock>
  lk->name = name;
    800041b2:	0324b023          	sd	s2,32(s1)
  lk->locked = 0;
    800041b6:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    800041ba:	0204a423          	sw	zero,40(s1)
}
    800041be:	60e2                	ld	ra,24(sp)
    800041c0:	6442                	ld	s0,16(sp)
    800041c2:	64a2                	ld	s1,8(sp)
    800041c4:	6902                	ld	s2,0(sp)
    800041c6:	6105                	addi	sp,sp,32
    800041c8:	8082                	ret

00000000800041ca <acquiresleep>:

void
acquiresleep(struct sleeplock *lk)
{
    800041ca:	1101                	addi	sp,sp,-32
    800041cc:	ec06                	sd	ra,24(sp)
    800041ce:	e822                	sd	s0,16(sp)
    800041d0:	e426                	sd	s1,8(sp)
    800041d2:	e04a                	sd	s2,0(sp)
    800041d4:	1000                	addi	s0,sp,32
    800041d6:	84aa                	mv	s1,a0
  acquire(&lk->lk);
    800041d8:	00850913          	addi	s2,a0,8
    800041dc:	854a                	mv	a0,s2
    800041de:	9f1fc0ef          	jal	80000bce <acquire>
  while (lk->locked) {
    800041e2:	409c                	lw	a5,0(s1)
    800041e4:	c799                	beqz	a5,800041f2 <acquiresleep+0x28>
    sleep(lk, &lk->lk);
    800041e6:	85ca                	mv	a1,s2
    800041e8:	8526                	mv	a0,s1
    800041ea:	d69fd0ef          	jal	80001f52 <sleep>
  while (lk->locked) {
    800041ee:	409c                	lw	a5,0(s1)
    800041f0:	fbfd                	bnez	a5,800041e6 <acquiresleep+0x1c>
  }
  lk->locked = 1;
    800041f2:	4785                	li	a5,1
    800041f4:	c09c                	sw	a5,0(s1)
  lk->pid = myproc()->pid;
    800041f6:	ed8fd0ef          	jal	800018ce <myproc>
    800041fa:	591c                	lw	a5,48(a0)
    800041fc:	d49c                	sw	a5,40(s1)
  release(&lk->lk);
    800041fe:	854a                	mv	a0,s2
    80004200:	a67fc0ef          	jal	80000c66 <release>
}
    80004204:	60e2                	ld	ra,24(sp)
    80004206:	6442                	ld	s0,16(sp)
    80004208:	64a2                	ld	s1,8(sp)
    8000420a:	6902                	ld	s2,0(sp)
    8000420c:	6105                	addi	sp,sp,32
    8000420e:	8082                	ret

0000000080004210 <releasesleep>:

void
releasesleep(struct sleeplock *lk)
{
    80004210:	1101                	addi	sp,sp,-32
    80004212:	ec06                	sd	ra,24(sp)
    80004214:	e822                	sd	s0,16(sp)
    80004216:	e426                	sd	s1,8(sp)
    80004218:	e04a                	sd	s2,0(sp)
    8000421a:	1000                	addi	s0,sp,32
    8000421c:	84aa                	mv	s1,a0
  acquire(&lk->lk);
    8000421e:	00850913          	addi	s2,a0,8
    80004222:	854a                	mv	a0,s2
    80004224:	9abfc0ef          	jal	80000bce <acquire>
  lk->locked = 0;
    80004228:	0004a023          	sw	zero,0(s1)
  lk->pid = 0;
    8000422c:	0204a423          	sw	zero,40(s1)
  wakeup(lk);
    80004230:	8526                	mv	a0,s1
    80004232:	d6dfd0ef          	jal	80001f9e <wakeup>
  release(&lk->lk);
    80004236:	854a                	mv	a0,s2
    80004238:	a2ffc0ef          	jal	80000c66 <release>
}
    8000423c:	60e2                	ld	ra,24(sp)
    8000423e:	6442                	ld	s0,16(sp)
    80004240:	64a2                	ld	s1,8(sp)
    80004242:	6902                	ld	s2,0(sp)
    80004244:	6105                	addi	sp,sp,32
    80004246:	8082                	ret

0000000080004248 <holdingsleep>:

int
holdingsleep(struct sleeplock *lk)
{
    80004248:	7179                	addi	sp,sp,-48
    8000424a:	f406                	sd	ra,40(sp)
    8000424c:	f022                	sd	s0,32(sp)
    8000424e:	ec26                	sd	s1,24(sp)
    80004250:	e84a                	sd	s2,16(sp)
    80004252:	1800                	addi	s0,sp,48
    80004254:	84aa                	mv	s1,a0
  int r;
  
  acquire(&lk->lk);
    80004256:	00850913          	addi	s2,a0,8
    8000425a:	854a                	mv	a0,s2
    8000425c:	973fc0ef          	jal	80000bce <acquire>
  r = lk->locked && (lk->pid == myproc()->pid);
    80004260:	409c                	lw	a5,0(s1)
    80004262:	ef81                	bnez	a5,8000427a <holdingsleep+0x32>
    80004264:	4481                	li	s1,0
  release(&lk->lk);
    80004266:	854a                	mv	a0,s2
    80004268:	9fffc0ef          	jal	80000c66 <release>
  return r;
}
    8000426c:	8526                	mv	a0,s1
    8000426e:	70a2                	ld	ra,40(sp)
    80004270:	7402                	ld	s0,32(sp)
    80004272:	64e2                	ld	s1,24(sp)
    80004274:	6942                	ld	s2,16(sp)
    80004276:	6145                	addi	sp,sp,48
    80004278:	8082                	ret
    8000427a:	e44e                	sd	s3,8(sp)
  r = lk->locked && (lk->pid == myproc()->pid);
    8000427c:	0284a983          	lw	s3,40(s1)
    80004280:	e4efd0ef          	jal	800018ce <myproc>
    80004284:	5904                	lw	s1,48(a0)
    80004286:	413484b3          	sub	s1,s1,s3
    8000428a:	0014b493          	seqz	s1,s1
    8000428e:	69a2                	ld	s3,8(sp)
    80004290:	bfd9                	j	80004266 <holdingsleep+0x1e>

0000000080004292 <fileinit>:
  struct file file[NFILE];
} ftable;

void
fileinit(void)
{
    80004292:	1141                	addi	sp,sp,-16
    80004294:	e406                	sd	ra,8(sp)
    80004296:	e022                	sd	s0,0(sp)
    80004298:	0800                	addi	s0,sp,16
  initlock(&ftable.lock, "ftable");
    8000429a:	00003597          	auipc	a1,0x3
    8000429e:	3c658593          	addi	a1,a1,966 # 80007660 <etext+0x660>
    800042a2:	0001f517          	auipc	a0,0x1f
    800042a6:	83e50513          	addi	a0,a0,-1986 # 80022ae0 <ftable>
    800042aa:	8a5fc0ef          	jal	80000b4e <initlock>
}
    800042ae:	60a2                	ld	ra,8(sp)
    800042b0:	6402                	ld	s0,0(sp)
    800042b2:	0141                	addi	sp,sp,16
    800042b4:	8082                	ret

00000000800042b6 <filealloc>:

// Allocate a file structure.
struct file*
filealloc(void)
{
    800042b6:	1101                	addi	sp,sp,-32
    800042b8:	ec06                	sd	ra,24(sp)
    800042ba:	e822                	sd	s0,16(sp)
    800042bc:	e426                	sd	s1,8(sp)
    800042be:	1000                	addi	s0,sp,32
  struct file *f;

  acquire(&ftable.lock);
    800042c0:	0001f517          	auipc	a0,0x1f
    800042c4:	82050513          	addi	a0,a0,-2016 # 80022ae0 <ftable>
    800042c8:	907fc0ef          	jal	80000bce <acquire>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    800042cc:	0001f497          	auipc	s1,0x1f
    800042d0:	82c48493          	addi	s1,s1,-2004 # 80022af8 <ftable+0x18>
    800042d4:	0001f717          	auipc	a4,0x1f
    800042d8:	7c470713          	addi	a4,a4,1988 # 80023a98 <disk>
    if(f->ref == 0){
    800042dc:	40dc                	lw	a5,4(s1)
    800042de:	cf89                	beqz	a5,800042f8 <filealloc+0x42>
  for(f = ftable.file; f < ftable.file + NFILE; f++){
    800042e0:	02848493          	addi	s1,s1,40
    800042e4:	fee49ce3          	bne	s1,a4,800042dc <filealloc+0x26>
      f->ref = 1;
      release(&ftable.lock);
      return f;
    }
  }
  release(&ftable.lock);
    800042e8:	0001e517          	auipc	a0,0x1e
    800042ec:	7f850513          	addi	a0,a0,2040 # 80022ae0 <ftable>
    800042f0:	977fc0ef          	jal	80000c66 <release>
  return 0;
    800042f4:	4481                	li	s1,0
    800042f6:	a809                	j	80004308 <filealloc+0x52>
      f->ref = 1;
    800042f8:	4785                	li	a5,1
    800042fa:	c0dc                	sw	a5,4(s1)
      release(&ftable.lock);
    800042fc:	0001e517          	auipc	a0,0x1e
    80004300:	7e450513          	addi	a0,a0,2020 # 80022ae0 <ftable>
    80004304:	963fc0ef          	jal	80000c66 <release>
}
    80004308:	8526                	mv	a0,s1
    8000430a:	60e2                	ld	ra,24(sp)
    8000430c:	6442                	ld	s0,16(sp)
    8000430e:	64a2                	ld	s1,8(sp)
    80004310:	6105                	addi	sp,sp,32
    80004312:	8082                	ret

0000000080004314 <filedup>:

// Increment ref count for file f.
struct file*
filedup(struct file *f)
{
    80004314:	1101                	addi	sp,sp,-32
    80004316:	ec06                	sd	ra,24(sp)
    80004318:	e822                	sd	s0,16(sp)
    8000431a:	e426                	sd	s1,8(sp)
    8000431c:	1000                	addi	s0,sp,32
    8000431e:	84aa                	mv	s1,a0
  acquire(&ftable.lock);
    80004320:	0001e517          	auipc	a0,0x1e
    80004324:	7c050513          	addi	a0,a0,1984 # 80022ae0 <ftable>
    80004328:	8a7fc0ef          	jal	80000bce <acquire>
  if(f->ref < 1)
    8000432c:	40dc                	lw	a5,4(s1)
    8000432e:	02f05063          	blez	a5,8000434e <filedup+0x3a>
    panic("filedup");
  f->ref++;
    80004332:	2785                	addiw	a5,a5,1
    80004334:	c0dc                	sw	a5,4(s1)
  release(&ftable.lock);
    80004336:	0001e517          	auipc	a0,0x1e
    8000433a:	7aa50513          	addi	a0,a0,1962 # 80022ae0 <ftable>
    8000433e:	929fc0ef          	jal	80000c66 <release>
  return f;
}
    80004342:	8526                	mv	a0,s1
    80004344:	60e2                	ld	ra,24(sp)
    80004346:	6442                	ld	s0,16(sp)
    80004348:	64a2                	ld	s1,8(sp)
    8000434a:	6105                	addi	sp,sp,32
    8000434c:	8082                	ret
    panic("filedup");
    8000434e:	00003517          	auipc	a0,0x3
    80004352:	31a50513          	addi	a0,a0,794 # 80007668 <etext+0x668>
    80004356:	c8afc0ef          	jal	800007e0 <panic>

000000008000435a <fileclose>:

// Close file f.  (Decrement ref count, close when reaches 0.)
void
fileclose(struct file *f)
{
    8000435a:	7139                	addi	sp,sp,-64
    8000435c:	fc06                	sd	ra,56(sp)
    8000435e:	f822                	sd	s0,48(sp)
    80004360:	f426                	sd	s1,40(sp)
    80004362:	0080                	addi	s0,sp,64
    80004364:	84aa                	mv	s1,a0
  struct file ff;

  acquire(&ftable.lock);
    80004366:	0001e517          	auipc	a0,0x1e
    8000436a:	77a50513          	addi	a0,a0,1914 # 80022ae0 <ftable>
    8000436e:	861fc0ef          	jal	80000bce <acquire>
  if(f->ref < 1)
    80004372:	40dc                	lw	a5,4(s1)
    80004374:	04f05a63          	blez	a5,800043c8 <fileclose+0x6e>
    panic("fileclose");
  if(--f->ref > 0){
    80004378:	37fd                	addiw	a5,a5,-1
    8000437a:	0007871b          	sext.w	a4,a5
    8000437e:	c0dc                	sw	a5,4(s1)
    80004380:	04e04e63          	bgtz	a4,800043dc <fileclose+0x82>
    80004384:	f04a                	sd	s2,32(sp)
    80004386:	ec4e                	sd	s3,24(sp)
    80004388:	e852                	sd	s4,16(sp)
    8000438a:	e456                	sd	s5,8(sp)
    release(&ftable.lock);
    return;
  }
  ff = *f;
    8000438c:	0004a903          	lw	s2,0(s1)
    80004390:	0094ca83          	lbu	s5,9(s1)
    80004394:	0104ba03          	ld	s4,16(s1)
    80004398:	0184b983          	ld	s3,24(s1)
  f->ref = 0;
    8000439c:	0004a223          	sw	zero,4(s1)
  f->type = FD_NONE;
    800043a0:	0004a023          	sw	zero,0(s1)
  release(&ftable.lock);
    800043a4:	0001e517          	auipc	a0,0x1e
    800043a8:	73c50513          	addi	a0,a0,1852 # 80022ae0 <ftable>
    800043ac:	8bbfc0ef          	jal	80000c66 <release>

  if(ff.type == FD_PIPE){
    800043b0:	4785                	li	a5,1
    800043b2:	04f90063          	beq	s2,a5,800043f2 <fileclose+0x98>
    pipeclose(ff.pipe, ff.writable);
  } else if(ff.type == FD_INODE || ff.type == FD_DEVICE){
    800043b6:	3979                	addiw	s2,s2,-2
    800043b8:	4785                	li	a5,1
    800043ba:	0527f563          	bgeu	a5,s2,80004404 <fileclose+0xaa>
    800043be:	7902                	ld	s2,32(sp)
    800043c0:	69e2                	ld	s3,24(sp)
    800043c2:	6a42                	ld	s4,16(sp)
    800043c4:	6aa2                	ld	s5,8(sp)
    800043c6:	a00d                	j	800043e8 <fileclose+0x8e>
    800043c8:	f04a                	sd	s2,32(sp)
    800043ca:	ec4e                	sd	s3,24(sp)
    800043cc:	e852                	sd	s4,16(sp)
    800043ce:	e456                	sd	s5,8(sp)
    panic("fileclose");
    800043d0:	00003517          	auipc	a0,0x3
    800043d4:	2a050513          	addi	a0,a0,672 # 80007670 <etext+0x670>
    800043d8:	c08fc0ef          	jal	800007e0 <panic>
    release(&ftable.lock);
    800043dc:	0001e517          	auipc	a0,0x1e
    800043e0:	70450513          	addi	a0,a0,1796 # 80022ae0 <ftable>
    800043e4:	883fc0ef          	jal	80000c66 <release>
    begin_op();
    iput(ff.ip);
    end_op();
  }
}
    800043e8:	70e2                	ld	ra,56(sp)
    800043ea:	7442                	ld	s0,48(sp)
    800043ec:	74a2                	ld	s1,40(sp)
    800043ee:	6121                	addi	sp,sp,64
    800043f0:	8082                	ret
    pipeclose(ff.pipe, ff.writable);
    800043f2:	85d6                	mv	a1,s5
    800043f4:	8552                	mv	a0,s4
    800043f6:	336000ef          	jal	8000472c <pipeclose>
    800043fa:	7902                	ld	s2,32(sp)
    800043fc:	69e2                	ld	s3,24(sp)
    800043fe:	6a42                	ld	s4,16(sp)
    80004400:	6aa2                	ld	s5,8(sp)
    80004402:	b7dd                	j	800043e8 <fileclose+0x8e>
    begin_op();
    80004404:	b4bff0ef          	jal	80003f4e <begin_op>
    iput(ff.ip);
    80004408:	854e                	mv	a0,s3
    8000440a:	adcff0ef          	jal	800036e6 <iput>
    end_op();
    8000440e:	babff0ef          	jal	80003fb8 <end_op>
    80004412:	7902                	ld	s2,32(sp)
    80004414:	69e2                	ld	s3,24(sp)
    80004416:	6a42                	ld	s4,16(sp)
    80004418:	6aa2                	ld	s5,8(sp)
    8000441a:	b7f9                	j	800043e8 <fileclose+0x8e>

000000008000441c <filestat>:

// Get metadata about file f.
// addr is a user virtual address, pointing to a struct stat.
int
filestat(struct file *f, uint64 addr)
{
    8000441c:	715d                	addi	sp,sp,-80
    8000441e:	e486                	sd	ra,72(sp)
    80004420:	e0a2                	sd	s0,64(sp)
    80004422:	fc26                	sd	s1,56(sp)
    80004424:	f44e                	sd	s3,40(sp)
    80004426:	0880                	addi	s0,sp,80
    80004428:	84aa                	mv	s1,a0
    8000442a:	89ae                	mv	s3,a1
  struct proc *p = myproc();
    8000442c:	ca2fd0ef          	jal	800018ce <myproc>
  struct stat st;
  
  if(f->type == FD_INODE || f->type == FD_DEVICE){
    80004430:	409c                	lw	a5,0(s1)
    80004432:	37f9                	addiw	a5,a5,-2
    80004434:	4705                	li	a4,1
    80004436:	04f76063          	bltu	a4,a5,80004476 <filestat+0x5a>
    8000443a:	f84a                	sd	s2,48(sp)
    8000443c:	892a                	mv	s2,a0
    ilock(f->ip);
    8000443e:	6c88                	ld	a0,24(s1)
    80004440:	924ff0ef          	jal	80003564 <ilock>
    stati(f->ip, &st);
    80004444:	fb840593          	addi	a1,s0,-72
    80004448:	6c88                	ld	a0,24(s1)
    8000444a:	c80ff0ef          	jal	800038ca <stati>
    iunlock(f->ip);
    8000444e:	6c88                	ld	a0,24(s1)
    80004450:	9c2ff0ef          	jal	80003612 <iunlock>
    if(copyout(p->pagetable, addr, (char *)&st, sizeof(st)) < 0)
    80004454:	46e1                	li	a3,24
    80004456:	fb840613          	addi	a2,s0,-72
    8000445a:	85ce                	mv	a1,s3
    8000445c:	05893503          	ld	a0,88(s2)
    80004460:	982fd0ef          	jal	800015e2 <copyout>
    80004464:	41f5551b          	sraiw	a0,a0,0x1f
    80004468:	7942                	ld	s2,48(sp)
      return -1;
    return 0;
  }
  return -1;
}
    8000446a:	60a6                	ld	ra,72(sp)
    8000446c:	6406                	ld	s0,64(sp)
    8000446e:	74e2                	ld	s1,56(sp)
    80004470:	79a2                	ld	s3,40(sp)
    80004472:	6161                	addi	sp,sp,80
    80004474:	8082                	ret
  return -1;
    80004476:	557d                	li	a0,-1
    80004478:	bfcd                	j	8000446a <filestat+0x4e>

000000008000447a <fileread>:

// Read from file f.
// addr is a user virtual address.
int
fileread(struct file *f, uint64 addr, int n)
{
    8000447a:	7179                	addi	sp,sp,-48
    8000447c:	f406                	sd	ra,40(sp)
    8000447e:	f022                	sd	s0,32(sp)
    80004480:	e84a                	sd	s2,16(sp)
    80004482:	1800                	addi	s0,sp,48
  int r = 0;

  if(f->readable == 0)
    80004484:	00854783          	lbu	a5,8(a0)
    80004488:	cfd1                	beqz	a5,80004524 <fileread+0xaa>
    8000448a:	ec26                	sd	s1,24(sp)
    8000448c:	e44e                	sd	s3,8(sp)
    8000448e:	84aa                	mv	s1,a0
    80004490:	89ae                	mv	s3,a1
    80004492:	8932                	mv	s2,a2
    return -1;

  if(f->type == FD_PIPE){
    80004494:	411c                	lw	a5,0(a0)
    80004496:	4705                	li	a4,1
    80004498:	04e78363          	beq	a5,a4,800044de <fileread+0x64>
    r = piperead(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    8000449c:	470d                	li	a4,3
    8000449e:	04e78763          	beq	a5,a4,800044ec <fileread+0x72>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
      return -1;
    r = devsw[f->major].read(1, addr, n);
  } else if(f->type == FD_INODE){
    800044a2:	4709                	li	a4,2
    800044a4:	06e79a63          	bne	a5,a4,80004518 <fileread+0x9e>
    ilock(f->ip);
    800044a8:	6d08                	ld	a0,24(a0)
    800044aa:	8baff0ef          	jal	80003564 <ilock>
    if((r = readi(f->ip, 1, addr, f->off, n)) > 0)
    800044ae:	874a                	mv	a4,s2
    800044b0:	5094                	lw	a3,32(s1)
    800044b2:	864e                	mv	a2,s3
    800044b4:	4585                	li	a1,1
    800044b6:	6c88                	ld	a0,24(s1)
    800044b8:	c3cff0ef          	jal	800038f4 <readi>
    800044bc:	892a                	mv	s2,a0
    800044be:	00a05563          	blez	a0,800044c8 <fileread+0x4e>
      f->off += r;
    800044c2:	509c                	lw	a5,32(s1)
    800044c4:	9fa9                	addw	a5,a5,a0
    800044c6:	d09c                	sw	a5,32(s1)
    iunlock(f->ip);
    800044c8:	6c88                	ld	a0,24(s1)
    800044ca:	948ff0ef          	jal	80003612 <iunlock>
    800044ce:	64e2                	ld	s1,24(sp)
    800044d0:	69a2                	ld	s3,8(sp)
  } else {
    panic("fileread");
  }

  return r;
}
    800044d2:	854a                	mv	a0,s2
    800044d4:	70a2                	ld	ra,40(sp)
    800044d6:	7402                	ld	s0,32(sp)
    800044d8:	6942                	ld	s2,16(sp)
    800044da:	6145                	addi	sp,sp,48
    800044dc:	8082                	ret
    r = piperead(f->pipe, addr, n);
    800044de:	6908                	ld	a0,16(a0)
    800044e0:	388000ef          	jal	80004868 <piperead>
    800044e4:	892a                	mv	s2,a0
    800044e6:	64e2                	ld	s1,24(sp)
    800044e8:	69a2                	ld	s3,8(sp)
    800044ea:	b7e5                	j	800044d2 <fileread+0x58>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].read)
    800044ec:	02451783          	lh	a5,36(a0)
    800044f0:	03079693          	slli	a3,a5,0x30
    800044f4:	92c1                	srli	a3,a3,0x30
    800044f6:	4725                	li	a4,9
    800044f8:	02d76863          	bltu	a4,a3,80004528 <fileread+0xae>
    800044fc:	0792                	slli	a5,a5,0x4
    800044fe:	0001e717          	auipc	a4,0x1e
    80004502:	54270713          	addi	a4,a4,1346 # 80022a40 <devsw>
    80004506:	97ba                	add	a5,a5,a4
    80004508:	639c                	ld	a5,0(a5)
    8000450a:	c39d                	beqz	a5,80004530 <fileread+0xb6>
    r = devsw[f->major].read(1, addr, n);
    8000450c:	4505                	li	a0,1
    8000450e:	9782                	jalr	a5
    80004510:	892a                	mv	s2,a0
    80004512:	64e2                	ld	s1,24(sp)
    80004514:	69a2                	ld	s3,8(sp)
    80004516:	bf75                	j	800044d2 <fileread+0x58>
    panic("fileread");
    80004518:	00003517          	auipc	a0,0x3
    8000451c:	16850513          	addi	a0,a0,360 # 80007680 <etext+0x680>
    80004520:	ac0fc0ef          	jal	800007e0 <panic>
    return -1;
    80004524:	597d                	li	s2,-1
    80004526:	b775                	j	800044d2 <fileread+0x58>
      return -1;
    80004528:	597d                	li	s2,-1
    8000452a:	64e2                	ld	s1,24(sp)
    8000452c:	69a2                	ld	s3,8(sp)
    8000452e:	b755                	j	800044d2 <fileread+0x58>
    80004530:	597d                	li	s2,-1
    80004532:	64e2                	ld	s1,24(sp)
    80004534:	69a2                	ld	s3,8(sp)
    80004536:	bf71                	j	800044d2 <fileread+0x58>

0000000080004538 <filewrite>:
int
filewrite(struct file *f, uint64 addr, int n)
{
  int r, ret = 0;

  if(f->writable == 0)
    80004538:	00954783          	lbu	a5,9(a0)
    8000453c:	10078b63          	beqz	a5,80004652 <filewrite+0x11a>
{
    80004540:	715d                	addi	sp,sp,-80
    80004542:	e486                	sd	ra,72(sp)
    80004544:	e0a2                	sd	s0,64(sp)
    80004546:	f84a                	sd	s2,48(sp)
    80004548:	f052                	sd	s4,32(sp)
    8000454a:	e85a                	sd	s6,16(sp)
    8000454c:	0880                	addi	s0,sp,80
    8000454e:	892a                	mv	s2,a0
    80004550:	8b2e                	mv	s6,a1
    80004552:	8a32                	mv	s4,a2
    return -1;

  if(f->type == FD_PIPE){
    80004554:	411c                	lw	a5,0(a0)
    80004556:	4705                	li	a4,1
    80004558:	02e78763          	beq	a5,a4,80004586 <filewrite+0x4e>
    ret = pipewrite(f->pipe, addr, n);
  } else if(f->type == FD_DEVICE){
    8000455c:	470d                	li	a4,3
    8000455e:	02e78863          	beq	a5,a4,8000458e <filewrite+0x56>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
      return -1;
    ret = devsw[f->major].write(1, addr, n);
  } else if(f->type == FD_INODE){
    80004562:	4709                	li	a4,2
    80004564:	0ce79c63          	bne	a5,a4,8000463c <filewrite+0x104>
    80004568:	f44e                	sd	s3,40(sp)
    // the maximum log transaction size, including
    // i-node, indirect block, allocation blocks,
    // and 2 blocks of slop for non-aligned writes.
    int max = ((MAXOPBLOCKS-1-1-2) / 2) * BSIZE;
    int i = 0;
    while(i < n){
    8000456a:	0ac05863          	blez	a2,8000461a <filewrite+0xe2>
    8000456e:	fc26                	sd	s1,56(sp)
    80004570:	ec56                	sd	s5,24(sp)
    80004572:	e45e                	sd	s7,8(sp)
    80004574:	e062                	sd	s8,0(sp)
    int i = 0;
    80004576:	4981                	li	s3,0
      int n1 = n - i;
      if(n1 > max)
    80004578:	6b85                	lui	s7,0x1
    8000457a:	c00b8b93          	addi	s7,s7,-1024 # c00 <_entry-0x7ffff400>
    8000457e:	6c05                	lui	s8,0x1
    80004580:	c00c0c1b          	addiw	s8,s8,-1024 # c00 <_entry-0x7ffff400>
    80004584:	a8b5                	j	80004600 <filewrite+0xc8>
    ret = pipewrite(f->pipe, addr, n);
    80004586:	6908                	ld	a0,16(a0)
    80004588:	1fc000ef          	jal	80004784 <pipewrite>
    8000458c:	a04d                	j	8000462e <filewrite+0xf6>
    if(f->major < 0 || f->major >= NDEV || !devsw[f->major].write)
    8000458e:	02451783          	lh	a5,36(a0)
    80004592:	03079693          	slli	a3,a5,0x30
    80004596:	92c1                	srli	a3,a3,0x30
    80004598:	4725                	li	a4,9
    8000459a:	0ad76e63          	bltu	a4,a3,80004656 <filewrite+0x11e>
    8000459e:	0792                	slli	a5,a5,0x4
    800045a0:	0001e717          	auipc	a4,0x1e
    800045a4:	4a070713          	addi	a4,a4,1184 # 80022a40 <devsw>
    800045a8:	97ba                	add	a5,a5,a4
    800045aa:	679c                	ld	a5,8(a5)
    800045ac:	c7dd                	beqz	a5,8000465a <filewrite+0x122>
    ret = devsw[f->major].write(1, addr, n);
    800045ae:	4505                	li	a0,1
    800045b0:	9782                	jalr	a5
    800045b2:	a8b5                	j	8000462e <filewrite+0xf6>
      if(n1 > max)
    800045b4:	00048a9b          	sext.w	s5,s1
        n1 = max;

      begin_op();
    800045b8:	997ff0ef          	jal	80003f4e <begin_op>
      ilock(f->ip);
    800045bc:	01893503          	ld	a0,24(s2)
    800045c0:	fa5fe0ef          	jal	80003564 <ilock>
      if ((r = writei(f->ip, 1, addr + i, f->off, n1)) > 0)
    800045c4:	8756                	mv	a4,s5
    800045c6:	02092683          	lw	a3,32(s2)
    800045ca:	01698633          	add	a2,s3,s6
    800045ce:	4585                	li	a1,1
    800045d0:	01893503          	ld	a0,24(s2)
    800045d4:	c1cff0ef          	jal	800039f0 <writei>
    800045d8:	84aa                	mv	s1,a0
    800045da:	00a05763          	blez	a0,800045e8 <filewrite+0xb0>
        f->off += r;
    800045de:	02092783          	lw	a5,32(s2)
    800045e2:	9fa9                	addw	a5,a5,a0
    800045e4:	02f92023          	sw	a5,32(s2)
      iunlock(f->ip);
    800045e8:	01893503          	ld	a0,24(s2)
    800045ec:	826ff0ef          	jal	80003612 <iunlock>
      end_op();
    800045f0:	9c9ff0ef          	jal	80003fb8 <end_op>

      if(r != n1){
    800045f4:	029a9563          	bne	s5,s1,8000461e <filewrite+0xe6>
        // error from writei
        break;
      }
      i += r;
    800045f8:	013489bb          	addw	s3,s1,s3
    while(i < n){
    800045fc:	0149da63          	bge	s3,s4,80004610 <filewrite+0xd8>
      int n1 = n - i;
    80004600:	413a04bb          	subw	s1,s4,s3
      if(n1 > max)
    80004604:	0004879b          	sext.w	a5,s1
    80004608:	fafbd6e3          	bge	s7,a5,800045b4 <filewrite+0x7c>
    8000460c:	84e2                	mv	s1,s8
    8000460e:	b75d                	j	800045b4 <filewrite+0x7c>
    80004610:	74e2                	ld	s1,56(sp)
    80004612:	6ae2                	ld	s5,24(sp)
    80004614:	6ba2                	ld	s7,8(sp)
    80004616:	6c02                	ld	s8,0(sp)
    80004618:	a039                	j	80004626 <filewrite+0xee>
    int i = 0;
    8000461a:	4981                	li	s3,0
    8000461c:	a029                	j	80004626 <filewrite+0xee>
    8000461e:	74e2                	ld	s1,56(sp)
    80004620:	6ae2                	ld	s5,24(sp)
    80004622:	6ba2                	ld	s7,8(sp)
    80004624:	6c02                	ld	s8,0(sp)
    }
    ret = (i == n ? n : -1);
    80004626:	033a1c63          	bne	s4,s3,8000465e <filewrite+0x126>
    8000462a:	8552                	mv	a0,s4
    8000462c:	79a2                	ld	s3,40(sp)
  } else {
    panic("filewrite");
  }

  return ret;
}
    8000462e:	60a6                	ld	ra,72(sp)
    80004630:	6406                	ld	s0,64(sp)
    80004632:	7942                	ld	s2,48(sp)
    80004634:	7a02                	ld	s4,32(sp)
    80004636:	6b42                	ld	s6,16(sp)
    80004638:	6161                	addi	sp,sp,80
    8000463a:	8082                	ret
    8000463c:	fc26                	sd	s1,56(sp)
    8000463e:	f44e                	sd	s3,40(sp)
    80004640:	ec56                	sd	s5,24(sp)
    80004642:	e45e                	sd	s7,8(sp)
    80004644:	e062                	sd	s8,0(sp)
    panic("filewrite");
    80004646:	00003517          	auipc	a0,0x3
    8000464a:	04a50513          	addi	a0,a0,74 # 80007690 <etext+0x690>
    8000464e:	992fc0ef          	jal	800007e0 <panic>
    return -1;
    80004652:	557d                	li	a0,-1
}
    80004654:	8082                	ret
      return -1;
    80004656:	557d                	li	a0,-1
    80004658:	bfd9                	j	8000462e <filewrite+0xf6>
    8000465a:	557d                	li	a0,-1
    8000465c:	bfc9                	j	8000462e <filewrite+0xf6>
    ret = (i == n ? n : -1);
    8000465e:	557d                	li	a0,-1
    80004660:	79a2                	ld	s3,40(sp)
    80004662:	b7f1                	j	8000462e <filewrite+0xf6>

0000000080004664 <pipealloc>:
  int writeopen;  // write fd is still open
};

int
pipealloc(struct file **f0, struct file **f1)
{
    80004664:	7179                	addi	sp,sp,-48
    80004666:	f406                	sd	ra,40(sp)
    80004668:	f022                	sd	s0,32(sp)
    8000466a:	ec26                	sd	s1,24(sp)
    8000466c:	e052                	sd	s4,0(sp)
    8000466e:	1800                	addi	s0,sp,48
    80004670:	84aa                	mv	s1,a0
    80004672:	8a2e                	mv	s4,a1
  struct pipe *pi;

  pi = 0;
  *f0 = *f1 = 0;
    80004674:	0005b023          	sd	zero,0(a1)
    80004678:	00053023          	sd	zero,0(a0)
  if((*f0 = filealloc()) == 0 || (*f1 = filealloc()) == 0)
    8000467c:	c3bff0ef          	jal	800042b6 <filealloc>
    80004680:	e088                	sd	a0,0(s1)
    80004682:	c549                	beqz	a0,8000470c <pipealloc+0xa8>
    80004684:	c33ff0ef          	jal	800042b6 <filealloc>
    80004688:	00aa3023          	sd	a0,0(s4)
    8000468c:	cd25                	beqz	a0,80004704 <pipealloc+0xa0>
    8000468e:	e84a                	sd	s2,16(sp)
    goto bad;
  if((pi = (struct pipe*)kalloc()) == 0)
    80004690:	c6efc0ef          	jal	80000afe <kalloc>
    80004694:	892a                	mv	s2,a0
    80004696:	c12d                	beqz	a0,800046f8 <pipealloc+0x94>
    80004698:	e44e                	sd	s3,8(sp)
    goto bad;
  pi->readopen = 1;
    8000469a:	4985                	li	s3,1
    8000469c:	23352023          	sw	s3,544(a0)
  pi->writeopen = 1;
    800046a0:	23352223          	sw	s3,548(a0)
  pi->nwrite = 0;
    800046a4:	20052e23          	sw	zero,540(a0)
  pi->nread = 0;
    800046a8:	20052c23          	sw	zero,536(a0)
  initlock(&pi->lock, "pipe");
    800046ac:	00003597          	auipc	a1,0x3
    800046b0:	d6458593          	addi	a1,a1,-668 # 80007410 <etext+0x410>
    800046b4:	c9afc0ef          	jal	80000b4e <initlock>
  (*f0)->type = FD_PIPE;
    800046b8:	609c                	ld	a5,0(s1)
    800046ba:	0137a023          	sw	s3,0(a5)
  (*f0)->readable = 1;
    800046be:	609c                	ld	a5,0(s1)
    800046c0:	01378423          	sb	s3,8(a5)
  (*f0)->writable = 0;
    800046c4:	609c                	ld	a5,0(s1)
    800046c6:	000784a3          	sb	zero,9(a5)
  (*f0)->pipe = pi;
    800046ca:	609c                	ld	a5,0(s1)
    800046cc:	0127b823          	sd	s2,16(a5)
  (*f1)->type = FD_PIPE;
    800046d0:	000a3783          	ld	a5,0(s4)
    800046d4:	0137a023          	sw	s3,0(a5)
  (*f1)->readable = 0;
    800046d8:	000a3783          	ld	a5,0(s4)
    800046dc:	00078423          	sb	zero,8(a5)
  (*f1)->writable = 1;
    800046e0:	000a3783          	ld	a5,0(s4)
    800046e4:	013784a3          	sb	s3,9(a5)
  (*f1)->pipe = pi;
    800046e8:	000a3783          	ld	a5,0(s4)
    800046ec:	0127b823          	sd	s2,16(a5)
  return 0;
    800046f0:	4501                	li	a0,0
    800046f2:	6942                	ld	s2,16(sp)
    800046f4:	69a2                	ld	s3,8(sp)
    800046f6:	a01d                	j	8000471c <pipealloc+0xb8>

 bad:
  if(pi)
    kfree((char*)pi);
  if(*f0)
    800046f8:	6088                	ld	a0,0(s1)
    800046fa:	c119                	beqz	a0,80004700 <pipealloc+0x9c>
    800046fc:	6942                	ld	s2,16(sp)
    800046fe:	a029                	j	80004708 <pipealloc+0xa4>
    80004700:	6942                	ld	s2,16(sp)
    80004702:	a029                	j	8000470c <pipealloc+0xa8>
    80004704:	6088                	ld	a0,0(s1)
    80004706:	c10d                	beqz	a0,80004728 <pipealloc+0xc4>
    fileclose(*f0);
    80004708:	c53ff0ef          	jal	8000435a <fileclose>
  if(*f1)
    8000470c:	000a3783          	ld	a5,0(s4)
    fileclose(*f1);
  return -1;
    80004710:	557d                	li	a0,-1
  if(*f1)
    80004712:	c789                	beqz	a5,8000471c <pipealloc+0xb8>
    fileclose(*f1);
    80004714:	853e                	mv	a0,a5
    80004716:	c45ff0ef          	jal	8000435a <fileclose>
  return -1;
    8000471a:	557d                	li	a0,-1
}
    8000471c:	70a2                	ld	ra,40(sp)
    8000471e:	7402                	ld	s0,32(sp)
    80004720:	64e2                	ld	s1,24(sp)
    80004722:	6a02                	ld	s4,0(sp)
    80004724:	6145                	addi	sp,sp,48
    80004726:	8082                	ret
  return -1;
    80004728:	557d                	li	a0,-1
    8000472a:	bfcd                	j	8000471c <pipealloc+0xb8>

000000008000472c <pipeclose>:

void
pipeclose(struct pipe *pi, int writable)
{
    8000472c:	1101                	addi	sp,sp,-32
    8000472e:	ec06                	sd	ra,24(sp)
    80004730:	e822                	sd	s0,16(sp)
    80004732:	e426                	sd	s1,8(sp)
    80004734:	e04a                	sd	s2,0(sp)
    80004736:	1000                	addi	s0,sp,32
    80004738:	84aa                	mv	s1,a0
    8000473a:	892e                	mv	s2,a1
  acquire(&pi->lock);
    8000473c:	c92fc0ef          	jal	80000bce <acquire>
  if(writable){
    80004740:	02090763          	beqz	s2,8000476e <pipeclose+0x42>
    pi->writeopen = 0;
    80004744:	2204a223          	sw	zero,548(s1)
    wakeup(&pi->nread);
    80004748:	21848513          	addi	a0,s1,536
    8000474c:	853fd0ef          	jal	80001f9e <wakeup>
  } else {
    pi->readopen = 0;
    wakeup(&pi->nwrite);
  }
  if(pi->readopen == 0 && pi->writeopen == 0){
    80004750:	2204b783          	ld	a5,544(s1)
    80004754:	e785                	bnez	a5,8000477c <pipeclose+0x50>
    release(&pi->lock);
    80004756:	8526                	mv	a0,s1
    80004758:	d0efc0ef          	jal	80000c66 <release>
    kfree((char*)pi);
    8000475c:	8526                	mv	a0,s1
    8000475e:	abefc0ef          	jal	80000a1c <kfree>
  } else
    release(&pi->lock);
}
    80004762:	60e2                	ld	ra,24(sp)
    80004764:	6442                	ld	s0,16(sp)
    80004766:	64a2                	ld	s1,8(sp)
    80004768:	6902                	ld	s2,0(sp)
    8000476a:	6105                	addi	sp,sp,32
    8000476c:	8082                	ret
    pi->readopen = 0;
    8000476e:	2204a023          	sw	zero,544(s1)
    wakeup(&pi->nwrite);
    80004772:	21c48513          	addi	a0,s1,540
    80004776:	829fd0ef          	jal	80001f9e <wakeup>
    8000477a:	bfd9                	j	80004750 <pipeclose+0x24>
    release(&pi->lock);
    8000477c:	8526                	mv	a0,s1
    8000477e:	ce8fc0ef          	jal	80000c66 <release>
}
    80004782:	b7c5                	j	80004762 <pipeclose+0x36>

0000000080004784 <pipewrite>:

int
pipewrite(struct pipe *pi, uint64 addr, int n)
{
    80004784:	711d                	addi	sp,sp,-96
    80004786:	ec86                	sd	ra,88(sp)
    80004788:	e8a2                	sd	s0,80(sp)
    8000478a:	e4a6                	sd	s1,72(sp)
    8000478c:	e0ca                	sd	s2,64(sp)
    8000478e:	fc4e                	sd	s3,56(sp)
    80004790:	f852                	sd	s4,48(sp)
    80004792:	f456                	sd	s5,40(sp)
    80004794:	1080                	addi	s0,sp,96
    80004796:	84aa                	mv	s1,a0
    80004798:	8aae                	mv	s5,a1
    8000479a:	8a32                	mv	s4,a2
  int i = 0;
  struct proc *pr = myproc();
    8000479c:	932fd0ef          	jal	800018ce <myproc>
    800047a0:	89aa                	mv	s3,a0

  acquire(&pi->lock);
    800047a2:	8526                	mv	a0,s1
    800047a4:	c2afc0ef          	jal	80000bce <acquire>
  while(i < n){
    800047a8:	0b405a63          	blez	s4,8000485c <pipewrite+0xd8>
    800047ac:	f05a                	sd	s6,32(sp)
    800047ae:	ec5e                	sd	s7,24(sp)
    800047b0:	e862                	sd	s8,16(sp)
  int i = 0;
    800047b2:	4901                	li	s2,0
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
      wakeup(&pi->nread);
      sleep(&pi->nwrite, &pi->lock);
    } else {
      char ch;
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    800047b4:	5b7d                	li	s6,-1
      wakeup(&pi->nread);
    800047b6:	21848c13          	addi	s8,s1,536
      sleep(&pi->nwrite, &pi->lock);
    800047ba:	21c48b93          	addi	s7,s1,540
    800047be:	a81d                	j	800047f4 <pipewrite+0x70>
      release(&pi->lock);
    800047c0:	8526                	mv	a0,s1
    800047c2:	ca4fc0ef          	jal	80000c66 <release>
      return -1;
    800047c6:	597d                	li	s2,-1
    800047c8:	7b02                	ld	s6,32(sp)
    800047ca:	6be2                	ld	s7,24(sp)
    800047cc:	6c42                	ld	s8,16(sp)
  }
  wakeup(&pi->nread);
  release(&pi->lock);

  return i;
}
    800047ce:	854a                	mv	a0,s2
    800047d0:	60e6                	ld	ra,88(sp)
    800047d2:	6446                	ld	s0,80(sp)
    800047d4:	64a6                	ld	s1,72(sp)
    800047d6:	6906                	ld	s2,64(sp)
    800047d8:	79e2                	ld	s3,56(sp)
    800047da:	7a42                	ld	s4,48(sp)
    800047dc:	7aa2                	ld	s5,40(sp)
    800047de:	6125                	addi	sp,sp,96
    800047e0:	8082                	ret
      wakeup(&pi->nread);
    800047e2:	8562                	mv	a0,s8
    800047e4:	fbafd0ef          	jal	80001f9e <wakeup>
      sleep(&pi->nwrite, &pi->lock);
    800047e8:	85a6                	mv	a1,s1
    800047ea:	855e                	mv	a0,s7
    800047ec:	f66fd0ef          	jal	80001f52 <sleep>
  while(i < n){
    800047f0:	05495b63          	bge	s2,s4,80004846 <pipewrite+0xc2>
    if(pi->readopen == 0 || killed(pr)){
    800047f4:	2204a783          	lw	a5,544(s1)
    800047f8:	d7e1                	beqz	a5,800047c0 <pipewrite+0x3c>
    800047fa:	854e                	mv	a0,s3
    800047fc:	98ffd0ef          	jal	8000218a <killed>
    80004800:	f161                	bnez	a0,800047c0 <pipewrite+0x3c>
    if(pi->nwrite == pi->nread + PIPESIZE){ //DOC: pipewrite-full
    80004802:	2184a783          	lw	a5,536(s1)
    80004806:	21c4a703          	lw	a4,540(s1)
    8000480a:	2007879b          	addiw	a5,a5,512
    8000480e:	fcf70ae3          	beq	a4,a5,800047e2 <pipewrite+0x5e>
      if(copyin(pr->pagetable, &ch, addr + i, 1) == -1)
    80004812:	4685                	li	a3,1
    80004814:	01590633          	add	a2,s2,s5
    80004818:	faf40593          	addi	a1,s0,-81
    8000481c:	0589b503          	ld	a0,88(s3)
    80004820:	ea7fc0ef          	jal	800016c6 <copyin>
    80004824:	03650e63          	beq	a0,s6,80004860 <pipewrite+0xdc>
      pi->data[pi->nwrite++ % PIPESIZE] = ch;
    80004828:	21c4a783          	lw	a5,540(s1)
    8000482c:	0017871b          	addiw	a4,a5,1
    80004830:	20e4ae23          	sw	a4,540(s1)
    80004834:	1ff7f793          	andi	a5,a5,511
    80004838:	97a6                	add	a5,a5,s1
    8000483a:	faf44703          	lbu	a4,-81(s0)
    8000483e:	00e78c23          	sb	a4,24(a5)
      i++;
    80004842:	2905                	addiw	s2,s2,1
    80004844:	b775                	j	800047f0 <pipewrite+0x6c>
    80004846:	7b02                	ld	s6,32(sp)
    80004848:	6be2                	ld	s7,24(sp)
    8000484a:	6c42                	ld	s8,16(sp)
  wakeup(&pi->nread);
    8000484c:	21848513          	addi	a0,s1,536
    80004850:	f4efd0ef          	jal	80001f9e <wakeup>
  release(&pi->lock);
    80004854:	8526                	mv	a0,s1
    80004856:	c10fc0ef          	jal	80000c66 <release>
  return i;
    8000485a:	bf95                	j	800047ce <pipewrite+0x4a>
  int i = 0;
    8000485c:	4901                	li	s2,0
    8000485e:	b7fd                	j	8000484c <pipewrite+0xc8>
    80004860:	7b02                	ld	s6,32(sp)
    80004862:	6be2                	ld	s7,24(sp)
    80004864:	6c42                	ld	s8,16(sp)
    80004866:	b7dd                	j	8000484c <pipewrite+0xc8>

0000000080004868 <piperead>:

int
piperead(struct pipe *pi, uint64 addr, int n)
{
    80004868:	715d                	addi	sp,sp,-80
    8000486a:	e486                	sd	ra,72(sp)
    8000486c:	e0a2                	sd	s0,64(sp)
    8000486e:	fc26                	sd	s1,56(sp)
    80004870:	f84a                	sd	s2,48(sp)
    80004872:	f44e                	sd	s3,40(sp)
    80004874:	f052                	sd	s4,32(sp)
    80004876:	ec56                	sd	s5,24(sp)
    80004878:	0880                	addi	s0,sp,80
    8000487a:	84aa                	mv	s1,a0
    8000487c:	892e                	mv	s2,a1
    8000487e:	8ab2                	mv	s5,a2
  int i;
  struct proc *pr = myproc();
    80004880:	84efd0ef          	jal	800018ce <myproc>
    80004884:	8a2a                	mv	s4,a0
  char ch;

  acquire(&pi->lock);
    80004886:	8526                	mv	a0,s1
    80004888:	b46fc0ef          	jal	80000bce <acquire>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    8000488c:	2184a703          	lw	a4,536(s1)
    80004890:	21c4a783          	lw	a5,540(s1)
    if(killed(pr)){
      release(&pi->lock);
      return -1;
    }
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    80004894:	21848993          	addi	s3,s1,536
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    80004898:	02f71563          	bne	a4,a5,800048c2 <piperead+0x5a>
    8000489c:	2244a783          	lw	a5,548(s1)
    800048a0:	cb85                	beqz	a5,800048d0 <piperead+0x68>
    if(killed(pr)){
    800048a2:	8552                	mv	a0,s4
    800048a4:	8e7fd0ef          	jal	8000218a <killed>
    800048a8:	ed19                	bnez	a0,800048c6 <piperead+0x5e>
    sleep(&pi->nread, &pi->lock); //DOC: piperead-sleep
    800048aa:	85a6                	mv	a1,s1
    800048ac:	854e                	mv	a0,s3
    800048ae:	ea4fd0ef          	jal	80001f52 <sleep>
  while(pi->nread == pi->nwrite && pi->writeopen){  //DOC: pipe-empty
    800048b2:	2184a703          	lw	a4,536(s1)
    800048b6:	21c4a783          	lw	a5,540(s1)
    800048ba:	fef701e3          	beq	a4,a5,8000489c <piperead+0x34>
    800048be:	e85a                	sd	s6,16(sp)
    800048c0:	a809                	j	800048d2 <piperead+0x6a>
    800048c2:	e85a                	sd	s6,16(sp)
    800048c4:	a039                	j	800048d2 <piperead+0x6a>
      release(&pi->lock);
    800048c6:	8526                	mv	a0,s1
    800048c8:	b9efc0ef          	jal	80000c66 <release>
      return -1;
    800048cc:	59fd                	li	s3,-1
    800048ce:	a8b9                	j	8000492c <piperead+0xc4>
    800048d0:	e85a                	sd	s6,16(sp)
  }
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    800048d2:	4981                	li	s3,0
    if(pi->nread == pi->nwrite)
      break;
    ch = pi->data[pi->nread % PIPESIZE];
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1) {
    800048d4:	5b7d                	li	s6,-1
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    800048d6:	05505363          	blez	s5,8000491c <piperead+0xb4>
    if(pi->nread == pi->nwrite)
    800048da:	2184a783          	lw	a5,536(s1)
    800048de:	21c4a703          	lw	a4,540(s1)
    800048e2:	02f70d63          	beq	a4,a5,8000491c <piperead+0xb4>
    ch = pi->data[pi->nread % PIPESIZE];
    800048e6:	1ff7f793          	andi	a5,a5,511
    800048ea:	97a6                	add	a5,a5,s1
    800048ec:	0187c783          	lbu	a5,24(a5)
    800048f0:	faf40fa3          	sb	a5,-65(s0)
    if(copyout(pr->pagetable, addr + i, &ch, 1) == -1) {
    800048f4:	4685                	li	a3,1
    800048f6:	fbf40613          	addi	a2,s0,-65
    800048fa:	85ca                	mv	a1,s2
    800048fc:	058a3503          	ld	a0,88(s4)
    80004900:	ce3fc0ef          	jal	800015e2 <copyout>
    80004904:	03650e63          	beq	a0,s6,80004940 <piperead+0xd8>
      if(i == 0)
        i = -1;
      break;
    }
    pi->nread++;
    80004908:	2184a783          	lw	a5,536(s1)
    8000490c:	2785                	addiw	a5,a5,1
    8000490e:	20f4ac23          	sw	a5,536(s1)
  for(i = 0; i < n; i++){  //DOC: piperead-copy
    80004912:	2985                	addiw	s3,s3,1
    80004914:	0905                	addi	s2,s2,1
    80004916:	fd3a92e3          	bne	s5,s3,800048da <piperead+0x72>
    8000491a:	89d6                	mv	s3,s5
  }
  wakeup(&pi->nwrite);  //DOC: piperead-wakeup
    8000491c:	21c48513          	addi	a0,s1,540
    80004920:	e7efd0ef          	jal	80001f9e <wakeup>
  release(&pi->lock);
    80004924:	8526                	mv	a0,s1
    80004926:	b40fc0ef          	jal	80000c66 <release>
    8000492a:	6b42                	ld	s6,16(sp)
  return i;
}
    8000492c:	854e                	mv	a0,s3
    8000492e:	60a6                	ld	ra,72(sp)
    80004930:	6406                	ld	s0,64(sp)
    80004932:	74e2                	ld	s1,56(sp)
    80004934:	7942                	ld	s2,48(sp)
    80004936:	79a2                	ld	s3,40(sp)
    80004938:	7a02                	ld	s4,32(sp)
    8000493a:	6ae2                	ld	s5,24(sp)
    8000493c:	6161                	addi	sp,sp,80
    8000493e:	8082                	ret
      if(i == 0)
    80004940:	fc099ee3          	bnez	s3,8000491c <piperead+0xb4>
        i = -1;
    80004944:	89aa                	mv	s3,a0
    80004946:	bfd9                	j	8000491c <piperead+0xb4>

0000000080004948 <flags2perm>:

static int loadseg(pde_t *, uint64, struct inode *, uint, uint);

// map ELF permissions to PTE permission bits.
int flags2perm(int flags)
{
    80004948:	1141                	addi	sp,sp,-16
    8000494a:	e422                	sd	s0,8(sp)
    8000494c:	0800                	addi	s0,sp,16
    8000494e:	87aa                	mv	a5,a0
    int perm = 0;
    if(flags & 0x1)
    80004950:	8905                	andi	a0,a0,1
    80004952:	050e                	slli	a0,a0,0x3
      perm = PTE_X;
    if(flags & 0x2)
    80004954:	8b89                	andi	a5,a5,2
    80004956:	c399                	beqz	a5,8000495c <flags2perm+0x14>
      perm |= PTE_W;
    80004958:	00456513          	ori	a0,a0,4
    return perm;
}
    8000495c:	6422                	ld	s0,8(sp)
    8000495e:	0141                	addi	sp,sp,16
    80004960:	8082                	ret

0000000080004962 <kexec>:
//
// the implementation of the exec() system call
//
int
kexec(char *path, char **argv)
{
    80004962:	df010113          	addi	sp,sp,-528
    80004966:	20113423          	sd	ra,520(sp)
    8000496a:	20813023          	sd	s0,512(sp)
    8000496e:	ffa6                	sd	s1,504(sp)
    80004970:	fbca                	sd	s2,496(sp)
    80004972:	0c00                	addi	s0,sp,528
    80004974:	892a                	mv	s2,a0
    80004976:	dea43c23          	sd	a0,-520(s0)
    8000497a:	e0b43023          	sd	a1,-512(s0)
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
  struct elfhdr elf;
  struct inode *ip;
  struct proghdr ph;
  pagetable_t pagetable = 0, oldpagetable;
  struct proc *p = myproc();
    8000497e:	f51fc0ef          	jal	800018ce <myproc>
    80004982:	84aa                	mv	s1,a0

  begin_op();
    80004984:	dcaff0ef          	jal	80003f4e <begin_op>

  // Open the executable file.
  if((ip = namei(path)) == 0){
    80004988:	854a                	mv	a0,s2
    8000498a:	bf0ff0ef          	jal	80003d7a <namei>
    8000498e:	c931                	beqz	a0,800049e2 <kexec+0x80>
    80004990:	f3d2                	sd	s4,480(sp)
    80004992:	8a2a                	mv	s4,a0
    end_op();
    return -1;
  }
  ilock(ip);
    80004994:	bd1fe0ef          	jal	80003564 <ilock>

  // Read the ELF header.
  if(readi(ip, 0, (uint64)&elf, 0, sizeof(elf)) != sizeof(elf))
    80004998:	04000713          	li	a4,64
    8000499c:	4681                	li	a3,0
    8000499e:	e5040613          	addi	a2,s0,-432
    800049a2:	4581                	li	a1,0
    800049a4:	8552                	mv	a0,s4
    800049a6:	f4ffe0ef          	jal	800038f4 <readi>
    800049aa:	04000793          	li	a5,64
    800049ae:	00f51a63          	bne	a0,a5,800049c2 <kexec+0x60>
    goto bad;

  // Is this really an ELF file?
  if(elf.magic != ELF_MAGIC)
    800049b2:	e5042703          	lw	a4,-432(s0)
    800049b6:	464c47b7          	lui	a5,0x464c4
    800049ba:	57f78793          	addi	a5,a5,1407 # 464c457f <_entry-0x39b3ba81>
    800049be:	02f70663          	beq	a4,a5,800049ea <kexec+0x88>

 bad:
  if(pagetable)
    proc_freepagetable(pagetable, sz);
  if(ip){
    iunlockput(ip);
    800049c2:	8552                	mv	a0,s4
    800049c4:	dabfe0ef          	jal	8000376e <iunlockput>
    end_op();
    800049c8:	df0ff0ef          	jal	80003fb8 <end_op>
  }
  return -1;
    800049cc:	557d                	li	a0,-1
    800049ce:	7a1e                	ld	s4,480(sp)
}
    800049d0:	20813083          	ld	ra,520(sp)
    800049d4:	20013403          	ld	s0,512(sp)
    800049d8:	74fe                	ld	s1,504(sp)
    800049da:	795e                	ld	s2,496(sp)
    800049dc:	21010113          	addi	sp,sp,528
    800049e0:	8082                	ret
    end_op();
    800049e2:	dd6ff0ef          	jal	80003fb8 <end_op>
    return -1;
    800049e6:	557d                	li	a0,-1
    800049e8:	b7e5                	j	800049d0 <kexec+0x6e>
    800049ea:	ebda                	sd	s6,464(sp)
  if((pagetable = proc_pagetable(p)) == 0)
    800049ec:	8526                	mv	a0,s1
    800049ee:	fe7fc0ef          	jal	800019d4 <proc_pagetable>
    800049f2:	8b2a                	mv	s6,a0
    800049f4:	2c050b63          	beqz	a0,80004cca <kexec+0x368>
    800049f8:	f7ce                	sd	s3,488(sp)
    800049fa:	efd6                	sd	s5,472(sp)
    800049fc:	e7de                	sd	s7,456(sp)
    800049fe:	e3e2                	sd	s8,448(sp)
    80004a00:	ff66                	sd	s9,440(sp)
    80004a02:	fb6a                	sd	s10,432(sp)
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    80004a04:	e7042d03          	lw	s10,-400(s0)
    80004a08:	e8845783          	lhu	a5,-376(s0)
    80004a0c:	12078963          	beqz	a5,80004b3e <kexec+0x1dc>
    80004a10:	f76e                	sd	s11,424(sp)
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    80004a12:	4901                	li	s2,0
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    80004a14:	4d81                	li	s11,0
    if(ph.vaddr % PGSIZE != 0)
    80004a16:	6c85                	lui	s9,0x1
    80004a18:	fffc8793          	addi	a5,s9,-1 # fff <_entry-0x7ffff001>
    80004a1c:	def43823          	sd	a5,-528(s0)

  for(i = 0; i < sz; i += PGSIZE){
    pa = walkaddr(pagetable, va + i);
    if(pa == 0)
      panic("loadseg: address should exist");
    if(sz - i < PGSIZE)
    80004a20:	6a85                	lui	s5,0x1
    80004a22:	a085                	j	80004a82 <kexec+0x120>
      panic("loadseg: address should exist");
    80004a24:	00003517          	auipc	a0,0x3
    80004a28:	c7c50513          	addi	a0,a0,-900 # 800076a0 <etext+0x6a0>
    80004a2c:	db5fb0ef          	jal	800007e0 <panic>
    if(sz - i < PGSIZE)
    80004a30:	2481                	sext.w	s1,s1
      n = sz - i;
    else
      n = PGSIZE;
    if(readi(ip, 0, (uint64)pa, offset+i, n) != n)
    80004a32:	8726                	mv	a4,s1
    80004a34:	012c06bb          	addw	a3,s8,s2
    80004a38:	4581                	li	a1,0
    80004a3a:	8552                	mv	a0,s4
    80004a3c:	eb9fe0ef          	jal	800038f4 <readi>
    80004a40:	2501                	sext.w	a0,a0
    80004a42:	24a49a63          	bne	s1,a0,80004c96 <kexec+0x334>
  for(i = 0; i < sz; i += PGSIZE){
    80004a46:	012a893b          	addw	s2,s5,s2
    80004a4a:	03397363          	bgeu	s2,s3,80004a70 <kexec+0x10e>
    pa = walkaddr(pagetable, va + i);
    80004a4e:	02091593          	slli	a1,s2,0x20
    80004a52:	9181                	srli	a1,a1,0x20
    80004a54:	95de                	add	a1,a1,s7
    80004a56:	855a                	mv	a0,s6
    80004a58:	d58fc0ef          	jal	80000fb0 <walkaddr>
    80004a5c:	862a                	mv	a2,a0
    if(pa == 0)
    80004a5e:	d179                	beqz	a0,80004a24 <kexec+0xc2>
    if(sz - i < PGSIZE)
    80004a60:	412984bb          	subw	s1,s3,s2
    80004a64:	0004879b          	sext.w	a5,s1
    80004a68:	fcfcf4e3          	bgeu	s9,a5,80004a30 <kexec+0xce>
    80004a6c:	84d6                	mv	s1,s5
    80004a6e:	b7c9                	j	80004a30 <kexec+0xce>
    sz = sz1;
    80004a70:	e0843903          	ld	s2,-504(s0)
  for(i=0, off=elf.phoff; i<elf.phnum; i++, off+=sizeof(ph)){
    80004a74:	2d85                	addiw	s11,s11,1
    80004a76:	038d0d1b          	addiw	s10,s10,56 # 1038 <_entry-0x7fffefc8>
    80004a7a:	e8845783          	lhu	a5,-376(s0)
    80004a7e:	08fdd063          	bge	s11,a5,80004afe <kexec+0x19c>
    if(readi(ip, 0, (uint64)&ph, off, sizeof(ph)) != sizeof(ph))
    80004a82:	2d01                	sext.w	s10,s10
    80004a84:	03800713          	li	a4,56
    80004a88:	86ea                	mv	a3,s10
    80004a8a:	e1840613          	addi	a2,s0,-488
    80004a8e:	4581                	li	a1,0
    80004a90:	8552                	mv	a0,s4
    80004a92:	e63fe0ef          	jal	800038f4 <readi>
    80004a96:	03800793          	li	a5,56
    80004a9a:	1cf51663          	bne	a0,a5,80004c66 <kexec+0x304>
    if(ph.type != ELF_PROG_LOAD)
    80004a9e:	e1842783          	lw	a5,-488(s0)
    80004aa2:	4705                	li	a4,1
    80004aa4:	fce798e3          	bne	a5,a4,80004a74 <kexec+0x112>
    if(ph.memsz < ph.filesz)
    80004aa8:	e4043483          	ld	s1,-448(s0)
    80004aac:	e3843783          	ld	a5,-456(s0)
    80004ab0:	1af4ef63          	bltu	s1,a5,80004c6e <kexec+0x30c>
    if(ph.vaddr + ph.memsz < ph.vaddr)
    80004ab4:	e2843783          	ld	a5,-472(s0)
    80004ab8:	94be                	add	s1,s1,a5
    80004aba:	1af4ee63          	bltu	s1,a5,80004c76 <kexec+0x314>
    if(ph.vaddr % PGSIZE != 0)
    80004abe:	df043703          	ld	a4,-528(s0)
    80004ac2:	8ff9                	and	a5,a5,a4
    80004ac4:	1a079d63          	bnez	a5,80004c7e <kexec+0x31c>
    if((sz1 = uvmalloc(pagetable, sz, ph.vaddr + ph.memsz, flags2perm(ph.flags))) == 0)
    80004ac8:	e1c42503          	lw	a0,-484(s0)
    80004acc:	e7dff0ef          	jal	80004948 <flags2perm>
    80004ad0:	86aa                	mv	a3,a0
    80004ad2:	8626                	mv	a2,s1
    80004ad4:	85ca                	mv	a1,s2
    80004ad6:	855a                	mv	a0,s6
    80004ad8:	fb0fc0ef          	jal	80001288 <uvmalloc>
    80004adc:	e0a43423          	sd	a0,-504(s0)
    80004ae0:	1a050363          	beqz	a0,80004c86 <kexec+0x324>
    if(loadseg(pagetable, ph.vaddr, ip, ph.off, ph.filesz) < 0)
    80004ae4:	e2843b83          	ld	s7,-472(s0)
    80004ae8:	e2042c03          	lw	s8,-480(s0)
    80004aec:	e3842983          	lw	s3,-456(s0)
  for(i = 0; i < sz; i += PGSIZE){
    80004af0:	00098463          	beqz	s3,80004af8 <kexec+0x196>
    80004af4:	4901                	li	s2,0
    80004af6:	bfa1                	j	80004a4e <kexec+0xec>
    sz = sz1;
    80004af8:	e0843903          	ld	s2,-504(s0)
    80004afc:	bfa5                	j	80004a74 <kexec+0x112>
    80004afe:	7dba                	ld	s11,424(sp)
  iunlockput(ip);
    80004b00:	8552                	mv	a0,s4
    80004b02:	c6dfe0ef          	jal	8000376e <iunlockput>
  end_op();
    80004b06:	cb2ff0ef          	jal	80003fb8 <end_op>
  p = myproc();
    80004b0a:	dc5fc0ef          	jal	800018ce <myproc>
    80004b0e:	8aaa                	mv	s5,a0
  uint64 oldsz = p->sz;
    80004b10:	04853c83          	ld	s9,72(a0)
  sz = PGROUNDUP(sz);
    80004b14:	6985                	lui	s3,0x1
    80004b16:	19fd                	addi	s3,s3,-1 # fff <_entry-0x7ffff001>
    80004b18:	99ca                	add	s3,s3,s2
    80004b1a:	77fd                	lui	a5,0xfffff
    80004b1c:	00f9f9b3          	and	s3,s3,a5
  if((sz1 = uvmalloc(pagetable, sz, sz + (USERSTACK+1)*PGSIZE, PTE_W)) == 0)
    80004b20:	4691                	li	a3,4
    80004b22:	6609                	lui	a2,0x2
    80004b24:	964e                	add	a2,a2,s3
    80004b26:	85ce                	mv	a1,s3
    80004b28:	855a                	mv	a0,s6
    80004b2a:	f5efc0ef          	jal	80001288 <uvmalloc>
    80004b2e:	892a                	mv	s2,a0
    80004b30:	e0a43423          	sd	a0,-504(s0)
    80004b34:	e519                	bnez	a0,80004b42 <kexec+0x1e0>
  if(pagetable)
    80004b36:	e1343423          	sd	s3,-504(s0)
    80004b3a:	4a01                	li	s4,0
    80004b3c:	aab1                	j	80004c98 <kexec+0x336>
  uint64 argc, sz = 0, sp, ustack[MAXARG], stackbase;
    80004b3e:	4901                	li	s2,0
    80004b40:	b7c1                	j	80004b00 <kexec+0x19e>
  uvmclear(pagetable, sz-(USERSTACK+1)*PGSIZE);
    80004b42:	75f9                	lui	a1,0xffffe
    80004b44:	95aa                	add	a1,a1,a0
    80004b46:	855a                	mv	a0,s6
    80004b48:	917fc0ef          	jal	8000145e <uvmclear>
  stackbase = sp - USERSTACK*PGSIZE;
    80004b4c:	7bfd                	lui	s7,0xfffff
    80004b4e:	9bca                	add	s7,s7,s2
  for(argc = 0; argv[argc]; argc++) {
    80004b50:	e0043783          	ld	a5,-512(s0)
    80004b54:	6388                	ld	a0,0(a5)
    80004b56:	cd39                	beqz	a0,80004bb4 <kexec+0x252>
    80004b58:	e9040993          	addi	s3,s0,-368
    80004b5c:	f9040c13          	addi	s8,s0,-112
    80004b60:	4481                	li	s1,0
    sp -= strlen(argv[argc]) + 1;
    80004b62:	ab0fc0ef          	jal	80000e12 <strlen>
    80004b66:	0015079b          	addiw	a5,a0,1
    80004b6a:	40f907b3          	sub	a5,s2,a5
    sp -= sp % 16; // riscv sp must be 16-byte aligned
    80004b6e:	ff07f913          	andi	s2,a5,-16
    if(sp < stackbase)
    80004b72:	11796e63          	bltu	s2,s7,80004c8e <kexec+0x32c>
    if(copyout(pagetable, sp, argv[argc], strlen(argv[argc]) + 1) < 0)
    80004b76:	e0043d03          	ld	s10,-512(s0)
    80004b7a:	000d3a03          	ld	s4,0(s10)
    80004b7e:	8552                	mv	a0,s4
    80004b80:	a92fc0ef          	jal	80000e12 <strlen>
    80004b84:	0015069b          	addiw	a3,a0,1
    80004b88:	8652                	mv	a2,s4
    80004b8a:	85ca                	mv	a1,s2
    80004b8c:	855a                	mv	a0,s6
    80004b8e:	a55fc0ef          	jal	800015e2 <copyout>
    80004b92:	10054063          	bltz	a0,80004c92 <kexec+0x330>
    ustack[argc] = sp;
    80004b96:	0129b023          	sd	s2,0(s3)
  for(argc = 0; argv[argc]; argc++) {
    80004b9a:	0485                	addi	s1,s1,1
    80004b9c:	008d0793          	addi	a5,s10,8
    80004ba0:	e0f43023          	sd	a5,-512(s0)
    80004ba4:	008d3503          	ld	a0,8(s10)
    80004ba8:	c909                	beqz	a0,80004bba <kexec+0x258>
    if(argc >= MAXARG)
    80004baa:	09a1                	addi	s3,s3,8
    80004bac:	fb899be3          	bne	s3,s8,80004b62 <kexec+0x200>
  ip = 0;
    80004bb0:	4a01                	li	s4,0
    80004bb2:	a0dd                	j	80004c98 <kexec+0x336>
  sp = sz;
    80004bb4:	e0843903          	ld	s2,-504(s0)
  for(argc = 0; argv[argc]; argc++) {
    80004bb8:	4481                	li	s1,0
  ustack[argc] = 0;
    80004bba:	00349793          	slli	a5,s1,0x3
    80004bbe:	f9078793          	addi	a5,a5,-112 # ffffffffffffef90 <end+0xffffffff7ffdb3b8>
    80004bc2:	97a2                	add	a5,a5,s0
    80004bc4:	f007b023          	sd	zero,-256(a5)
  sp -= (argc+1) * sizeof(uint64);
    80004bc8:	00148693          	addi	a3,s1,1
    80004bcc:	068e                	slli	a3,a3,0x3
    80004bce:	40d90933          	sub	s2,s2,a3
  sp -= sp % 16;
    80004bd2:	ff097913          	andi	s2,s2,-16
  sz = sz1;
    80004bd6:	e0843983          	ld	s3,-504(s0)
  if(sp < stackbase)
    80004bda:	f5796ee3          	bltu	s2,s7,80004b36 <kexec+0x1d4>
  if(copyout(pagetable, sp, (char *)ustack, (argc+1)*sizeof(uint64)) < 0)
    80004bde:	e9040613          	addi	a2,s0,-368
    80004be2:	85ca                	mv	a1,s2
    80004be4:	855a                	mv	a0,s6
    80004be6:	9fdfc0ef          	jal	800015e2 <copyout>
    80004bea:	0e054263          	bltz	a0,80004cce <kexec+0x36c>
  p->trapframe->a1 = sp;
    80004bee:	060ab783          	ld	a5,96(s5) # 1060 <_entry-0x7fffefa0>
    80004bf2:	0727bc23          	sd	s2,120(a5)
  for(last=s=path; *s; s++)
    80004bf6:	df843783          	ld	a5,-520(s0)
    80004bfa:	0007c703          	lbu	a4,0(a5)
    80004bfe:	cf11                	beqz	a4,80004c1a <kexec+0x2b8>
    80004c00:	0785                	addi	a5,a5,1
    if(*s == '/')
    80004c02:	02f00693          	li	a3,47
    80004c06:	a039                	j	80004c14 <kexec+0x2b2>
      last = s+1;
    80004c08:	def43c23          	sd	a5,-520(s0)
  for(last=s=path; *s; s++)
    80004c0c:	0785                	addi	a5,a5,1
    80004c0e:	fff7c703          	lbu	a4,-1(a5)
    80004c12:	c701                	beqz	a4,80004c1a <kexec+0x2b8>
    if(*s == '/')
    80004c14:	fed71ce3          	bne	a4,a3,80004c0c <kexec+0x2aa>
    80004c18:	bfc5                	j	80004c08 <kexec+0x2a6>
  safestrcpy(p->name, last, sizeof(p->name));
    80004c1a:	4641                	li	a2,16
    80004c1c:	df843583          	ld	a1,-520(s0)
    80004c20:	160a8513          	addi	a0,s5,352
    80004c24:	9bcfc0ef          	jal	80000de0 <safestrcpy>
  oldpagetable = p->pagetable;
    80004c28:	058ab503          	ld	a0,88(s5)
  p->pagetable = pagetable;
    80004c2c:	056abc23          	sd	s6,88(s5)
  p->sz = sz;
    80004c30:	e0843783          	ld	a5,-504(s0)
    80004c34:	04fab423          	sd	a5,72(s5)
  p->trapframe->epc = elf.entry;  // initial program counter = ulib.c:start()
    80004c38:	060ab783          	ld	a5,96(s5)
    80004c3c:	e6843703          	ld	a4,-408(s0)
    80004c40:	ef98                	sd	a4,24(a5)
  p->trapframe->sp = sp; // initial stack pointer
    80004c42:	060ab783          	ld	a5,96(s5)
    80004c46:	0327b823          	sd	s2,48(a5)
  proc_freepagetable(oldpagetable, oldsz);
    80004c4a:	85e6                	mv	a1,s9
    80004c4c:	e0dfc0ef          	jal	80001a58 <proc_freepagetable>
  return argc; // this ends up in a0, the first argument to main(argc, argv)
    80004c50:	0004851b          	sext.w	a0,s1
    80004c54:	79be                	ld	s3,488(sp)
    80004c56:	7a1e                	ld	s4,480(sp)
    80004c58:	6afe                	ld	s5,472(sp)
    80004c5a:	6b5e                	ld	s6,464(sp)
    80004c5c:	6bbe                	ld	s7,456(sp)
    80004c5e:	6c1e                	ld	s8,448(sp)
    80004c60:	7cfa                	ld	s9,440(sp)
    80004c62:	7d5a                	ld	s10,432(sp)
    80004c64:	b3b5                	j	800049d0 <kexec+0x6e>
    80004c66:	e1243423          	sd	s2,-504(s0)
    80004c6a:	7dba                	ld	s11,424(sp)
    80004c6c:	a035                	j	80004c98 <kexec+0x336>
    80004c6e:	e1243423          	sd	s2,-504(s0)
    80004c72:	7dba                	ld	s11,424(sp)
    80004c74:	a015                	j	80004c98 <kexec+0x336>
    80004c76:	e1243423          	sd	s2,-504(s0)
    80004c7a:	7dba                	ld	s11,424(sp)
    80004c7c:	a831                	j	80004c98 <kexec+0x336>
    80004c7e:	e1243423          	sd	s2,-504(s0)
    80004c82:	7dba                	ld	s11,424(sp)
    80004c84:	a811                	j	80004c98 <kexec+0x336>
    80004c86:	e1243423          	sd	s2,-504(s0)
    80004c8a:	7dba                	ld	s11,424(sp)
    80004c8c:	a031                	j	80004c98 <kexec+0x336>
  ip = 0;
    80004c8e:	4a01                	li	s4,0
    80004c90:	a021                	j	80004c98 <kexec+0x336>
    80004c92:	4a01                	li	s4,0
  if(pagetable)
    80004c94:	a011                	j	80004c98 <kexec+0x336>
    80004c96:	7dba                	ld	s11,424(sp)
    proc_freepagetable(pagetable, sz);
    80004c98:	e0843583          	ld	a1,-504(s0)
    80004c9c:	855a                	mv	a0,s6
    80004c9e:	dbbfc0ef          	jal	80001a58 <proc_freepagetable>
  return -1;
    80004ca2:	557d                	li	a0,-1
  if(ip){
    80004ca4:	000a1b63          	bnez	s4,80004cba <kexec+0x358>
    80004ca8:	79be                	ld	s3,488(sp)
    80004caa:	7a1e                	ld	s4,480(sp)
    80004cac:	6afe                	ld	s5,472(sp)
    80004cae:	6b5e                	ld	s6,464(sp)
    80004cb0:	6bbe                	ld	s7,456(sp)
    80004cb2:	6c1e                	ld	s8,448(sp)
    80004cb4:	7cfa                	ld	s9,440(sp)
    80004cb6:	7d5a                	ld	s10,432(sp)
    80004cb8:	bb21                	j	800049d0 <kexec+0x6e>
    80004cba:	79be                	ld	s3,488(sp)
    80004cbc:	6afe                	ld	s5,472(sp)
    80004cbe:	6b5e                	ld	s6,464(sp)
    80004cc0:	6bbe                	ld	s7,456(sp)
    80004cc2:	6c1e                	ld	s8,448(sp)
    80004cc4:	7cfa                	ld	s9,440(sp)
    80004cc6:	7d5a                	ld	s10,432(sp)
    80004cc8:	b9ed                	j	800049c2 <kexec+0x60>
    80004cca:	6b5e                	ld	s6,464(sp)
    80004ccc:	b9dd                	j	800049c2 <kexec+0x60>
  sz = sz1;
    80004cce:	e0843983          	ld	s3,-504(s0)
    80004cd2:	b595                	j	80004b36 <kexec+0x1d4>

0000000080004cd4 <argfd>:

// Fetch the nth word-sized system call argument as a file descriptor
// and return both the descriptor and the corresponding struct file.
static int
argfd(int n, int *pfd, struct file **pf)
{
    80004cd4:	7179                	addi	sp,sp,-48
    80004cd6:	f406                	sd	ra,40(sp)
    80004cd8:	f022                	sd	s0,32(sp)
    80004cda:	ec26                	sd	s1,24(sp)
    80004cdc:	e84a                	sd	s2,16(sp)
    80004cde:	1800                	addi	s0,sp,48
    80004ce0:	892e                	mv	s2,a1
    80004ce2:	84b2                	mv	s1,a2
  int fd;
  struct file *f;

  argint(n, &fd);
    80004ce4:	fdc40593          	addi	a1,s0,-36
    80004ce8:	b6ffd0ef          	jal	80002856 <argint>
  if(fd < 0 || fd >= NOFILE || (f=myproc()->ofile[fd]) == 0)
    80004cec:	fdc42703          	lw	a4,-36(s0)
    80004cf0:	47bd                	li	a5,15
    80004cf2:	02e7e963          	bltu	a5,a4,80004d24 <argfd+0x50>
    80004cf6:	bd9fc0ef          	jal	800018ce <myproc>
    80004cfa:	fdc42703          	lw	a4,-36(s0)
    80004cfe:	01a70793          	addi	a5,a4,26
    80004d02:	078e                	slli	a5,a5,0x3
    80004d04:	953e                	add	a0,a0,a5
    80004d06:	651c                	ld	a5,8(a0)
    80004d08:	c385                	beqz	a5,80004d28 <argfd+0x54>
    return -1;
  if(pfd)
    80004d0a:	00090463          	beqz	s2,80004d12 <argfd+0x3e>
    *pfd = fd;
    80004d0e:	00e92023          	sw	a4,0(s2)
  if(pf)
    *pf = f;
  return 0;
    80004d12:	4501                	li	a0,0
  if(pf)
    80004d14:	c091                	beqz	s1,80004d18 <argfd+0x44>
    *pf = f;
    80004d16:	e09c                	sd	a5,0(s1)
}
    80004d18:	70a2                	ld	ra,40(sp)
    80004d1a:	7402                	ld	s0,32(sp)
    80004d1c:	64e2                	ld	s1,24(sp)
    80004d1e:	6942                	ld	s2,16(sp)
    80004d20:	6145                	addi	sp,sp,48
    80004d22:	8082                	ret
    return -1;
    80004d24:	557d                	li	a0,-1
    80004d26:	bfcd                	j	80004d18 <argfd+0x44>
    80004d28:	557d                	li	a0,-1
    80004d2a:	b7fd                	j	80004d18 <argfd+0x44>

0000000080004d2c <fdalloc>:

// Allocate a file descriptor for the given file.
// Takes over file reference from caller on success.
static int
fdalloc(struct file *f)
{
    80004d2c:	1101                	addi	sp,sp,-32
    80004d2e:	ec06                	sd	ra,24(sp)
    80004d30:	e822                	sd	s0,16(sp)
    80004d32:	e426                	sd	s1,8(sp)
    80004d34:	1000                	addi	s0,sp,32
    80004d36:	84aa                	mv	s1,a0
  int fd;
  struct proc *p = myproc();
    80004d38:	b97fc0ef          	jal	800018ce <myproc>
    80004d3c:	862a                	mv	a2,a0

  for(fd = 0; fd < NOFILE; fd++){
    80004d3e:	0d850793          	addi	a5,a0,216
    80004d42:	4501                	li	a0,0
    80004d44:	46c1                	li	a3,16
    if(p->ofile[fd] == 0){
    80004d46:	6398                	ld	a4,0(a5)
    80004d48:	cb19                	beqz	a4,80004d5e <fdalloc+0x32>
  for(fd = 0; fd < NOFILE; fd++){
    80004d4a:	2505                	addiw	a0,a0,1
    80004d4c:	07a1                	addi	a5,a5,8
    80004d4e:	fed51ce3          	bne	a0,a3,80004d46 <fdalloc+0x1a>
      p->ofile[fd] = f;
      return fd;
    }
  }
  return -1;
    80004d52:	557d                	li	a0,-1
}
    80004d54:	60e2                	ld	ra,24(sp)
    80004d56:	6442                	ld	s0,16(sp)
    80004d58:	64a2                	ld	s1,8(sp)
    80004d5a:	6105                	addi	sp,sp,32
    80004d5c:	8082                	ret
      p->ofile[fd] = f;
    80004d5e:	01a50793          	addi	a5,a0,26
    80004d62:	078e                	slli	a5,a5,0x3
    80004d64:	963e                	add	a2,a2,a5
    80004d66:	e604                	sd	s1,8(a2)
      return fd;
    80004d68:	b7f5                	j	80004d54 <fdalloc+0x28>

0000000080004d6a <create>:
  return -1;
}

static struct inode*
create(char *path, short type, short major, short minor)
{
    80004d6a:	715d                	addi	sp,sp,-80
    80004d6c:	e486                	sd	ra,72(sp)
    80004d6e:	e0a2                	sd	s0,64(sp)
    80004d70:	fc26                	sd	s1,56(sp)
    80004d72:	f84a                	sd	s2,48(sp)
    80004d74:	f44e                	sd	s3,40(sp)
    80004d76:	ec56                	sd	s5,24(sp)
    80004d78:	e85a                	sd	s6,16(sp)
    80004d7a:	0880                	addi	s0,sp,80
    80004d7c:	8b2e                	mv	s6,a1
    80004d7e:	89b2                	mv	s3,a2
    80004d80:	8936                	mv	s2,a3
  struct inode *ip, *dp;
  char name[DIRSIZ];

  if((dp = nameiparent(path, name)) == 0)
    80004d82:	fb040593          	addi	a1,s0,-80
    80004d86:	80eff0ef          	jal	80003d94 <nameiparent>
    80004d8a:	84aa                	mv	s1,a0
    80004d8c:	10050a63          	beqz	a0,80004ea0 <create+0x136>
    return 0;

  ilock(dp);
    80004d90:	fd4fe0ef          	jal	80003564 <ilock>

  if((ip = dirlookup(dp, name, 0)) != 0){
    80004d94:	4601                	li	a2,0
    80004d96:	fb040593          	addi	a1,s0,-80
    80004d9a:	8526                	mv	a0,s1
    80004d9c:	d79fe0ef          	jal	80003b14 <dirlookup>
    80004da0:	8aaa                	mv	s5,a0
    80004da2:	c129                	beqz	a0,80004de4 <create+0x7a>
    iunlockput(dp);
    80004da4:	8526                	mv	a0,s1
    80004da6:	9c9fe0ef          	jal	8000376e <iunlockput>
    ilock(ip);
    80004daa:	8556                	mv	a0,s5
    80004dac:	fb8fe0ef          	jal	80003564 <ilock>
    if(type == T_FILE && (ip->type == T_FILE || ip->type == T_DEVICE))
    80004db0:	4789                	li	a5,2
    80004db2:	02fb1463          	bne	s6,a5,80004dda <create+0x70>
    80004db6:	044ad783          	lhu	a5,68(s5)
    80004dba:	37f9                	addiw	a5,a5,-2
    80004dbc:	17c2                	slli	a5,a5,0x30
    80004dbe:	93c1                	srli	a5,a5,0x30
    80004dc0:	4705                	li	a4,1
    80004dc2:	00f76c63          	bltu	a4,a5,80004dda <create+0x70>
  ip->nlink = 0;
  iupdate(ip);
  iunlockput(ip);
  iunlockput(dp);
  return 0;
}
    80004dc6:	8556                	mv	a0,s5
    80004dc8:	60a6                	ld	ra,72(sp)
    80004dca:	6406                	ld	s0,64(sp)
    80004dcc:	74e2                	ld	s1,56(sp)
    80004dce:	7942                	ld	s2,48(sp)
    80004dd0:	79a2                	ld	s3,40(sp)
    80004dd2:	6ae2                	ld	s5,24(sp)
    80004dd4:	6b42                	ld	s6,16(sp)
    80004dd6:	6161                	addi	sp,sp,80
    80004dd8:	8082                	ret
    iunlockput(ip);
    80004dda:	8556                	mv	a0,s5
    80004ddc:	993fe0ef          	jal	8000376e <iunlockput>
    return 0;
    80004de0:	4a81                	li	s5,0
    80004de2:	b7d5                	j	80004dc6 <create+0x5c>
    80004de4:	f052                	sd	s4,32(sp)
  if((ip = ialloc(dp->dev, type)) == 0){
    80004de6:	85da                	mv	a1,s6
    80004de8:	4088                	lw	a0,0(s1)
    80004dea:	e0afe0ef          	jal	800033f4 <ialloc>
    80004dee:	8a2a                	mv	s4,a0
    80004df0:	cd15                	beqz	a0,80004e2c <create+0xc2>
  ilock(ip);
    80004df2:	f72fe0ef          	jal	80003564 <ilock>
  ip->major = major;
    80004df6:	053a1323          	sh	s3,70(s4)
  ip->minor = minor;
    80004dfa:	052a1423          	sh	s2,72(s4)
  ip->nlink = 1;
    80004dfe:	4905                	li	s2,1
    80004e00:	052a1523          	sh	s2,74(s4)
  iupdate(ip);
    80004e04:	8552                	mv	a0,s4
    80004e06:	eaafe0ef          	jal	800034b0 <iupdate>
  if(type == T_DIR){  // Create . and .. entries.
    80004e0a:	032b0763          	beq	s6,s2,80004e38 <create+0xce>
  if(dirlink(dp, name, ip->inum) < 0)
    80004e0e:	004a2603          	lw	a2,4(s4)
    80004e12:	fb040593          	addi	a1,s0,-80
    80004e16:	8526                	mv	a0,s1
    80004e18:	ec9fe0ef          	jal	80003ce0 <dirlink>
    80004e1c:	06054563          	bltz	a0,80004e86 <create+0x11c>
  iunlockput(dp);
    80004e20:	8526                	mv	a0,s1
    80004e22:	94dfe0ef          	jal	8000376e <iunlockput>
  return ip;
    80004e26:	8ad2                	mv	s5,s4
    80004e28:	7a02                	ld	s4,32(sp)
    80004e2a:	bf71                	j	80004dc6 <create+0x5c>
    iunlockput(dp);
    80004e2c:	8526                	mv	a0,s1
    80004e2e:	941fe0ef          	jal	8000376e <iunlockput>
    return 0;
    80004e32:	8ad2                	mv	s5,s4
    80004e34:	7a02                	ld	s4,32(sp)
    80004e36:	bf41                	j	80004dc6 <create+0x5c>
    if(dirlink(ip, ".", ip->inum) < 0 || dirlink(ip, "..", dp->inum) < 0)
    80004e38:	004a2603          	lw	a2,4(s4)
    80004e3c:	00003597          	auipc	a1,0x3
    80004e40:	88458593          	addi	a1,a1,-1916 # 800076c0 <etext+0x6c0>
    80004e44:	8552                	mv	a0,s4
    80004e46:	e9bfe0ef          	jal	80003ce0 <dirlink>
    80004e4a:	02054e63          	bltz	a0,80004e86 <create+0x11c>
    80004e4e:	40d0                	lw	a2,4(s1)
    80004e50:	00003597          	auipc	a1,0x3
    80004e54:	87858593          	addi	a1,a1,-1928 # 800076c8 <etext+0x6c8>
    80004e58:	8552                	mv	a0,s4
    80004e5a:	e87fe0ef          	jal	80003ce0 <dirlink>
    80004e5e:	02054463          	bltz	a0,80004e86 <create+0x11c>
  if(dirlink(dp, name, ip->inum) < 0)
    80004e62:	004a2603          	lw	a2,4(s4)
    80004e66:	fb040593          	addi	a1,s0,-80
    80004e6a:	8526                	mv	a0,s1
    80004e6c:	e75fe0ef          	jal	80003ce0 <dirlink>
    80004e70:	00054b63          	bltz	a0,80004e86 <create+0x11c>
    dp->nlink++;  // for ".."
    80004e74:	04a4d783          	lhu	a5,74(s1)
    80004e78:	2785                	addiw	a5,a5,1
    80004e7a:	04f49523          	sh	a5,74(s1)
    iupdate(dp);
    80004e7e:	8526                	mv	a0,s1
    80004e80:	e30fe0ef          	jal	800034b0 <iupdate>
    80004e84:	bf71                	j	80004e20 <create+0xb6>
  ip->nlink = 0;
    80004e86:	040a1523          	sh	zero,74(s4)
  iupdate(ip);
    80004e8a:	8552                	mv	a0,s4
    80004e8c:	e24fe0ef          	jal	800034b0 <iupdate>
  iunlockput(ip);
    80004e90:	8552                	mv	a0,s4
    80004e92:	8ddfe0ef          	jal	8000376e <iunlockput>
  iunlockput(dp);
    80004e96:	8526                	mv	a0,s1
    80004e98:	8d7fe0ef          	jal	8000376e <iunlockput>
  return 0;
    80004e9c:	7a02                	ld	s4,32(sp)
    80004e9e:	b725                	j	80004dc6 <create+0x5c>
    return 0;
    80004ea0:	8aaa                	mv	s5,a0
    80004ea2:	b715                	j	80004dc6 <create+0x5c>

0000000080004ea4 <sys_dup>:
{
    80004ea4:	7179                	addi	sp,sp,-48
    80004ea6:	f406                	sd	ra,40(sp)
    80004ea8:	f022                	sd	s0,32(sp)
    80004eaa:	1800                	addi	s0,sp,48
  if(argfd(0, 0, &f) < 0)
    80004eac:	fd840613          	addi	a2,s0,-40
    80004eb0:	4581                	li	a1,0
    80004eb2:	4501                	li	a0,0
    80004eb4:	e21ff0ef          	jal	80004cd4 <argfd>
    return -1;
    80004eb8:	57fd                	li	a5,-1
  if(argfd(0, 0, &f) < 0)
    80004eba:	02054363          	bltz	a0,80004ee0 <sys_dup+0x3c>
    80004ebe:	ec26                	sd	s1,24(sp)
    80004ec0:	e84a                	sd	s2,16(sp)
  if((fd=fdalloc(f)) < 0)
    80004ec2:	fd843903          	ld	s2,-40(s0)
    80004ec6:	854a                	mv	a0,s2
    80004ec8:	e65ff0ef          	jal	80004d2c <fdalloc>
    80004ecc:	84aa                	mv	s1,a0
    return -1;
    80004ece:	57fd                	li	a5,-1
  if((fd=fdalloc(f)) < 0)
    80004ed0:	00054d63          	bltz	a0,80004eea <sys_dup+0x46>
  filedup(f);
    80004ed4:	854a                	mv	a0,s2
    80004ed6:	c3eff0ef          	jal	80004314 <filedup>
  return fd;
    80004eda:	87a6                	mv	a5,s1
    80004edc:	64e2                	ld	s1,24(sp)
    80004ede:	6942                	ld	s2,16(sp)
}
    80004ee0:	853e                	mv	a0,a5
    80004ee2:	70a2                	ld	ra,40(sp)
    80004ee4:	7402                	ld	s0,32(sp)
    80004ee6:	6145                	addi	sp,sp,48
    80004ee8:	8082                	ret
    80004eea:	64e2                	ld	s1,24(sp)
    80004eec:	6942                	ld	s2,16(sp)
    80004eee:	bfcd                	j	80004ee0 <sys_dup+0x3c>

0000000080004ef0 <sys_read>:
{
    80004ef0:	7179                	addi	sp,sp,-48
    80004ef2:	f406                	sd	ra,40(sp)
    80004ef4:	f022                	sd	s0,32(sp)
    80004ef6:	1800                	addi	s0,sp,48
  argaddr(1, &p);
    80004ef8:	fd840593          	addi	a1,s0,-40
    80004efc:	4505                	li	a0,1
    80004efe:	975fd0ef          	jal	80002872 <argaddr>
  argint(2, &n);
    80004f02:	fe440593          	addi	a1,s0,-28
    80004f06:	4509                	li	a0,2
    80004f08:	94ffd0ef          	jal	80002856 <argint>
  if(argfd(0, 0, &f) < 0)
    80004f0c:	fe840613          	addi	a2,s0,-24
    80004f10:	4581                	li	a1,0
    80004f12:	4501                	li	a0,0
    80004f14:	dc1ff0ef          	jal	80004cd4 <argfd>
    80004f18:	87aa                	mv	a5,a0
    return -1;
    80004f1a:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    80004f1c:	0007ca63          	bltz	a5,80004f30 <sys_read+0x40>
  return fileread(f, p, n);
    80004f20:	fe442603          	lw	a2,-28(s0)
    80004f24:	fd843583          	ld	a1,-40(s0)
    80004f28:	fe843503          	ld	a0,-24(s0)
    80004f2c:	d4eff0ef          	jal	8000447a <fileread>
}
    80004f30:	70a2                	ld	ra,40(sp)
    80004f32:	7402                	ld	s0,32(sp)
    80004f34:	6145                	addi	sp,sp,48
    80004f36:	8082                	ret

0000000080004f38 <sys_write>:
{
    80004f38:	7179                	addi	sp,sp,-48
    80004f3a:	f406                	sd	ra,40(sp)
    80004f3c:	f022                	sd	s0,32(sp)
    80004f3e:	1800                	addi	s0,sp,48
  argaddr(1, &p);
    80004f40:	fd840593          	addi	a1,s0,-40
    80004f44:	4505                	li	a0,1
    80004f46:	92dfd0ef          	jal	80002872 <argaddr>
  argint(2, &n);
    80004f4a:	fe440593          	addi	a1,s0,-28
    80004f4e:	4509                	li	a0,2
    80004f50:	907fd0ef          	jal	80002856 <argint>
  if(argfd(0, 0, &f) < 0)
    80004f54:	fe840613          	addi	a2,s0,-24
    80004f58:	4581                	li	a1,0
    80004f5a:	4501                	li	a0,0
    80004f5c:	d79ff0ef          	jal	80004cd4 <argfd>
    80004f60:	87aa                	mv	a5,a0
    return -1;
    80004f62:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    80004f64:	0007ca63          	bltz	a5,80004f78 <sys_write+0x40>
  return filewrite(f, p, n);
    80004f68:	fe442603          	lw	a2,-28(s0)
    80004f6c:	fd843583          	ld	a1,-40(s0)
    80004f70:	fe843503          	ld	a0,-24(s0)
    80004f74:	dc4ff0ef          	jal	80004538 <filewrite>
}
    80004f78:	70a2                	ld	ra,40(sp)
    80004f7a:	7402                	ld	s0,32(sp)
    80004f7c:	6145                	addi	sp,sp,48
    80004f7e:	8082                	ret

0000000080004f80 <sys_close>:
{
    80004f80:	1101                	addi	sp,sp,-32
    80004f82:	ec06                	sd	ra,24(sp)
    80004f84:	e822                	sd	s0,16(sp)
    80004f86:	1000                	addi	s0,sp,32
  if(argfd(0, &fd, &f) < 0)
    80004f88:	fe040613          	addi	a2,s0,-32
    80004f8c:	fec40593          	addi	a1,s0,-20
    80004f90:	4501                	li	a0,0
    80004f92:	d43ff0ef          	jal	80004cd4 <argfd>
    return -1;
    80004f96:	57fd                	li	a5,-1
  if(argfd(0, &fd, &f) < 0)
    80004f98:	02054063          	bltz	a0,80004fb8 <sys_close+0x38>
  myproc()->ofile[fd] = 0;
    80004f9c:	933fc0ef          	jal	800018ce <myproc>
    80004fa0:	fec42783          	lw	a5,-20(s0)
    80004fa4:	07e9                	addi	a5,a5,26
    80004fa6:	078e                	slli	a5,a5,0x3
    80004fa8:	953e                	add	a0,a0,a5
    80004faa:	00053423          	sd	zero,8(a0)
  fileclose(f);
    80004fae:	fe043503          	ld	a0,-32(s0)
    80004fb2:	ba8ff0ef          	jal	8000435a <fileclose>
  return 0;
    80004fb6:	4781                	li	a5,0
}
    80004fb8:	853e                	mv	a0,a5
    80004fba:	60e2                	ld	ra,24(sp)
    80004fbc:	6442                	ld	s0,16(sp)
    80004fbe:	6105                	addi	sp,sp,32
    80004fc0:	8082                	ret

0000000080004fc2 <sys_fstat>:
{
    80004fc2:	1101                	addi	sp,sp,-32
    80004fc4:	ec06                	sd	ra,24(sp)
    80004fc6:	e822                	sd	s0,16(sp)
    80004fc8:	1000                	addi	s0,sp,32
  argaddr(1, &st);
    80004fca:	fe040593          	addi	a1,s0,-32
    80004fce:	4505                	li	a0,1
    80004fd0:	8a3fd0ef          	jal	80002872 <argaddr>
  if(argfd(0, 0, &f) < 0)
    80004fd4:	fe840613          	addi	a2,s0,-24
    80004fd8:	4581                	li	a1,0
    80004fda:	4501                	li	a0,0
    80004fdc:	cf9ff0ef          	jal	80004cd4 <argfd>
    80004fe0:	87aa                	mv	a5,a0
    return -1;
    80004fe2:	557d                	li	a0,-1
  if(argfd(0, 0, &f) < 0)
    80004fe4:	0007c863          	bltz	a5,80004ff4 <sys_fstat+0x32>
  return filestat(f, st);
    80004fe8:	fe043583          	ld	a1,-32(s0)
    80004fec:	fe843503          	ld	a0,-24(s0)
    80004ff0:	c2cff0ef          	jal	8000441c <filestat>
}
    80004ff4:	60e2                	ld	ra,24(sp)
    80004ff6:	6442                	ld	s0,16(sp)
    80004ff8:	6105                	addi	sp,sp,32
    80004ffa:	8082                	ret

0000000080004ffc <sys_link>:
{
    80004ffc:	7169                	addi	sp,sp,-304
    80004ffe:	f606                	sd	ra,296(sp)
    80005000:	f222                	sd	s0,288(sp)
    80005002:	1a00                	addi	s0,sp,304
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005004:	08000613          	li	a2,128
    80005008:	ed040593          	addi	a1,s0,-304
    8000500c:	4501                	li	a0,0
    8000500e:	881fd0ef          	jal	8000288e <argstr>
    return -1;
    80005012:	57fd                	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005014:	0c054e63          	bltz	a0,800050f0 <sys_link+0xf4>
    80005018:	08000613          	li	a2,128
    8000501c:	f5040593          	addi	a1,s0,-176
    80005020:	4505                	li	a0,1
    80005022:	86dfd0ef          	jal	8000288e <argstr>
    return -1;
    80005026:	57fd                	li	a5,-1
  if(argstr(0, old, MAXPATH) < 0 || argstr(1, new, MAXPATH) < 0)
    80005028:	0c054463          	bltz	a0,800050f0 <sys_link+0xf4>
    8000502c:	ee26                	sd	s1,280(sp)
  begin_op();
    8000502e:	f21fe0ef          	jal	80003f4e <begin_op>
  if((ip = namei(old)) == 0){
    80005032:	ed040513          	addi	a0,s0,-304
    80005036:	d45fe0ef          	jal	80003d7a <namei>
    8000503a:	84aa                	mv	s1,a0
    8000503c:	c53d                	beqz	a0,800050aa <sys_link+0xae>
  ilock(ip);
    8000503e:	d26fe0ef          	jal	80003564 <ilock>
  if(ip->type == T_DIR){
    80005042:	04449703          	lh	a4,68(s1)
    80005046:	4785                	li	a5,1
    80005048:	06f70663          	beq	a4,a5,800050b4 <sys_link+0xb8>
    8000504c:	ea4a                	sd	s2,272(sp)
  ip->nlink++;
    8000504e:	04a4d783          	lhu	a5,74(s1)
    80005052:	2785                	addiw	a5,a5,1
    80005054:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    80005058:	8526                	mv	a0,s1
    8000505a:	c56fe0ef          	jal	800034b0 <iupdate>
  iunlock(ip);
    8000505e:	8526                	mv	a0,s1
    80005060:	db2fe0ef          	jal	80003612 <iunlock>
  if((dp = nameiparent(new, name)) == 0)
    80005064:	fd040593          	addi	a1,s0,-48
    80005068:	f5040513          	addi	a0,s0,-176
    8000506c:	d29fe0ef          	jal	80003d94 <nameiparent>
    80005070:	892a                	mv	s2,a0
    80005072:	cd21                	beqz	a0,800050ca <sys_link+0xce>
  ilock(dp);
    80005074:	cf0fe0ef          	jal	80003564 <ilock>
  if(dp->dev != ip->dev || dirlink(dp, name, ip->inum) < 0){
    80005078:	00092703          	lw	a4,0(s2)
    8000507c:	409c                	lw	a5,0(s1)
    8000507e:	04f71363          	bne	a4,a5,800050c4 <sys_link+0xc8>
    80005082:	40d0                	lw	a2,4(s1)
    80005084:	fd040593          	addi	a1,s0,-48
    80005088:	854a                	mv	a0,s2
    8000508a:	c57fe0ef          	jal	80003ce0 <dirlink>
    8000508e:	02054b63          	bltz	a0,800050c4 <sys_link+0xc8>
  iunlockput(dp);
    80005092:	854a                	mv	a0,s2
    80005094:	edafe0ef          	jal	8000376e <iunlockput>
  iput(ip);
    80005098:	8526                	mv	a0,s1
    8000509a:	e4cfe0ef          	jal	800036e6 <iput>
  end_op();
    8000509e:	f1bfe0ef          	jal	80003fb8 <end_op>
  return 0;
    800050a2:	4781                	li	a5,0
    800050a4:	64f2                	ld	s1,280(sp)
    800050a6:	6952                	ld	s2,272(sp)
    800050a8:	a0a1                	j	800050f0 <sys_link+0xf4>
    end_op();
    800050aa:	f0ffe0ef          	jal	80003fb8 <end_op>
    return -1;
    800050ae:	57fd                	li	a5,-1
    800050b0:	64f2                	ld	s1,280(sp)
    800050b2:	a83d                	j	800050f0 <sys_link+0xf4>
    iunlockput(ip);
    800050b4:	8526                	mv	a0,s1
    800050b6:	eb8fe0ef          	jal	8000376e <iunlockput>
    end_op();
    800050ba:	efffe0ef          	jal	80003fb8 <end_op>
    return -1;
    800050be:	57fd                	li	a5,-1
    800050c0:	64f2                	ld	s1,280(sp)
    800050c2:	a03d                	j	800050f0 <sys_link+0xf4>
    iunlockput(dp);
    800050c4:	854a                	mv	a0,s2
    800050c6:	ea8fe0ef          	jal	8000376e <iunlockput>
  ilock(ip);
    800050ca:	8526                	mv	a0,s1
    800050cc:	c98fe0ef          	jal	80003564 <ilock>
  ip->nlink--;
    800050d0:	04a4d783          	lhu	a5,74(s1)
    800050d4:	37fd                	addiw	a5,a5,-1
    800050d6:	04f49523          	sh	a5,74(s1)
  iupdate(ip);
    800050da:	8526                	mv	a0,s1
    800050dc:	bd4fe0ef          	jal	800034b0 <iupdate>
  iunlockput(ip);
    800050e0:	8526                	mv	a0,s1
    800050e2:	e8cfe0ef          	jal	8000376e <iunlockput>
  end_op();
    800050e6:	ed3fe0ef          	jal	80003fb8 <end_op>
  return -1;
    800050ea:	57fd                	li	a5,-1
    800050ec:	64f2                	ld	s1,280(sp)
    800050ee:	6952                	ld	s2,272(sp)
}
    800050f0:	853e                	mv	a0,a5
    800050f2:	70b2                	ld	ra,296(sp)
    800050f4:	7412                	ld	s0,288(sp)
    800050f6:	6155                	addi	sp,sp,304
    800050f8:	8082                	ret

00000000800050fa <sys_unlink>:
{
    800050fa:	7151                	addi	sp,sp,-240
    800050fc:	f586                	sd	ra,232(sp)
    800050fe:	f1a2                	sd	s0,224(sp)
    80005100:	1980                	addi	s0,sp,240
  if(argstr(0, path, MAXPATH) < 0)
    80005102:	08000613          	li	a2,128
    80005106:	f3040593          	addi	a1,s0,-208
    8000510a:	4501                	li	a0,0
    8000510c:	f82fd0ef          	jal	8000288e <argstr>
    80005110:	16054063          	bltz	a0,80005270 <sys_unlink+0x176>
    80005114:	eda6                	sd	s1,216(sp)
  begin_op();
    80005116:	e39fe0ef          	jal	80003f4e <begin_op>
  if((dp = nameiparent(path, name)) == 0){
    8000511a:	fb040593          	addi	a1,s0,-80
    8000511e:	f3040513          	addi	a0,s0,-208
    80005122:	c73fe0ef          	jal	80003d94 <nameiparent>
    80005126:	84aa                	mv	s1,a0
    80005128:	c945                	beqz	a0,800051d8 <sys_unlink+0xde>
  ilock(dp);
    8000512a:	c3afe0ef          	jal	80003564 <ilock>
  if(namecmp(name, ".") == 0 || namecmp(name, "..") == 0)
    8000512e:	00002597          	auipc	a1,0x2
    80005132:	59258593          	addi	a1,a1,1426 # 800076c0 <etext+0x6c0>
    80005136:	fb040513          	addi	a0,s0,-80
    8000513a:	9c5fe0ef          	jal	80003afe <namecmp>
    8000513e:	10050e63          	beqz	a0,8000525a <sys_unlink+0x160>
    80005142:	00002597          	auipc	a1,0x2
    80005146:	58658593          	addi	a1,a1,1414 # 800076c8 <etext+0x6c8>
    8000514a:	fb040513          	addi	a0,s0,-80
    8000514e:	9b1fe0ef          	jal	80003afe <namecmp>
    80005152:	10050463          	beqz	a0,8000525a <sys_unlink+0x160>
    80005156:	e9ca                	sd	s2,208(sp)
  if((ip = dirlookup(dp, name, &off)) == 0)
    80005158:	f2c40613          	addi	a2,s0,-212
    8000515c:	fb040593          	addi	a1,s0,-80
    80005160:	8526                	mv	a0,s1
    80005162:	9b3fe0ef          	jal	80003b14 <dirlookup>
    80005166:	892a                	mv	s2,a0
    80005168:	0e050863          	beqz	a0,80005258 <sys_unlink+0x15e>
  ilock(ip);
    8000516c:	bf8fe0ef          	jal	80003564 <ilock>
  if(ip->nlink < 1)
    80005170:	04a91783          	lh	a5,74(s2)
    80005174:	06f05763          	blez	a5,800051e2 <sys_unlink+0xe8>
  if(ip->type == T_DIR && !isdirempty(ip)){
    80005178:	04491703          	lh	a4,68(s2)
    8000517c:	4785                	li	a5,1
    8000517e:	06f70963          	beq	a4,a5,800051f0 <sys_unlink+0xf6>
  memset(&de, 0, sizeof(de));
    80005182:	4641                	li	a2,16
    80005184:	4581                	li	a1,0
    80005186:	fc040513          	addi	a0,s0,-64
    8000518a:	b19fb0ef          	jal	80000ca2 <memset>
  if(writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    8000518e:	4741                	li	a4,16
    80005190:	f2c42683          	lw	a3,-212(s0)
    80005194:	fc040613          	addi	a2,s0,-64
    80005198:	4581                	li	a1,0
    8000519a:	8526                	mv	a0,s1
    8000519c:	855fe0ef          	jal	800039f0 <writei>
    800051a0:	47c1                	li	a5,16
    800051a2:	08f51b63          	bne	a0,a5,80005238 <sys_unlink+0x13e>
  if(ip->type == T_DIR){
    800051a6:	04491703          	lh	a4,68(s2)
    800051aa:	4785                	li	a5,1
    800051ac:	08f70d63          	beq	a4,a5,80005246 <sys_unlink+0x14c>
  iunlockput(dp);
    800051b0:	8526                	mv	a0,s1
    800051b2:	dbcfe0ef          	jal	8000376e <iunlockput>
  ip->nlink--;
    800051b6:	04a95783          	lhu	a5,74(s2)
    800051ba:	37fd                	addiw	a5,a5,-1
    800051bc:	04f91523          	sh	a5,74(s2)
  iupdate(ip);
    800051c0:	854a                	mv	a0,s2
    800051c2:	aeefe0ef          	jal	800034b0 <iupdate>
  iunlockput(ip);
    800051c6:	854a                	mv	a0,s2
    800051c8:	da6fe0ef          	jal	8000376e <iunlockput>
  end_op();
    800051cc:	dedfe0ef          	jal	80003fb8 <end_op>
  return 0;
    800051d0:	4501                	li	a0,0
    800051d2:	64ee                	ld	s1,216(sp)
    800051d4:	694e                	ld	s2,208(sp)
    800051d6:	a849                	j	80005268 <sys_unlink+0x16e>
    end_op();
    800051d8:	de1fe0ef          	jal	80003fb8 <end_op>
    return -1;
    800051dc:	557d                	li	a0,-1
    800051de:	64ee                	ld	s1,216(sp)
    800051e0:	a061                	j	80005268 <sys_unlink+0x16e>
    800051e2:	e5ce                	sd	s3,200(sp)
    panic("unlink: nlink < 1");
    800051e4:	00002517          	auipc	a0,0x2
    800051e8:	4ec50513          	addi	a0,a0,1260 # 800076d0 <etext+0x6d0>
    800051ec:	df4fb0ef          	jal	800007e0 <panic>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    800051f0:	04c92703          	lw	a4,76(s2)
    800051f4:	02000793          	li	a5,32
    800051f8:	f8e7f5e3          	bgeu	a5,a4,80005182 <sys_unlink+0x88>
    800051fc:	e5ce                	sd	s3,200(sp)
    800051fe:	02000993          	li	s3,32
    if(readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
    80005202:	4741                	li	a4,16
    80005204:	86ce                	mv	a3,s3
    80005206:	f1840613          	addi	a2,s0,-232
    8000520a:	4581                	li	a1,0
    8000520c:	854a                	mv	a0,s2
    8000520e:	ee6fe0ef          	jal	800038f4 <readi>
    80005212:	47c1                	li	a5,16
    80005214:	00f51c63          	bne	a0,a5,8000522c <sys_unlink+0x132>
    if(de.inum != 0)
    80005218:	f1845783          	lhu	a5,-232(s0)
    8000521c:	efa1                	bnez	a5,80005274 <sys_unlink+0x17a>
  for(off=2*sizeof(de); off<dp->size; off+=sizeof(de)){
    8000521e:	29c1                	addiw	s3,s3,16
    80005220:	04c92783          	lw	a5,76(s2)
    80005224:	fcf9efe3          	bltu	s3,a5,80005202 <sys_unlink+0x108>
    80005228:	69ae                	ld	s3,200(sp)
    8000522a:	bfa1                	j	80005182 <sys_unlink+0x88>
      panic("isdirempty: readi");
    8000522c:	00002517          	auipc	a0,0x2
    80005230:	4bc50513          	addi	a0,a0,1212 # 800076e8 <etext+0x6e8>
    80005234:	dacfb0ef          	jal	800007e0 <panic>
    80005238:	e5ce                	sd	s3,200(sp)
    panic("unlink: writei");
    8000523a:	00002517          	auipc	a0,0x2
    8000523e:	4c650513          	addi	a0,a0,1222 # 80007700 <etext+0x700>
    80005242:	d9efb0ef          	jal	800007e0 <panic>
    dp->nlink--;
    80005246:	04a4d783          	lhu	a5,74(s1)
    8000524a:	37fd                	addiw	a5,a5,-1
    8000524c:	04f49523          	sh	a5,74(s1)
    iupdate(dp);
    80005250:	8526                	mv	a0,s1
    80005252:	a5efe0ef          	jal	800034b0 <iupdate>
    80005256:	bfa9                	j	800051b0 <sys_unlink+0xb6>
    80005258:	694e                	ld	s2,208(sp)
  iunlockput(dp);
    8000525a:	8526                	mv	a0,s1
    8000525c:	d12fe0ef          	jal	8000376e <iunlockput>
  end_op();
    80005260:	d59fe0ef          	jal	80003fb8 <end_op>
  return -1;
    80005264:	557d                	li	a0,-1
    80005266:	64ee                	ld	s1,216(sp)
}
    80005268:	70ae                	ld	ra,232(sp)
    8000526a:	740e                	ld	s0,224(sp)
    8000526c:	616d                	addi	sp,sp,240
    8000526e:	8082                	ret
    return -1;
    80005270:	557d                	li	a0,-1
    80005272:	bfdd                	j	80005268 <sys_unlink+0x16e>
    iunlockput(ip);
    80005274:	854a                	mv	a0,s2
    80005276:	cf8fe0ef          	jal	8000376e <iunlockput>
    goto bad;
    8000527a:	694e                	ld	s2,208(sp)
    8000527c:	69ae                	ld	s3,200(sp)
    8000527e:	bff1                	j	8000525a <sys_unlink+0x160>

0000000080005280 <sys_open>:

uint64
sys_open(void)
{
    80005280:	7131                	addi	sp,sp,-192
    80005282:	fd06                	sd	ra,184(sp)
    80005284:	f922                	sd	s0,176(sp)
    80005286:	0180                	addi	s0,sp,192
  int fd, omode;
  struct file *f;
  struct inode *ip;
  int n;

  argint(1, &omode);
    80005288:	f4c40593          	addi	a1,s0,-180
    8000528c:	4505                	li	a0,1
    8000528e:	dc8fd0ef          	jal	80002856 <argint>
  if((n = argstr(0, path, MAXPATH)) < 0)
    80005292:	08000613          	li	a2,128
    80005296:	f5040593          	addi	a1,s0,-176
    8000529a:	4501                	li	a0,0
    8000529c:	df2fd0ef          	jal	8000288e <argstr>
    800052a0:	87aa                	mv	a5,a0
    return -1;
    800052a2:	557d                	li	a0,-1
  if((n = argstr(0, path, MAXPATH)) < 0)
    800052a4:	0a07c263          	bltz	a5,80005348 <sys_open+0xc8>
    800052a8:	f526                	sd	s1,168(sp)

  begin_op();
    800052aa:	ca5fe0ef          	jal	80003f4e <begin_op>

  if(omode & O_CREATE){
    800052ae:	f4c42783          	lw	a5,-180(s0)
    800052b2:	2007f793          	andi	a5,a5,512
    800052b6:	c3d5                	beqz	a5,8000535a <sys_open+0xda>
    ip = create(path, T_FILE, 0, 0);
    800052b8:	4681                	li	a3,0
    800052ba:	4601                	li	a2,0
    800052bc:	4589                	li	a1,2
    800052be:	f5040513          	addi	a0,s0,-176
    800052c2:	aa9ff0ef          	jal	80004d6a <create>
    800052c6:	84aa                	mv	s1,a0
    if(ip == 0){
    800052c8:	c541                	beqz	a0,80005350 <sys_open+0xd0>
      end_op();
      return -1;
    }
  }

  if(ip->type == T_DEVICE && (ip->major < 0 || ip->major >= NDEV)){
    800052ca:	04449703          	lh	a4,68(s1)
    800052ce:	478d                	li	a5,3
    800052d0:	00f71763          	bne	a4,a5,800052de <sys_open+0x5e>
    800052d4:	0464d703          	lhu	a4,70(s1)
    800052d8:	47a5                	li	a5,9
    800052da:	0ae7ed63          	bltu	a5,a4,80005394 <sys_open+0x114>
    800052de:	f14a                	sd	s2,160(sp)
    iunlockput(ip);
    end_op();
    return -1;
  }

  if((f = filealloc()) == 0 || (fd = fdalloc(f)) < 0){
    800052e0:	fd7fe0ef          	jal	800042b6 <filealloc>
    800052e4:	892a                	mv	s2,a0
    800052e6:	c179                	beqz	a0,800053ac <sys_open+0x12c>
    800052e8:	ed4e                	sd	s3,152(sp)
    800052ea:	a43ff0ef          	jal	80004d2c <fdalloc>
    800052ee:	89aa                	mv	s3,a0
    800052f0:	0a054a63          	bltz	a0,800053a4 <sys_open+0x124>
    iunlockput(ip);
    end_op();
    return -1;
  }

  if(ip->type == T_DEVICE){
    800052f4:	04449703          	lh	a4,68(s1)
    800052f8:	478d                	li	a5,3
    800052fa:	0cf70263          	beq	a4,a5,800053be <sys_open+0x13e>
    f->type = FD_DEVICE;
    f->major = ip->major;
  } else {
    f->type = FD_INODE;
    800052fe:	4789                	li	a5,2
    80005300:	00f92023          	sw	a5,0(s2)
    f->off = 0;
    80005304:	02092023          	sw	zero,32(s2)
  }
  f->ip = ip;
    80005308:	00993c23          	sd	s1,24(s2)
  f->readable = !(omode & O_WRONLY);
    8000530c:	f4c42783          	lw	a5,-180(s0)
    80005310:	0017c713          	xori	a4,a5,1
    80005314:	8b05                	andi	a4,a4,1
    80005316:	00e90423          	sb	a4,8(s2)
  f->writable = (omode & O_WRONLY) || (omode & O_RDWR);
    8000531a:	0037f713          	andi	a4,a5,3
    8000531e:	00e03733          	snez	a4,a4
    80005322:	00e904a3          	sb	a4,9(s2)

  if((omode & O_TRUNC) && ip->type == T_FILE){
    80005326:	4007f793          	andi	a5,a5,1024
    8000532a:	c791                	beqz	a5,80005336 <sys_open+0xb6>
    8000532c:	04449703          	lh	a4,68(s1)
    80005330:	4789                	li	a5,2
    80005332:	08f70d63          	beq	a4,a5,800053cc <sys_open+0x14c>
    itrunc(ip);
  }

  iunlock(ip);
    80005336:	8526                	mv	a0,s1
    80005338:	adafe0ef          	jal	80003612 <iunlock>
  end_op();
    8000533c:	c7dfe0ef          	jal	80003fb8 <end_op>

  return fd;
    80005340:	854e                	mv	a0,s3
    80005342:	74aa                	ld	s1,168(sp)
    80005344:	790a                	ld	s2,160(sp)
    80005346:	69ea                	ld	s3,152(sp)
}
    80005348:	70ea                	ld	ra,184(sp)
    8000534a:	744a                	ld	s0,176(sp)
    8000534c:	6129                	addi	sp,sp,192
    8000534e:	8082                	ret
      end_op();
    80005350:	c69fe0ef          	jal	80003fb8 <end_op>
      return -1;
    80005354:	557d                	li	a0,-1
    80005356:	74aa                	ld	s1,168(sp)
    80005358:	bfc5                	j	80005348 <sys_open+0xc8>
    if((ip = namei(path)) == 0){
    8000535a:	f5040513          	addi	a0,s0,-176
    8000535e:	a1dfe0ef          	jal	80003d7a <namei>
    80005362:	84aa                	mv	s1,a0
    80005364:	c11d                	beqz	a0,8000538a <sys_open+0x10a>
    ilock(ip);
    80005366:	9fefe0ef          	jal	80003564 <ilock>
    if(ip->type == T_DIR && omode != O_RDONLY){
    8000536a:	04449703          	lh	a4,68(s1)
    8000536e:	4785                	li	a5,1
    80005370:	f4f71de3          	bne	a4,a5,800052ca <sys_open+0x4a>
    80005374:	f4c42783          	lw	a5,-180(s0)
    80005378:	d3bd                	beqz	a5,800052de <sys_open+0x5e>
      iunlockput(ip);
    8000537a:	8526                	mv	a0,s1
    8000537c:	bf2fe0ef          	jal	8000376e <iunlockput>
      end_op();
    80005380:	c39fe0ef          	jal	80003fb8 <end_op>
      return -1;
    80005384:	557d                	li	a0,-1
    80005386:	74aa                	ld	s1,168(sp)
    80005388:	b7c1                	j	80005348 <sys_open+0xc8>
      end_op();
    8000538a:	c2ffe0ef          	jal	80003fb8 <end_op>
      return -1;
    8000538e:	557d                	li	a0,-1
    80005390:	74aa                	ld	s1,168(sp)
    80005392:	bf5d                	j	80005348 <sys_open+0xc8>
    iunlockput(ip);
    80005394:	8526                	mv	a0,s1
    80005396:	bd8fe0ef          	jal	8000376e <iunlockput>
    end_op();
    8000539a:	c1ffe0ef          	jal	80003fb8 <end_op>
    return -1;
    8000539e:	557d                	li	a0,-1
    800053a0:	74aa                	ld	s1,168(sp)
    800053a2:	b75d                	j	80005348 <sys_open+0xc8>
      fileclose(f);
    800053a4:	854a                	mv	a0,s2
    800053a6:	fb5fe0ef          	jal	8000435a <fileclose>
    800053aa:	69ea                	ld	s3,152(sp)
    iunlockput(ip);
    800053ac:	8526                	mv	a0,s1
    800053ae:	bc0fe0ef          	jal	8000376e <iunlockput>
    end_op();
    800053b2:	c07fe0ef          	jal	80003fb8 <end_op>
    return -1;
    800053b6:	557d                	li	a0,-1
    800053b8:	74aa                	ld	s1,168(sp)
    800053ba:	790a                	ld	s2,160(sp)
    800053bc:	b771                	j	80005348 <sys_open+0xc8>
    f->type = FD_DEVICE;
    800053be:	00f92023          	sw	a5,0(s2)
    f->major = ip->major;
    800053c2:	04649783          	lh	a5,70(s1)
    800053c6:	02f91223          	sh	a5,36(s2)
    800053ca:	bf3d                	j	80005308 <sys_open+0x88>
    itrunc(ip);
    800053cc:	8526                	mv	a0,s1
    800053ce:	a84fe0ef          	jal	80003652 <itrunc>
    800053d2:	b795                	j	80005336 <sys_open+0xb6>

00000000800053d4 <sys_mkdir>:

uint64
sys_mkdir(void)
{
    800053d4:	7175                	addi	sp,sp,-144
    800053d6:	e506                	sd	ra,136(sp)
    800053d8:	e122                	sd	s0,128(sp)
    800053da:	0900                	addi	s0,sp,144
  char path[MAXPATH];
  struct inode *ip;

  begin_op();
    800053dc:	b73fe0ef          	jal	80003f4e <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = create(path, T_DIR, 0, 0)) == 0){
    800053e0:	08000613          	li	a2,128
    800053e4:	f7040593          	addi	a1,s0,-144
    800053e8:	4501                	li	a0,0
    800053ea:	ca4fd0ef          	jal	8000288e <argstr>
    800053ee:	02054363          	bltz	a0,80005414 <sys_mkdir+0x40>
    800053f2:	4681                	li	a3,0
    800053f4:	4601                	li	a2,0
    800053f6:	4585                	li	a1,1
    800053f8:	f7040513          	addi	a0,s0,-144
    800053fc:	96fff0ef          	jal	80004d6a <create>
    80005400:	c911                	beqz	a0,80005414 <sys_mkdir+0x40>
    end_op();
    return -1;
  }
  iunlockput(ip);
    80005402:	b6cfe0ef          	jal	8000376e <iunlockput>
  end_op();
    80005406:	bb3fe0ef          	jal	80003fb8 <end_op>
  return 0;
    8000540a:	4501                	li	a0,0
}
    8000540c:	60aa                	ld	ra,136(sp)
    8000540e:	640a                	ld	s0,128(sp)
    80005410:	6149                	addi	sp,sp,144
    80005412:	8082                	ret
    end_op();
    80005414:	ba5fe0ef          	jal	80003fb8 <end_op>
    return -1;
    80005418:	557d                	li	a0,-1
    8000541a:	bfcd                	j	8000540c <sys_mkdir+0x38>

000000008000541c <sys_mknod>:

uint64
sys_mknod(void)
{
    8000541c:	7135                	addi	sp,sp,-160
    8000541e:	ed06                	sd	ra,152(sp)
    80005420:	e922                	sd	s0,144(sp)
    80005422:	1100                	addi	s0,sp,160
  struct inode *ip;
  char path[MAXPATH];
  int major, minor;

  begin_op();
    80005424:	b2bfe0ef          	jal	80003f4e <begin_op>
  argint(1, &major);
    80005428:	f6c40593          	addi	a1,s0,-148
    8000542c:	4505                	li	a0,1
    8000542e:	c28fd0ef          	jal	80002856 <argint>
  argint(2, &minor);
    80005432:	f6840593          	addi	a1,s0,-152
    80005436:	4509                	li	a0,2
    80005438:	c1efd0ef          	jal	80002856 <argint>
  if((argstr(0, path, MAXPATH)) < 0 ||
    8000543c:	08000613          	li	a2,128
    80005440:	f7040593          	addi	a1,s0,-144
    80005444:	4501                	li	a0,0
    80005446:	c48fd0ef          	jal	8000288e <argstr>
    8000544a:	02054563          	bltz	a0,80005474 <sys_mknod+0x58>
     (ip = create(path, T_DEVICE, major, minor)) == 0){
    8000544e:	f6841683          	lh	a3,-152(s0)
    80005452:	f6c41603          	lh	a2,-148(s0)
    80005456:	458d                	li	a1,3
    80005458:	f7040513          	addi	a0,s0,-144
    8000545c:	90fff0ef          	jal	80004d6a <create>
  if((argstr(0, path, MAXPATH)) < 0 ||
    80005460:	c911                	beqz	a0,80005474 <sys_mknod+0x58>
    end_op();
    return -1;
  }
  iunlockput(ip);
    80005462:	b0cfe0ef          	jal	8000376e <iunlockput>
  end_op();
    80005466:	b53fe0ef          	jal	80003fb8 <end_op>
  return 0;
    8000546a:	4501                	li	a0,0
}
    8000546c:	60ea                	ld	ra,152(sp)
    8000546e:	644a                	ld	s0,144(sp)
    80005470:	610d                	addi	sp,sp,160
    80005472:	8082                	ret
    end_op();
    80005474:	b45fe0ef          	jal	80003fb8 <end_op>
    return -1;
    80005478:	557d                	li	a0,-1
    8000547a:	bfcd                	j	8000546c <sys_mknod+0x50>

000000008000547c <sys_chdir>:

uint64
sys_chdir(void)
{
    8000547c:	7135                	addi	sp,sp,-160
    8000547e:	ed06                	sd	ra,152(sp)
    80005480:	e922                	sd	s0,144(sp)
    80005482:	e14a                	sd	s2,128(sp)
    80005484:	1100                	addi	s0,sp,160
  char path[MAXPATH];
  struct inode *ip;
  struct proc *p = myproc();
    80005486:	c48fc0ef          	jal	800018ce <myproc>
    8000548a:	892a                	mv	s2,a0
  
  begin_op();
    8000548c:	ac3fe0ef          	jal	80003f4e <begin_op>
  if(argstr(0, path, MAXPATH) < 0 || (ip = namei(path)) == 0){
    80005490:	08000613          	li	a2,128
    80005494:	f6040593          	addi	a1,s0,-160
    80005498:	4501                	li	a0,0
    8000549a:	bf4fd0ef          	jal	8000288e <argstr>
    8000549e:	04054363          	bltz	a0,800054e4 <sys_chdir+0x68>
    800054a2:	e526                	sd	s1,136(sp)
    800054a4:	f6040513          	addi	a0,s0,-160
    800054a8:	8d3fe0ef          	jal	80003d7a <namei>
    800054ac:	84aa                	mv	s1,a0
    800054ae:	c915                	beqz	a0,800054e2 <sys_chdir+0x66>
    end_op();
    return -1;
  }
  ilock(ip);
    800054b0:	8b4fe0ef          	jal	80003564 <ilock>
  if(ip->type != T_DIR){
    800054b4:	04449703          	lh	a4,68(s1)
    800054b8:	4785                	li	a5,1
    800054ba:	02f71963          	bne	a4,a5,800054ec <sys_chdir+0x70>
    iunlockput(ip);
    end_op();
    return -1;
  }
  iunlock(ip);
    800054be:	8526                	mv	a0,s1
    800054c0:	952fe0ef          	jal	80003612 <iunlock>
  iput(p->cwd);
    800054c4:	15893503          	ld	a0,344(s2)
    800054c8:	a1efe0ef          	jal	800036e6 <iput>
  end_op();
    800054cc:	aedfe0ef          	jal	80003fb8 <end_op>
  p->cwd = ip;
    800054d0:	14993c23          	sd	s1,344(s2)
  return 0;
    800054d4:	4501                	li	a0,0
    800054d6:	64aa                	ld	s1,136(sp)
}
    800054d8:	60ea                	ld	ra,152(sp)
    800054da:	644a                	ld	s0,144(sp)
    800054dc:	690a                	ld	s2,128(sp)
    800054de:	610d                	addi	sp,sp,160
    800054e0:	8082                	ret
    800054e2:	64aa                	ld	s1,136(sp)
    end_op();
    800054e4:	ad5fe0ef          	jal	80003fb8 <end_op>
    return -1;
    800054e8:	557d                	li	a0,-1
    800054ea:	b7fd                	j	800054d8 <sys_chdir+0x5c>
    iunlockput(ip);
    800054ec:	8526                	mv	a0,s1
    800054ee:	a80fe0ef          	jal	8000376e <iunlockput>
    end_op();
    800054f2:	ac7fe0ef          	jal	80003fb8 <end_op>
    return -1;
    800054f6:	557d                	li	a0,-1
    800054f8:	64aa                	ld	s1,136(sp)
    800054fa:	bff9                	j	800054d8 <sys_chdir+0x5c>

00000000800054fc <sys_exec>:

uint64
sys_exec(void)
{
    800054fc:	7121                	addi	sp,sp,-448
    800054fe:	ff06                	sd	ra,440(sp)
    80005500:	fb22                	sd	s0,432(sp)
    80005502:	0380                	addi	s0,sp,448
  char path[MAXPATH], *argv[MAXARG];
  int i;
  uint64 uargv, uarg;

  argaddr(1, &uargv);
    80005504:	e4840593          	addi	a1,s0,-440
    80005508:	4505                	li	a0,1
    8000550a:	b68fd0ef          	jal	80002872 <argaddr>
  if(argstr(0, path, MAXPATH) < 0) {
    8000550e:	08000613          	li	a2,128
    80005512:	f5040593          	addi	a1,s0,-176
    80005516:	4501                	li	a0,0
    80005518:	b76fd0ef          	jal	8000288e <argstr>
    8000551c:	87aa                	mv	a5,a0
    return -1;
    8000551e:	557d                	li	a0,-1
  if(argstr(0, path, MAXPATH) < 0) {
    80005520:	0c07c463          	bltz	a5,800055e8 <sys_exec+0xec>
    80005524:	f726                	sd	s1,424(sp)
    80005526:	f34a                	sd	s2,416(sp)
    80005528:	ef4e                	sd	s3,408(sp)
    8000552a:	eb52                	sd	s4,400(sp)
  }
  memset(argv, 0, sizeof(argv));
    8000552c:	10000613          	li	a2,256
    80005530:	4581                	li	a1,0
    80005532:	e5040513          	addi	a0,s0,-432
    80005536:	f6cfb0ef          	jal	80000ca2 <memset>
  for(i=0;; i++){
    if(i >= NELEM(argv)){
    8000553a:	e5040493          	addi	s1,s0,-432
  memset(argv, 0, sizeof(argv));
    8000553e:	89a6                	mv	s3,s1
    80005540:	4901                	li	s2,0
    if(i >= NELEM(argv)){
    80005542:	02000a13          	li	s4,32
      goto bad;
    }
    if(fetchaddr(uargv+sizeof(uint64)*i, (uint64*)&uarg) < 0){
    80005546:	00391513          	slli	a0,s2,0x3
    8000554a:	e4040593          	addi	a1,s0,-448
    8000554e:	e4843783          	ld	a5,-440(s0)
    80005552:	953e                	add	a0,a0,a5
    80005554:	a78fd0ef          	jal	800027cc <fetchaddr>
    80005558:	02054663          	bltz	a0,80005584 <sys_exec+0x88>
      goto bad;
    }
    if(uarg == 0){
    8000555c:	e4043783          	ld	a5,-448(s0)
    80005560:	c3a9                	beqz	a5,800055a2 <sys_exec+0xa6>
      argv[i] = 0;
      break;
    }
    argv[i] = kalloc();
    80005562:	d9cfb0ef          	jal	80000afe <kalloc>
    80005566:	85aa                	mv	a1,a0
    80005568:	00a9b023          	sd	a0,0(s3)
    if(argv[i] == 0)
    8000556c:	cd01                	beqz	a0,80005584 <sys_exec+0x88>
      goto bad;
    if(fetchstr(uarg, argv[i], PGSIZE) < 0)
    8000556e:	6605                	lui	a2,0x1
    80005570:	e4043503          	ld	a0,-448(s0)
    80005574:	aa2fd0ef          	jal	80002816 <fetchstr>
    80005578:	00054663          	bltz	a0,80005584 <sys_exec+0x88>
    if(i >= NELEM(argv)){
    8000557c:	0905                	addi	s2,s2,1
    8000557e:	09a1                	addi	s3,s3,8
    80005580:	fd4913e3          	bne	s2,s4,80005546 <sys_exec+0x4a>
    kfree(argv[i]);

  return ret;

 bad:
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80005584:	f5040913          	addi	s2,s0,-176
    80005588:	6088                	ld	a0,0(s1)
    8000558a:	c931                	beqz	a0,800055de <sys_exec+0xe2>
    kfree(argv[i]);
    8000558c:	c90fb0ef          	jal	80000a1c <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    80005590:	04a1                	addi	s1,s1,8
    80005592:	ff249be3          	bne	s1,s2,80005588 <sys_exec+0x8c>
  return -1;
    80005596:	557d                	li	a0,-1
    80005598:	74ba                	ld	s1,424(sp)
    8000559a:	791a                	ld	s2,416(sp)
    8000559c:	69fa                	ld	s3,408(sp)
    8000559e:	6a5a                	ld	s4,400(sp)
    800055a0:	a0a1                	j	800055e8 <sys_exec+0xec>
      argv[i] = 0;
    800055a2:	0009079b          	sext.w	a5,s2
    800055a6:	078e                	slli	a5,a5,0x3
    800055a8:	fd078793          	addi	a5,a5,-48
    800055ac:	97a2                	add	a5,a5,s0
    800055ae:	e807b023          	sd	zero,-384(a5)
  int ret = kexec(path, argv);
    800055b2:	e5040593          	addi	a1,s0,-432
    800055b6:	f5040513          	addi	a0,s0,-176
    800055ba:	ba8ff0ef          	jal	80004962 <kexec>
    800055be:	892a                	mv	s2,a0
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    800055c0:	f5040993          	addi	s3,s0,-176
    800055c4:	6088                	ld	a0,0(s1)
    800055c6:	c511                	beqz	a0,800055d2 <sys_exec+0xd6>
    kfree(argv[i]);
    800055c8:	c54fb0ef          	jal	80000a1c <kfree>
  for(i = 0; i < NELEM(argv) && argv[i] != 0; i++)
    800055cc:	04a1                	addi	s1,s1,8
    800055ce:	ff349be3          	bne	s1,s3,800055c4 <sys_exec+0xc8>
  return ret;
    800055d2:	854a                	mv	a0,s2
    800055d4:	74ba                	ld	s1,424(sp)
    800055d6:	791a                	ld	s2,416(sp)
    800055d8:	69fa                	ld	s3,408(sp)
    800055da:	6a5a                	ld	s4,400(sp)
    800055dc:	a031                	j	800055e8 <sys_exec+0xec>
  return -1;
    800055de:	557d                	li	a0,-1
    800055e0:	74ba                	ld	s1,424(sp)
    800055e2:	791a                	ld	s2,416(sp)
    800055e4:	69fa                	ld	s3,408(sp)
    800055e6:	6a5a                	ld	s4,400(sp)
}
    800055e8:	70fa                	ld	ra,440(sp)
    800055ea:	745a                	ld	s0,432(sp)
    800055ec:	6139                	addi	sp,sp,448
    800055ee:	8082                	ret

00000000800055f0 <sys_pipe>:

uint64
sys_pipe(void)
{
    800055f0:	7139                	addi	sp,sp,-64
    800055f2:	fc06                	sd	ra,56(sp)
    800055f4:	f822                	sd	s0,48(sp)
    800055f6:	f426                	sd	s1,40(sp)
    800055f8:	0080                	addi	s0,sp,64
  uint64 fdarray; // user pointer to array of two integers
  struct file *rf, *wf;
  int fd0, fd1;
  struct proc *p = myproc();
    800055fa:	ad4fc0ef          	jal	800018ce <myproc>
    800055fe:	84aa                	mv	s1,a0

  argaddr(0, &fdarray);
    80005600:	fd840593          	addi	a1,s0,-40
    80005604:	4501                	li	a0,0
    80005606:	a6cfd0ef          	jal	80002872 <argaddr>
  if(pipealloc(&rf, &wf) < 0)
    8000560a:	fc840593          	addi	a1,s0,-56
    8000560e:	fd040513          	addi	a0,s0,-48
    80005612:	852ff0ef          	jal	80004664 <pipealloc>
    return -1;
    80005616:	57fd                	li	a5,-1
  if(pipealloc(&rf, &wf) < 0)
    80005618:	0a054463          	bltz	a0,800056c0 <sys_pipe+0xd0>
  fd0 = -1;
    8000561c:	fcf42223          	sw	a5,-60(s0)
  if((fd0 = fdalloc(rf)) < 0 || (fd1 = fdalloc(wf)) < 0){
    80005620:	fd043503          	ld	a0,-48(s0)
    80005624:	f08ff0ef          	jal	80004d2c <fdalloc>
    80005628:	fca42223          	sw	a0,-60(s0)
    8000562c:	08054163          	bltz	a0,800056ae <sys_pipe+0xbe>
    80005630:	fc843503          	ld	a0,-56(s0)
    80005634:	ef8ff0ef          	jal	80004d2c <fdalloc>
    80005638:	fca42023          	sw	a0,-64(s0)
    8000563c:	06054063          	bltz	a0,8000569c <sys_pipe+0xac>
      p->ofile[fd0] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    80005640:	4691                	li	a3,4
    80005642:	fc440613          	addi	a2,s0,-60
    80005646:	fd843583          	ld	a1,-40(s0)
    8000564a:	6ca8                	ld	a0,88(s1)
    8000564c:	f97fb0ef          	jal	800015e2 <copyout>
    80005650:	00054e63          	bltz	a0,8000566c <sys_pipe+0x7c>
     copyout(p->pagetable, fdarray+sizeof(fd0), (char *)&fd1, sizeof(fd1)) < 0){
    80005654:	4691                	li	a3,4
    80005656:	fc040613          	addi	a2,s0,-64
    8000565a:	fd843583          	ld	a1,-40(s0)
    8000565e:	0591                	addi	a1,a1,4
    80005660:	6ca8                	ld	a0,88(s1)
    80005662:	f81fb0ef          	jal	800015e2 <copyout>
    p->ofile[fd1] = 0;
    fileclose(rf);
    fileclose(wf);
    return -1;
  }
  return 0;
    80005666:	4781                	li	a5,0
  if(copyout(p->pagetable, fdarray, (char*)&fd0, sizeof(fd0)) < 0 ||
    80005668:	04055c63          	bgez	a0,800056c0 <sys_pipe+0xd0>
    p->ofile[fd0] = 0;
    8000566c:	fc442783          	lw	a5,-60(s0)
    80005670:	07e9                	addi	a5,a5,26
    80005672:	078e                	slli	a5,a5,0x3
    80005674:	97a6                	add	a5,a5,s1
    80005676:	0007b423          	sd	zero,8(a5)
    p->ofile[fd1] = 0;
    8000567a:	fc042783          	lw	a5,-64(s0)
    8000567e:	07e9                	addi	a5,a5,26
    80005680:	078e                	slli	a5,a5,0x3
    80005682:	94be                	add	s1,s1,a5
    80005684:	0004b423          	sd	zero,8(s1)
    fileclose(rf);
    80005688:	fd043503          	ld	a0,-48(s0)
    8000568c:	ccffe0ef          	jal	8000435a <fileclose>
    fileclose(wf);
    80005690:	fc843503          	ld	a0,-56(s0)
    80005694:	cc7fe0ef          	jal	8000435a <fileclose>
    return -1;
    80005698:	57fd                	li	a5,-1
    8000569a:	a01d                	j	800056c0 <sys_pipe+0xd0>
    if(fd0 >= 0)
    8000569c:	fc442783          	lw	a5,-60(s0)
    800056a0:	0007c763          	bltz	a5,800056ae <sys_pipe+0xbe>
      p->ofile[fd0] = 0;
    800056a4:	07e9                	addi	a5,a5,26
    800056a6:	078e                	slli	a5,a5,0x3
    800056a8:	97a6                	add	a5,a5,s1
    800056aa:	0007b423          	sd	zero,8(a5)
    fileclose(rf);
    800056ae:	fd043503          	ld	a0,-48(s0)
    800056b2:	ca9fe0ef          	jal	8000435a <fileclose>
    fileclose(wf);
    800056b6:	fc843503          	ld	a0,-56(s0)
    800056ba:	ca1fe0ef          	jal	8000435a <fileclose>
    return -1;
    800056be:	57fd                	li	a5,-1
}
    800056c0:	853e                	mv	a0,a5
    800056c2:	70e2                	ld	ra,56(sp)
    800056c4:	7442                	ld	s0,48(sp)
    800056c6:	74a2                	ld	s1,40(sp)
    800056c8:	6121                	addi	sp,sp,64
    800056ca:	8082                	ret
    800056cc:	0000                	unimp
	...

00000000800056d0 <kernelvec>:
.globl kerneltrap
.globl kernelvec
.align 4
kernelvec:
        # make room to save registers.
        addi sp, sp, -256
    800056d0:	7111                	addi	sp,sp,-256

        # save caller-saved registers.
        sd ra, 0(sp)
    800056d2:	e006                	sd	ra,0(sp)
        # sd sp, 8(sp)
        sd gp, 16(sp)
    800056d4:	e80e                	sd	gp,16(sp)
        sd tp, 24(sp)
    800056d6:	ec12                	sd	tp,24(sp)
        sd t0, 32(sp)
    800056d8:	f016                	sd	t0,32(sp)
        sd t1, 40(sp)
    800056da:	f41a                	sd	t1,40(sp)
        sd t2, 48(sp)
    800056dc:	f81e                	sd	t2,48(sp)
        sd a0, 72(sp)
    800056de:	e4aa                	sd	a0,72(sp)
        sd a1, 80(sp)
    800056e0:	e8ae                	sd	a1,80(sp)
        sd a2, 88(sp)
    800056e2:	ecb2                	sd	a2,88(sp)
        sd a3, 96(sp)
    800056e4:	f0b6                	sd	a3,96(sp)
        sd a4, 104(sp)
    800056e6:	f4ba                	sd	a4,104(sp)
        sd a5, 112(sp)
    800056e8:	f8be                	sd	a5,112(sp)
        sd a6, 120(sp)
    800056ea:	fcc2                	sd	a6,120(sp)
        sd a7, 128(sp)
    800056ec:	e146                	sd	a7,128(sp)
        sd t3, 216(sp)
    800056ee:	edf2                	sd	t3,216(sp)
        sd t4, 224(sp)
    800056f0:	f1f6                	sd	t4,224(sp)
        sd t5, 232(sp)
    800056f2:	f5fa                	sd	t5,232(sp)
        sd t6, 240(sp)
    800056f4:	f9fe                	sd	t6,240(sp)

        # call the C trap handler in trap.c
        call kerneltrap
    800056f6:	fe7fc0ef          	jal	800026dc <kerneltrap>

        # restore registers.
        ld ra, 0(sp)
    800056fa:	6082                	ld	ra,0(sp)
        # ld sp, 8(sp)
        ld gp, 16(sp)
    800056fc:	61c2                	ld	gp,16(sp)
        # not tp (contains hartid), in case we moved CPUs
        ld t0, 32(sp)
    800056fe:	7282                	ld	t0,32(sp)
        ld t1, 40(sp)
    80005700:	7322                	ld	t1,40(sp)
        ld t2, 48(sp)
    80005702:	73c2                	ld	t2,48(sp)
        ld a0, 72(sp)
    80005704:	6526                	ld	a0,72(sp)
        ld a1, 80(sp)
    80005706:	65c6                	ld	a1,80(sp)
        ld a2, 88(sp)
    80005708:	6666                	ld	a2,88(sp)
        ld a3, 96(sp)
    8000570a:	7686                	ld	a3,96(sp)
        ld a4, 104(sp)
    8000570c:	7726                	ld	a4,104(sp)
        ld a5, 112(sp)
    8000570e:	77c6                	ld	a5,112(sp)
        ld a6, 120(sp)
    80005710:	7866                	ld	a6,120(sp)
        ld a7, 128(sp)
    80005712:	688a                	ld	a7,128(sp)
        ld t3, 216(sp)
    80005714:	6e6e                	ld	t3,216(sp)
        ld t4, 224(sp)
    80005716:	7e8e                	ld	t4,224(sp)
        ld t5, 232(sp)
    80005718:	7f2e                	ld	t5,232(sp)
        ld t6, 240(sp)
    8000571a:	7fce                	ld	t6,240(sp)

        addi sp, sp, 256
    8000571c:	6111                	addi	sp,sp,256

        # return to whatever we were doing in the kernel.
        sret
    8000571e:	10200073          	sret
	...

000000008000572e <plicinit>:
// the riscv Platform Level Interrupt Controller (PLIC).
//

void
plicinit(void)
{
    8000572e:	1141                	addi	sp,sp,-16
    80005730:	e422                	sd	s0,8(sp)
    80005732:	0800                	addi	s0,sp,16
  // set desired IRQ priorities non-zero (otherwise disabled).
  *(uint32*)(PLIC + UART0_IRQ*4) = 1;
    80005734:	0c0007b7          	lui	a5,0xc000
    80005738:	4705                	li	a4,1
    8000573a:	d798                	sw	a4,40(a5)
  *(uint32*)(PLIC + VIRTIO0_IRQ*4) = 1;
    8000573c:	0c0007b7          	lui	a5,0xc000
    80005740:	c3d8                	sw	a4,4(a5)
}
    80005742:	6422                	ld	s0,8(sp)
    80005744:	0141                	addi	sp,sp,16
    80005746:	8082                	ret

0000000080005748 <plicinithart>:

void
plicinithart(void)
{
    80005748:	1141                	addi	sp,sp,-16
    8000574a:	e406                	sd	ra,8(sp)
    8000574c:	e022                	sd	s0,0(sp)
    8000574e:	0800                	addi	s0,sp,16
  int hart = cpuid();
    80005750:	952fc0ef          	jal	800018a2 <cpuid>
  
  // set enable bits for this hart's S-mode
  // for the uart and virtio disk.
  *(uint32*)PLIC_SENABLE(hart) = (1 << UART0_IRQ) | (1 << VIRTIO0_IRQ);
    80005754:	0085171b          	slliw	a4,a0,0x8
    80005758:	0c0027b7          	lui	a5,0xc002
    8000575c:	97ba                	add	a5,a5,a4
    8000575e:	40200713          	li	a4,1026
    80005762:	08e7a023          	sw	a4,128(a5) # c002080 <_entry-0x73ffdf80>

  // set this hart's S-mode priority threshold to 0.
  *(uint32*)PLIC_SPRIORITY(hart) = 0;
    80005766:	00d5151b          	slliw	a0,a0,0xd
    8000576a:	0c2017b7          	lui	a5,0xc201
    8000576e:	97aa                	add	a5,a5,a0
    80005770:	0007a023          	sw	zero,0(a5) # c201000 <_entry-0x73dff000>
}
    80005774:	60a2                	ld	ra,8(sp)
    80005776:	6402                	ld	s0,0(sp)
    80005778:	0141                	addi	sp,sp,16
    8000577a:	8082                	ret

000000008000577c <plic_claim>:

// ask the PLIC what interrupt we should serve.
int
plic_claim(void)
{
    8000577c:	1141                	addi	sp,sp,-16
    8000577e:	e406                	sd	ra,8(sp)
    80005780:	e022                	sd	s0,0(sp)
    80005782:	0800                	addi	s0,sp,16
  int hart = cpuid();
    80005784:	91efc0ef          	jal	800018a2 <cpuid>
  int irq = *(uint32*)PLIC_SCLAIM(hart);
    80005788:	00d5151b          	slliw	a0,a0,0xd
    8000578c:	0c2017b7          	lui	a5,0xc201
    80005790:	97aa                	add	a5,a5,a0
  return irq;
}
    80005792:	43c8                	lw	a0,4(a5)
    80005794:	60a2                	ld	ra,8(sp)
    80005796:	6402                	ld	s0,0(sp)
    80005798:	0141                	addi	sp,sp,16
    8000579a:	8082                	ret

000000008000579c <plic_complete>:

// tell the PLIC we've served this IRQ.
void
plic_complete(int irq)
{
    8000579c:	1101                	addi	sp,sp,-32
    8000579e:	ec06                	sd	ra,24(sp)
    800057a0:	e822                	sd	s0,16(sp)
    800057a2:	e426                	sd	s1,8(sp)
    800057a4:	1000                	addi	s0,sp,32
    800057a6:	84aa                	mv	s1,a0
  int hart = cpuid();
    800057a8:	8fafc0ef          	jal	800018a2 <cpuid>
  *(uint32*)PLIC_SCLAIM(hart) = irq;
    800057ac:	00d5151b          	slliw	a0,a0,0xd
    800057b0:	0c2017b7          	lui	a5,0xc201
    800057b4:	97aa                	add	a5,a5,a0
    800057b6:	c3c4                	sw	s1,4(a5)
}
    800057b8:	60e2                	ld	ra,24(sp)
    800057ba:	6442                	ld	s0,16(sp)
    800057bc:	64a2                	ld	s1,8(sp)
    800057be:	6105                	addi	sp,sp,32
    800057c0:	8082                	ret

00000000800057c2 <free_desc>:
}

// mark a descriptor as free.
static void
free_desc(int i)
{
    800057c2:	1141                	addi	sp,sp,-16
    800057c4:	e406                	sd	ra,8(sp)
    800057c6:	e022                	sd	s0,0(sp)
    800057c8:	0800                	addi	s0,sp,16
  if(i >= NUM)
    800057ca:	479d                	li	a5,7
    800057cc:	04a7ca63          	blt	a5,a0,80005820 <free_desc+0x5e>
    panic("free_desc 1");
  if(disk.free[i])
    800057d0:	0001e797          	auipc	a5,0x1e
    800057d4:	2c878793          	addi	a5,a5,712 # 80023a98 <disk>
    800057d8:	97aa                	add	a5,a5,a0
    800057da:	0187c783          	lbu	a5,24(a5)
    800057de:	e7b9                	bnez	a5,8000582c <free_desc+0x6a>
    panic("free_desc 2");
  disk.desc[i].addr = 0;
    800057e0:	00451693          	slli	a3,a0,0x4
    800057e4:	0001e797          	auipc	a5,0x1e
    800057e8:	2b478793          	addi	a5,a5,692 # 80023a98 <disk>
    800057ec:	6398                	ld	a4,0(a5)
    800057ee:	9736                	add	a4,a4,a3
    800057f0:	00073023          	sd	zero,0(a4)
  disk.desc[i].len = 0;
    800057f4:	6398                	ld	a4,0(a5)
    800057f6:	9736                	add	a4,a4,a3
    800057f8:	00072423          	sw	zero,8(a4)
  disk.desc[i].flags = 0;
    800057fc:	00071623          	sh	zero,12(a4)
  disk.desc[i].next = 0;
    80005800:	00071723          	sh	zero,14(a4)
  disk.free[i] = 1;
    80005804:	97aa                	add	a5,a5,a0
    80005806:	4705                	li	a4,1
    80005808:	00e78c23          	sb	a4,24(a5)
  wakeup(&disk.free[0]);
    8000580c:	0001e517          	auipc	a0,0x1e
    80005810:	2a450513          	addi	a0,a0,676 # 80023ab0 <disk+0x18>
    80005814:	f8afc0ef          	jal	80001f9e <wakeup>
}
    80005818:	60a2                	ld	ra,8(sp)
    8000581a:	6402                	ld	s0,0(sp)
    8000581c:	0141                	addi	sp,sp,16
    8000581e:	8082                	ret
    panic("free_desc 1");
    80005820:	00002517          	auipc	a0,0x2
    80005824:	ef050513          	addi	a0,a0,-272 # 80007710 <etext+0x710>
    80005828:	fb9fa0ef          	jal	800007e0 <panic>
    panic("free_desc 2");
    8000582c:	00002517          	auipc	a0,0x2
    80005830:	ef450513          	addi	a0,a0,-268 # 80007720 <etext+0x720>
    80005834:	fadfa0ef          	jal	800007e0 <panic>

0000000080005838 <virtio_disk_init>:
{
    80005838:	1101                	addi	sp,sp,-32
    8000583a:	ec06                	sd	ra,24(sp)
    8000583c:	e822                	sd	s0,16(sp)
    8000583e:	e426                	sd	s1,8(sp)
    80005840:	e04a                	sd	s2,0(sp)
    80005842:	1000                	addi	s0,sp,32
  initlock(&disk.vdisk_lock, "virtio_disk");
    80005844:	00002597          	auipc	a1,0x2
    80005848:	eec58593          	addi	a1,a1,-276 # 80007730 <etext+0x730>
    8000584c:	0001e517          	auipc	a0,0x1e
    80005850:	37450513          	addi	a0,a0,884 # 80023bc0 <disk+0x128>
    80005854:	afafb0ef          	jal	80000b4e <initlock>
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    80005858:	100017b7          	lui	a5,0x10001
    8000585c:	4398                	lw	a4,0(a5)
    8000585e:	2701                	sext.w	a4,a4
    80005860:	747277b7          	lui	a5,0x74727
    80005864:	97678793          	addi	a5,a5,-1674 # 74726976 <_entry-0xb8d968a>
    80005868:	18f71063          	bne	a4,a5,800059e8 <virtio_disk_init+0x1b0>
     *R(VIRTIO_MMIO_VERSION) != 2 ||
    8000586c:	100017b7          	lui	a5,0x10001
    80005870:	0791                	addi	a5,a5,4 # 10001004 <_entry-0x6fffeffc>
    80005872:	439c                	lw	a5,0(a5)
    80005874:	2781                	sext.w	a5,a5
  if(*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
    80005876:	4709                	li	a4,2
    80005878:	16e79863          	bne	a5,a4,800059e8 <virtio_disk_init+0x1b0>
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    8000587c:	100017b7          	lui	a5,0x10001
    80005880:	07a1                	addi	a5,a5,8 # 10001008 <_entry-0x6fffeff8>
    80005882:	439c                	lw	a5,0(a5)
    80005884:	2781                	sext.w	a5,a5
     *R(VIRTIO_MMIO_VERSION) != 2 ||
    80005886:	16e79163          	bne	a5,a4,800059e8 <virtio_disk_init+0x1b0>
     *R(VIRTIO_MMIO_VENDOR_ID) != 0x554d4551){
    8000588a:	100017b7          	lui	a5,0x10001
    8000588e:	47d8                	lw	a4,12(a5)
    80005890:	2701                	sext.w	a4,a4
     *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
    80005892:	554d47b7          	lui	a5,0x554d4
    80005896:	55178793          	addi	a5,a5,1361 # 554d4551 <_entry-0x2ab2baaf>
    8000589a:	14f71763          	bne	a4,a5,800059e8 <virtio_disk_init+0x1b0>
  *R(VIRTIO_MMIO_STATUS) = status;
    8000589e:	100017b7          	lui	a5,0x10001
    800058a2:	0607a823          	sw	zero,112(a5) # 10001070 <_entry-0x6fffef90>
  *R(VIRTIO_MMIO_STATUS) = status;
    800058a6:	4705                	li	a4,1
    800058a8:	dbb8                	sw	a4,112(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    800058aa:	470d                	li	a4,3
    800058ac:	dbb8                	sw	a4,112(a5)
  uint64 features = *R(VIRTIO_MMIO_DEVICE_FEATURES);
    800058ae:	10001737          	lui	a4,0x10001
    800058b2:	4b14                	lw	a3,16(a4)
  features &= ~(1 << VIRTIO_RING_F_INDIRECT_DESC);
    800058b4:	c7ffe737          	lui	a4,0xc7ffe
    800058b8:	75f70713          	addi	a4,a4,1887 # ffffffffc7ffe75f <end+0xffffffff47fdab87>
  *R(VIRTIO_MMIO_DRIVER_FEATURES) = features;
    800058bc:	8ef9                	and	a3,a3,a4
    800058be:	10001737          	lui	a4,0x10001
    800058c2:	d314                	sw	a3,32(a4)
  *R(VIRTIO_MMIO_STATUS) = status;
    800058c4:	472d                	li	a4,11
    800058c6:	dbb8                	sw	a4,112(a5)
  *R(VIRTIO_MMIO_STATUS) = status;
    800058c8:	07078793          	addi	a5,a5,112
  status = *R(VIRTIO_MMIO_STATUS);
    800058cc:	439c                	lw	a5,0(a5)
    800058ce:	0007891b          	sext.w	s2,a5
  if(!(status & VIRTIO_CONFIG_S_FEATURES_OK))
    800058d2:	8ba1                	andi	a5,a5,8
    800058d4:	12078063          	beqz	a5,800059f4 <virtio_disk_init+0x1bc>
  *R(VIRTIO_MMIO_QUEUE_SEL) = 0;
    800058d8:	100017b7          	lui	a5,0x10001
    800058dc:	0207a823          	sw	zero,48(a5) # 10001030 <_entry-0x6fffefd0>
  if(*R(VIRTIO_MMIO_QUEUE_READY))
    800058e0:	100017b7          	lui	a5,0x10001
    800058e4:	04478793          	addi	a5,a5,68 # 10001044 <_entry-0x6fffefbc>
    800058e8:	439c                	lw	a5,0(a5)
    800058ea:	2781                	sext.w	a5,a5
    800058ec:	10079a63          	bnez	a5,80005a00 <virtio_disk_init+0x1c8>
  uint32 max = *R(VIRTIO_MMIO_QUEUE_NUM_MAX);
    800058f0:	100017b7          	lui	a5,0x10001
    800058f4:	03478793          	addi	a5,a5,52 # 10001034 <_entry-0x6fffefcc>
    800058f8:	439c                	lw	a5,0(a5)
    800058fa:	2781                	sext.w	a5,a5
  if(max == 0)
    800058fc:	10078863          	beqz	a5,80005a0c <virtio_disk_init+0x1d4>
  if(max < NUM)
    80005900:	471d                	li	a4,7
    80005902:	10f77b63          	bgeu	a4,a5,80005a18 <virtio_disk_init+0x1e0>
  disk.desc = kalloc();
    80005906:	9f8fb0ef          	jal	80000afe <kalloc>
    8000590a:	0001e497          	auipc	s1,0x1e
    8000590e:	18e48493          	addi	s1,s1,398 # 80023a98 <disk>
    80005912:	e088                	sd	a0,0(s1)
  disk.avail = kalloc();
    80005914:	9eafb0ef          	jal	80000afe <kalloc>
    80005918:	e488                	sd	a0,8(s1)
  disk.used = kalloc();
    8000591a:	9e4fb0ef          	jal	80000afe <kalloc>
    8000591e:	87aa                	mv	a5,a0
    80005920:	e888                	sd	a0,16(s1)
  if(!disk.desc || !disk.avail || !disk.used)
    80005922:	6088                	ld	a0,0(s1)
    80005924:	10050063          	beqz	a0,80005a24 <virtio_disk_init+0x1ec>
    80005928:	0001e717          	auipc	a4,0x1e
    8000592c:	17873703          	ld	a4,376(a4) # 80023aa0 <disk+0x8>
    80005930:	0e070a63          	beqz	a4,80005a24 <virtio_disk_init+0x1ec>
    80005934:	0e078863          	beqz	a5,80005a24 <virtio_disk_init+0x1ec>
  memset(disk.desc, 0, PGSIZE);
    80005938:	6605                	lui	a2,0x1
    8000593a:	4581                	li	a1,0
    8000593c:	b66fb0ef          	jal	80000ca2 <memset>
  memset(disk.avail, 0, PGSIZE);
    80005940:	0001e497          	auipc	s1,0x1e
    80005944:	15848493          	addi	s1,s1,344 # 80023a98 <disk>
    80005948:	6605                	lui	a2,0x1
    8000594a:	4581                	li	a1,0
    8000594c:	6488                	ld	a0,8(s1)
    8000594e:	b54fb0ef          	jal	80000ca2 <memset>
  memset(disk.used, 0, PGSIZE);
    80005952:	6605                	lui	a2,0x1
    80005954:	4581                	li	a1,0
    80005956:	6888                	ld	a0,16(s1)
    80005958:	b4afb0ef          	jal	80000ca2 <memset>
  *R(VIRTIO_MMIO_QUEUE_NUM) = NUM;
    8000595c:	100017b7          	lui	a5,0x10001
    80005960:	4721                	li	a4,8
    80005962:	df98                	sw	a4,56(a5)
  *R(VIRTIO_MMIO_QUEUE_DESC_LOW) = (uint64)disk.desc;
    80005964:	4098                	lw	a4,0(s1)
    80005966:	100017b7          	lui	a5,0x10001
    8000596a:	08e7a023          	sw	a4,128(a5) # 10001080 <_entry-0x6fffef80>
  *R(VIRTIO_MMIO_QUEUE_DESC_HIGH) = (uint64)disk.desc >> 32;
    8000596e:	40d8                	lw	a4,4(s1)
    80005970:	100017b7          	lui	a5,0x10001
    80005974:	08e7a223          	sw	a4,132(a5) # 10001084 <_entry-0x6fffef7c>
  *R(VIRTIO_MMIO_DRIVER_DESC_LOW) = (uint64)disk.avail;
    80005978:	649c                	ld	a5,8(s1)
    8000597a:	0007869b          	sext.w	a3,a5
    8000597e:	10001737          	lui	a4,0x10001
    80005982:	08d72823          	sw	a3,144(a4) # 10001090 <_entry-0x6fffef70>
  *R(VIRTIO_MMIO_DRIVER_DESC_HIGH) = (uint64)disk.avail >> 32;
    80005986:	9781                	srai	a5,a5,0x20
    80005988:	10001737          	lui	a4,0x10001
    8000598c:	08f72a23          	sw	a5,148(a4) # 10001094 <_entry-0x6fffef6c>
  *R(VIRTIO_MMIO_DEVICE_DESC_LOW) = (uint64)disk.used;
    80005990:	689c                	ld	a5,16(s1)
    80005992:	0007869b          	sext.w	a3,a5
    80005996:	10001737          	lui	a4,0x10001
    8000599a:	0ad72023          	sw	a3,160(a4) # 100010a0 <_entry-0x6fffef60>
  *R(VIRTIO_MMIO_DEVICE_DESC_HIGH) = (uint64)disk.used >> 32;
    8000599e:	9781                	srai	a5,a5,0x20
    800059a0:	10001737          	lui	a4,0x10001
    800059a4:	0af72223          	sw	a5,164(a4) # 100010a4 <_entry-0x6fffef5c>
  *R(VIRTIO_MMIO_QUEUE_READY) = 0x1;
    800059a8:	10001737          	lui	a4,0x10001
    800059ac:	4785                	li	a5,1
    800059ae:	c37c                	sw	a5,68(a4)
    disk.free[i] = 1;
    800059b0:	00f48c23          	sb	a5,24(s1)
    800059b4:	00f48ca3          	sb	a5,25(s1)
    800059b8:	00f48d23          	sb	a5,26(s1)
    800059bc:	00f48da3          	sb	a5,27(s1)
    800059c0:	00f48e23          	sb	a5,28(s1)
    800059c4:	00f48ea3          	sb	a5,29(s1)
    800059c8:	00f48f23          	sb	a5,30(s1)
    800059cc:	00f48fa3          	sb	a5,31(s1)
  status |= VIRTIO_CONFIG_S_DRIVER_OK;
    800059d0:	00496913          	ori	s2,s2,4
  *R(VIRTIO_MMIO_STATUS) = status;
    800059d4:	100017b7          	lui	a5,0x10001
    800059d8:	0727a823          	sw	s2,112(a5) # 10001070 <_entry-0x6fffef90>
}
    800059dc:	60e2                	ld	ra,24(sp)
    800059de:	6442                	ld	s0,16(sp)
    800059e0:	64a2                	ld	s1,8(sp)
    800059e2:	6902                	ld	s2,0(sp)
    800059e4:	6105                	addi	sp,sp,32
    800059e6:	8082                	ret
    panic("could not find virtio disk");
    800059e8:	00002517          	auipc	a0,0x2
    800059ec:	d5850513          	addi	a0,a0,-680 # 80007740 <etext+0x740>
    800059f0:	df1fa0ef          	jal	800007e0 <panic>
    panic("virtio disk FEATURES_OK unset");
    800059f4:	00002517          	auipc	a0,0x2
    800059f8:	d6c50513          	addi	a0,a0,-660 # 80007760 <etext+0x760>
    800059fc:	de5fa0ef          	jal	800007e0 <panic>
    panic("virtio disk should not be ready");
    80005a00:	00002517          	auipc	a0,0x2
    80005a04:	d8050513          	addi	a0,a0,-640 # 80007780 <etext+0x780>
    80005a08:	dd9fa0ef          	jal	800007e0 <panic>
    panic("virtio disk has no queue 0");
    80005a0c:	00002517          	auipc	a0,0x2
    80005a10:	d9450513          	addi	a0,a0,-620 # 800077a0 <etext+0x7a0>
    80005a14:	dcdfa0ef          	jal	800007e0 <panic>
    panic("virtio disk max queue too short");
    80005a18:	00002517          	auipc	a0,0x2
    80005a1c:	da850513          	addi	a0,a0,-600 # 800077c0 <etext+0x7c0>
    80005a20:	dc1fa0ef          	jal	800007e0 <panic>
    panic("virtio disk kalloc");
    80005a24:	00002517          	auipc	a0,0x2
    80005a28:	dbc50513          	addi	a0,a0,-580 # 800077e0 <etext+0x7e0>
    80005a2c:	db5fa0ef          	jal	800007e0 <panic>

0000000080005a30 <virtio_disk_rw>:
  return 0;
}

void
virtio_disk_rw(struct buf *b, int write)
{
    80005a30:	7159                	addi	sp,sp,-112
    80005a32:	f486                	sd	ra,104(sp)
    80005a34:	f0a2                	sd	s0,96(sp)
    80005a36:	eca6                	sd	s1,88(sp)
    80005a38:	e8ca                	sd	s2,80(sp)
    80005a3a:	e4ce                	sd	s3,72(sp)
    80005a3c:	e0d2                	sd	s4,64(sp)
    80005a3e:	fc56                	sd	s5,56(sp)
    80005a40:	f85a                	sd	s6,48(sp)
    80005a42:	f45e                	sd	s7,40(sp)
    80005a44:	f062                	sd	s8,32(sp)
    80005a46:	ec66                	sd	s9,24(sp)
    80005a48:	1880                	addi	s0,sp,112
    80005a4a:	8a2a                	mv	s4,a0
    80005a4c:	8bae                	mv	s7,a1
  uint64 sector = b->blockno * (BSIZE / 512);
    80005a4e:	00c52c83          	lw	s9,12(a0)
    80005a52:	001c9c9b          	slliw	s9,s9,0x1
    80005a56:	1c82                	slli	s9,s9,0x20
    80005a58:	020cdc93          	srli	s9,s9,0x20

  acquire(&disk.vdisk_lock);
    80005a5c:	0001e517          	auipc	a0,0x1e
    80005a60:	16450513          	addi	a0,a0,356 # 80023bc0 <disk+0x128>
    80005a64:	96afb0ef          	jal	80000bce <acquire>
  for(int i = 0; i < 3; i++){
    80005a68:	4981                	li	s3,0
  for(int i = 0; i < NUM; i++){
    80005a6a:	44a1                	li	s1,8
      disk.free[i] = 0;
    80005a6c:	0001eb17          	auipc	s6,0x1e
    80005a70:	02cb0b13          	addi	s6,s6,44 # 80023a98 <disk>
  for(int i = 0; i < 3; i++){
    80005a74:	4a8d                	li	s5,3
  int idx[3];
  while(1){
    if(alloc3_desc(idx) == 0) {
      break;
    }
    sleep(&disk.free[0], &disk.vdisk_lock);
    80005a76:	0001ec17          	auipc	s8,0x1e
    80005a7a:	14ac0c13          	addi	s8,s8,330 # 80023bc0 <disk+0x128>
    80005a7e:	a8b9                	j	80005adc <virtio_disk_rw+0xac>
      disk.free[i] = 0;
    80005a80:	00fb0733          	add	a4,s6,a5
    80005a84:	00070c23          	sb	zero,24(a4) # 10001018 <_entry-0x6fffefe8>
    idx[i] = alloc_desc();
    80005a88:	c19c                	sw	a5,0(a1)
    if(idx[i] < 0){
    80005a8a:	0207c563          	bltz	a5,80005ab4 <virtio_disk_rw+0x84>
  for(int i = 0; i < 3; i++){
    80005a8e:	2905                	addiw	s2,s2,1
    80005a90:	0611                	addi	a2,a2,4 # 1004 <_entry-0x7fffeffc>
    80005a92:	05590963          	beq	s2,s5,80005ae4 <virtio_disk_rw+0xb4>
    idx[i] = alloc_desc();
    80005a96:	85b2                	mv	a1,a2
  for(int i = 0; i < NUM; i++){
    80005a98:	0001e717          	auipc	a4,0x1e
    80005a9c:	00070713          	mv	a4,a4
    80005aa0:	87ce                	mv	a5,s3
    if(disk.free[i]){
    80005aa2:	01874683          	lbu	a3,24(a4) # 80023ab0 <disk+0x18>
    80005aa6:	fee9                	bnez	a3,80005a80 <virtio_disk_rw+0x50>
  for(int i = 0; i < NUM; i++){
    80005aa8:	2785                	addiw	a5,a5,1
    80005aaa:	0705                	addi	a4,a4,1
    80005aac:	fe979be3          	bne	a5,s1,80005aa2 <virtio_disk_rw+0x72>
    idx[i] = alloc_desc();
    80005ab0:	57fd                	li	a5,-1
    80005ab2:	c19c                	sw	a5,0(a1)
      for(int j = 0; j < i; j++)
    80005ab4:	01205d63          	blez	s2,80005ace <virtio_disk_rw+0x9e>
        free_desc(idx[j]);
    80005ab8:	f9042503          	lw	a0,-112(s0)
    80005abc:	d07ff0ef          	jal	800057c2 <free_desc>
      for(int j = 0; j < i; j++)
    80005ac0:	4785                	li	a5,1
    80005ac2:	0127d663          	bge	a5,s2,80005ace <virtio_disk_rw+0x9e>
        free_desc(idx[j]);
    80005ac6:	f9442503          	lw	a0,-108(s0)
    80005aca:	cf9ff0ef          	jal	800057c2 <free_desc>
    sleep(&disk.free[0], &disk.vdisk_lock);
    80005ace:	85e2                	mv	a1,s8
    80005ad0:	0001e517          	auipc	a0,0x1e
    80005ad4:	fe050513          	addi	a0,a0,-32 # 80023ab0 <disk+0x18>
    80005ad8:	c7afc0ef          	jal	80001f52 <sleep>
  for(int i = 0; i < 3; i++){
    80005adc:	f9040613          	addi	a2,s0,-112
    80005ae0:	894e                	mv	s2,s3
    80005ae2:	bf55                	j	80005a96 <virtio_disk_rw+0x66>
  }

  // format the three descriptors.
  // qemu's virtio-blk.c reads them.

  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    80005ae4:	f9042503          	lw	a0,-112(s0)
    80005ae8:	00451693          	slli	a3,a0,0x4

  if(write)
    80005aec:	0001e797          	auipc	a5,0x1e
    80005af0:	fac78793          	addi	a5,a5,-84 # 80023a98 <disk>
    80005af4:	00a50713          	addi	a4,a0,10
    80005af8:	0712                	slli	a4,a4,0x4
    80005afa:	973e                	add	a4,a4,a5
    80005afc:	01703633          	snez	a2,s7
    80005b00:	c710                	sw	a2,8(a4)
    buf0->type = VIRTIO_BLK_T_OUT; // write the disk
  else
    buf0->type = VIRTIO_BLK_T_IN; // read the disk
  buf0->reserved = 0;
    80005b02:	00072623          	sw	zero,12(a4)
  buf0->sector = sector;
    80005b06:	01973823          	sd	s9,16(a4)

  disk.desc[idx[0]].addr = (uint64) buf0;
    80005b0a:	6398                	ld	a4,0(a5)
    80005b0c:	9736                	add	a4,a4,a3
  struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    80005b0e:	0a868613          	addi	a2,a3,168
    80005b12:	963e                	add	a2,a2,a5
  disk.desc[idx[0]].addr = (uint64) buf0;
    80005b14:	e310                	sd	a2,0(a4)
  disk.desc[idx[0]].len = sizeof(struct virtio_blk_req);
    80005b16:	6390                	ld	a2,0(a5)
    80005b18:	00d605b3          	add	a1,a2,a3
    80005b1c:	4741                	li	a4,16
    80005b1e:	c598                	sw	a4,8(a1)
  disk.desc[idx[0]].flags = VRING_DESC_F_NEXT;
    80005b20:	4805                	li	a6,1
    80005b22:	01059623          	sh	a6,12(a1)
  disk.desc[idx[0]].next = idx[1];
    80005b26:	f9442703          	lw	a4,-108(s0)
    80005b2a:	00e59723          	sh	a4,14(a1)

  disk.desc[idx[1]].addr = (uint64) b->data;
    80005b2e:	0712                	slli	a4,a4,0x4
    80005b30:	963a                	add	a2,a2,a4
    80005b32:	058a0593          	addi	a1,s4,88
    80005b36:	e20c                	sd	a1,0(a2)
  disk.desc[idx[1]].len = BSIZE;
    80005b38:	0007b883          	ld	a7,0(a5)
    80005b3c:	9746                	add	a4,a4,a7
    80005b3e:	40000613          	li	a2,1024
    80005b42:	c710                	sw	a2,8(a4)
  if(write)
    80005b44:	001bb613          	seqz	a2,s7
    80005b48:	0016161b          	slliw	a2,a2,0x1
    disk.desc[idx[1]].flags = 0; // device reads b->data
  else
    disk.desc[idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
  disk.desc[idx[1]].flags |= VRING_DESC_F_NEXT;
    80005b4c:	00166613          	ori	a2,a2,1
    80005b50:	00c71623          	sh	a2,12(a4)
  disk.desc[idx[1]].next = idx[2];
    80005b54:	f9842583          	lw	a1,-104(s0)
    80005b58:	00b71723          	sh	a1,14(a4)

  disk.info[idx[0]].status = 0xff; // device writes 0 on success
    80005b5c:	00250613          	addi	a2,a0,2
    80005b60:	0612                	slli	a2,a2,0x4
    80005b62:	963e                	add	a2,a2,a5
    80005b64:	577d                	li	a4,-1
    80005b66:	00e60823          	sb	a4,16(a2)
  disk.desc[idx[2]].addr = (uint64) &disk.info[idx[0]].status;
    80005b6a:	0592                	slli	a1,a1,0x4
    80005b6c:	98ae                	add	a7,a7,a1
    80005b6e:	03068713          	addi	a4,a3,48
    80005b72:	973e                	add	a4,a4,a5
    80005b74:	00e8b023          	sd	a4,0(a7)
  disk.desc[idx[2]].len = 1;
    80005b78:	6398                	ld	a4,0(a5)
    80005b7a:	972e                	add	a4,a4,a1
    80005b7c:	01072423          	sw	a6,8(a4)
  disk.desc[idx[2]].flags = VRING_DESC_F_WRITE; // device writes the status
    80005b80:	4689                	li	a3,2
    80005b82:	00d71623          	sh	a3,12(a4)
  disk.desc[idx[2]].next = 0;
    80005b86:	00071723          	sh	zero,14(a4)

  // record struct buf for virtio_disk_intr().
  b->disk = 1;
    80005b8a:	010a2223          	sw	a6,4(s4)
  disk.info[idx[0]].b = b;
    80005b8e:	01463423          	sd	s4,8(a2)

  // tell the device the first index in our chain of descriptors.
  disk.avail->ring[disk.avail->idx % NUM] = idx[0];
    80005b92:	6794                	ld	a3,8(a5)
    80005b94:	0026d703          	lhu	a4,2(a3)
    80005b98:	8b1d                	andi	a4,a4,7
    80005b9a:	0706                	slli	a4,a4,0x1
    80005b9c:	96ba                	add	a3,a3,a4
    80005b9e:	00a69223          	sh	a0,4(a3)

  __sync_synchronize();
    80005ba2:	0330000f          	fence	rw,rw

  // tell the device another avail ring entry is available.
  disk.avail->idx += 1; // not % NUM ...
    80005ba6:	6798                	ld	a4,8(a5)
    80005ba8:	00275783          	lhu	a5,2(a4)
    80005bac:	2785                	addiw	a5,a5,1
    80005bae:	00f71123          	sh	a5,2(a4)

  __sync_synchronize();
    80005bb2:	0330000f          	fence	rw,rw

  *R(VIRTIO_MMIO_QUEUE_NOTIFY) = 0; // value is queue number
    80005bb6:	100017b7          	lui	a5,0x10001
    80005bba:	0407a823          	sw	zero,80(a5) # 10001050 <_entry-0x6fffefb0>

  // Wait for virtio_disk_intr() to say request has finished.
  while(b->disk == 1) {
    80005bbe:	004a2783          	lw	a5,4(s4)
    sleep(b, &disk.vdisk_lock);
    80005bc2:	0001e917          	auipc	s2,0x1e
    80005bc6:	ffe90913          	addi	s2,s2,-2 # 80023bc0 <disk+0x128>
  while(b->disk == 1) {
    80005bca:	4485                	li	s1,1
    80005bcc:	01079a63          	bne	a5,a6,80005be0 <virtio_disk_rw+0x1b0>
    sleep(b, &disk.vdisk_lock);
    80005bd0:	85ca                	mv	a1,s2
    80005bd2:	8552                	mv	a0,s4
    80005bd4:	b7efc0ef          	jal	80001f52 <sleep>
  while(b->disk == 1) {
    80005bd8:	004a2783          	lw	a5,4(s4)
    80005bdc:	fe978ae3          	beq	a5,s1,80005bd0 <virtio_disk_rw+0x1a0>
  }

  disk.info[idx[0]].b = 0;
    80005be0:	f9042903          	lw	s2,-112(s0)
    80005be4:	00290713          	addi	a4,s2,2
    80005be8:	0712                	slli	a4,a4,0x4
    80005bea:	0001e797          	auipc	a5,0x1e
    80005bee:	eae78793          	addi	a5,a5,-338 # 80023a98 <disk>
    80005bf2:	97ba                	add	a5,a5,a4
    80005bf4:	0007b423          	sd	zero,8(a5)
    int flag = disk.desc[i].flags;
    80005bf8:	0001e997          	auipc	s3,0x1e
    80005bfc:	ea098993          	addi	s3,s3,-352 # 80023a98 <disk>
    80005c00:	00491713          	slli	a4,s2,0x4
    80005c04:	0009b783          	ld	a5,0(s3)
    80005c08:	97ba                	add	a5,a5,a4
    80005c0a:	00c7d483          	lhu	s1,12(a5)
    int nxt = disk.desc[i].next;
    80005c0e:	854a                	mv	a0,s2
    80005c10:	00e7d903          	lhu	s2,14(a5)
    free_desc(i);
    80005c14:	bafff0ef          	jal	800057c2 <free_desc>
    if(flag & VRING_DESC_F_NEXT)
    80005c18:	8885                	andi	s1,s1,1
    80005c1a:	f0fd                	bnez	s1,80005c00 <virtio_disk_rw+0x1d0>
  free_chain(idx[0]);

  release(&disk.vdisk_lock);
    80005c1c:	0001e517          	auipc	a0,0x1e
    80005c20:	fa450513          	addi	a0,a0,-92 # 80023bc0 <disk+0x128>
    80005c24:	842fb0ef          	jal	80000c66 <release>
}
    80005c28:	70a6                	ld	ra,104(sp)
    80005c2a:	7406                	ld	s0,96(sp)
    80005c2c:	64e6                	ld	s1,88(sp)
    80005c2e:	6946                	ld	s2,80(sp)
    80005c30:	69a6                	ld	s3,72(sp)
    80005c32:	6a06                	ld	s4,64(sp)
    80005c34:	7ae2                	ld	s5,56(sp)
    80005c36:	7b42                	ld	s6,48(sp)
    80005c38:	7ba2                	ld	s7,40(sp)
    80005c3a:	7c02                	ld	s8,32(sp)
    80005c3c:	6ce2                	ld	s9,24(sp)
    80005c3e:	6165                	addi	sp,sp,112
    80005c40:	8082                	ret

0000000080005c42 <virtio_disk_intr>:

void
virtio_disk_intr()
{
    80005c42:	1101                	addi	sp,sp,-32
    80005c44:	ec06                	sd	ra,24(sp)
    80005c46:	e822                	sd	s0,16(sp)
    80005c48:	e426                	sd	s1,8(sp)
    80005c4a:	1000                	addi	s0,sp,32
  acquire(&disk.vdisk_lock);
    80005c4c:	0001e497          	auipc	s1,0x1e
    80005c50:	e4c48493          	addi	s1,s1,-436 # 80023a98 <disk>
    80005c54:	0001e517          	auipc	a0,0x1e
    80005c58:	f6c50513          	addi	a0,a0,-148 # 80023bc0 <disk+0x128>
    80005c5c:	f73fa0ef          	jal	80000bce <acquire>
  // we've seen this interrupt, which the following line does.
  // this may race with the device writing new entries to
  // the "used" ring, in which case we may process the new
  // completion entries in this interrupt, and have nothing to do
  // in the next interrupt, which is harmless.
  *R(VIRTIO_MMIO_INTERRUPT_ACK) = *R(VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;
    80005c60:	100017b7          	lui	a5,0x10001
    80005c64:	53b8                	lw	a4,96(a5)
    80005c66:	8b0d                	andi	a4,a4,3
    80005c68:	100017b7          	lui	a5,0x10001
    80005c6c:	d3f8                	sw	a4,100(a5)

  __sync_synchronize();
    80005c6e:	0330000f          	fence	rw,rw

  // the device increments disk.used->idx when it
  // adds an entry to the used ring.

  while(disk.used_idx != disk.used->idx){
    80005c72:	689c                	ld	a5,16(s1)
    80005c74:	0204d703          	lhu	a4,32(s1)
    80005c78:	0027d783          	lhu	a5,2(a5) # 10001002 <_entry-0x6fffeffe>
    80005c7c:	04f70663          	beq	a4,a5,80005cc8 <virtio_disk_intr+0x86>
    __sync_synchronize();
    80005c80:	0330000f          	fence	rw,rw
    int id = disk.used->ring[disk.used_idx % NUM].id;
    80005c84:	6898                	ld	a4,16(s1)
    80005c86:	0204d783          	lhu	a5,32(s1)
    80005c8a:	8b9d                	andi	a5,a5,7
    80005c8c:	078e                	slli	a5,a5,0x3
    80005c8e:	97ba                	add	a5,a5,a4
    80005c90:	43dc                	lw	a5,4(a5)

    if(disk.info[id].status != 0)
    80005c92:	00278713          	addi	a4,a5,2
    80005c96:	0712                	slli	a4,a4,0x4
    80005c98:	9726                	add	a4,a4,s1
    80005c9a:	01074703          	lbu	a4,16(a4)
    80005c9e:	e321                	bnez	a4,80005cde <virtio_disk_intr+0x9c>
      panic("virtio_disk_intr status");

    struct buf *b = disk.info[id].b;
    80005ca0:	0789                	addi	a5,a5,2
    80005ca2:	0792                	slli	a5,a5,0x4
    80005ca4:	97a6                	add	a5,a5,s1
    80005ca6:	6788                	ld	a0,8(a5)
    b->disk = 0;   // disk is done with buf
    80005ca8:	00052223          	sw	zero,4(a0)
    wakeup(b);
    80005cac:	af2fc0ef          	jal	80001f9e <wakeup>

    disk.used_idx += 1;
    80005cb0:	0204d783          	lhu	a5,32(s1)
    80005cb4:	2785                	addiw	a5,a5,1
    80005cb6:	17c2                	slli	a5,a5,0x30
    80005cb8:	93c1                	srli	a5,a5,0x30
    80005cba:	02f49023          	sh	a5,32(s1)
  while(disk.used_idx != disk.used->idx){
    80005cbe:	6898                	ld	a4,16(s1)
    80005cc0:	00275703          	lhu	a4,2(a4)
    80005cc4:	faf71ee3          	bne	a4,a5,80005c80 <virtio_disk_intr+0x3e>
  }

  release(&disk.vdisk_lock);
    80005cc8:	0001e517          	auipc	a0,0x1e
    80005ccc:	ef850513          	addi	a0,a0,-264 # 80023bc0 <disk+0x128>
    80005cd0:	f97fa0ef          	jal	80000c66 <release>
}
    80005cd4:	60e2                	ld	ra,24(sp)
    80005cd6:	6442                	ld	s0,16(sp)
    80005cd8:	64a2                	ld	s1,8(sp)
    80005cda:	6105                	addi	sp,sp,32
    80005cdc:	8082                	ret
      panic("virtio_disk_intr status");
    80005cde:	00002517          	auipc	a0,0x2
    80005ce2:	b1a50513          	addi	a0,a0,-1254 # 800077f8 <etext+0x7f8>
    80005ce6:	afbfa0ef          	jal	800007e0 <panic>
	...

0000000080006000 <_trampoline>:
    80006000:	14051073          	csrw	sscratch,a0
    80006004:	02000537          	lui	a0,0x2000
    80006008:	357d                	addiw	a0,a0,-1 # 1ffffff <_entry-0x7e000001>
    8000600a:	0536                	slli	a0,a0,0xd
    8000600c:	02153423          	sd	ra,40(a0)
    80006010:	02253823          	sd	sp,48(a0)
    80006014:	02353c23          	sd	gp,56(a0)
    80006018:	04453023          	sd	tp,64(a0)
    8000601c:	04553423          	sd	t0,72(a0)
    80006020:	04653823          	sd	t1,80(a0)
    80006024:	04753c23          	sd	t2,88(a0)
    80006028:	f120                	sd	s0,96(a0)
    8000602a:	f524                	sd	s1,104(a0)
    8000602c:	fd2c                	sd	a1,120(a0)
    8000602e:	e150                	sd	a2,128(a0)
    80006030:	e554                	sd	a3,136(a0)
    80006032:	e958                	sd	a4,144(a0)
    80006034:	ed5c                	sd	a5,152(a0)
    80006036:	0b053023          	sd	a6,160(a0)
    8000603a:	0b153423          	sd	a7,168(a0)
    8000603e:	0b253823          	sd	s2,176(a0)
    80006042:	0b353c23          	sd	s3,184(a0)
    80006046:	0d453023          	sd	s4,192(a0)
    8000604a:	0d553423          	sd	s5,200(a0)
    8000604e:	0d653823          	sd	s6,208(a0)
    80006052:	0d753c23          	sd	s7,216(a0)
    80006056:	0f853023          	sd	s8,224(a0)
    8000605a:	0f953423          	sd	s9,232(a0)
    8000605e:	0fa53823          	sd	s10,240(a0)
    80006062:	0fb53c23          	sd	s11,248(a0)
    80006066:	11c53023          	sd	t3,256(a0)
    8000606a:	11d53423          	sd	t4,264(a0)
    8000606e:	11e53823          	sd	t5,272(a0)
    80006072:	11f53c23          	sd	t6,280(a0)
    80006076:	140022f3          	csrr	t0,sscratch
    8000607a:	06553823          	sd	t0,112(a0)
    8000607e:	00853103          	ld	sp,8(a0)
    80006082:	02053203          	ld	tp,32(a0)
    80006086:	01053283          	ld	t0,16(a0)
    8000608a:	00053303          	ld	t1,0(a0)
    8000608e:	12000073          	sfence.vma
    80006092:	18031073          	csrw	satp,t1
    80006096:	12000073          	sfence.vma
    8000609a:	9282                	jalr	t0

000000008000609c <userret>:
    8000609c:	12000073          	sfence.vma
    800060a0:	18051073          	csrw	satp,a0
    800060a4:	12000073          	sfence.vma
    800060a8:	02000537          	lui	a0,0x2000
    800060ac:	357d                	addiw	a0,a0,-1 # 1ffffff <_entry-0x7e000001>
    800060ae:	0536                	slli	a0,a0,0xd
    800060b0:	02853083          	ld	ra,40(a0)
    800060b4:	03053103          	ld	sp,48(a0)
    800060b8:	03853183          	ld	gp,56(a0)
    800060bc:	04053203          	ld	tp,64(a0)
    800060c0:	04853283          	ld	t0,72(a0)
    800060c4:	05053303          	ld	t1,80(a0)
    800060c8:	05853383          	ld	t2,88(a0)
    800060cc:	7120                	ld	s0,96(a0)
    800060ce:	7524                	ld	s1,104(a0)
    800060d0:	7d2c                	ld	a1,120(a0)
    800060d2:	6150                	ld	a2,128(a0)
    800060d4:	6554                	ld	a3,136(a0)
    800060d6:	6958                	ld	a4,144(a0)
    800060d8:	6d5c                	ld	a5,152(a0)
    800060da:	0a053803          	ld	a6,160(a0)
    800060de:	0a853883          	ld	a7,168(a0)
    800060e2:	0b053903          	ld	s2,176(a0)
    800060e6:	0b853983          	ld	s3,184(a0)
    800060ea:	0c053a03          	ld	s4,192(a0)
    800060ee:	0c853a83          	ld	s5,200(a0)
    800060f2:	0d053b03          	ld	s6,208(a0)
    800060f6:	0d853b83          	ld	s7,216(a0)
    800060fa:	0e053c03          	ld	s8,224(a0)
    800060fe:	0e853c83          	ld	s9,232(a0)
    80006102:	0f053d03          	ld	s10,240(a0)
    80006106:	0f853d83          	ld	s11,248(a0)
    8000610a:	10053e03          	ld	t3,256(a0)
    8000610e:	10853e83          	ld	t4,264(a0)
    80006112:	11053f03          	ld	t5,272(a0)
    80006116:	11853f83          	ld	t6,280(a0)
    8000611a:	7928                	ld	a0,112(a0)
    8000611c:	10200073          	sret
	...
