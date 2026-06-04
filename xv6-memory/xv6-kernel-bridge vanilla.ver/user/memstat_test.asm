
user/_memstat_test:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <print_memstat>:
#include "kernel/memstat.h"
#include "user/user.h"

static void
print_memstat(void)
{
   0:	81010113          	addi	sp,sp,-2032
   4:	7e113423          	sd	ra,2024(sp)
   8:	7e813023          	sd	s0,2016(sp)
   c:	7c913c23          	sd	s1,2008(sp)
  10:	7d213823          	sd	s2,2000(sp)
  14:	7d313423          	sd	s3,1992(sp)
  18:	7f010413          	addi	s0,sp,2032
  1c:	dc010113          	addi	sp,sp,-576
  struct memstat stats[MEMSTAT_MAX];
  int n;
  int i;

  n = getmemstat(stats, MEMSTAT_MAX);
  20:	757d                	lui	a0,0xfffff
  22:	04000593          	li	a1,64
  26:	5d050793          	addi	a5,a0,1488 # fffffffffffff5d0 <base+0xffffffffffffe5c0>
  2a:	00878533          	add	a0,a5,s0
  2e:	450000ef          	jal	47e <getmemstat>

  if(n < 0){
  32:	06054863          	bltz	a0,a2 <print_memstat+0xa2>
  36:	892a                	mv	s2,a0
    printf("getmemstat failed\n");
    return;
  }

  printf("pid\tstate\tsz\tquota\tname\n");
  38:	00001517          	auipc	a0,0x1
  3c:	9b050513          	addi	a0,a0,-1616 # 9e8 <malloc+0x11e>
  40:	7d6000ef          	jal	816 <printf>

  for(i = 0; i < n; i++){
  44:	05205063          	blez	s2,84 <print_memstat+0x84>
  48:	74fd                	lui	s1,0xfffff
  4a:	5e848793          	addi	a5,s1,1512 # fffffffffffff5e8 <base+0xffffffffffffe5d8>
  4e:	008784b3          	add	s1,a5,s0
  52:	02800793          	li	a5,40
  56:	02f90933          	mul	s2,s2,a5
  5a:	9926                	add	s2,s2,s1
    printf("%d\t%d\t%d\t%d\t%s\n",
  5c:	00001997          	auipc	s3,0x1
  60:	9ac98993          	addi	s3,s3,-1620 # a08 <malloc+0x13e>
  64:	87a6                	mv	a5,s1
  66:	ff84a703          	lw	a4,-8(s1)
  6a:	ff04a683          	lw	a3,-16(s1)
  6e:	fec4a603          	lw	a2,-20(s1)
  72:	fe84a583          	lw	a1,-24(s1)
  76:	854e                	mv	a0,s3
  78:	79e000ef          	jal	816 <printf>
  for(i = 0; i < n; i++){
  7c:	02848493          	addi	s1,s1,40
  80:	ff2492e3          	bne	s1,s2,64 <print_memstat+0x64>
      stats[i].state,
      (int)stats[i].sz,
      (int)stats[i].mem_quota,
      stats[i].name);
  }
}
  84:	24010113          	addi	sp,sp,576
  88:	7e813083          	ld	ra,2024(sp)
  8c:	7e013403          	ld	s0,2016(sp)
  90:	7d813483          	ld	s1,2008(sp)
  94:	7d013903          	ld	s2,2000(sp)
  98:	7c813983          	ld	s3,1992(sp)
  9c:	7f010113          	addi	sp,sp,2032
  a0:	8082                	ret
    printf("getmemstat failed\n");
  a2:	00001517          	auipc	a0,0x1
  a6:	92e50513          	addi	a0,a0,-1746 # 9d0 <malloc+0x106>
  aa:	76c000ef          	jal	816 <printf>
    return;
  ae:	bfd9                	j	84 <print_memstat+0x84>

00000000000000b0 <main>:

int
main(int argc, char *argv[])
{
  b0:	7179                	addi	sp,sp,-48
  b2:	f406                	sd	ra,40(sp)
  b4:	f022                	sd	s0,32(sp)
  b6:	ec26                	sd	s1,24(sp)
  b8:	e84a                	sd	s2,16(sp)
  ba:	e44e                	sd	s3,8(sp)
  bc:	e052                	sd	s4,0(sp)
  be:	1800                	addi	s0,sp,48
  c0:	89aa                	mv	s3,a0
  c2:	8a2e                	mv	s4,a1
  int pid = getpid();
  c4:	382000ef          	jal	446 <getpid>
  c8:	84aa                	mv	s1,a0
  int quota = 65536;

  if(argc >= 2){
  ca:	4785                	li	a5,1
  int quota = 65536;
  cc:	6941                	lui	s2,0x10
  if(argc >= 2){
  ce:	0537c363          	blt	a5,s3,114 <main+0x64>
    quota = atoi(argv[1]);
  }

  printf("=== before setmemquota ===\n");
  d2:	00001517          	auipc	a0,0x1
  d6:	94650513          	addi	a0,a0,-1722 # a18 <malloc+0x14e>
  da:	73c000ef          	jal	816 <printf>
  print_memstat();
  de:	f23ff0ef          	jal	0 <print_memstat>

  printf("\nsetmemquota pid=%d quota=%d\n", pid, quota);
  e2:	864a                	mv	a2,s2
  e4:	85a6                	mv	a1,s1
  e6:	00001517          	auipc	a0,0x1
  ea:	95250513          	addi	a0,a0,-1710 # a38 <malloc+0x16e>
  ee:	728000ef          	jal	816 <printf>

  if(setmemquota(pid, quota) < 0){
  f2:	85ca                	mv	a1,s2
  f4:	8526                	mv	a0,s1
  f6:	390000ef          	jal	486 <setmemquota>
  fa:	02054363          	bltz	a0,120 <main+0x70>
    printf("setmemquota failed\n");
    exit(1);
  }

  printf("\n=== after setmemquota ===\n");
  fe:	00001517          	auipc	a0,0x1
 102:	97250513          	addi	a0,a0,-1678 # a70 <malloc+0x1a6>
 106:	710000ef          	jal	816 <printf>
  print_memstat();
 10a:	ef7ff0ef          	jal	0 <print_memstat>

  exit(0);
 10e:	4501                	li	a0,0
 110:	2b6000ef          	jal	3c6 <exit>
    quota = atoi(argv[1]);
 114:	008a3503          	ld	a0,8(s4)
 118:	18c000ef          	jal	2a4 <atoi>
 11c:	892a                	mv	s2,a0
 11e:	bf55                	j	d2 <main+0x22>
    printf("setmemquota failed\n");
 120:	00001517          	auipc	a0,0x1
 124:	93850513          	addi	a0,a0,-1736 # a58 <malloc+0x18e>
 128:	6ee000ef          	jal	816 <printf>
    exit(1);
 12c:	4505                	li	a0,1
 12e:	298000ef          	jal	3c6 <exit>

0000000000000132 <start>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
start(int argc, char **argv)
{
 132:	1141                	addi	sp,sp,-16
 134:	e406                	sd	ra,8(sp)
 136:	e022                	sd	s0,0(sp)
 138:	0800                	addi	s0,sp,16
  int r;
  extern int main(int argc, char **argv);
  r = main(argc, argv);
 13a:	f77ff0ef          	jal	b0 <main>
  exit(r);
 13e:	288000ef          	jal	3c6 <exit>

0000000000000142 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 142:	1141                	addi	sp,sp,-16
 144:	e422                	sd	s0,8(sp)
 146:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 148:	87aa                	mv	a5,a0
 14a:	0585                	addi	a1,a1,1
 14c:	0785                	addi	a5,a5,1
 14e:	fff5c703          	lbu	a4,-1(a1)
 152:	fee78fa3          	sb	a4,-1(a5)
 156:	fb75                	bnez	a4,14a <strcpy+0x8>
    ;
  return os;
}
 158:	6422                	ld	s0,8(sp)
 15a:	0141                	addi	sp,sp,16
 15c:	8082                	ret

000000000000015e <strcmp>:

int
strcmp(const char *p, const char *q)
{
 15e:	1141                	addi	sp,sp,-16
 160:	e422                	sd	s0,8(sp)
 162:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 164:	00054783          	lbu	a5,0(a0)
 168:	cb91                	beqz	a5,17c <strcmp+0x1e>
 16a:	0005c703          	lbu	a4,0(a1)
 16e:	00f71763          	bne	a4,a5,17c <strcmp+0x1e>
    p++, q++;
 172:	0505                	addi	a0,a0,1
 174:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 176:	00054783          	lbu	a5,0(a0)
 17a:	fbe5                	bnez	a5,16a <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 17c:	0005c503          	lbu	a0,0(a1)
}
 180:	40a7853b          	subw	a0,a5,a0
 184:	6422                	ld	s0,8(sp)
 186:	0141                	addi	sp,sp,16
 188:	8082                	ret

000000000000018a <strlen>:

uint
strlen(const char *s)
{
 18a:	1141                	addi	sp,sp,-16
 18c:	e422                	sd	s0,8(sp)
 18e:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 190:	00054783          	lbu	a5,0(a0)
 194:	cf91                	beqz	a5,1b0 <strlen+0x26>
 196:	0505                	addi	a0,a0,1
 198:	87aa                	mv	a5,a0
 19a:	86be                	mv	a3,a5
 19c:	0785                	addi	a5,a5,1
 19e:	fff7c703          	lbu	a4,-1(a5)
 1a2:	ff65                	bnez	a4,19a <strlen+0x10>
 1a4:	40a6853b          	subw	a0,a3,a0
 1a8:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 1aa:	6422                	ld	s0,8(sp)
 1ac:	0141                	addi	sp,sp,16
 1ae:	8082                	ret
  for(n = 0; s[n]; n++)
 1b0:	4501                	li	a0,0
 1b2:	bfe5                	j	1aa <strlen+0x20>

00000000000001b4 <memset>:

void*
memset(void *dst, int c, uint n)
{
 1b4:	1141                	addi	sp,sp,-16
 1b6:	e422                	sd	s0,8(sp)
 1b8:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 1ba:	ca19                	beqz	a2,1d0 <memset+0x1c>
 1bc:	87aa                	mv	a5,a0
 1be:	1602                	slli	a2,a2,0x20
 1c0:	9201                	srli	a2,a2,0x20
 1c2:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 1c6:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 1ca:	0785                	addi	a5,a5,1
 1cc:	fee79de3          	bne	a5,a4,1c6 <memset+0x12>
  }
  return dst;
}
 1d0:	6422                	ld	s0,8(sp)
 1d2:	0141                	addi	sp,sp,16
 1d4:	8082                	ret

00000000000001d6 <strchr>:

char*
strchr(const char *s, char c)
{
 1d6:	1141                	addi	sp,sp,-16
 1d8:	e422                	sd	s0,8(sp)
 1da:	0800                	addi	s0,sp,16
  for(; *s; s++)
 1dc:	00054783          	lbu	a5,0(a0)
 1e0:	cb99                	beqz	a5,1f6 <strchr+0x20>
    if(*s == c)
 1e2:	00f58763          	beq	a1,a5,1f0 <strchr+0x1a>
  for(; *s; s++)
 1e6:	0505                	addi	a0,a0,1
 1e8:	00054783          	lbu	a5,0(a0)
 1ec:	fbfd                	bnez	a5,1e2 <strchr+0xc>
      return (char*)s;
  return 0;
 1ee:	4501                	li	a0,0
}
 1f0:	6422                	ld	s0,8(sp)
 1f2:	0141                	addi	sp,sp,16
 1f4:	8082                	ret
  return 0;
 1f6:	4501                	li	a0,0
 1f8:	bfe5                	j	1f0 <strchr+0x1a>

00000000000001fa <gets>:

char*
gets(char *buf, int max)
{
 1fa:	711d                	addi	sp,sp,-96
 1fc:	ec86                	sd	ra,88(sp)
 1fe:	e8a2                	sd	s0,80(sp)
 200:	e4a6                	sd	s1,72(sp)
 202:	e0ca                	sd	s2,64(sp)
 204:	fc4e                	sd	s3,56(sp)
 206:	f852                	sd	s4,48(sp)
 208:	f456                	sd	s5,40(sp)
 20a:	f05a                	sd	s6,32(sp)
 20c:	ec5e                	sd	s7,24(sp)
 20e:	1080                	addi	s0,sp,96
 210:	8baa                	mv	s7,a0
 212:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 214:	892a                	mv	s2,a0
 216:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 218:	4aa9                	li	s5,10
 21a:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 21c:	89a6                	mv	s3,s1
 21e:	2485                	addiw	s1,s1,1
 220:	0344d663          	bge	s1,s4,24c <gets+0x52>
    cc = read(0, &c, 1);
 224:	4605                	li	a2,1
 226:	faf40593          	addi	a1,s0,-81
 22a:	4501                	li	a0,0
 22c:	1b2000ef          	jal	3de <read>
    if(cc < 1)
 230:	00a05e63          	blez	a0,24c <gets+0x52>
    buf[i++] = c;
 234:	faf44783          	lbu	a5,-81(s0)
 238:	00f90023          	sb	a5,0(s2) # 10000 <base+0xeff0>
    if(c == '\n' || c == '\r')
 23c:	01578763          	beq	a5,s5,24a <gets+0x50>
 240:	0905                	addi	s2,s2,1
 242:	fd679de3          	bne	a5,s6,21c <gets+0x22>
    buf[i++] = c;
 246:	89a6                	mv	s3,s1
 248:	a011                	j	24c <gets+0x52>
 24a:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 24c:	99de                	add	s3,s3,s7
 24e:	00098023          	sb	zero,0(s3)
  return buf;
}
 252:	855e                	mv	a0,s7
 254:	60e6                	ld	ra,88(sp)
 256:	6446                	ld	s0,80(sp)
 258:	64a6                	ld	s1,72(sp)
 25a:	6906                	ld	s2,64(sp)
 25c:	79e2                	ld	s3,56(sp)
 25e:	7a42                	ld	s4,48(sp)
 260:	7aa2                	ld	s5,40(sp)
 262:	7b02                	ld	s6,32(sp)
 264:	6be2                	ld	s7,24(sp)
 266:	6125                	addi	sp,sp,96
 268:	8082                	ret

000000000000026a <stat>:

int
stat(const char *n, struct stat *st)
{
 26a:	1101                	addi	sp,sp,-32
 26c:	ec06                	sd	ra,24(sp)
 26e:	e822                	sd	s0,16(sp)
 270:	e04a                	sd	s2,0(sp)
 272:	1000                	addi	s0,sp,32
 274:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 276:	4581                	li	a1,0
 278:	18e000ef          	jal	406 <open>
  if(fd < 0)
 27c:	02054263          	bltz	a0,2a0 <stat+0x36>
 280:	e426                	sd	s1,8(sp)
 282:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 284:	85ca                	mv	a1,s2
 286:	198000ef          	jal	41e <fstat>
 28a:	892a                	mv	s2,a0
  close(fd);
 28c:	8526                	mv	a0,s1
 28e:	160000ef          	jal	3ee <close>
  return r;
 292:	64a2                	ld	s1,8(sp)
}
 294:	854a                	mv	a0,s2
 296:	60e2                	ld	ra,24(sp)
 298:	6442                	ld	s0,16(sp)
 29a:	6902                	ld	s2,0(sp)
 29c:	6105                	addi	sp,sp,32
 29e:	8082                	ret
    return -1;
 2a0:	597d                	li	s2,-1
 2a2:	bfcd                	j	294 <stat+0x2a>

00000000000002a4 <atoi>:

int
atoi(const char *s)
{
 2a4:	1141                	addi	sp,sp,-16
 2a6:	e422                	sd	s0,8(sp)
 2a8:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 2aa:	00054683          	lbu	a3,0(a0)
 2ae:	fd06879b          	addiw	a5,a3,-48
 2b2:	0ff7f793          	zext.b	a5,a5
 2b6:	4625                	li	a2,9
 2b8:	02f66863          	bltu	a2,a5,2e8 <atoi+0x44>
 2bc:	872a                	mv	a4,a0
  n = 0;
 2be:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 2c0:	0705                	addi	a4,a4,1
 2c2:	0025179b          	slliw	a5,a0,0x2
 2c6:	9fa9                	addw	a5,a5,a0
 2c8:	0017979b          	slliw	a5,a5,0x1
 2cc:	9fb5                	addw	a5,a5,a3
 2ce:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 2d2:	00074683          	lbu	a3,0(a4)
 2d6:	fd06879b          	addiw	a5,a3,-48
 2da:	0ff7f793          	zext.b	a5,a5
 2de:	fef671e3          	bgeu	a2,a5,2c0 <atoi+0x1c>
  return n;
}
 2e2:	6422                	ld	s0,8(sp)
 2e4:	0141                	addi	sp,sp,16
 2e6:	8082                	ret
  n = 0;
 2e8:	4501                	li	a0,0
 2ea:	bfe5                	j	2e2 <atoi+0x3e>

00000000000002ec <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 2ec:	1141                	addi	sp,sp,-16
 2ee:	e422                	sd	s0,8(sp)
 2f0:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 2f2:	02b57463          	bgeu	a0,a1,31a <memmove+0x2e>
    while(n-- > 0)
 2f6:	00c05f63          	blez	a2,314 <memmove+0x28>
 2fa:	1602                	slli	a2,a2,0x20
 2fc:	9201                	srli	a2,a2,0x20
 2fe:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 302:	872a                	mv	a4,a0
      *dst++ = *src++;
 304:	0585                	addi	a1,a1,1
 306:	0705                	addi	a4,a4,1
 308:	fff5c683          	lbu	a3,-1(a1)
 30c:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 310:	fef71ae3          	bne	a4,a5,304 <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 314:	6422                	ld	s0,8(sp)
 316:	0141                	addi	sp,sp,16
 318:	8082                	ret
    dst += n;
 31a:	00c50733          	add	a4,a0,a2
    src += n;
 31e:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 320:	fec05ae3          	blez	a2,314 <memmove+0x28>
 324:	fff6079b          	addiw	a5,a2,-1
 328:	1782                	slli	a5,a5,0x20
 32a:	9381                	srli	a5,a5,0x20
 32c:	fff7c793          	not	a5,a5
 330:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 332:	15fd                	addi	a1,a1,-1
 334:	177d                	addi	a4,a4,-1
 336:	0005c683          	lbu	a3,0(a1)
 33a:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 33e:	fee79ae3          	bne	a5,a4,332 <memmove+0x46>
 342:	bfc9                	j	314 <memmove+0x28>

0000000000000344 <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 344:	1141                	addi	sp,sp,-16
 346:	e422                	sd	s0,8(sp)
 348:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 34a:	ca05                	beqz	a2,37a <memcmp+0x36>
 34c:	fff6069b          	addiw	a3,a2,-1
 350:	1682                	slli	a3,a3,0x20
 352:	9281                	srli	a3,a3,0x20
 354:	0685                	addi	a3,a3,1
 356:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 358:	00054783          	lbu	a5,0(a0)
 35c:	0005c703          	lbu	a4,0(a1)
 360:	00e79863          	bne	a5,a4,370 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 364:	0505                	addi	a0,a0,1
    p2++;
 366:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 368:	fed518e3          	bne	a0,a3,358 <memcmp+0x14>
  }
  return 0;
 36c:	4501                	li	a0,0
 36e:	a019                	j	374 <memcmp+0x30>
      return *p1 - *p2;
 370:	40e7853b          	subw	a0,a5,a4
}
 374:	6422                	ld	s0,8(sp)
 376:	0141                	addi	sp,sp,16
 378:	8082                	ret
  return 0;
 37a:	4501                	li	a0,0
 37c:	bfe5                	j	374 <memcmp+0x30>

000000000000037e <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 37e:	1141                	addi	sp,sp,-16
 380:	e406                	sd	ra,8(sp)
 382:	e022                	sd	s0,0(sp)
 384:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 386:	f67ff0ef          	jal	2ec <memmove>
}
 38a:	60a2                	ld	ra,8(sp)
 38c:	6402                	ld	s0,0(sp)
 38e:	0141                	addi	sp,sp,16
 390:	8082                	ret

