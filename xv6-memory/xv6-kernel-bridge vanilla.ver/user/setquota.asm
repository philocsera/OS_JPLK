
user/_setquota:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <main>:
#include "kernel/stat.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
   0:	1101                	addi	sp,sp,-32
   2:	ec06                	sd	ra,24(sp)
   4:	e822                	sd	s0,16(sp)
   6:	1000                	addi	s0,sp,32
  int pid;
  int quota;

  if(argc != 3){
   8:	478d                	li	a5,3
   a:	00f50d63          	beq	a0,a5,24 <main+0x24>
   e:	e426                	sd	s1,8(sp)
  10:	e04a                	sd	s2,0(sp)
    printf("usage: setquota pid quota\n");
  12:	00001517          	auipc	a0,0x1
  16:	8fe50513          	addi	a0,a0,-1794 # 910 <malloc+0x106>
  1a:	73c000ef          	jal	756 <printf>
    exit(1);
  1e:	4505                	li	a0,1
  20:	2e6000ef          	jal	306 <exit>
  24:	e426                	sd	s1,8(sp)
  26:	e04a                	sd	s2,0(sp)
  28:	84ae                	mv	s1,a1
  }

  pid = atoi(argv[1]);
  2a:	6588                	ld	a0,8(a1)
  2c:	1b8000ef          	jal	1e4 <atoi>
  30:	892a                	mv	s2,a0
  quota = atoi(argv[2]);
  32:	6888                	ld	a0,16(s1)
  34:	1b0000ef          	jal	1e4 <atoi>
  38:	84aa                	mv	s1,a0

  if(setmemquota(pid, quota) < 0){
  3a:	85aa                	mv	a1,a0
  3c:	854a                	mv	a0,s2
  3e:	388000ef          	jal	3c6 <setmemquota>
  42:	00054d63          	bltz	a0,5c <main+0x5c>
    printf("setquota failed pid=%d quota=%d\n", pid, quota);
    exit(1);
  }

  printf("setquota ok pid=%d quota=%d\n", pid, quota);
  46:	8626                	mv	a2,s1
  48:	85ca                	mv	a1,s2
  4a:	00001517          	auipc	a0,0x1
  4e:	90e50513          	addi	a0,a0,-1778 # 958 <malloc+0x14e>
  52:	704000ef          	jal	756 <printf>
  exit(0);
  56:	4501                	li	a0,0
  58:	2ae000ef          	jal	306 <exit>
    printf("setquota failed pid=%d quota=%d\n", pid, quota);
  5c:	8626                	mv	a2,s1
  5e:	85ca                	mv	a1,s2
  60:	00001517          	auipc	a0,0x1
  64:	8d050513          	addi	a0,a0,-1840 # 930 <malloc+0x126>
  68:	6ee000ef          	jal	756 <printf>
    exit(1);
  6c:	4505                	li	a0,1
  6e:	298000ef          	jal	306 <exit>

0000000000000072 <start>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
start(int argc, char **argv)
{
  72:	1141                	addi	sp,sp,-16
  74:	e406                	sd	ra,8(sp)
  76:	e022                	sd	s0,0(sp)
  78:	0800                	addi	s0,sp,16
  int r;
  extern int main(int argc, char **argv);
  r = main(argc, argv);
  7a:	f87ff0ef          	jal	0 <main>
  exit(r);
  7e:	288000ef          	jal	306 <exit>

0000000000000082 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
  82:	1141                	addi	sp,sp,-16
  84:	e422                	sd	s0,8(sp)
  86:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
  88:	87aa                	mv	a5,a0
  8a:	0585                	addi	a1,a1,1
  8c:	0785                	addi	a5,a5,1
  8e:	fff5c703          	lbu	a4,-1(a1)
  92:	fee78fa3          	sb	a4,-1(a5)
  96:	fb75                	bnez	a4,8a <strcpy+0x8>
    ;
  return os;
}
  98:	6422                	ld	s0,8(sp)
  9a:	0141                	addi	sp,sp,16
  9c:	8082                	ret

000000000000009e <strcmp>:

int
strcmp(const char *p, const char *q)
{
  9e:	1141                	addi	sp,sp,-16
  a0:	e422                	sd	s0,8(sp)
  a2:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
  a4:	00054783          	lbu	a5,0(a0)
  a8:	cb91                	beqz	a5,bc <strcmp+0x1e>
  aa:	0005c703          	lbu	a4,0(a1)
  ae:	00f71763          	bne	a4,a5,bc <strcmp+0x1e>
    p++, q++;
  b2:	0505                	addi	a0,a0,1
  b4:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
  b6:	00054783          	lbu	a5,0(a0)
  ba:	fbe5                	bnez	a5,aa <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
  bc:	0005c503          	lbu	a0,0(a1)
}
  c0:	40a7853b          	subw	a0,a5,a0
  c4:	6422                	ld	s0,8(sp)
  c6:	0141                	addi	sp,sp,16
  c8:	8082                	ret

00000000000000ca <strlen>:

uint
strlen(const char *s)
{
  ca:	1141                	addi	sp,sp,-16
  cc:	e422                	sd	s0,8(sp)
  ce:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
  d0:	00054783          	lbu	a5,0(a0)
  d4:	cf91                	beqz	a5,f0 <strlen+0x26>
  d6:	0505                	addi	a0,a0,1
  d8:	87aa                	mv	a5,a0
  da:	86be                	mv	a3,a5
  dc:	0785                	addi	a5,a5,1
  de:	fff7c703          	lbu	a4,-1(a5)
  e2:	ff65                	bnez	a4,da <strlen+0x10>
  e4:	40a6853b          	subw	a0,a3,a0
  e8:	2505                	addiw	a0,a0,1
    ;
  return n;
}
  ea:	6422                	ld	s0,8(sp)
  ec:	0141                	addi	sp,sp,16
  ee:	8082                	ret
  for(n = 0; s[n]; n++)
  f0:	4501                	li	a0,0
  f2:	bfe5                	j	ea <strlen+0x20>

00000000000000f4 <memset>:

void*
memset(void *dst, int c, uint n)
{
  f4:	1141                	addi	sp,sp,-16
  f6:	e422                	sd	s0,8(sp)
  f8:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
  fa:	ca19                	beqz	a2,110 <memset+0x1c>
  fc:	87aa                	mv	a5,a0
  fe:	1602                	slli	a2,a2,0x20
 100:	9201                	srli	a2,a2,0x20
 102:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 106:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 10a:	0785                	addi	a5,a5,1
 10c:	fee79de3          	bne	a5,a4,106 <memset+0x12>
  }
  return dst;
}
 110:	6422                	ld	s0,8(sp)
 112:	0141                	addi	sp,sp,16
 114:	8082                	ret