0000000000000392 <sbrk>:

char *
sbrk(int n) {
 392:	1141                	addi	sp,sp,-16
 394:	e406                	sd	ra,8(sp)
 396:	e022                	sd	s0,0(sp)
 398:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_EAGER);
 39a:	4585                	li	a1,1
 39c:	0b2000ef          	jal	44e <sys_sbrk>
}
 3a0:	60a2                	ld	ra,8(sp)
 3a2:	6402                	ld	s0,0(sp)
 3a4:	0141                	addi	sp,sp,16
 3a6:	8082                	ret

00000000000003a8 <sbrklazy>:

char *
sbrklazy(int n) {
 3a8:	1141                	addi	sp,sp,-16
 3aa:	e406                	sd	ra,8(sp)
 3ac:	e022                	sd	s0,0(sp)
 3ae:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_LAZY);
 3b0:	4589                	li	a1,2
 3b2:	09c000ef          	jal	44e <sys_sbrk>
}
 3b6:	60a2                	ld	ra,8(sp)
 3b8:	6402                	ld	s0,0(sp)
 3ba:	0141                	addi	sp,sp,16
 3bc:	8082                	ret

00000000000003be <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 3be:	4885                	li	a7,1
 ecall
 3c0:	00000073          	ecall
 ret
 3c4:	8082                	ret