0000000000000116 <strchr>:

char*
strchr(const char *s, char c)
{
 116:	1141                	addi	sp,sp,-16
 118:	e422                	sd	s0,8(sp)
 11a:	0800                	addi	s0,sp,16
  for(; *s; s++)
 11c:	00054783          	lbu	a5,0(a0)
 120:	cb99                	beqz	a5,136 <strchr+0x20>
    if(*s == c)
 122:	00f58763          	beq	a1,a5,130 <strchr+0x1a>
  for(; *s; s++)
 126:	0505                	addi	a0,a0,1
 128:	00054783          	lbu	a5,0(a0)
 12c:	fbfd                	bnez	a5,122 <strchr+0xc>
      return (char*)s;
  return 0;
 12e:	4501                	li	a0,0
}
 130:	6422                	ld	s0,8(sp)
 132:	0141                	addi	sp,sp,16
 134:	8082                	ret
  return 0;
 136:	4501                	li	a0,0
 138:	bfe5                	j	130 <strchr+0x1a>

000000000000013a <gets>:

char*
gets(char *buf, int max)
{
 13a:	711d                	addi	sp,sp,-96
 13c:	ec86                	sd	ra,88(sp)
 13e:	e8a2                	sd	s0,80(sp)
 140:	e4a6                	sd	s1,72(sp)
 142:	e0ca                	sd	s2,64(sp)
 144:	fc4e                	sd	s3,56(sp)
 146:	f852                	sd	s4,48(sp)
 148:	f456                	sd	s5,40(sp)
 14a:	f05a                	sd	s6,32(sp)
 14c:	ec5e                	sd	s7,24(sp)
 14e:	1080                	addi	s0,sp,96
 150:	8baa                	mv	s7,a0
 152:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 154:	892a                	mv	s2,a0
 156:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 158:	4aa9                	li	s5,10
 15a:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 15c:	89a6                	mv	s3,s1
 15e:	2485                	addiw	s1,s1,1
 160:	0344d663          	bge	s1,s4,18c <gets+0x52>
    cc = read(0, &c, 1);
 164:	4605                	li	a2,1
 166:	faf40593          	addi	a1,s0,-81
 16a:	4501                	li	a0,0
 16c:	1b2000ef          	jal	31e <read>
    if(cc < 1)
 170:	00a05e63          	blez	a0,18c <gets+0x52>
    buf[i++] = c;
 174:	faf44783          	lbu	a5,-81(s0)
 178:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 17c:	01578763          	beq	a5,s5,18a <gets+0x50>
 180:	0905                	addi	s2,s2,1
 182:	fd679de3          	bne	a5,s6,15c <gets+0x22>
    buf[i++] = c;
 186:	89a6                	mv	s3,s1
 188:	a011                	j	18c <gets+0x52>
 18a:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 18c:	99de                	add	s3,s3,s7
 18e:	00098023          	sb	zero,0(s3)
  return buf;
}
 192:	855e                	mv	a0,s7
 194:	60e6                	ld	ra,88(sp)
 196:	6446                	ld	s0,80(sp)
 198:	64a6                	ld	s1,72(sp)
 19a:	6906                	ld	s2,64(sp)
 19c:	79e2                	ld	s3,56(sp)
 19e:	7a42                	ld	s4,48(sp)
 1a0:	7aa2                	ld	s5,40(sp)
 1a2:	7b02                	ld	s6,32(sp)
 1a4:	6be2                	ld	s7,24(sp)
 1a6:	6125                	addi	sp,sp,96
 1a8:	8082                	ret

00000000000001aa <stat>:

int
stat(const char *n, struct stat *st)
{
 1aa:	1101                	addi	sp,sp,-32
 1ac:	ec06                	sd	ra,24(sp)
 1ae:	e822                	sd	s0,16(sp)
 1b0:	e04a                	sd	s2,0(sp)
 1b2:	1000                	addi	s0,sp,32
 1b4:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 1b6:	4581                	li	a1,0
 1b8:	18e000ef          	jal	346 <open>
  if(fd < 0)
 1bc:	02054263          	bltz	a0,1e0 <stat+0x36>
 1c0:	e426                	sd	s1,8(sp)
 1c2:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 1c4:	85ca                	mv	a1,s2
 1c6:	198000ef          	jal	35e <fstat>
 1ca:	892a                	mv	s2,a0
  close(fd);
 1cc:	8526                	mv	a0,s1
 1ce:	160000ef          	jal	32e <close>
  return r;
 1d2:	64a2                	ld	s1,8(sp)
}
 1d4:	854a                	mv	a0,s2
 1d6:	60e2                	ld	ra,24(sp)
 1d8:	6442                	ld	s0,16(sp)
 1da:	6902                	ld	s2,0(sp)
 1dc:	6105                	addi	sp,sp,32
 1de:	8082                	ret
    return -1;
 1e0:	597d                	li	s2,-1
 1e2:	bfcd                	j	1d4 <stat+0x2a>

00000000000001e4 <atoi>:

int
atoi(const char *s)
{
 1e4:	1141                	addi	sp,sp,-16
 1e6:	e422                	sd	s0,8(sp)
 1e8:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 1ea:	00054683          	lbu	a3,0(a0)
 1ee:	fd06879b          	addiw	a5,a3,-48
 1f2:	0ff7f793          	zext.b	a5,a5
 1f6:	4625                	li	a2,9
 1f8:	02f66863          	bltu	a2,a5,228 <atoi+0x44>
 1fc:	872a                	mv	a4,a0
  n = 0;
 1fe:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 200:	0705                	addi	a4,a4,1
 202:	0025179b          	slliw	a5,a0,0x2
 206:	9fa9                	addw	a5,a5,a0
 208:	0017979b          	slliw	a5,a5,0x1
 20c:	9fb5                	addw	a5,a5,a3
 20e:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 212:	00074683          	lbu	a3,0(a4)
 216:	fd06879b          	addiw	a5,a3,-48
 21a:	0ff7f793          	zext.b	a5,a5
 21e:	fef671e3          	bgeu	a2,a5,200 <atoi+0x1c>
  return n;
}
 222:	6422                	ld	s0,8(sp)
 224:	0141                	addi	sp,sp,16
 226:	8082                	ret
  n = 0;
 228:	4501                	li	a0,0
 22a:	bfe5                	j	222 <atoi+0x3e>

000000000000022c <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 22c:	1141                	addi	sp,sp,-16
 22e:	e422                	sd	s0,8(sp)
 230:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 232:	02b57463          	bgeu	a0,a1,25a <memmove+0x2e>
    while(n-- > 0)
 236:	00c05f63          	blez	a2,254 <memmove+0x28>
 23a:	1602                	slli	a2,a2,0x20
 23c:	9201                	srli	a2,a2,0x20
 23e:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 242:	872a                	mv	a4,a0
      *dst++ = *src++;
 244:	0585                	addi	a1,a1,1
 246:	0705                	addi	a4,a4,1
 248:	fff5c683          	lbu	a3,-1(a1)
 24c:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 250:	fef71ae3          	bne	a4,a5,244 <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 254:	6422                	ld	s0,8(sp)
 256:	0141                	addi	sp,sp,16
 258:	8082                	ret
    dst += n;
 25a:	00c50733          	add	a4,a0,a2
    src += n;
 25e:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 260:	fec05ae3          	blez	a2,254 <memmove+0x28>
 264:	fff6079b          	addiw	a5,a2,-1
 268:	1782                	slli	a5,a5,0x20
 26a:	9381                	srli	a5,a5,0x20
 26c:	fff7c793          	not	a5,a5
 270:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 272:	15fd                	addi	a1,a1,-1
 274:	177d                	addi	a4,a4,-1
 276:	0005c683          	lbu	a3,0(a1)
 27a:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 27e:	fee79ae3          	bne	a5,a4,272 <memmove+0x46>
 282:	bfc9                	j	254 <memmove+0x28>

0000000000000284 <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 284:	1141                	addi	sp,sp,-16
 286:	e422                	sd	s0,8(sp)
 288:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 28a:	ca05                	beqz	a2,2ba <memcmp+0x36>
 28c:	fff6069b          	addiw	a3,a2,-1
 290:	1682                	slli	a3,a3,0x20
 292:	9281                	srli	a3,a3,0x20
 294:	0685                	addi	a3,a3,1
 296:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 298:	00054783          	lbu	a5,0(a0)
 29c:	0005c703          	lbu	a4,0(a1)
 2a0:	00e79863          	bne	a5,a4,2b0 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 2a4:	0505                	addi	a0,a0,1
    p2++;
 2a6:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 2a8:	fed518e3          	bne	a0,a3,298 <memcmp+0x14>
  }
  return 0;
 2ac:	4501                	li	a0,0
 2ae:	a019                	j	2b4 <memcmp+0x30>
      return *p1 - *p2;
 2b0:	40e7853b          	subw	a0,a5,a4
}
 2b4:	6422                	ld	s0,8(sp)
 2b6:	0141                	addi	sp,sp,16
 2b8:	8082                	ret
  return 0;
 2ba:	4501                	li	a0,0
 2bc:	bfe5                	j	2b4 <memcmp+0x30>

00000000000002be <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 2be:	1141                	addi	sp,sp,-16
 2c0:	e406                	sd	ra,8(sp)
 2c2:	e022                	sd	s0,0(sp)
 2c4:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 2c6:	f67ff0ef          	jal	22c <memmove>
}
 2ca:	60a2                	ld	ra,8(sp)
 2cc:	6402                	ld	s0,0(sp)
 2ce:	0141                	addi	sp,sp,16
 2d0:	8082                	ret

00000000000002d2 <sbrk>:

char *
sbrk(int n) {
 2d2:	1141                	addi	sp,sp,-16
 2d4:	e406                	sd	ra,8(sp)
 2d6:	e022                	sd	s0,0(sp)
 2d8:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_EAGER);
 2da:	4585                	li	a1,1
 2dc:	0b2000ef          	jal	38e <sys_sbrk>
}
 2e0:	60a2                	ld	ra,8(sp)
 2e2:	6402                	ld	s0,0(sp)
 2e4:	0141                	addi	sp,sp,16
 2e6:	8082                	ret

00000000000002e8 <sbrklazy>:

char *
sbrklazy(int n) {
 2e8:	1141                	addi	sp,sp,-16
 2ea:	e406                	sd	ra,8(sp)
 2ec:	e022                	sd	s0,0(sp)
 2ee:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_LAZY);
 2f0:	4589                	li	a1,2
 2f2:	09c000ef          	jal	38e <sys_sbrk>
}
 2f6:	60a2                	ld	ra,8(sp)
 2f8:	6402                	ld	s0,0(sp)
 2fa:	0141                	addi	sp,sp,16
 2fc:	8082                	ret

00000000000002fe <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 2fe:	4885                	li	a7,1
 ecall
 300:	00000073          	ecall
 ret
 304:	8082                	ret

0000000000000306 <exit>:
.global exit
exit:
 li a7, SYS_exit
 306:	4889                	li	a7,2
 ecall
 308:	00000073          	ecall
 ret
 30c:	8082                	ret

000000000000030e <wait>:
.global wait
wait:
 li a7, SYS_wait
 30e:	488d                	li	a7,3
 ecall
 310:	00000073          	ecall
 ret
 314:	8082                	ret

0000000000000316 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 316:	4891                	li	a7,4
 ecall
 318:	00000073          	ecall
 ret
 31c:	8082                	ret

000000000000031e <read>:
.global read
read:
 li a7, SYS_read
 31e:	4895                	li	a7,5
 ecall
 320:	00000073          	ecall
 ret
 324:	8082                	ret

0000000000000326 <write>:
.global write
write:
 li a7, SYS_write
 326:	48c1                	li	a7,16
 ecall
 328:	00000073          	ecall
 ret
 32c:	8082                	ret

000000000000032e <close>:
.global close
close:
 li a7, SYS_close
 32e:	48d5                	li	a7,21
 ecall
 330:	00000073          	ecall
 ret
 334:	8082                	ret

0000000000000336 <kill>:
.global kill
kill:
 li a7, SYS_kill
 336:	4899                	li	a7,6
 ecall
 338:	00000073          	ecall
 ret
 33c:	8082                	ret

000000000000033e <exec>:
.global exec
exec:
 li a7, SYS_exec
 33e:	489d                	li	a7,7
 ecall
 340:	00000073          	ecall
 ret
 344:	8082                	ret