00000000000003c6 <exit>:
.global exit
exit:
 li a7, SYS_exit
 3c6:	4889                	li	a7,2
 ecall
 3c8:	00000073          	ecall
 ret
 3cc:	8082                	ret

00000000000003ce <wait>:
.global wait
wait:
 li a7, SYS_wait
 3ce:	488d                	li	a7,3
 ecall
 3d0:	00000073          	ecall
 ret
 3d4:	8082                	ret

00000000000003d6 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 3d6:	4891                	li	a7,4
 ecall
 3d8:	00000073          	ecall
 ret
 3dc:	8082                	ret

00000000000003de <read>:
.global read
read:
 li a7, SYS_read
 3de:	4895                	li	a7,5
 ecall
 3e0:	00000073          	ecall
 ret
 3e4:	8082                	ret

00000000000003e6 <write>:
.global write
write:
 li a7, SYS_write
 3e6:	48c1                	li	a7,16
 ecall
 3e8:	00000073          	ecall
 ret
 3ec:	8082                	ret

00000000000003ee <close>:
.global close
close:
 li a7, SYS_close
 3ee:	48d5                	li	a7,21
 ecall
 3f0:	00000073          	ecall
 ret
 3f4:	8082                	ret

00000000000003f6 <kill>:
.global kill
kill:
 li a7, SYS_kill
 3f6:	4899                	li	a7,6
 ecall
 3f8:	00000073          	ecall
 ret
 3fc:	8082                	ret