0000000000000346 <open>:
.global open
open:
 li a7, SYS_open
 346:	48bd                	li	a7,15
 ecall
 348:	00000073          	ecall
 ret
 34c:	8082                	ret

000000000000034e <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 34e:	48c5                	li	a7,17
 ecall
 350:	00000073          	ecall
 ret
 354:	8082                	ret

0000000000000356 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 356:	48c9                	li	a7,18
 ecall
 358:	00000073          	ecall
 ret
 35c:	8082                	ret

000000000000035e <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 35e:	48a1                	li	a7,8
 ecall
 360:	00000073          	ecall
 ret
 364:	8082                	ret

0000000000000366 <link>:
.global link
link:
 li a7, SYS_link
 366:	48cd                	li	a7,19
 ecall
 368:	00000073          	ecall
 ret
 36c:	8082                	ret

000000000000036e <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 36e:	48d1                	li	a7,20
 ecall
 370:	00000073          	ecall
 ret
 374:	8082                	ret

0000000000000376 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 376:	48a5                	li	a7,9
 ecall
 378:	00000073          	ecall
 ret
 37c:	8082                	ret

000000000000037e <dup>:
.global dup
dup:
 li a7, SYS_dup
 37e:	48a9                	li	a7,10
 ecall
 380:	00000073          	ecall
 ret
 384:	8082                	ret

0000000000000386 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 386:	48ad                	li	a7,11
 ecall
 388:	00000073          	ecall
 ret
 38c:	8082                	ret

000000000000038e <sys_sbrk>:
.global sys_sbrk
sys_sbrk:
 li a7, SYS_sbrk
 38e:	48b1                	li	a7,12
 ecall
 390:	00000073          	ecall
 ret
 394:	8082                	ret

0000000000000396 <pause>:
.global pause
pause:
 li a7, SYS_pause
 396:	48b5                	li	a7,13
 ecall
 398:	00000073          	ecall
 ret
 39c:	8082                	ret

000000000000039e <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 39e:	48b9                	li	a7,14
 ecall
 3a0:	00000073          	ecall
 ret
 3a4:	8082                	ret

00000000000003a6 <trace>:
.global trace
trace:
 li a7, SYS_trace
 3a6:	48d9                	li	a7,22
 ecall
 3a8:	00000073          	ecall
 ret
 3ac:	8082                	ret

00000000000003ae <setpriority>:
.global setpriority
setpriority:
 li a7, SYS_setpriority
 3ae:	48dd                	li	a7,23
 ecall
 3b0:	00000073          	ecall
 ret
 3b4:	8082                	ret

00000000000003b6 <getpriority>:
.global getpriority
getpriority:
 li a7, SYS_getpriority
 3b6:	48e1                	li	a7,24
 ecall
 3b8:	00000073          	ecall
 ret
 3bc:	8082                	ret

00000000000003be <getmemstat>:
.global getmemstat
getmemstat:
 li a7, SYS_getmemstat
 3be:	48e5                	li	a7,25
 ecall
 3c0:	00000073          	ecall
 ret
 3c4:	8082                	ret

00000000000003c6 <setmemquota>:
.global setmemquota
setmemquota:
 li a7, SYS_setmemquota
 3c6:	48e9                	li	a7,26
 ecall
 3c8:	00000073          	ecall
 ret
 3cc:	8082                	ret

00000000000003ce <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 3ce:	1101                	addi	sp,sp,-32
 3d0:	ec06                	sd	ra,24(sp)
 3d2:	e822                	sd	s0,16(sp)
 3d4:	1000                	addi	s0,sp,32
 3d6:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 3da:	4605                	li	a2,1
 3dc:	fef40593          	addi	a1,s0,-17
 3e0:	f47ff0ef          	jal	326 <write>
}
 3e4:	60e2                	ld	ra,24(sp)
 3e6:	6442                	ld	s0,16(sp)
 3e8:	6105                	addi	sp,sp,32
 3ea:	8082                	ret

00000000000003ec <printint>:

static void
printint(int fd, long long xx, int base, int sgn)
{
 3ec:	715d                	addi	sp,sp,-80
 3ee:	e486                	sd	ra,72(sp)
 3f0:	e0a2                	sd	s0,64(sp)
 3f2:	f84a                	sd	s2,48(sp)
 3f4:	0880                	addi	s0,sp,80
 3f6:	892a                	mv	s2,a0
  char buf[20];
  int i, neg;
  unsigned long long x;

  neg = 0;
  if(sgn && xx < 0){
 3f8:	c299                	beqz	a3,3fe <printint+0x12>
 3fa:	0805c363          	bltz	a1,480 <printint+0x94>
  neg = 0;
 3fe:	4881                	li	a7,0
 400:	fb840693          	addi	a3,s0,-72
    x = -xx;
  } else {
    x = xx;
  }

  i = 0;
 404:	4781                	li	a5,0
  do{
    buf[i++] = digits[x % base];
 406:	00000517          	auipc	a0,0x0
 40a:	57a50513          	addi	a0,a0,1402 # 980 <digits>
 40e:	883e                	mv	a6,a5
 410:	2785                	addiw	a5,a5,1
 412:	02c5f733          	remu	a4,a1,a2
 416:	972a                	add	a4,a4,a0
 418:	00074703          	lbu	a4,0(a4)
 41c:	00e68023          	sb	a4,0(a3)
  }while((x /= base) != 0);
 420:	872e                	mv	a4,a1
 422:	02c5d5b3          	divu	a1,a1,a2
 426:	0685                	addi	a3,a3,1
 428:	fec773e3          	bgeu	a4,a2,40e <printint+0x22>
  if(neg)
 42c:	00088b63          	beqz	a7,442 <printint+0x56>
    buf[i++] = '-';
 430:	fd078793          	addi	a5,a5,-48
 434:	97a2                	add	a5,a5,s0
 436:	02d00713          	li	a4,45
 43a:	fee78423          	sb	a4,-24(a5)
 43e:	0028079b          	addiw	a5,a6,2

  while(--i >= 0)
 442:	02f05a63          	blez	a5,476 <printint+0x8a>
 446:	fc26                	sd	s1,56(sp)
 448:	f44e                	sd	s3,40(sp)
 44a:	fb840713          	addi	a4,s0,-72
 44e:	00f704b3          	add	s1,a4,a5
 452:	fff70993          	addi	s3,a4,-1
 456:	99be                	add	s3,s3,a5
 458:	37fd                	addiw	a5,a5,-1
 45a:	1782                	slli	a5,a5,0x20
 45c:	9381                	srli	a5,a5,0x20
 45e:	40f989b3          	sub	s3,s3,a5
    putc(fd, buf[i]);
 462:	fff4c583          	lbu	a1,-1(s1)
 466:	854a                	mv	a0,s2
 468:	f67ff0ef          	jal	3ce <putc>
  while(--i >= 0)
 46c:	14fd                	addi	s1,s1,-1
 46e:	ff349ae3          	bne	s1,s3,462 <printint+0x76>
 472:	74e2                	ld	s1,56(sp)
 474:	79a2                	ld	s3,40(sp)
}
 476:	60a6                	ld	ra,72(sp)
 478:	6406                	ld	s0,64(sp)
 47a:	7942                	ld	s2,48(sp)
 47c:	6161                	addi	sp,sp,80
 47e:	8082                	ret
    x = -xx;
 480:	40b005b3          	neg	a1,a1
    neg = 1;
 484:	4885                	li	a7,1
    x = -xx;
 486:	bfad                	j	400 <printint+0x14>