00000000000003fe <exec>:
.global exec
exec:
 li a7, SYS_exec
 3fe:	489d                	li	a7,7
 ecall
 400:	00000073          	ecall
 ret
 404:	8082                	ret

0000000000000406 <open>:
.global open
open:
 li a7, SYS_open
 406:	48bd                	li	a7,15
 ecall
 408:	00000073          	ecall
 ret
 40c:	8082                	ret

000000000000040e <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 40e:	48c5                	li	a7,17
 ecall
 410:	00000073          	ecall
 ret
 414:	8082                	ret

0000000000000416 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 416:	48c9                	li	a7,18
 ecall
 418:	00000073          	ecall
 ret
 41c:	8082                	ret

000000000000041e <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 41e:	48a1                	li	a7,8
 ecall
 420:	00000073          	ecall
 ret
 424:	8082                	ret

0000000000000426 <link>:
.global link
link:
 li a7, SYS_link
 426:	48cd                	li	a7,19
 ecall
 428:	00000073          	ecall
 ret
 42c:	8082                	ret

000000000000042e <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 42e:	48d1                	li	a7,20
 ecall
 430:	00000073          	ecall
 ret
 434:	8082                	ret

0000000000000436 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 436:	48a5                	li	a7,9
 ecall
 438:	00000073          	ecall
 ret
 43c:	8082                	ret

000000000000043e <dup>:
.global dup
dup:
 li a7, SYS_dup
 43e:	48a9                	li	a7,10
 ecall
 440:	00000073          	ecall
 ret
 444:	8082                	ret

0000000000000446 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 446:	48ad                	li	a7,11
 ecall
 448:	00000073          	ecall
 ret
 44c:	8082                	ret

000000000000044e <sys_sbrk>:
.global sys_sbrk
sys_sbrk:
 li a7, SYS_sbrk
 44e:	48b1                	li	a7,12
 ecall
 450:	00000073          	ecall
 ret
 454:	8082                	ret

0000000000000456 <pause>:
.global pause
pause:
 li a7, SYS_pause
 456:	48b5                	li	a7,13
 ecall
 458:	00000073          	ecall
 ret
 45c:	8082                	ret

000000000000045e <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 45e:	48b9                	li	a7,14
 ecall
 460:	00000073          	ecall
 ret
 464:	8082                	ret

0000000000000466 <trace>:
.global trace
trace:
 li a7, SYS_trace
 466:	48d9                	li	a7,22
 ecall
 468:	00000073          	ecall
 ret
 46c:	8082                	ret

000000000000046e <setpriority>:
.global setpriority
setpriority:
 li a7, SYS_setpriority
 46e:	48dd                	li	a7,23
 ecall
 470:	00000073          	ecall
 ret
 474:	8082                	ret

0000000000000476 <getpriority>:
.global getpriority
getpriority:
 li a7, SYS_getpriority
 476:	48e1                	li	a7,24
 ecall
 478:	00000073          	ecall
 ret
 47c:	8082                	ret

000000000000047e <getmemstat>:
.global getmemstat
getmemstat:
 li a7, SYS_getmemstat
 47e:	48e5                	li	a7,25
 ecall
 480:	00000073          	ecall
 ret
 484:	8082                	ret

0000000000000486 <setmemquota>:
.global setmemquota
setmemquota:
 li a7, SYS_setmemquota
 486:	48e9                	li	a7,26
 ecall
 488:	00000073          	ecall
 ret
 48c:	8082                	ret

000000000000048e <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 48e:	1101                	addi	sp,sp,-32
 490:	ec06                	sd	ra,24(sp)
 492:	e822                	sd	s0,16(sp)
 494:	1000                	addi	s0,sp,32
 496:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 49a:	4605                	li	a2,1
 49c:	fef40593          	addi	a1,s0,-17
 4a0:	f47ff0ef          	jal	3e6 <write>
}
 4a4:	60e2                	ld	ra,24(sp)
 4a6:	6442                	ld	s0,16(sp)
 4a8:	6105                	addi	sp,sp,32
 4aa:	8082                	ret

00000000000004ac <printint>:

static void
printint(int fd, long long xx, int base, int sgn)
{
 4ac:	715d                	addi	sp,sp,-80
 4ae:	e486                	sd	ra,72(sp)
 4b0:	e0a2                	sd	s0,64(sp)
 4b2:	f84a                	sd	s2,48(sp)
 4b4:	0880                	addi	s0,sp,80
 4b6:	892a                	mv	s2,a0
  char buf[20];
  int i, neg;
  unsigned long long x;

  neg = 0;
  if(sgn && xx < 0){
 4b8:	c299                	beqz	a3,4be <printint+0x12>
 4ba:	0805c363          	bltz	a1,540 <printint+0x94>
  neg = 0;
 4be:	4881                	li	a7,0
 4c0:	fb840693          	addi	a3,s0,-72
    x = -xx;
  } else {
    x = xx;
  }

  i = 0;
 4c4:	4781                	li	a5,0
  do{
    buf[i++] = digits[x % base];
 4c6:	00000517          	auipc	a0,0x0
 4ca:	5d250513          	addi	a0,a0,1490 # a98 <digits>
 4ce:	883e                	mv	a6,a5
 4d0:	2785                	addiw	a5,a5,1
 4d2:	02c5f733          	remu	a4,a1,a2
 4d6:	972a                	add	a4,a4,a0
 4d8:	00074703          	lbu	a4,0(a4)
 4dc:	00e68023          	sb	a4,0(a3)
  }while((x /= base) != 0);
 4e0:	872e                	mv	a4,a1
 4e2:	02c5d5b3          	divu	a1,a1,a2
 4e6:	0685                	addi	a3,a3,1
 4e8:	fec773e3          	bgeu	a4,a2,4ce <printint+0x22>
  if(neg)
 4ec:	00088b63          	beqz	a7,502 <printint+0x56>
    buf[i++] = '-';
 4f0:	fd078793          	addi	a5,a5,-48
 4f4:	97a2                	add	a5,a5,s0
 4f6:	02d00713          	li	a4,45
 4fa:	fee78423          	sb	a4,-24(a5)
 4fe:	0028079b          	addiw	a5,a6,2

  while(--i >= 0)
 502:	02f05a63          	blez	a5,536 <printint+0x8a>
 506:	fc26                	sd	s1,56(sp)
 508:	f44e                	sd	s3,40(sp)
 50a:	fb840713          	addi	a4,s0,-72
 50e:	00f704b3          	add	s1,a4,a5
 512:	fff70993          	addi	s3,a4,-1
 516:	99be                	add	s3,s3,a5
 518:	37fd                	addiw	a5,a5,-1
 51a:	1782                	slli	a5,a5,0x20
 51c:	9381                	srli	a5,a5,0x20
 51e:	40f989b3          	sub	s3,s3,a5
    putc(fd, buf[i]);
 522:	fff4c583          	lbu	a1,-1(s1)
 526:	854a                	mv	a0,s2
 528:	f67ff0ef          	jal	48e <putc>
  while(--i >= 0)
 52c:	14fd                	addi	s1,s1,-1
 52e:	ff349ae3          	bne	s1,s3,522 <printint+0x76>
 532:	74e2                	ld	s1,56(sp)
 534:	79a2                	ld	s3,40(sp)
}
 536:	60a6                	ld	ra,72(sp)
 538:	6406                	ld	s0,64(sp)
 53a:	7942                	ld	s2,48(sp)
 53c:	6161                	addi	sp,sp,80
 53e:	8082                	ret
    x = -xx;
 540:	40b005b3          	neg	a1,a1
    neg = 1;
 544:	4885                	li	a7,1
    x = -xx;
 546:	bfad                	j	4c0 <printint+0x14>