0000000000000488 <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %c, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 488:	711d                	addi	sp,sp,-96
 48a:	ec86                	sd	ra,88(sp)
 48c:	e8a2                	sd	s0,80(sp)
 48e:	e0ca                	sd	s2,64(sp)
 490:	1080                	addi	s0,sp,96
  char *s;
  int c0, c1, c2, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 492:	0005c903          	lbu	s2,0(a1)
 496:	28090663          	beqz	s2,722 <vprintf+0x29a>
 49a:	e4a6                	sd	s1,72(sp)
 49c:	fc4e                	sd	s3,56(sp)
 49e:	f852                	sd	s4,48(sp)
 4a0:	f456                	sd	s5,40(sp)
 4a2:	f05a                	sd	s6,32(sp)
 4a4:	ec5e                	sd	s7,24(sp)
 4a6:	e862                	sd	s8,16(sp)
 4a8:	e466                	sd	s9,8(sp)
 4aa:	8b2a                	mv	s6,a0
 4ac:	8a2e                	mv	s4,a1
 4ae:	8bb2                	mv	s7,a2
  state = 0;
 4b0:	4981                	li	s3,0
  for(i = 0; fmt[i]; i++){
 4b2:	4481                	li	s1,0
 4b4:	4701                	li	a4,0
      if(c0 == '%'){
        state = '%';
      } else {
        putc(fd, c0);
      }
    } else if(state == '%'){
 4b6:	02500a93          	li	s5,37
      c1 = c2 = 0;
      if(c0) c1 = fmt[i+1] & 0xff;
      if(c1) c2 = fmt[i+2] & 0xff;
      if(c0 == 'd'){
 4ba:	06400c13          	li	s8,100
        printint(fd, va_arg(ap, int), 10, 1);
      } else if(c0 == 'l' && c1 == 'd'){
 4be:	06c00c93          	li	s9,108
 4c2:	a005                	j	4e2 <vprintf+0x5a>
        putc(fd, c0);
 4c4:	85ca                	mv	a1,s2
 4c6:	855a                	mv	a0,s6
 4c8:	f07ff0ef          	jal	3ce <putc>
 4cc:	a019                	j	4d2 <vprintf+0x4a>
    } else if(state == '%'){
 4ce:	03598263          	beq	s3,s5,4f2 <vprintf+0x6a>
  for(i = 0; fmt[i]; i++){
 4d2:	2485                	addiw	s1,s1,1
 4d4:	8726                	mv	a4,s1
 4d6:	009a07b3          	add	a5,s4,s1
 4da:	0007c903          	lbu	s2,0(a5)
 4de:	22090a63          	beqz	s2,712 <vprintf+0x28a>
    c0 = fmt[i] & 0xff;
 4e2:	0009079b          	sext.w	a5,s2
    if(state == 0){
 4e6:	fe0994e3          	bnez	s3,4ce <vprintf+0x46>
      if(c0 == '%'){
 4ea:	fd579de3          	bne	a5,s5,4c4 <vprintf+0x3c>
        state = '%';
 4ee:	89be                	mv	s3,a5
 4f0:	b7cd                	j	4d2 <vprintf+0x4a>
      if(c0) c1 = fmt[i+1] & 0xff;
 4f2:	00ea06b3          	add	a3,s4,a4
 4f6:	0016c683          	lbu	a3,1(a3)
      c1 = c2 = 0;
 4fa:	8636                	mv	a2,a3
      if(c1) c2 = fmt[i+2] & 0xff;
 4fc:	c681                	beqz	a3,504 <vprintf+0x7c>
 4fe:	9752                	add	a4,a4,s4
 500:	00274603          	lbu	a2,2(a4)
      if(c0 == 'd'){
 504:	05878363          	beq	a5,s8,54a <vprintf+0xc2>
      } else if(c0 == 'l' && c1 == 'd'){
 508:	05978d63          	beq	a5,s9,562 <vprintf+0xda>
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 2;
      } else if(c0 == 'u'){
 50c:	07500713          	li	a4,117
 510:	0ee78763          	beq	a5,a4,5fe <vprintf+0x176>
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 2;
      } else if(c0 == 'x'){
 514:	07800713          	li	a4,120
 518:	12e78963          	beq	a5,a4,64a <vprintf+0x1c2>
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 2;
      } else if(c0 == 'p'){
 51c:	07000713          	li	a4,112
 520:	14e78e63          	beq	a5,a4,67c <vprintf+0x1f4>
        printptr(fd, va_arg(ap, uint64));
      } else if(c0 == 'c'){
 524:	06300713          	li	a4,99
 528:	18e78e63          	beq	a5,a4,6c4 <vprintf+0x23c>
        putc(fd, va_arg(ap, uint32));
      } else if(c0 == 's'){
 52c:	07300713          	li	a4,115
 530:	1ae78463          	beq	a5,a4,6d8 <vprintf+0x250>
        if((s = va_arg(ap, char*)) == 0)
          s = "(null)";
        for(; *s; s++)
          putc(fd, *s);
      } else if(c0 == '%'){
 534:	02500713          	li	a4,37
 538:	04e79563          	bne	a5,a4,582 <vprintf+0xfa>
        putc(fd, '%');
 53c:	02500593          	li	a1,37
 540:	855a                	mv	a0,s6
 542:	e8dff0ef          	jal	3ce <putc>
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c0);
      }

      state = 0;
 546:	4981                	li	s3,0
 548:	b769                	j	4d2 <vprintf+0x4a>
        printint(fd, va_arg(ap, int), 10, 1);
 54a:	008b8913          	addi	s2,s7,8
 54e:	4685                	li	a3,1
 550:	4629                	li	a2,10
 552:	000ba583          	lw	a1,0(s7)
 556:	855a                	mv	a0,s6
 558:	e95ff0ef          	jal	3ec <printint>
 55c:	8bca                	mv	s7,s2
      state = 0;
 55e:	4981                	li	s3,0
 560:	bf8d                	j	4d2 <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'd'){
 562:	06400793          	li	a5,100
 566:	02f68963          	beq	a3,a5,598 <vprintf+0x110>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 56a:	06c00793          	li	a5,108
 56e:	04f68263          	beq	a3,a5,5b2 <vprintf+0x12a>
      } else if(c0 == 'l' && c1 == 'u'){
 572:	07500793          	li	a5,117
 576:	0af68063          	beq	a3,a5,616 <vprintf+0x18e>
      } else if(c0 == 'l' && c1 == 'x'){
 57a:	07800793          	li	a5,120
 57e:	0ef68263          	beq	a3,a5,662 <vprintf+0x1da>
        putc(fd, '%');
 582:	02500593          	li	a1,37
 586:	855a                	mv	a0,s6
 588:	e47ff0ef          	jal	3ce <putc>
        putc(fd, c0);
 58c:	85ca                	mv	a1,s2
 58e:	855a                	mv	a0,s6
 590:	e3fff0ef          	jal	3ce <putc>
      state = 0;
 594:	4981                	li	s3,0
 596:	bf35                	j	4d2 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 598:	008b8913          	addi	s2,s7,8
 59c:	4685                	li	a3,1
 59e:	4629                	li	a2,10
 5a0:	000bb583          	ld	a1,0(s7)
 5a4:	855a                	mv	a0,s6
 5a6:	e47ff0ef          	jal	3ec <printint>
        i += 1;
 5aa:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 1);
 5ac:	8bca                	mv	s7,s2
      state = 0;
 5ae:	4981                	li	s3,0
        i += 1;
 5b0:	b70d                	j	4d2 <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 5b2:	06400793          	li	a5,100
 5b6:	02f60763          	beq	a2,a5,5e4 <vprintf+0x15c>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
 5ba:	07500793          	li	a5,117
 5be:	06f60963          	beq	a2,a5,630 <vprintf+0x1a8>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
 5c2:	07800793          	li	a5,120
 5c6:	faf61ee3          	bne	a2,a5,582 <vprintf+0xfa>
        printint(fd, va_arg(ap, uint64), 16, 0);
 5ca:	008b8913          	addi	s2,s7,8
 5ce:	4681                	li	a3,0
 5d0:	4641                	li	a2,16
 5d2:	000bb583          	ld	a1,0(s7)
 5d6:	855a                	mv	a0,s6
 5d8:	e15ff0ef          	jal	3ec <printint>
        i += 2;
 5dc:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 16, 0);
 5de:	8bca                	mv	s7,s2
      state = 0;
 5e0:	4981                	li	s3,0
        i += 2;
 5e2:	bdc5                	j	4d2 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 5e4:	008b8913          	addi	s2,s7,8
 5e8:	4685                	li	a3,1
 5ea:	4629                	li	a2,10
 5ec:	000bb583          	ld	a1,0(s7)
 5f0:	855a                	mv	a0,s6
 5f2:	dfbff0ef          	jal	3ec <printint>
        i += 2;
 5f6:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 1);
 5f8:	8bca                	mv	s7,s2
      state = 0;
 5fa:	4981                	li	s3,0
        i += 2;
 5fc:	bdd9                	j	4d2 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 10, 0);
 5fe:	008b8913          	addi	s2,s7,8
 602:	4681                	li	a3,0
 604:	4629                	li	a2,10
 606:	000be583          	lwu	a1,0(s7)
 60a:	855a                	mv	a0,s6
 60c:	de1ff0ef          	jal	3ec <printint>
 610:	8bca                	mv	s7,s2
      state = 0;
 612:	4981                	li	s3,0
 614:	bd7d                	j	4d2 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 616:	008b8913          	addi	s2,s7,8
 61a:	4681                	li	a3,0
 61c:	4629                	li	a2,10
 61e:	000bb583          	ld	a1,0(s7)
 622:	855a                	mv	a0,s6
 624:	dc9ff0ef          	jal	3ec <printint>
        i += 1;
 628:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 0);
 62a:	8bca                	mv	s7,s2
      state = 0;
 62c:	4981                	li	s3,0
        i += 1;
 62e:	b555                	j	4d2 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 630:	008b8913          	addi	s2,s7,8
 634:	4681                	li	a3,0
 636:	4629                	li	a2,10
 638:	000bb583          	ld	a1,0(s7)
 63c:	855a                	mv	a0,s6
 63e:	dafff0ef          	jal	3ec <printint>
        i += 2;
 642:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 0);
 644:	8bca                	mv	s7,s2
      state = 0;
 646:	4981                	li	s3,0
        i += 2;
 648:	b569                	j	4d2 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 16, 0);
 64a:	008b8913          	addi	s2,s7,8
 64e:	4681                	li	a3,0
 650:	4641                	li	a2,16
 652:	000be583          	lwu	a1,0(s7)
 656:	855a                	mv	a0,s6
 658:	d95ff0ef          	jal	3ec <printint>
 65c:	8bca                	mv	s7,s2
      state = 0;
 65e:	4981                	li	s3,0
 660:	bd8d                	j	4d2 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 16, 0);
 662:	008b8913          	addi	s2,s7,8
 666:	4681                	li	a3,0
 668:	4641                	li	a2,16
 66a:	000bb583          	ld	a1,0(s7)
 66e:	855a                	mv	a0,s6
 670:	d7dff0ef          	jal	3ec <printint>
        i += 1;
 674:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 16, 0);
 676:	8bca                	mv	s7,s2
      state = 0;
 678:	4981                	li	s3,0
        i += 1;
 67a:	bda1                	j	4d2 <vprintf+0x4a>
 67c:	e06a                	sd	s10,0(sp)
        printptr(fd, va_arg(ap, uint64));
 67e:	008b8d13          	addi	s10,s7,8
 682:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 686:	03000593          	li	a1,48
 68a:	855a                	mv	a0,s6
 68c:	d43ff0ef          	jal	3ce <putc>
  putc(fd, 'x');
 690:	07800593          	li	a1,120
 694:	855a                	mv	a0,s6
 696:	d39ff0ef          	jal	3ce <putc>
 69a:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 69c:	00000b97          	auipc	s7,0x0
 6a0:	2e4b8b93          	addi	s7,s7,740 # 980 <digits>
 6a4:	03c9d793          	srli	a5,s3,0x3c
 6a8:	97de                	add	a5,a5,s7
 6aa:	0007c583          	lbu	a1,0(a5)
 6ae:	855a                	mv	a0,s6
 6b0:	d1fff0ef          	jal	3ce <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 6b4:	0992                	slli	s3,s3,0x4
 6b6:	397d                	addiw	s2,s2,-1
 6b8:	fe0916e3          	bnez	s2,6a4 <vprintf+0x21c>
        printptr(fd, va_arg(ap, uint64));
 6bc:	8bea                	mv	s7,s10
      state = 0;
 6be:	4981                	li	s3,0
 6c0:	6d02                	ld	s10,0(sp)
 6c2:	bd01                	j	4d2 <vprintf+0x4a>
        putc(fd, va_arg(ap, uint32));
 6c4:	008b8913          	addi	s2,s7,8
 6c8:	000bc583          	lbu	a1,0(s7)
 6cc:	855a                	mv	a0,s6
 6ce:	d01ff0ef          	jal	3ce <putc>
 6d2:	8bca                	mv	s7,s2
      state = 0;
 6d4:	4981                	li	s3,0
 6d6:	bbf5                	j	4d2 <vprintf+0x4a>
        if((s = va_arg(ap, char*)) == 0)
 6d8:	008b8993          	addi	s3,s7,8
 6dc:	000bb903          	ld	s2,0(s7)
 6e0:	00090f63          	beqz	s2,6fe <vprintf+0x276>
        for(; *s; s++)
 6e4:	00094583          	lbu	a1,0(s2)
 6e8:	c195                	beqz	a1,70c <vprintf+0x284>
          putc(fd, *s);
 6ea:	855a                	mv	a0,s6
 6ec:	ce3ff0ef          	jal	3ce <putc>
        for(; *s; s++)
 6f0:	0905                	addi	s2,s2,1
 6f2:	00094583          	lbu	a1,0(s2)
 6f6:	f9f5                	bnez	a1,6ea <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 6f8:	8bce                	mv	s7,s3
      state = 0;
 6fa:	4981                	li	s3,0
 6fc:	bbd9                	j	4d2 <vprintf+0x4a>
          s = "(null)";
 6fe:	00000917          	auipc	s2,0x0
 702:	27a90913          	addi	s2,s2,634 # 978 <malloc+0x16e>
        for(; *s; s++)
 706:	02800593          	li	a1,40
 70a:	b7c5                	j	6ea <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 70c:	8bce                	mv	s7,s3
      state = 0;
 70e:	4981                	li	s3,0
 710:	b3c9                	j	4d2 <vprintf+0x4a>
 712:	64a6                	ld	s1,72(sp)
 714:	79e2                	ld	s3,56(sp)
 716:	7a42                	ld	s4,48(sp)
 718:	7aa2                	ld	s5,40(sp)
 71a:	7b02                	ld	s6,32(sp)
 71c:	6be2                	ld	s7,24(sp)
 71e:	6c42                	ld	s8,16(sp)
 720:	6ca2                	ld	s9,8(sp)
    }
  }
}
 722:	60e6                	ld	ra,88(sp)
 724:	6446                	ld	s0,80(sp)
 726:	6906                	ld	s2,64(sp)
 728:	6125                	addi	sp,sp,96
 72a:	8082                	ret