0000000000000548 <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %c, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 548:	711d                	addi	sp,sp,-96
 54a:	ec86                	sd	ra,88(sp)
 54c:	e8a2                	sd	s0,80(sp)
 54e:	e0ca                	sd	s2,64(sp)
 550:	1080                	addi	s0,sp,96
  char *s;
  int c0, c1, c2, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 552:	0005c903          	lbu	s2,0(a1)
 556:	28090663          	beqz	s2,7e2 <vprintf+0x29a>
 55a:	e4a6                	sd	s1,72(sp)
 55c:	fc4e                	sd	s3,56(sp)
 55e:	f852                	sd	s4,48(sp)
 560:	f456                	sd	s5,40(sp)
 562:	f05a                	sd	s6,32(sp)
 564:	ec5e                	sd	s7,24(sp)
 566:	e862                	sd	s8,16(sp)
 568:	e466                	sd	s9,8(sp)
 56a:	8b2a                	mv	s6,a0
 56c:	8a2e                	mv	s4,a1
 56e:	8bb2                	mv	s7,a2
  state = 0;
 570:	4981                	li	s3,0
  for(i = 0; fmt[i]; i++){
 572:	4481                	li	s1,0
 574:	4701                	li	a4,0
      if(c0 == '%'){
        state = '%';
      } else {
        putc(fd, c0);
      }
    } else if(state == '%'){
 576:	02500a93          	li	s5,37
      c1 = c2 = 0;
      if(c0) c1 = fmt[i+1] & 0xff;
      if(c1) c2 = fmt[i+2] & 0xff;
      if(c0 == 'd'){
 57a:	06400c13          	li	s8,100
        printint(fd, va_arg(ap, int), 10, 1);
      } else if(c0 == 'l' && c1 == 'd'){
 57e:	06c00c93          	li	s9,108
 582:	a005                	j	5a2 <vprintf+0x5a>
        putc(fd, c0);
 584:	85ca                	mv	a1,s2
 586:	855a                	mv	a0,s6
 588:	f07ff0ef          	jal	48e <putc>
 58c:	a019                	j	592 <vprintf+0x4a>
    } else if(state == '%'){
 58e:	03598263          	beq	s3,s5,5b2 <vprintf+0x6a>
  for(i = 0; fmt[i]; i++){
 592:	2485                	addiw	s1,s1,1
 594:	8726                	mv	a4,s1
 596:	009a07b3          	add	a5,s4,s1
 59a:	0007c903          	lbu	s2,0(a5)
 59e:	22090a63          	beqz	s2,7d2 <vprintf+0x28a>
    c0 = fmt[i] & 0xff;
 5a2:	0009079b          	sext.w	a5,s2
    if(state == 0){
 5a6:	fe0994e3          	bnez	s3,58e <vprintf+0x46>
      if(c0 == '%'){
 5aa:	fd579de3          	bne	a5,s5,584 <vprintf+0x3c>
        state = '%';
 5ae:	89be                	mv	s3,a5
 5b0:	b7cd                	j	592 <vprintf+0x4a>
      if(c0) c1 = fmt[i+1] & 0xff;
 5b2:	00ea06b3          	add	a3,s4,a4
 5b6:	0016c683          	lbu	a3,1(a3)
      c1 = c2 = 0;
 5ba:	8636                	mv	a2,a3
      if(c1) c2 = fmt[i+2] & 0xff;
 5bc:	c681                	beqz	a3,5c4 <vprintf+0x7c>
 5be:	9752                	add	a4,a4,s4
 5c0:	00274603          	lbu	a2,2(a4)
      if(c0 == 'd'){
 5c4:	05878363          	beq	a5,s8,60a <vprintf+0xc2>
      } else if(c0 == 'l' && c1 == 'd'){
 5c8:	05978d63          	beq	a5,s9,622 <vprintf+0xda>
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 2;
      } else if(c0 == 'u'){
 5cc:	07500713          	li	a4,117
 5d0:	0ee78763          	beq	a5,a4,6be <vprintf+0x176>
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 2;
      } else if(c0 == 'x'){
 5d4:	07800713          	li	a4,120
 5d8:	12e78963          	beq	a5,a4,70a <vprintf+0x1c2>
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 2;
      } else if(c0 == 'p'){
 5dc:	07000713          	li	a4,112
 5e0:	14e78e63          	beq	a5,a4,73c <vprintf+0x1f4>
        printptr(fd, va_arg(ap, uint64));
      } else if(c0 == 'c'){
 5e4:	06300713          	li	a4,99
 5e8:	18e78e63          	beq	a5,a4,784 <vprintf+0x23c>
        putc(fd, va_arg(ap, uint32));
      } else if(c0 == 's'){
 5ec:	07300713          	li	a4,115
 5f0:	1ae78463          	beq	a5,a4,798 <vprintf+0x250>
        if((s = va_arg(ap, char*)) == 0)
          s = "(null)";
        for(; *s; s++)
          putc(fd, *s);
      } else if(c0 == '%'){
 5f4:	02500713          	li	a4,37
 5f8:	04e79563          	bne	a5,a4,642 <vprintf+0xfa>
        putc(fd, '%');
 5fc:	02500593          	li	a1,37
 600:	855a                	mv	a0,s6
 602:	e8dff0ef          	jal	48e <putc>
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c0);
      }

      state = 0;
 606:	4981                	li	s3,0
 608:	b769                	j	592 <vprintf+0x4a>
        printint(fd, va_arg(ap, int), 10, 1);
 60a:	008b8913          	addi	s2,s7,8
 60e:	4685                	li	a3,1
 610:	4629                	li	a2,10
 612:	000ba583          	lw	a1,0(s7)
 616:	855a                	mv	a0,s6
 618:	e95ff0ef          	jal	4ac <printint>
 61c:	8bca                	mv	s7,s2
      state = 0;
 61e:	4981                	li	s3,0
 620:	bf8d                	j	592 <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'd'){
 622:	06400793          	li	a5,100
 626:	02f68963          	beq	a3,a5,658 <vprintf+0x110>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 62a:	06c00793          	li	a5,108
 62e:	04f68263          	beq	a3,a5,672 <vprintf+0x12a>
      } else if(c0 == 'l' && c1 == 'u'){
 632:	07500793          	li	a5,117
 636:	0af68063          	beq	a3,a5,6d6 <vprintf+0x18e>
      } else if(c0 == 'l' && c1 == 'x'){
 63a:	07800793          	li	a5,120
 63e:	0ef68263          	beq	a3,a5,722 <vprintf+0x1da>
        putc(fd, '%');
 642:	02500593          	li	a1,37
 646:	855a                	mv	a0,s6
 648:	e47ff0ef          	jal	48e <putc>
        putc(fd, c0);
 64c:	85ca                	mv	a1,s2
 64e:	855a                	mv	a0,s6
 650:	e3fff0ef          	jal	48e <putc>
      state = 0;
 654:	4981                	li	s3,0
 656:	bf35                	j	592 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 658:	008b8913          	addi	s2,s7,8
 65c:	4685                	li	a3,1
 65e:	4629                	li	a2,10
 660:	000bb583          	ld	a1,0(s7)
 664:	855a                	mv	a0,s6
 666:	e47ff0ef          	jal	4ac <printint>
        i += 1;
 66a:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 1);
 66c:	8bca                	mv	s7,s2
      state = 0;
 66e:	4981                	li	s3,0
        i += 1;
 670:	b70d                	j	592 <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 672:	06400793          	li	a5,100
 676:	02f60763          	beq	a2,a5,6a4 <vprintf+0x15c>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
 67a:	07500793          	li	a5,117
 67e:	06f60963          	beq	a2,a5,6f0 <vprintf+0x1a8>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
 682:	07800793          	li	a5,120
 686:	faf61ee3          	bne	a2,a5,642 <vprintf+0xfa>
        printint(fd, va_arg(ap, uint64), 16, 0);
 68a:	008b8913          	addi	s2,s7,8
 68e:	4681                	li	a3,0
 690:	4641                	li	a2,16
 692:	000bb583          	ld	a1,0(s7)
 696:	855a                	mv	a0,s6
 698:	e15ff0ef          	jal	4ac <printint>
        i += 2;
 69c:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 16, 0);
 69e:	8bca                	mv	s7,s2
      state = 0;
 6a0:	4981                	li	s3,0
        i += 2;
 6a2:	bdc5                	j	592 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 6a4:	008b8913          	addi	s2,s7,8
 6a8:	4685                	li	a3,1
 6aa:	4629                	li	a2,10
 6ac:	000bb583          	ld	a1,0(s7)
 6b0:	855a                	mv	a0,s6
 6b2:	dfbff0ef          	jal	4ac <printint>
        i += 2;
 6b6:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 1);
 6b8:	8bca                	mv	s7,s2
      state = 0;
 6ba:	4981                	li	s3,0
        i += 2;
 6bc:	bdd9                	j	592 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 10, 0);
 6be:	008b8913          	addi	s2,s7,8
 6c2:	4681                	li	a3,0
 6c4:	4629                	li	a2,10
 6c6:	000be583          	lwu	a1,0(s7)
 6ca:	855a                	mv	a0,s6
 6cc:	de1ff0ef          	jal	4ac <printint>
 6d0:	8bca                	mv	s7,s2
      state = 0;
 6d2:	4981                	li	s3,0
 6d4:	bd7d                	j	592 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 6d6:	008b8913          	addi	s2,s7,8
 6da:	4681                	li	a3,0
 6dc:	4629                	li	a2,10
 6de:	000bb583          	ld	a1,0(s7)
 6e2:	855a                	mv	a0,s6
 6e4:	dc9ff0ef          	jal	4ac <printint>
        i += 1;
 6e8:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 0);
 6ea:	8bca                	mv	s7,s2
      state = 0;
 6ec:	4981                	li	s3,0
        i += 1;
 6ee:	b555                	j	592 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 6f0:	008b8913          	addi	s2,s7,8
 6f4:	4681                	li	a3,0
 6f6:	4629                	li	a2,10
 6f8:	000bb583          	ld	a1,0(s7)
 6fc:	855a                	mv	a0,s6
 6fe:	dafff0ef          	jal	4ac <printint>
        i += 2;
 702:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 0);
 704:	8bca                	mv	s7,s2
      state = 0;
 706:	4981                	li	s3,0
        i += 2;
 708:	b569                	j	592 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 16, 0);
 70a:	008b8913          	addi	s2,s7,8
 70e:	4681                	li	a3,0
 710:	4641                	li	a2,16
 712:	000be583          	lwu	a1,0(s7)
 716:	855a                	mv	a0,s6
 718:	d95ff0ef          	jal	4ac <printint>
 71c:	8bca                	mv	s7,s2
      state = 0;
 71e:	4981                	li	s3,0
 720:	bd8d                	j	592 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 16, 0);
 722:	008b8913          	addi	s2,s7,8
 726:	4681                	li	a3,0
 728:	4641                	li	a2,16
 72a:	000bb583          	ld	a1,0(s7)
 72e:	855a                	mv	a0,s6
 730:	d7dff0ef          	jal	4ac <printint>
        i += 1;
 734:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 16, 0);
 736:	8bca                	mv	s7,s2
      state = 0;
 738:	4981                	li	s3,0
        i += 1;
 73a:	bda1                	j	592 <vprintf+0x4a>
 73c:	e06a                	sd	s10,0(sp)
        printptr(fd, va_arg(ap, uint64));
 73e:	008b8d13          	addi	s10,s7,8
 742:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 746:	03000593          	li	a1,48
 74a:	855a                	mv	a0,s6
 74c:	d43ff0ef          	jal	48e <putc>
  putc(fd, 'x');
 750:	07800593          	li	a1,120
 754:	855a                	mv	a0,s6
 756:	d39ff0ef          	jal	48e <putc>
 75a:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 75c:	00000b97          	auipc	s7,0x0
 760:	33cb8b93          	addi	s7,s7,828 # a98 <digits>
 764:	03c9d793          	srli	a5,s3,0x3c
 768:	97de                	add	a5,a5,s7
 76a:	0007c583          	lbu	a1,0(a5)
 76e:	855a                	mv	a0,s6
 770:	d1fff0ef          	jal	48e <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 774:	0992                	slli	s3,s3,0x4
 776:	397d                	addiw	s2,s2,-1
 778:	fe0916e3          	bnez	s2,764 <vprintf+0x21c>
        printptr(fd, va_arg(ap, uint64));
 77c:	8bea                	mv	s7,s10
      state = 0;
 77e:	4981                	li	s3,0
 780:	6d02                	ld	s10,0(sp)
 782:	bd01                	j	592 <vprintf+0x4a>
        putc(fd, va_arg(ap, uint32));
 784:	008b8913          	addi	s2,s7,8
 788:	000bc583          	lbu	a1,0(s7)
 78c:	855a                	mv	a0,s6
 78e:	d01ff0ef          	jal	48e <putc>
 792:	8bca                	mv	s7,s2
      state = 0;
 794:	4981                	li	s3,0
 796:	bbf5                	j	592 <vprintf+0x4a>
        if((s = va_arg(ap, char*)) == 0)
 798:	008b8993          	addi	s3,s7,8
 79c:	000bb903          	ld	s2,0(s7)
 7a0:	00090f63          	beqz	s2,7be <vprintf+0x276>
        for(; *s; s++)
 7a4:	00094583          	lbu	a1,0(s2)
 7a8:	c195                	beqz	a1,7cc <vprintf+0x284>
          putc(fd, *s);
 7aa:	855a                	mv	a0,s6
 7ac:	ce3ff0ef          	jal	48e <putc>
        for(; *s; s++)
 7b0:	0905                	addi	s2,s2,1
 7b2:	00094583          	lbu	a1,0(s2)
 7b6:	f9f5                	bnez	a1,7aa <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 7b8:	8bce                	mv	s7,s3
      state = 0;
 7ba:	4981                	li	s3,0
 7bc:	bbd9                	j	592 <vprintf+0x4a>
          s = "(null)";
 7be:	00000917          	auipc	s2,0x0
 7c2:	2d290913          	addi	s2,s2,722 # a90 <malloc+0x1c6>
        for(; *s; s++)
 7c6:	02800593          	li	a1,40
 7ca:	b7c5                	j	7aa <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 7cc:	8bce                	mv	s7,s3
      state = 0;
 7ce:	4981                	li	s3,0
 7d0:	b3c9                	j	592 <vprintf+0x4a>
 7d2:	64a6                	ld	s1,72(sp)
 7d4:	79e2                	ld	s3,56(sp)
 7d6:	7a42                	ld	s4,48(sp)
 7d8:	7aa2                	ld	s5,40(sp)
 7da:	7b02                	ld	s6,32(sp)
 7dc:	6be2                	ld	s7,24(sp)
 7de:	6c42                	ld	s8,16(sp)
 7e0:	6ca2                	ld	s9,8(sp)
    }
  }
}
 7e2:	60e6                	ld	ra,88(sp)
 7e4:	6446                	ld	s0,80(sp)
 7e6:	6906                	ld	s2,64(sp)
 7e8:	6125                	addi	sp,sp,96
 7ea:	8082                	ret