000000000000072c <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 72c:	715d                	addi	sp,sp,-80
 72e:	ec06                	sd	ra,24(sp)
 730:	e822                	sd	s0,16(sp)
 732:	1000                	addi	s0,sp,32
 734:	e010                	sd	a2,0(s0)
 736:	e414                	sd	a3,8(s0)
 738:	e818                	sd	a4,16(s0)
 73a:	ec1c                	sd	a5,24(s0)
 73c:	03043023          	sd	a6,32(s0)
 740:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 744:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 748:	8622                	mv	a2,s0
 74a:	d3fff0ef          	jal	488 <vprintf>
}
 74e:	60e2                	ld	ra,24(sp)
 750:	6442                	ld	s0,16(sp)
 752:	6161                	addi	sp,sp,80
 754:	8082                	ret

0000000000000756 <printf>:

void
printf(const char *fmt, ...)
{
 756:	711d                	addi	sp,sp,-96
 758:	ec06                	sd	ra,24(sp)
 75a:	e822                	sd	s0,16(sp)
 75c:	1000                	addi	s0,sp,32
 75e:	e40c                	sd	a1,8(s0)
 760:	e810                	sd	a2,16(s0)
 762:	ec14                	sd	a3,24(s0)
 764:	f018                	sd	a4,32(s0)
 766:	f41c                	sd	a5,40(s0)
 768:	03043823          	sd	a6,48(s0)
 76c:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 770:	00840613          	addi	a2,s0,8
 774:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 778:	85aa                	mv	a1,a0
 77a:	4505                	li	a0,1
 77c:	d0dff0ef          	jal	488 <vprintf>
}
 780:	60e2                	ld	ra,24(sp)
 782:	6442                	ld	s0,16(sp)
 784:	6125                	addi	sp,sp,96
 786:	8082                	ret