00000000000007ec <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 7ec:	715d                	addi	sp,sp,-80
 7ee:	ec06                	sd	ra,24(sp)
 7f0:	e822                	sd	s0,16(sp)
 7f2:	1000                	addi	s0,sp,32
 7f4:	e010                	sd	a2,0(s0)
 7f6:	e414                	sd	a3,8(s0)
 7f8:	e818                	sd	a4,16(s0)
 7fa:	ec1c                	sd	a5,24(s0)
 7fc:	03043023          	sd	a6,32(s0)
 800:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 804:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 808:	8622                	mv	a2,s0
 80a:	d3fff0ef          	jal	548 <vprintf>
}
 80e:	60e2                	ld	ra,24(sp)
 810:	6442                	ld	s0,16(sp)
 812:	6161                	addi	sp,sp,80
 814:	8082                	ret

0000000000000816 <printf>:

void
printf(const char *fmt, ...)
{
 816:	711d                	addi	sp,sp,-96
 818:	ec06                	sd	ra,24(sp)
 81a:	e822                	sd	s0,16(sp)
 81c:	1000                	addi	s0,sp,32
 81e:	e40c                	sd	a1,8(s0)
 820:	e810                	sd	a2,16(s0)
 822:	ec14                	sd	a3,24(s0)
 824:	f018                	sd	a4,32(s0)
 826:	f41c                	sd	a5,40(s0)
 828:	03043823          	sd	a6,48(s0)
 82c:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 830:	00840613          	addi	a2,s0,8
 834:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 838:	85aa                	mv	a1,a0
 83a:	4505                	li	a0,1
 83c:	d0dff0ef          	jal	548 <vprintf>
}
 840:	60e2                	ld	ra,24(sp)
 842:	6442                	ld	s0,16(sp)
 844:	6125                	addi	sp,sp,96
 846:	8082                	ret