0000000000000788 <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 788:	1141                	addi	sp,sp,-16
 78a:	e422                	sd	s0,8(sp)
 78c:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 78e:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 792:	00001797          	auipc	a5,0x1
 796:	86e7b783          	ld	a5,-1938(a5) # 1000 <freep>
 79a:	a02d                	j	7c4 <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 79c:	4618                	lw	a4,8(a2)
 79e:	9f2d                	addw	a4,a4,a1
 7a0:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 7a4:	6398                	ld	a4,0(a5)
 7a6:	6310                	ld	a2,0(a4)
 7a8:	a83d                	j	7e6 <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 7aa:	ff852703          	lw	a4,-8(a0)
 7ae:	9f31                	addw	a4,a4,a2
 7b0:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 7b2:	ff053683          	ld	a3,-16(a0)
 7b6:	a091                	j	7fa <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 7b8:	6398                	ld	a4,0(a5)
 7ba:	00e7e463          	bltu	a5,a4,7c2 <free+0x3a>
 7be:	00e6ea63          	bltu	a3,a4,7d2 <free+0x4a>
{
 7c2:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 7c4:	fed7fae3          	bgeu	a5,a3,7b8 <free+0x30>
 7c8:	6398                	ld	a4,0(a5)
 7ca:	00e6e463          	bltu	a3,a4,7d2 <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 7ce:	fee7eae3          	bltu	a5,a4,7c2 <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 7d2:	ff852583          	lw	a1,-8(a0)
 7d6:	6390                	ld	a2,0(a5)
 7d8:	02059813          	slli	a6,a1,0x20
 7dc:	01c85713          	srli	a4,a6,0x1c
 7e0:	9736                	add	a4,a4,a3
 7e2:	fae60de3          	beq	a2,a4,79c <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 7e6:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 7ea:	4790                	lw	a2,8(a5)
 7ec:	02061593          	slli	a1,a2,0x20
 7f0:	01c5d713          	srli	a4,a1,0x1c
 7f4:	973e                	add	a4,a4,a5
 7f6:	fae68ae3          	beq	a3,a4,7aa <free+0x22>
    p->s.ptr = bp->s.ptr;
 7fa:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 7fc:	00001717          	auipc	a4,0x1
 800:	80f73223          	sd	a5,-2044(a4) # 1000 <freep>
}
 804:	6422                	ld	s0,8(sp)
 806:	0141                	addi	sp,sp,16
 808:	8082                	ret

000000000000080a <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 80a:	7139                	addi	sp,sp,-64
 80c:	fc06                	sd	ra,56(sp)
 80e:	f822                	sd	s0,48(sp)
 810:	f426                	sd	s1,40(sp)
 812:	ec4e                	sd	s3,24(sp)
 814:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 816:	02051493          	slli	s1,a0,0x20
 81a:	9081                	srli	s1,s1,0x20
 81c:	04bd                	addi	s1,s1,15
 81e:	8091                	srli	s1,s1,0x4
 820:	0014899b          	addiw	s3,s1,1
 824:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 826:	00000517          	auipc	a0,0x0
 82a:	7da53503          	ld	a0,2010(a0) # 1000 <freep>
 82e:	c915                	beqz	a0,862 <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 830:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 832:	4798                	lw	a4,8(a5)
 834:	08977a63          	bgeu	a4,s1,8c8 <malloc+0xbe>
 838:	f04a                	sd	s2,32(sp)
 83a:	e852                	sd	s4,16(sp)
 83c:	e456                	sd	s5,8(sp)
 83e:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 840:	8a4e                	mv	s4,s3
 842:	0009871b          	sext.w	a4,s3
 846:	6685                	lui	a3,0x1
 848:	00d77363          	bgeu	a4,a3,84e <malloc+0x44>
 84c:	6a05                	lui	s4,0x1
 84e:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 852:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 856:	00000917          	auipc	s2,0x0
 85a:	7aa90913          	addi	s2,s2,1962 # 1000 <freep>
  if(p == SBRK_ERROR)
 85e:	5afd                	li	s5,-1
 860:	a081                	j	8a0 <malloc+0x96>
 862:	f04a                	sd	s2,32(sp)
 864:	e852                	sd	s4,16(sp)
 866:	e456                	sd	s5,8(sp)
 868:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 86a:	00000797          	auipc	a5,0x0
 86e:	7a678793          	addi	a5,a5,1958 # 1010 <base>
 872:	00000717          	auipc	a4,0x0
 876:	78f73723          	sd	a5,1934(a4) # 1000 <freep>
 87a:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 87c:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 880:	b7c1                	j	840 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 882:	6398                	ld	a4,0(a5)
 884:	e118                	sd	a4,0(a0)
 886:	a8a9                	j	8e0 <malloc+0xd6>
  hp->s.size = nu;
 888:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 88c:	0541                	addi	a0,a0,16
 88e:	efbff0ef          	jal	788 <free>
  return freep;
 892:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 896:	c12d                	beqz	a0,8f8 <malloc+0xee>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 898:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 89a:	4798                	lw	a4,8(a5)
 89c:	02977263          	bgeu	a4,s1,8c0 <malloc+0xb6>
    if(p == freep)
 8a0:	00093703          	ld	a4,0(s2)
 8a4:	853e                	mv	a0,a5
 8a6:	fef719e3          	bne	a4,a5,898 <malloc+0x8e>
  p = sbrk(nu * sizeof(Header));
 8aa:	8552                	mv	a0,s4
 8ac:	a27ff0ef          	jal	2d2 <sbrk>
  if(p == SBRK_ERROR)
 8b0:	fd551ce3          	bne	a0,s5,888 <malloc+0x7e>
        return 0;
 8b4:	4501                	li	a0,0
 8b6:	7902                	ld	s2,32(sp)
 8b8:	6a42                	ld	s4,16(sp)
 8ba:	6aa2                	ld	s5,8(sp)
 8bc:	6b02                	ld	s6,0(sp)
 8be:	a03d                	j	8ec <malloc+0xe2>
 8c0:	7902                	ld	s2,32(sp)
 8c2:	6a42                	ld	s4,16(sp)
 8c4:	6aa2                	ld	s5,8(sp)
 8c6:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 8c8:	fae48de3          	beq	s1,a4,882 <malloc+0x78>
        p->s.size -= nunits;
 8cc:	4137073b          	subw	a4,a4,s3
 8d0:	c798                	sw	a4,8(a5)
        p += p->s.size;
 8d2:	02071693          	slli	a3,a4,0x20
 8d6:	01c6d713          	srli	a4,a3,0x1c
 8da:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 8dc:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 8e0:	00000717          	auipc	a4,0x0
 8e4:	72a73023          	sd	a0,1824(a4) # 1000 <freep>
      return (void*)(p + 1);
 8e8:	01078513          	addi	a0,a5,16
  }
}
 8ec:	70e2                	ld	ra,56(sp)
 8ee:	7442                	ld	s0,48(sp)
 8f0:	74a2                	ld	s1,40(sp)
 8f2:	69e2                	ld	s3,24(sp)
 8f4:	6121                	addi	sp,sp,64
 8f6:	8082                	ret
 8f8:	7902                	ld	s2,32(sp)
 8fa:	6a42                	ld	s4,16(sp)
 8fc:	6aa2                	ld	s5,8(sp)
 8fe:	6b02                	ld	s6,0(sp)
 900:	b7f5                	j	8ec <malloc+0xe2>