0000000000000848 <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 848:	1141                	addi	sp,sp,-16
 84a:	e422                	sd	s0,8(sp)
 84c:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 84e:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 852:	00000797          	auipc	a5,0x0
 856:	7ae7b783          	ld	a5,1966(a5) # 1000 <freep>
 85a:	a02d                	j	884 <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 85c:	4618                	lw	a4,8(a2)
 85e:	9f2d                	addw	a4,a4,a1
 860:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 864:	6398                	ld	a4,0(a5)
 866:	6310                	ld	a2,0(a4)
 868:	a83d                	j	8a6 <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 86a:	ff852703          	lw	a4,-8(a0)
 86e:	9f31                	addw	a4,a4,a2
 870:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 872:	ff053683          	ld	a3,-16(a0)
 876:	a091                	j	8ba <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 878:	6398                	ld	a4,0(a5)
 87a:	00e7e463          	bltu	a5,a4,882 <free+0x3a>
 87e:	00e6ea63          	bltu	a3,a4,892 <free+0x4a>
{
 882:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 884:	fed7fae3          	bgeu	a5,a3,878 <free+0x30>
 888:	6398                	ld	a4,0(a5)
 88a:	00e6e463          	bltu	a3,a4,892 <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 88e:	fee7eae3          	bltu	a5,a4,882 <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 892:	ff852583          	lw	a1,-8(a0)
 896:	6390                	ld	a2,0(a5)
 898:	02059813          	slli	a6,a1,0x20
 89c:	01c85713          	srli	a4,a6,0x1c
 8a0:	9736                	add	a4,a4,a3
 8a2:	fae60de3          	beq	a2,a4,85c <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 8a6:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 8aa:	4790                	lw	a2,8(a5)
 8ac:	02061593          	slli	a1,a2,0x20
 8b0:	01c5d713          	srli	a4,a1,0x1c
 8b4:	973e                	add	a4,a4,a5
 8b6:	fae68ae3          	beq	a3,a4,86a <free+0x22>
    p->s.ptr = bp->s.ptr;
 8ba:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 8bc:	00000717          	auipc	a4,0x0
 8c0:	74f73223          	sd	a5,1860(a4) # 1000 <freep>
}
 8c4:	6422                	ld	s0,8(sp)
 8c6:	0141                	addi	sp,sp,16
 8c8:	8082                	ret

00000000000008ca <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 8ca:	7139                	addi	sp,sp,-64
 8cc:	fc06                	sd	ra,56(sp)
 8ce:	f822                	sd	s0,48(sp)
 8d0:	f426                	sd	s1,40(sp)
 8d2:	ec4e                	sd	s3,24(sp)
 8d4:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 8d6:	02051493          	slli	s1,a0,0x20
 8da:	9081                	srli	s1,s1,0x20
 8dc:	04bd                	addi	s1,s1,15
 8de:	8091                	srli	s1,s1,0x4
 8e0:	0014899b          	addiw	s3,s1,1
 8e4:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 8e6:	00000517          	auipc	a0,0x0
 8ea:	71a53503          	ld	a0,1818(a0) # 1000 <freep>
 8ee:	c915                	beqz	a0,922 <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 8f0:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 8f2:	4798                	lw	a4,8(a5)
 8f4:	08977a63          	bgeu	a4,s1,988 <malloc+0xbe>
 8f8:	f04a                	sd	s2,32(sp)
 8fa:	e852                	sd	s4,16(sp)
 8fc:	e456                	sd	s5,8(sp)
 8fe:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 900:	8a4e                	mv	s4,s3
 902:	0009871b          	sext.w	a4,s3
 906:	6685                	lui	a3,0x1
 908:	00d77363          	bgeu	a4,a3,90e <malloc+0x44>
 90c:	6a05                	lui	s4,0x1
 90e:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 912:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 916:	00000917          	auipc	s2,0x0
 91a:	6ea90913          	addi	s2,s2,1770 # 1000 <freep>
  if(p == SBRK_ERROR)
 91e:	5afd                	li	s5,-1
 920:	a081                	j	960 <malloc+0x96>
 922:	f04a                	sd	s2,32(sp)
 924:	e852                	sd	s4,16(sp)
 926:	e456                	sd	s5,8(sp)
 928:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 92a:	00000797          	auipc	a5,0x0
 92e:	6e678793          	addi	a5,a5,1766 # 1010 <base>
 932:	00000717          	auipc	a4,0x0
 936:	6cf73723          	sd	a5,1742(a4) # 1000 <freep>
 93a:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 93c:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 940:	b7c1                	j	900 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 942:	6398                	ld	a4,0(a5)
 944:	e118                	sd	a4,0(a0)
 946:	a8a9                	j	9a0 <malloc+0xd6>
  hp->s.size = nu;
 948:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 94c:	0541                	addi	a0,a0,16
 94e:	efbff0ef          	jal	848 <free>
  return freep;
 952:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 956:	c12d                	beqz	a0,9b8 <malloc+0xee>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 958:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 95a:	4798                	lw	a4,8(a5)
 95c:	02977263          	bgeu	a4,s1,980 <malloc+0xb6>
    if(p == freep)
 960:	00093703          	ld	a4,0(s2)
 964:	853e                	mv	a0,a5
 966:	fef719e3          	bne	a4,a5,958 <malloc+0x8e>
  p = sbrk(nu * sizeof(Header));
 96a:	8552                	mv	a0,s4
 96c:	a27ff0ef          	jal	392 <sbrk>
  if(p == SBRK_ERROR)
 970:	fd551ce3          	bne	a0,s5,948 <malloc+0x7e>
        return 0;
 974:	4501                	li	a0,0
 976:	7902                	ld	s2,32(sp)
 978:	6a42                	ld	s4,16(sp)
 97a:	6aa2                	ld	s5,8(sp)
 97c:	6b02                	ld	s6,0(sp)
 97e:	a03d                	j	9ac <malloc+0xe2>
 980:	7902                	ld	s2,32(sp)
 982:	6a42                	ld	s4,16(sp)
 984:	6aa2                	ld	s5,8(sp)
 986:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 988:	fae48de3          	beq	s1,a4,942 <malloc+0x78>
        p->s.size -= nunits;
 98c:	4137073b          	subw	a4,a4,s3
 990:	c798                	sw	a4,8(a5)
        p += p->s.size;
 992:	02071693          	slli	a3,a4,0x20
 996:	01c6d713          	srli	a4,a3,0x1c
 99a:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 99c:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 9a0:	00000717          	auipc	a4,0x0
 9a4:	66a73023          	sd	a0,1632(a4) # 1000 <freep>
      return (void*)(p + 1);
 9a8:	01078513          	addi	a0,a5,16
  }
}
 9ac:	70e2                	ld	ra,56(sp)
 9ae:	7442                	ld	s0,48(sp)
 9b0:	74a2                	ld	s1,40(sp)
 9b2:	69e2                	ld	s3,24(sp)
 9b4:	6121                	addi	sp,sp,64
 9b6:	8082                	ret
 9b8:	7902                	ld	s2,32(sp)
 9ba:	6a42                	ld	s4,16(sp)
 9bc:	6aa2                	ld	s5,8(sp)
 9be:	6b02                	ld	s6,0(sp)
 9c0:	b7f5                	j	9ac <malloc+0xe2>
