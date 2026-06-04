
user/_trace_test:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <test_trace_fork>:
#include "kernel/syscall.h"
#include "user/user.h"

void
test_trace_fork(void)
{
   0:	1141                	addi	sp,sp,-16
   2:	e406                	sd	ra,8(sp)
   4:	e022                	sd	s0,0(sp)
   6:	0800                	addi	s0,sp,16
  int pid;

  printf("=== Test 1: trace fork ===\n");
   8:	00001517          	auipc	a0,0x1
   c:	b4850513          	addi	a0,a0,-1208 # b50 <malloc+0x100>
  10:	18d000ef          	jal	99c <printf>
  trace(1 << SYS_fork);
  14:	4509                	li	a0,2
  16:	5d6000ef          	jal	5ec <trace>
  pid = fork();
  1a:	52a000ef          	jal	544 <fork>
  if(pid < 0){
  1e:	02054363          	bltz	a0,44 <test_trace_fork+0x44>
    printf("test_trace_fork: fork failed\n");
    exit(1);
  }
  if(pid == 0){
  22:	c915                	beqz	a0,56 <test_trace_fork+0x56>
    exit(0);
  } else {
    wait(0);
  24:	4501                	li	a0,0
  26:	52e000ef          	jal	554 <wait>
  }
  trace(0);
  2a:	4501                	li	a0,0
  2c:	5c0000ef          	jal	5ec <trace>
  printf("Test 1 PASSED\n\n");
  30:	00001517          	auipc	a0,0x1
  34:	b6050513          	addi	a0,a0,-1184 # b90 <malloc+0x140>
  38:	165000ef          	jal	99c <printf>
}
  3c:	60a2                	ld	ra,8(sp)
  3e:	6402                	ld	s0,0(sp)
  40:	0141                	addi	sp,sp,16
  42:	8082                	ret
    printf("test_trace_fork: fork failed\n");
  44:	00001517          	auipc	a0,0x1
  48:	b2c50513          	addi	a0,a0,-1236 # b70 <malloc+0x120>
  4c:	151000ef          	jal	99c <printf>
    exit(1);
  50:	4505                	li	a0,1
  52:	4fa000ef          	jal	54c <exit>
    exit(0);
  56:	4f6000ef          	jal	54c <exit>

000000000000005a <test_trace_rw>:

void
test_trace_rw(void)
{
  5a:	1101                	addi	sp,sp,-32
  5c:	ec06                	sd	ra,24(sp)
  5e:	e822                	sd	s0,16(sp)
  60:	1000                	addi	s0,sp,32
  int fds[2];
  char buf[8];

  printf("=== Test 2: trace read/write ===\n");
  62:	00001517          	auipc	a0,0x1
  66:	b3e50513          	addi	a0,a0,-1218 # ba0 <malloc+0x150>
  6a:	133000ef          	jal	99c <printf>
  trace((1 << SYS_read) | (1 << SYS_write));
  6e:	6541                	lui	a0,0x10
  70:	02050513          	addi	a0,a0,32 # 10020 <base+0xe010>
  74:	578000ef          	jal	5ec <trace>

  if(pipe(fds) < 0){
  78:	fe840513          	addi	a0,s0,-24
  7c:	4e0000ef          	jal	55c <pipe>
  80:	04054763          	bltz	a0,ce <test_trace_rw+0x74>
    printf("test_trace_rw: pipe failed\n");
    exit(1);
  }

  write(fds[1], "hello", 5);
  84:	4615                	li	a2,5
  86:	00001597          	auipc	a1,0x1
  8a:	b6258593          	addi	a1,a1,-1182 # be8 <malloc+0x198>
  8e:	fec42503          	lw	a0,-20(s0)
  92:	4da000ef          	jal	56c <write>
  read(fds[0], buf, 5);
  96:	4615                	li	a2,5
  98:	fe040593          	addi	a1,s0,-32
  9c:	fe842503          	lw	a0,-24(s0)
  a0:	4c4000ef          	jal	564 <read>

  close(fds[0]);
  a4:	fe842503          	lw	a0,-24(s0)
  a8:	4cc000ef          	jal	574 <close>
  close(fds[1]);
  ac:	fec42503          	lw	a0,-20(s0)
  b0:	4c4000ef          	jal	574 <close>

  trace(0);
  b4:	4501                	li	a0,0
  b6:	536000ef          	jal	5ec <trace>
  printf("Test 2 PASSED\n\n");
  ba:	00001517          	auipc	a0,0x1
  be:	b3650513          	addi	a0,a0,-1226 # bf0 <malloc+0x1a0>
  c2:	0db000ef          	jal	99c <printf>
}
  c6:	60e2                	ld	ra,24(sp)
  c8:	6442                	ld	s0,16(sp)
  ca:	6105                	addi	sp,sp,32
  cc:	8082                	ret
    printf("test_trace_rw: pipe failed\n");
  ce:	00001517          	auipc	a0,0x1
  d2:	afa50513          	addi	a0,a0,-1286 # bc8 <malloc+0x178>
  d6:	0c7000ef          	jal	99c <printf>
    exit(1);
  da:	4505                	li	a0,1
  dc:	470000ef          	jal	54c <exit>

00000000000000e0 <test_trace_multi>:

void
test_trace_multi(void)
{
  e0:	1141                	addi	sp,sp,-16
  e2:	e406                	sd	ra,8(sp)
  e4:	e022                	sd	s0,0(sp)
  e6:	0800                	addi	s0,sp,16
  int pid;

  printf("=== Test 3: trace multiple syscalls ===\n");
  e8:	00001517          	auipc	a0,0x1
  ec:	b1850513          	addi	a0,a0,-1256 # c00 <malloc+0x1b0>
  f0:	0ad000ef          	jal	99c <printf>
  trace((1 << SYS_getpid) | (1 << SYS_fork) | (1 << SYS_write));
  f4:	6545                	lui	a0,0x11
  f6:	80250513          	addi	a0,a0,-2046 # 10802 <base+0xe7f2>
  fa:	4f2000ef          	jal	5ec <trace>

  pid = getpid();
  fe:	4ce000ef          	jal	5cc <getpid>
 102:	85aa                	mv	a1,a0
  printf("my pid is %d\n", pid);
 104:	00001517          	auipc	a0,0x1
 108:	b2c50513          	addi	a0,a0,-1236 # c30 <malloc+0x1e0>
 10c:	091000ef          	jal	99c <printf>

  pid = fork();
 110:	434000ef          	jal	544 <fork>
  if(pid < 0){
 114:	02054363          	bltz	a0,13a <test_trace_multi+0x5a>
    printf("test_trace_multi: fork failed\n");
    exit(1);
  }
  if(pid == 0){
 118:	c915                	beqz	a0,14c <test_trace_multi+0x6c>
    exit(0);
  } else {
    wait(0);
 11a:	4501                	li	a0,0
 11c:	438000ef          	jal	554 <wait>
  }

  trace(0);
 120:	4501                	li	a0,0
 122:	4ca000ef          	jal	5ec <trace>
  printf("Test 3 PASSED\n\n");
 126:	00001517          	auipc	a0,0x1
 12a:	b3a50513          	addi	a0,a0,-1222 # c60 <malloc+0x210>
 12e:	06f000ef          	jal	99c <printf>
}
 132:	60a2                	ld	ra,8(sp)
 134:	6402                	ld	s0,0(sp)
 136:	0141                	addi	sp,sp,16
 138:	8082                	ret
    printf("test_trace_multi: fork failed\n");
 13a:	00001517          	auipc	a0,0x1
 13e:	b0650513          	addi	a0,a0,-1274 # c40 <malloc+0x1f0>
 142:	05b000ef          	jal	99c <printf>
    exit(1);
 146:	4505                	li	a0,1
 148:	404000ef          	jal	54c <exit>
    exit(0);
 14c:	400000ef          	jal	54c <exit>

0000000000000150 <test_trace_inherit>:

void
test_trace_inherit(void)
{
 150:	1101                	addi	sp,sp,-32
 152:	ec06                	sd	ra,24(sp)
 154:	e822                	sd	s0,16(sp)
 156:	1000                	addi	s0,sp,32
  int pid;
  int fds[2];
  char buf[8];

  printf("=== Test 4: trace inheritance ===\n");
 158:	00001517          	auipc	a0,0x1
 15c:	b1850513          	addi	a0,a0,-1256 # c70 <malloc+0x220>
 160:	03d000ef          	jal	99c <printf>
  trace((1 << SYS_read) | (1 << SYS_write));
 164:	6541                	lui	a0,0x10
 166:	02050513          	addi	a0,a0,32 # 10020 <base+0xe010>
 16a:	482000ef          	jal	5ec <trace>

  if(pipe(fds) < 0){
 16e:	fe840513          	addi	a0,s0,-24
 172:	3ea000ef          	jal	55c <pipe>
 176:	04054663          	bltz	a0,1c2 <test_trace_inherit+0x72>
    printf("test_trace_inherit: pipe failed\n");
    exit(1);
  }

  pid = fork();
 17a:	3ca000ef          	jal	544 <fork>
  if(pid < 0){
 17e:	04054b63          	bltz	a0,1d4 <test_trace_inherit+0x84>
    printf("test_trace_inherit: fork failed\n");
    exit(1);
  }

  if(pid == 0){
 182:	c135                	beqz	a0,1e6 <test_trace_inherit+0x96>
    write(fds[1], "hi", 2);
    close(fds[0]);
    close(fds[1]);
    exit(0);
  } else {
    read(fds[0], buf, 2);
 184:	4609                	li	a2,2
 186:	fe040593          	addi	a1,s0,-32
 18a:	fe842503          	lw	a0,-24(s0)
 18e:	3d6000ef          	jal	564 <read>
    close(fds[0]);
 192:	fe842503          	lw	a0,-24(s0)
 196:	3de000ef          	jal	574 <close>
    close(fds[1]);
 19a:	fec42503          	lw	a0,-20(s0)
 19e:	3d6000ef          	jal	574 <close>
    wait(0);
 1a2:	4501                	li	a0,0
 1a4:	3b0000ef          	jal	554 <wait>
  }

  trace(0);
 1a8:	4501                	li	a0,0
 1aa:	442000ef          	jal	5ec <trace>
  printf("Test 4 PASSED\n\n");
 1ae:	00001517          	auipc	a0,0x1
 1b2:	b4250513          	addi	a0,a0,-1214 # cf0 <malloc+0x2a0>
 1b6:	7e6000ef          	jal	99c <printf>
}
 1ba:	60e2                	ld	ra,24(sp)
 1bc:	6442                	ld	s0,16(sp)
 1be:	6105                	addi	sp,sp,32
 1c0:	8082                	ret
    printf("test_trace_inherit: pipe failed\n");
 1c2:	00001517          	auipc	a0,0x1
 1c6:	ad650513          	addi	a0,a0,-1322 # c98 <malloc+0x248>
 1ca:	7d2000ef          	jal	99c <printf>
    exit(1);
 1ce:	4505                	li	a0,1
 1d0:	37c000ef          	jal	54c <exit>
    printf("test_trace_inherit: fork failed\n");
 1d4:	00001517          	auipc	a0,0x1
 1d8:	aec50513          	addi	a0,a0,-1300 # cc0 <malloc+0x270>
 1dc:	7c0000ef          	jal	99c <printf>
    exit(1);
 1e0:	4505                	li	a0,1
 1e2:	36a000ef          	jal	54c <exit>
    write(fds[1], "hi", 2);
 1e6:	4609                	li	a2,2
 1e8:	00001597          	auipc	a1,0x1
 1ec:	b0058593          	addi	a1,a1,-1280 # ce8 <malloc+0x298>
 1f0:	fec42503          	lw	a0,-20(s0)
 1f4:	378000ef          	jal	56c <write>
    close(fds[0]);
 1f8:	fe842503          	lw	a0,-24(s0)
 1fc:	378000ef          	jal	574 <close>
    close(fds[1]);
 200:	fec42503          	lw	a0,-20(s0)
 204:	370000ef          	jal	574 <close>
    exit(0);
 208:	4501                	li	a0,0
 20a:	342000ef          	jal	54c <exit>

000000000000020e <test_trace_none>:

void
test_trace_none(void)
{
 20e:	1141                	addi	sp,sp,-16
 210:	e406                	sd	ra,8(sp)
 212:	e022                	sd	s0,0(sp)
 214:	0800                	addi	s0,sp,16
  int pid;

  printf("=== Test 5: trace disabled ===\n");
 216:	00001517          	auipc	a0,0x1
 21a:	aea50513          	addi	a0,a0,-1302 # d00 <malloc+0x2b0>
 21e:	77e000ef          	jal	99c <printf>
  trace(0);
 222:	4501                	li	a0,0
 224:	3c8000ef          	jal	5ec <trace>

  getpid();
 228:	3a4000ef          	jal	5cc <getpid>
  pid = fork();
 22c:	318000ef          	jal	544 <fork>
  if(pid < 0){
 230:	02054063          	bltz	a0,250 <test_trace_none+0x42>
    printf("test_trace_none: fork failed\n");
    exit(1);
  }
  if(pid == 0){
 234:	c51d                	beqz	a0,262 <test_trace_none+0x54>
    exit(0);
  }
  wait(0);
 236:	4501                	li	a0,0
 238:	31c000ef          	jal	554 <wait>

  printf("Test 5 PASSED (no trace output above means success)\n\n");
 23c:	00001517          	auipc	a0,0x1
 240:	b0450513          	addi	a0,a0,-1276 # d40 <malloc+0x2f0>
 244:	758000ef          	jal	99c <printf>
}
 248:	60a2                	ld	ra,8(sp)
 24a:	6402                	ld	s0,0(sp)
 24c:	0141                	addi	sp,sp,16
 24e:	8082                	ret
    printf("test_trace_none: fork failed\n");
 250:	00001517          	auipc	a0,0x1
 254:	ad050513          	addi	a0,a0,-1328 # d20 <malloc+0x2d0>
 258:	744000ef          	jal	99c <printf>
    exit(1);
 25c:	4505                	li	a0,1
 25e:	2ee000ef          	jal	54c <exit>
    exit(0);
 262:	2ea000ef          	jal	54c <exit>

0000000000000266 <main>:

int
main(int argc, char *argv[])
{
 266:	1141                	addi	sp,sp,-16
 268:	e406                	sd	ra,8(sp)
 26a:	e022                	sd	s0,0(sp)
 26c:	0800                	addi	s0,sp,16
  printf("========================================\n");
 26e:	00001517          	auipc	a0,0x1
 272:	b0a50513          	addi	a0,a0,-1270 # d78 <malloc+0x328>
 276:	726000ef          	jal	99c <printf>
  printf("  trace system call test suite\n");
 27a:	00001517          	auipc	a0,0x1
 27e:	b2e50513          	addi	a0,a0,-1234 # da8 <malloc+0x358>
 282:	71a000ef          	jal	99c <printf>
  printf("========================================\n\n");
 286:	00001517          	auipc	a0,0x1
 28a:	b4250513          	addi	a0,a0,-1214 # dc8 <malloc+0x378>
 28e:	70e000ef          	jal	99c <printf>

  test_trace_fork();
 292:	d6fff0ef          	jal	0 <test_trace_fork>
  test_trace_rw();
 296:	dc5ff0ef          	jal	5a <test_trace_rw>
  test_trace_multi();
 29a:	e47ff0ef          	jal	e0 <test_trace_multi>
  test_trace_inherit();
 29e:	eb3ff0ef          	jal	150 <test_trace_inherit>
  test_trace_none();
 2a2:	f6dff0ef          	jal	20e <test_trace_none>

  printf("All tests passed!\n");
 2a6:	00001517          	auipc	a0,0x1
 2aa:	b5250513          	addi	a0,a0,-1198 # df8 <malloc+0x3a8>
 2ae:	6ee000ef          	jal	99c <printf>
  exit(0);
 2b2:	4501                	li	a0,0
 2b4:	298000ef          	jal	54c <exit>

00000000000002b8 <start>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
start(int argc, char **argv)
{
 2b8:	1141                	addi	sp,sp,-16
 2ba:	e406                	sd	ra,8(sp)
 2bc:	e022                	sd	s0,0(sp)
 2be:	0800                	addi	s0,sp,16
  int r;
  extern int main(int argc, char **argv);
  r = main(argc, argv);
 2c0:	fa7ff0ef          	jal	266 <main>
  exit(r);
 2c4:	288000ef          	jal	54c <exit>

00000000000002c8 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 2c8:	1141                	addi	sp,sp,-16
 2ca:	e422                	sd	s0,8(sp)
 2cc:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 2ce:	87aa                	mv	a5,a0
 2d0:	0585                	addi	a1,a1,1
 2d2:	0785                	addi	a5,a5,1
 2d4:	fff5c703          	lbu	a4,-1(a1)
 2d8:	fee78fa3          	sb	a4,-1(a5)
 2dc:	fb75                	bnez	a4,2d0 <strcpy+0x8>
    ;
  return os;
}
 2de:	6422                	ld	s0,8(sp)
 2e0:	0141                	addi	sp,sp,16
 2e2:	8082                	ret

00000000000002e4 <strcmp>:

int
strcmp(const char *p, const char *q)
{
 2e4:	1141                	addi	sp,sp,-16
 2e6:	e422                	sd	s0,8(sp)
 2e8:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 2ea:	00054783          	lbu	a5,0(a0)
 2ee:	cb91                	beqz	a5,302 <strcmp+0x1e>
 2f0:	0005c703          	lbu	a4,0(a1)
 2f4:	00f71763          	bne	a4,a5,302 <strcmp+0x1e>
    p++, q++;
 2f8:	0505                	addi	a0,a0,1
 2fa:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 2fc:	00054783          	lbu	a5,0(a0)
 300:	fbe5                	bnez	a5,2f0 <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 302:	0005c503          	lbu	a0,0(a1)
}
 306:	40a7853b          	subw	a0,a5,a0
 30a:	6422                	ld	s0,8(sp)
 30c:	0141                	addi	sp,sp,16
 30e:	8082                	ret

0000000000000310 <strlen>:

uint
strlen(const char *s)
{
 310:	1141                	addi	sp,sp,-16
 312:	e422                	sd	s0,8(sp)
 314:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 316:	00054783          	lbu	a5,0(a0)
 31a:	cf91                	beqz	a5,336 <strlen+0x26>
 31c:	0505                	addi	a0,a0,1
 31e:	87aa                	mv	a5,a0
 320:	86be                	mv	a3,a5
 322:	0785                	addi	a5,a5,1
 324:	fff7c703          	lbu	a4,-1(a5)
 328:	ff65                	bnez	a4,320 <strlen+0x10>
 32a:	40a6853b          	subw	a0,a3,a0
 32e:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 330:	6422                	ld	s0,8(sp)
 332:	0141                	addi	sp,sp,16
 334:	8082                	ret
  for(n = 0; s[n]; n++)
 336:	4501                	li	a0,0
 338:	bfe5                	j	330 <strlen+0x20>

000000000000033a <memset>:

void*
memset(void *dst, int c, uint n)
{
 33a:	1141                	addi	sp,sp,-16
 33c:	e422                	sd	s0,8(sp)
 33e:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 340:	ca19                	beqz	a2,356 <memset+0x1c>
 342:	87aa                	mv	a5,a0
 344:	1602                	slli	a2,a2,0x20
 346:	9201                	srli	a2,a2,0x20
 348:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 34c:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 350:	0785                	addi	a5,a5,1
 352:	fee79de3          	bne	a5,a4,34c <memset+0x12>
  }
  return dst;
}
 356:	6422                	ld	s0,8(sp)
 358:	0141                	addi	sp,sp,16
 35a:	8082                	ret

000000000000035c <strchr>:

char*
strchr(const char *s, char c)
{
 35c:	1141                	addi	sp,sp,-16
 35e:	e422                	sd	s0,8(sp)
 360:	0800                	addi	s0,sp,16
  for(; *s; s++)
 362:	00054783          	lbu	a5,0(a0)
 366:	cb99                	beqz	a5,37c <strchr+0x20>
    if(*s == c)
 368:	00f58763          	beq	a1,a5,376 <strchr+0x1a>
  for(; *s; s++)
 36c:	0505                	addi	a0,a0,1
 36e:	00054783          	lbu	a5,0(a0)
 372:	fbfd                	bnez	a5,368 <strchr+0xc>
      return (char*)s;
  return 0;
 374:	4501                	li	a0,0
}
 376:	6422                	ld	s0,8(sp)
 378:	0141                	addi	sp,sp,16
 37a:	8082                	ret
  return 0;
 37c:	4501                	li	a0,0
 37e:	bfe5                	j	376 <strchr+0x1a>

0000000000000380 <gets>:

char*
gets(char *buf, int max)
{
 380:	711d                	addi	sp,sp,-96
 382:	ec86                	sd	ra,88(sp)
 384:	e8a2                	sd	s0,80(sp)
 386:	e4a6                	sd	s1,72(sp)
 388:	e0ca                	sd	s2,64(sp)
 38a:	fc4e                	sd	s3,56(sp)
 38c:	f852                	sd	s4,48(sp)
 38e:	f456                	sd	s5,40(sp)
 390:	f05a                	sd	s6,32(sp)
 392:	ec5e                	sd	s7,24(sp)
 394:	1080                	addi	s0,sp,96
 396:	8baa                	mv	s7,a0
 398:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 39a:	892a                	mv	s2,a0
 39c:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 39e:	4aa9                	li	s5,10
 3a0:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 3a2:	89a6                	mv	s3,s1
 3a4:	2485                	addiw	s1,s1,1
 3a6:	0344d663          	bge	s1,s4,3d2 <gets+0x52>
    cc = read(0, &c, 1);
 3aa:	4605                	li	a2,1
 3ac:	faf40593          	addi	a1,s0,-81
 3b0:	4501                	li	a0,0
 3b2:	1b2000ef          	jal	564 <read>
    if(cc < 1)
 3b6:	00a05e63          	blez	a0,3d2 <gets+0x52>
    buf[i++] = c;
 3ba:	faf44783          	lbu	a5,-81(s0)
 3be:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 3c2:	01578763          	beq	a5,s5,3d0 <gets+0x50>
 3c6:	0905                	addi	s2,s2,1
 3c8:	fd679de3          	bne	a5,s6,3a2 <gets+0x22>
    buf[i++] = c;
 3cc:	89a6                	mv	s3,s1
 3ce:	a011                	j	3d2 <gets+0x52>
 3d0:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 3d2:	99de                	add	s3,s3,s7
 3d4:	00098023          	sb	zero,0(s3)
  return buf;
}
 3d8:	855e                	mv	a0,s7
 3da:	60e6                	ld	ra,88(sp)
 3dc:	6446                	ld	s0,80(sp)
 3de:	64a6                	ld	s1,72(sp)
 3e0:	6906                	ld	s2,64(sp)
 3e2:	79e2                	ld	s3,56(sp)
 3e4:	7a42                	ld	s4,48(sp)
 3e6:	7aa2                	ld	s5,40(sp)
 3e8:	7b02                	ld	s6,32(sp)
 3ea:	6be2                	ld	s7,24(sp)
 3ec:	6125                	addi	sp,sp,96
 3ee:	8082                	ret

00000000000003f0 <stat>:

int
stat(const char *n, struct stat *st)
{
 3f0:	1101                	addi	sp,sp,-32
 3f2:	ec06                	sd	ra,24(sp)
 3f4:	e822                	sd	s0,16(sp)
 3f6:	e04a                	sd	s2,0(sp)
 3f8:	1000                	addi	s0,sp,32
 3fa:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 3fc:	4581                	li	a1,0
 3fe:	18e000ef          	jal	58c <open>
  if(fd < 0)
 402:	02054263          	bltz	a0,426 <stat+0x36>
 406:	e426                	sd	s1,8(sp)
 408:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 40a:	85ca                	mv	a1,s2
 40c:	198000ef          	jal	5a4 <fstat>
 410:	892a                	mv	s2,a0
  close(fd);
 412:	8526                	mv	a0,s1
 414:	160000ef          	jal	574 <close>
  return r;
 418:	64a2                	ld	s1,8(sp)
}
 41a:	854a                	mv	a0,s2
 41c:	60e2                	ld	ra,24(sp)
 41e:	6442                	ld	s0,16(sp)
 420:	6902                	ld	s2,0(sp)
 422:	6105                	addi	sp,sp,32
 424:	8082                	ret
    return -1;
 426:	597d                	li	s2,-1
 428:	bfcd                	j	41a <stat+0x2a>

000000000000042a <atoi>:

int
atoi(const char *s)
{
 42a:	1141                	addi	sp,sp,-16
 42c:	e422                	sd	s0,8(sp)
 42e:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 430:	00054683          	lbu	a3,0(a0)
 434:	fd06879b          	addiw	a5,a3,-48
 438:	0ff7f793          	zext.b	a5,a5
 43c:	4625                	li	a2,9
 43e:	02f66863          	bltu	a2,a5,46e <atoi+0x44>
 442:	872a                	mv	a4,a0
  n = 0;
 444:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 446:	0705                	addi	a4,a4,1
 448:	0025179b          	slliw	a5,a0,0x2
 44c:	9fa9                	addw	a5,a5,a0
 44e:	0017979b          	slliw	a5,a5,0x1
 452:	9fb5                	addw	a5,a5,a3
 454:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 458:	00074683          	lbu	a3,0(a4)
 45c:	fd06879b          	addiw	a5,a3,-48
 460:	0ff7f793          	zext.b	a5,a5
 464:	fef671e3          	bgeu	a2,a5,446 <atoi+0x1c>
  return n;
}
 468:	6422                	ld	s0,8(sp)
 46a:	0141                	addi	sp,sp,16
 46c:	8082                	ret
  n = 0;
 46e:	4501                	li	a0,0
 470:	bfe5                	j	468 <atoi+0x3e>

0000000000000472 <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 472:	1141                	addi	sp,sp,-16
 474:	e422                	sd	s0,8(sp)
 476:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 478:	02b57463          	bgeu	a0,a1,4a0 <memmove+0x2e>
    while(n-- > 0)
 47c:	00c05f63          	blez	a2,49a <memmove+0x28>
 480:	1602                	slli	a2,a2,0x20
 482:	9201                	srli	a2,a2,0x20
 484:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 488:	872a                	mv	a4,a0
      *dst++ = *src++;
 48a:	0585                	addi	a1,a1,1
 48c:	0705                	addi	a4,a4,1
 48e:	fff5c683          	lbu	a3,-1(a1)
 492:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 496:	fef71ae3          	bne	a4,a5,48a <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 49a:	6422                	ld	s0,8(sp)
 49c:	0141                	addi	sp,sp,16
 49e:	8082                	ret
    dst += n;
 4a0:	00c50733          	add	a4,a0,a2
    src += n;
 4a4:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 4a6:	fec05ae3          	blez	a2,49a <memmove+0x28>
 4aa:	fff6079b          	addiw	a5,a2,-1
 4ae:	1782                	slli	a5,a5,0x20
 4b0:	9381                	srli	a5,a5,0x20
 4b2:	fff7c793          	not	a5,a5
 4b6:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 4b8:	15fd                	addi	a1,a1,-1
 4ba:	177d                	addi	a4,a4,-1
 4bc:	0005c683          	lbu	a3,0(a1)
 4c0:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 4c4:	fee79ae3          	bne	a5,a4,4b8 <memmove+0x46>
 4c8:	bfc9                	j	49a <memmove+0x28>

00000000000004ca <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 4ca:	1141                	addi	sp,sp,-16
 4cc:	e422                	sd	s0,8(sp)
 4ce:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 4d0:	ca05                	beqz	a2,500 <memcmp+0x36>
 4d2:	fff6069b          	addiw	a3,a2,-1
 4d6:	1682                	slli	a3,a3,0x20
 4d8:	9281                	srli	a3,a3,0x20
 4da:	0685                	addi	a3,a3,1
 4dc:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 4de:	00054783          	lbu	a5,0(a0)
 4e2:	0005c703          	lbu	a4,0(a1)
 4e6:	00e79863          	bne	a5,a4,4f6 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 4ea:	0505                	addi	a0,a0,1
    p2++;
 4ec:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 4ee:	fed518e3          	bne	a0,a3,4de <memcmp+0x14>
  }
  return 0;
 4f2:	4501                	li	a0,0
 4f4:	a019                	j	4fa <memcmp+0x30>
      return *p1 - *p2;
 4f6:	40e7853b          	subw	a0,a5,a4
}
 4fa:	6422                	ld	s0,8(sp)
 4fc:	0141                	addi	sp,sp,16
 4fe:	8082                	ret
  return 0;
 500:	4501                	li	a0,0
 502:	bfe5                	j	4fa <memcmp+0x30>

0000000000000504 <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 504:	1141                	addi	sp,sp,-16
 506:	e406                	sd	ra,8(sp)
 508:	e022                	sd	s0,0(sp)
 50a:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 50c:	f67ff0ef          	jal	472 <memmove>
}
 510:	60a2                	ld	ra,8(sp)
 512:	6402                	ld	s0,0(sp)
 514:	0141                	addi	sp,sp,16
 516:	8082                	ret

0000000000000518 <sbrk>:

char *
sbrk(int n) {
 518:	1141                	addi	sp,sp,-16
 51a:	e406                	sd	ra,8(sp)
 51c:	e022                	sd	s0,0(sp)
 51e:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_EAGER);
 520:	4585                	li	a1,1
 522:	0b2000ef          	jal	5d4 <sys_sbrk>
}
 526:	60a2                	ld	ra,8(sp)
 528:	6402                	ld	s0,0(sp)
 52a:	0141                	addi	sp,sp,16
 52c:	8082                	ret

000000000000052e <sbrklazy>:

char *
sbrklazy(int n) {
 52e:	1141                	addi	sp,sp,-16
 530:	e406                	sd	ra,8(sp)
 532:	e022                	sd	s0,0(sp)
 534:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_LAZY);
 536:	4589                	li	a1,2
 538:	09c000ef          	jal	5d4 <sys_sbrk>
}
 53c:	60a2                	ld	ra,8(sp)
 53e:	6402                	ld	s0,0(sp)
 540:	0141                	addi	sp,sp,16
 542:	8082                	ret

0000000000000544 <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 544:	4885                	li	a7,1
 ecall
 546:	00000073          	ecall
 ret
 54a:	8082                	ret

000000000000054c <exit>:
.global exit
exit:
 li a7, SYS_exit
 54c:	4889                	li	a7,2
 ecall
 54e:	00000073          	ecall
 ret
 552:	8082                	ret

0000000000000554 <wait>:
.global wait
wait:
 li a7, SYS_wait
 554:	488d                	li	a7,3
 ecall
 556:	00000073          	ecall
 ret
 55a:	8082                	ret

000000000000055c <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 55c:	4891                	li	a7,4
 ecall
 55e:	00000073          	ecall
 ret
 562:	8082                	ret

0000000000000564 <read>:
.global read
read:
 li a7, SYS_read
 564:	4895                	li	a7,5
 ecall
 566:	00000073          	ecall
 ret
 56a:	8082                	ret

000000000000056c <write>:
.global write
write:
 li a7, SYS_write
 56c:	48c1                	li	a7,16
 ecall
 56e:	00000073          	ecall
 ret
 572:	8082                	ret

0000000000000574 <close>:
.global close
close:
 li a7, SYS_close
 574:	48d5                	li	a7,21
 ecall
 576:	00000073          	ecall
 ret
 57a:	8082                	ret

000000000000057c <kill>:
.global kill
kill:
 li a7, SYS_kill
 57c:	4899                	li	a7,6
 ecall
 57e:	00000073          	ecall
 ret
 582:	8082                	ret

0000000000000584 <exec>:
.global exec
exec:
 li a7, SYS_exec
 584:	489d                	li	a7,7
 ecall
 586:	00000073          	ecall
 ret
 58a:	8082                	ret

000000000000058c <open>:
.global open
open:
 li a7, SYS_open
 58c:	48bd                	li	a7,15
 ecall
 58e:	00000073          	ecall
 ret
 592:	8082                	ret

0000000000000594 <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 594:	48c5                	li	a7,17
 ecall
 596:	00000073          	ecall
 ret
 59a:	8082                	ret

000000000000059c <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 59c:	48c9                	li	a7,18
 ecall
 59e:	00000073          	ecall
 ret
 5a2:	8082                	ret

00000000000005a4 <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 5a4:	48a1                	li	a7,8
 ecall
 5a6:	00000073          	ecall
 ret
 5aa:	8082                	ret

00000000000005ac <link>:
.global link
link:
 li a7, SYS_link
 5ac:	48cd                	li	a7,19
 ecall
 5ae:	00000073          	ecall
 ret
 5b2:	8082                	ret

00000000000005b4 <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 5b4:	48d1                	li	a7,20
 ecall
 5b6:	00000073          	ecall
 ret
 5ba:	8082                	ret

00000000000005bc <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 5bc:	48a5                	li	a7,9
 ecall
 5be:	00000073          	ecall
 ret
 5c2:	8082                	ret

00000000000005c4 <dup>:
.global dup
dup:
 li a7, SYS_dup
 5c4:	48a9                	li	a7,10
 ecall
 5c6:	00000073          	ecall
 ret
 5ca:	8082                	ret

00000000000005cc <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 5cc:	48ad                	li	a7,11
 ecall
 5ce:	00000073          	ecall
 ret
 5d2:	8082                	ret

00000000000005d4 <sys_sbrk>:
.global sys_sbrk
sys_sbrk:
 li a7, SYS_sbrk
 5d4:	48b1                	li	a7,12
 ecall
 5d6:	00000073          	ecall
 ret
 5da:	8082                	ret

00000000000005dc <pause>:
.global pause
pause:
 li a7, SYS_pause
 5dc:	48b5                	li	a7,13
 ecall
 5de:	00000073          	ecall
 ret
 5e2:	8082                	ret

00000000000005e4 <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 5e4:	48b9                	li	a7,14
 ecall
 5e6:	00000073          	ecall
 ret
 5ea:	8082                	ret

00000000000005ec <trace>:
.global trace
trace:
 li a7, SYS_trace
 5ec:	48d9                	li	a7,22
 ecall
 5ee:	00000073          	ecall
 ret
 5f2:	8082                	ret

00000000000005f4 <setpriority>:
.global setpriority
setpriority:
 li a7, SYS_setpriority
 5f4:	48dd                	li	a7,23
 ecall
 5f6:	00000073          	ecall
 ret
 5fa:	8082                	ret

00000000000005fc <getpriority>:
.global getpriority
getpriority:
 li a7, SYS_getpriority
 5fc:	48e1                	li	a7,24
 ecall
 5fe:	00000073          	ecall
 ret
 602:	8082                	ret

0000000000000604 <getmemstat>:
.global getmemstat
getmemstat:
 li a7, SYS_getmemstat
 604:	48e5                	li	a7,25
 ecall
 606:	00000073          	ecall
 ret
 60a:	8082                	ret

000000000000060c <setmemquota>:
.global setmemquota
setmemquota:
 li a7, SYS_setmemquota
 60c:	48e9                	li	a7,26
 ecall
 60e:	00000073          	ecall
 ret
 612:	8082                	ret

0000000000000614 <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 614:	1101                	addi	sp,sp,-32
 616:	ec06                	sd	ra,24(sp)
 618:	e822                	sd	s0,16(sp)
 61a:	1000                	addi	s0,sp,32
 61c:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 620:	4605                	li	a2,1
 622:	fef40593          	addi	a1,s0,-17
 626:	f47ff0ef          	jal	56c <write>
}
 62a:	60e2                	ld	ra,24(sp)
 62c:	6442                	ld	s0,16(sp)
 62e:	6105                	addi	sp,sp,32
 630:	8082                	ret

0000000000000632 <printint>:

static void
printint(int fd, long long xx, int base, int sgn)
{
 632:	715d                	addi	sp,sp,-80
 634:	e486                	sd	ra,72(sp)
 636:	e0a2                	sd	s0,64(sp)
 638:	f84a                	sd	s2,48(sp)
 63a:	0880                	addi	s0,sp,80
 63c:	892a                	mv	s2,a0
  char buf[20];
  int i, neg;
  unsigned long long x;

  neg = 0;
  if(sgn && xx < 0){
 63e:	c299                	beqz	a3,644 <printint+0x12>
 640:	0805c363          	bltz	a1,6c6 <printint+0x94>
  neg = 0;
 644:	4881                	li	a7,0
 646:	fb840693          	addi	a3,s0,-72
    x = -xx;
  } else {
    x = xx;
  }

  i = 0;
 64a:	4781                	li	a5,0
  do{
    buf[i++] = digits[x % base];
 64c:	00000517          	auipc	a0,0x0
 650:	7cc50513          	addi	a0,a0,1996 # e18 <digits>
 654:	883e                	mv	a6,a5
 656:	2785                	addiw	a5,a5,1
 658:	02c5f733          	remu	a4,a1,a2
 65c:	972a                	add	a4,a4,a0
 65e:	00074703          	lbu	a4,0(a4)
 662:	00e68023          	sb	a4,0(a3)
  }while((x /= base) != 0);
 666:	872e                	mv	a4,a1
 668:	02c5d5b3          	divu	a1,a1,a2
 66c:	0685                	addi	a3,a3,1
 66e:	fec773e3          	bgeu	a4,a2,654 <printint+0x22>
  if(neg)
 672:	00088b63          	beqz	a7,688 <printint+0x56>
    buf[i++] = '-';
 676:	fd078793          	addi	a5,a5,-48
 67a:	97a2                	add	a5,a5,s0
 67c:	02d00713          	li	a4,45
 680:	fee78423          	sb	a4,-24(a5)
 684:	0028079b          	addiw	a5,a6,2

  while(--i >= 0)
 688:	02f05a63          	blez	a5,6bc <printint+0x8a>
 68c:	fc26                	sd	s1,56(sp)
 68e:	f44e                	sd	s3,40(sp)
 690:	fb840713          	addi	a4,s0,-72
 694:	00f704b3          	add	s1,a4,a5
 698:	fff70993          	addi	s3,a4,-1
 69c:	99be                	add	s3,s3,a5
 69e:	37fd                	addiw	a5,a5,-1
 6a0:	1782                	slli	a5,a5,0x20
 6a2:	9381                	srli	a5,a5,0x20
 6a4:	40f989b3          	sub	s3,s3,a5
    putc(fd, buf[i]);
 6a8:	fff4c583          	lbu	a1,-1(s1)
 6ac:	854a                	mv	a0,s2
 6ae:	f67ff0ef          	jal	614 <putc>
  while(--i >= 0)
 6b2:	14fd                	addi	s1,s1,-1
 6b4:	ff349ae3          	bne	s1,s3,6a8 <printint+0x76>
 6b8:	74e2                	ld	s1,56(sp)
 6ba:	79a2                	ld	s3,40(sp)
}
 6bc:	60a6                	ld	ra,72(sp)
 6be:	6406                	ld	s0,64(sp)
 6c0:	7942                	ld	s2,48(sp)
 6c2:	6161                	addi	sp,sp,80
 6c4:	8082                	ret
    x = -xx;
 6c6:	40b005b3          	neg	a1,a1
    neg = 1;
 6ca:	4885                	li	a7,1
    x = -xx;
 6cc:	bfad                	j	646 <printint+0x14>

00000000000006ce <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %c, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 6ce:	711d                	addi	sp,sp,-96
 6d0:	ec86                	sd	ra,88(sp)
 6d2:	e8a2                	sd	s0,80(sp)
 6d4:	e0ca                	sd	s2,64(sp)
 6d6:	1080                	addi	s0,sp,96
  char *s;
  int c0, c1, c2, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 6d8:	0005c903          	lbu	s2,0(a1)
 6dc:	28090663          	beqz	s2,968 <vprintf+0x29a>
 6e0:	e4a6                	sd	s1,72(sp)
 6e2:	fc4e                	sd	s3,56(sp)
 6e4:	f852                	sd	s4,48(sp)
 6e6:	f456                	sd	s5,40(sp)
 6e8:	f05a                	sd	s6,32(sp)
 6ea:	ec5e                	sd	s7,24(sp)
 6ec:	e862                	sd	s8,16(sp)
 6ee:	e466                	sd	s9,8(sp)
 6f0:	8b2a                	mv	s6,a0
 6f2:	8a2e                	mv	s4,a1
 6f4:	8bb2                	mv	s7,a2
  state = 0;
 6f6:	4981                	li	s3,0
  for(i = 0; fmt[i]; i++){
 6f8:	4481                	li	s1,0
 6fa:	4701                	li	a4,0
      if(c0 == '%'){
        state = '%';
      } else {
        putc(fd, c0);
      }
    } else if(state == '%'){
 6fc:	02500a93          	li	s5,37
      c1 = c2 = 0;
      if(c0) c1 = fmt[i+1] & 0xff;
      if(c1) c2 = fmt[i+2] & 0xff;
      if(c0 == 'd'){
 700:	06400c13          	li	s8,100
        printint(fd, va_arg(ap, int), 10, 1);
      } else if(c0 == 'l' && c1 == 'd'){
 704:	06c00c93          	li	s9,108
 708:	a005                	j	728 <vprintf+0x5a>
        putc(fd, c0);
 70a:	85ca                	mv	a1,s2
 70c:	855a                	mv	a0,s6
 70e:	f07ff0ef          	jal	614 <putc>
 712:	a019                	j	718 <vprintf+0x4a>
    } else if(state == '%'){
 714:	03598263          	beq	s3,s5,738 <vprintf+0x6a>
  for(i = 0; fmt[i]; i++){
 718:	2485                	addiw	s1,s1,1
 71a:	8726                	mv	a4,s1
 71c:	009a07b3          	add	a5,s4,s1
 720:	0007c903          	lbu	s2,0(a5)
 724:	22090a63          	beqz	s2,958 <vprintf+0x28a>
    c0 = fmt[i] & 0xff;
 728:	0009079b          	sext.w	a5,s2
    if(state == 0){
 72c:	fe0994e3          	bnez	s3,714 <vprintf+0x46>
      if(c0 == '%'){
 730:	fd579de3          	bne	a5,s5,70a <vprintf+0x3c>
        state = '%';
 734:	89be                	mv	s3,a5
 736:	b7cd                	j	718 <vprintf+0x4a>
      if(c0) c1 = fmt[i+1] & 0xff;
 738:	00ea06b3          	add	a3,s4,a4
 73c:	0016c683          	lbu	a3,1(a3)
      c1 = c2 = 0;
 740:	8636                	mv	a2,a3
      if(c1) c2 = fmt[i+2] & 0xff;
 742:	c681                	beqz	a3,74a <vprintf+0x7c>
 744:	9752                	add	a4,a4,s4
 746:	00274603          	lbu	a2,2(a4)
      if(c0 == 'd'){
 74a:	05878363          	beq	a5,s8,790 <vprintf+0xc2>
      } else if(c0 == 'l' && c1 == 'd'){
 74e:	05978d63          	beq	a5,s9,7a8 <vprintf+0xda>
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 2;
      } else if(c0 == 'u'){
 752:	07500713          	li	a4,117
 756:	0ee78763          	beq	a5,a4,844 <vprintf+0x176>
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 2;
      } else if(c0 == 'x'){
 75a:	07800713          	li	a4,120
 75e:	12e78963          	beq	a5,a4,890 <vprintf+0x1c2>
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 2;
      } else if(c0 == 'p'){
 762:	07000713          	li	a4,112
 766:	14e78e63          	beq	a5,a4,8c2 <vprintf+0x1f4>
        printptr(fd, va_arg(ap, uint64));
      } else if(c0 == 'c'){
 76a:	06300713          	li	a4,99
 76e:	18e78e63          	beq	a5,a4,90a <vprintf+0x23c>
        putc(fd, va_arg(ap, uint32));
      } else if(c0 == 's'){
 772:	07300713          	li	a4,115
 776:	1ae78463          	beq	a5,a4,91e <vprintf+0x250>
        if((s = va_arg(ap, char*)) == 0)
          s = "(null)";
        for(; *s; s++)
          putc(fd, *s);
      } else if(c0 == '%'){
 77a:	02500713          	li	a4,37
 77e:	04e79563          	bne	a5,a4,7c8 <vprintf+0xfa>
        putc(fd, '%');
 782:	02500593          	li	a1,37
 786:	855a                	mv	a0,s6
 788:	e8dff0ef          	jal	614 <putc>
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c0);
      }

      state = 0;
 78c:	4981                	li	s3,0
 78e:	b769                	j	718 <vprintf+0x4a>
        printint(fd, va_arg(ap, int), 10, 1);
 790:	008b8913          	addi	s2,s7,8
 794:	4685                	li	a3,1
 796:	4629                	li	a2,10
 798:	000ba583          	lw	a1,0(s7)
 79c:	855a                	mv	a0,s6
 79e:	e95ff0ef          	jal	632 <printint>
 7a2:	8bca                	mv	s7,s2
      state = 0;
 7a4:	4981                	li	s3,0
 7a6:	bf8d                	j	718 <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'd'){
 7a8:	06400793          	li	a5,100
 7ac:	02f68963          	beq	a3,a5,7de <vprintf+0x110>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 7b0:	06c00793          	li	a5,108
 7b4:	04f68263          	beq	a3,a5,7f8 <vprintf+0x12a>
      } else if(c0 == 'l' && c1 == 'u'){
 7b8:	07500793          	li	a5,117
 7bc:	0af68063          	beq	a3,a5,85c <vprintf+0x18e>
      } else if(c0 == 'l' && c1 == 'x'){
 7c0:	07800793          	li	a5,120
 7c4:	0ef68263          	beq	a3,a5,8a8 <vprintf+0x1da>
        putc(fd, '%');
 7c8:	02500593          	li	a1,37
 7cc:	855a                	mv	a0,s6
 7ce:	e47ff0ef          	jal	614 <putc>
        putc(fd, c0);
 7d2:	85ca                	mv	a1,s2
 7d4:	855a                	mv	a0,s6
 7d6:	e3fff0ef          	jal	614 <putc>
      state = 0;
 7da:	4981                	li	s3,0
 7dc:	bf35                	j	718 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 7de:	008b8913          	addi	s2,s7,8
 7e2:	4685                	li	a3,1
 7e4:	4629                	li	a2,10
 7e6:	000bb583          	ld	a1,0(s7)
 7ea:	855a                	mv	a0,s6
 7ec:	e47ff0ef          	jal	632 <printint>
        i += 1;
 7f0:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 1);
 7f2:	8bca                	mv	s7,s2
      state = 0;
 7f4:	4981                	li	s3,0
        i += 1;
 7f6:	b70d                	j	718 <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 7f8:	06400793          	li	a5,100
 7fc:	02f60763          	beq	a2,a5,82a <vprintf+0x15c>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
 800:	07500793          	li	a5,117
 804:	06f60963          	beq	a2,a5,876 <vprintf+0x1a8>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
 808:	07800793          	li	a5,120
 80c:	faf61ee3          	bne	a2,a5,7c8 <vprintf+0xfa>
        printint(fd, va_arg(ap, uint64), 16, 0);
 810:	008b8913          	addi	s2,s7,8
 814:	4681                	li	a3,0
 816:	4641                	li	a2,16
 818:	000bb583          	ld	a1,0(s7)
 81c:	855a                	mv	a0,s6
 81e:	e15ff0ef          	jal	632 <printint>
        i += 2;
 822:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 16, 0);
 824:	8bca                	mv	s7,s2
      state = 0;
 826:	4981                	li	s3,0
        i += 2;
 828:	bdc5                	j	718 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 82a:	008b8913          	addi	s2,s7,8
 82e:	4685                	li	a3,1
 830:	4629                	li	a2,10
 832:	000bb583          	ld	a1,0(s7)
 836:	855a                	mv	a0,s6
 838:	dfbff0ef          	jal	632 <printint>
        i += 2;
 83c:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 1);
 83e:	8bca                	mv	s7,s2
      state = 0;
 840:	4981                	li	s3,0
        i += 2;
 842:	bdd9                	j	718 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 10, 0);
 844:	008b8913          	addi	s2,s7,8
 848:	4681                	li	a3,0
 84a:	4629                	li	a2,10
 84c:	000be583          	lwu	a1,0(s7)
 850:	855a                	mv	a0,s6
 852:	de1ff0ef          	jal	632 <printint>
 856:	8bca                	mv	s7,s2
      state = 0;
 858:	4981                	li	s3,0
 85a:	bd7d                	j	718 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 85c:	008b8913          	addi	s2,s7,8
 860:	4681                	li	a3,0
 862:	4629                	li	a2,10
 864:	000bb583          	ld	a1,0(s7)
 868:	855a                	mv	a0,s6
 86a:	dc9ff0ef          	jal	632 <printint>
        i += 1;
 86e:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 0);
 870:	8bca                	mv	s7,s2
      state = 0;
 872:	4981                	li	s3,0
        i += 1;
 874:	b555                	j	718 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 876:	008b8913          	addi	s2,s7,8
 87a:	4681                	li	a3,0
 87c:	4629                	li	a2,10
 87e:	000bb583          	ld	a1,0(s7)
 882:	855a                	mv	a0,s6
 884:	dafff0ef          	jal	632 <printint>
        i += 2;
 888:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 0);
 88a:	8bca                	mv	s7,s2
      state = 0;
 88c:	4981                	li	s3,0
        i += 2;
 88e:	b569                	j	718 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 16, 0);
 890:	008b8913          	addi	s2,s7,8
 894:	4681                	li	a3,0
 896:	4641                	li	a2,16
 898:	000be583          	lwu	a1,0(s7)
 89c:	855a                	mv	a0,s6
 89e:	d95ff0ef          	jal	632 <printint>
 8a2:	8bca                	mv	s7,s2
      state = 0;
 8a4:	4981                	li	s3,0
 8a6:	bd8d                	j	718 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 16, 0);
 8a8:	008b8913          	addi	s2,s7,8
 8ac:	4681                	li	a3,0
 8ae:	4641                	li	a2,16
 8b0:	000bb583          	ld	a1,0(s7)
 8b4:	855a                	mv	a0,s6
 8b6:	d7dff0ef          	jal	632 <printint>
        i += 1;
 8ba:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 16, 0);
 8bc:	8bca                	mv	s7,s2
      state = 0;
 8be:	4981                	li	s3,0
        i += 1;
 8c0:	bda1                	j	718 <vprintf+0x4a>
 8c2:	e06a                	sd	s10,0(sp)
        printptr(fd, va_arg(ap, uint64));
 8c4:	008b8d13          	addi	s10,s7,8
 8c8:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 8cc:	03000593          	li	a1,48
 8d0:	855a                	mv	a0,s6
 8d2:	d43ff0ef          	jal	614 <putc>
  putc(fd, 'x');
 8d6:	07800593          	li	a1,120
 8da:	855a                	mv	a0,s6
 8dc:	d39ff0ef          	jal	614 <putc>
 8e0:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 8e2:	00000b97          	auipc	s7,0x0
 8e6:	536b8b93          	addi	s7,s7,1334 # e18 <digits>
 8ea:	03c9d793          	srli	a5,s3,0x3c
 8ee:	97de                	add	a5,a5,s7
 8f0:	0007c583          	lbu	a1,0(a5)
 8f4:	855a                	mv	a0,s6
 8f6:	d1fff0ef          	jal	614 <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 8fa:	0992                	slli	s3,s3,0x4
 8fc:	397d                	addiw	s2,s2,-1
 8fe:	fe0916e3          	bnez	s2,8ea <vprintf+0x21c>
        printptr(fd, va_arg(ap, uint64));
 902:	8bea                	mv	s7,s10
      state = 0;
 904:	4981                	li	s3,0
 906:	6d02                	ld	s10,0(sp)
 908:	bd01                	j	718 <vprintf+0x4a>
        putc(fd, va_arg(ap, uint32));
 90a:	008b8913          	addi	s2,s7,8
 90e:	000bc583          	lbu	a1,0(s7)
 912:	855a                	mv	a0,s6
 914:	d01ff0ef          	jal	614 <putc>
 918:	8bca                	mv	s7,s2
      state = 0;
 91a:	4981                	li	s3,0
 91c:	bbf5                	j	718 <vprintf+0x4a>
        if((s = va_arg(ap, char*)) == 0)
 91e:	008b8993          	addi	s3,s7,8
 922:	000bb903          	ld	s2,0(s7)
 926:	00090f63          	beqz	s2,944 <vprintf+0x276>
        for(; *s; s++)
 92a:	00094583          	lbu	a1,0(s2)
 92e:	c195                	beqz	a1,952 <vprintf+0x284>
          putc(fd, *s);
 930:	855a                	mv	a0,s6
 932:	ce3ff0ef          	jal	614 <putc>
        for(; *s; s++)
 936:	0905                	addi	s2,s2,1
 938:	00094583          	lbu	a1,0(s2)
 93c:	f9f5                	bnez	a1,930 <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 93e:	8bce                	mv	s7,s3
      state = 0;
 940:	4981                	li	s3,0
 942:	bbd9                	j	718 <vprintf+0x4a>
          s = "(null)";
 944:	00000917          	auipc	s2,0x0
 948:	4cc90913          	addi	s2,s2,1228 # e10 <malloc+0x3c0>
        for(; *s; s++)
 94c:	02800593          	li	a1,40
 950:	b7c5                	j	930 <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 952:	8bce                	mv	s7,s3
      state = 0;
 954:	4981                	li	s3,0
 956:	b3c9                	j	718 <vprintf+0x4a>
 958:	64a6                	ld	s1,72(sp)
 95a:	79e2                	ld	s3,56(sp)
 95c:	7a42                	ld	s4,48(sp)
 95e:	7aa2                	ld	s5,40(sp)
 960:	7b02                	ld	s6,32(sp)
 962:	6be2                	ld	s7,24(sp)
 964:	6c42                	ld	s8,16(sp)
 966:	6ca2                	ld	s9,8(sp)
    }
  }
}
 968:	60e6                	ld	ra,88(sp)
 96a:	6446                	ld	s0,80(sp)
 96c:	6906                	ld	s2,64(sp)
 96e:	6125                	addi	sp,sp,96
 970:	8082                	ret

0000000000000972 <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 972:	715d                	addi	sp,sp,-80
 974:	ec06                	sd	ra,24(sp)
 976:	e822                	sd	s0,16(sp)
 978:	1000                	addi	s0,sp,32
 97a:	e010                	sd	a2,0(s0)
 97c:	e414                	sd	a3,8(s0)
 97e:	e818                	sd	a4,16(s0)
 980:	ec1c                	sd	a5,24(s0)
 982:	03043023          	sd	a6,32(s0)
 986:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 98a:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 98e:	8622                	mv	a2,s0
 990:	d3fff0ef          	jal	6ce <vprintf>
}
 994:	60e2                	ld	ra,24(sp)
 996:	6442                	ld	s0,16(sp)
 998:	6161                	addi	sp,sp,80
 99a:	8082                	ret

000000000000099c <printf>:

void
printf(const char *fmt, ...)
{
 99c:	711d                	addi	sp,sp,-96
 99e:	ec06                	sd	ra,24(sp)
 9a0:	e822                	sd	s0,16(sp)
 9a2:	1000                	addi	s0,sp,32
 9a4:	e40c                	sd	a1,8(s0)
 9a6:	e810                	sd	a2,16(s0)
 9a8:	ec14                	sd	a3,24(s0)
 9aa:	f018                	sd	a4,32(s0)
 9ac:	f41c                	sd	a5,40(s0)
 9ae:	03043823          	sd	a6,48(s0)
 9b2:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 9b6:	00840613          	addi	a2,s0,8
 9ba:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 9be:	85aa                	mv	a1,a0
 9c0:	4505                	li	a0,1
 9c2:	d0dff0ef          	jal	6ce <vprintf>
}
 9c6:	60e2                	ld	ra,24(sp)
 9c8:	6442                	ld	s0,16(sp)
 9ca:	6125                	addi	sp,sp,96
 9cc:	8082                	ret

00000000000009ce <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 9ce:	1141                	addi	sp,sp,-16
 9d0:	e422                	sd	s0,8(sp)
 9d2:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 9d4:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 9d8:	00001797          	auipc	a5,0x1
 9dc:	6287b783          	ld	a5,1576(a5) # 2000 <freep>
 9e0:	a02d                	j	a0a <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 9e2:	4618                	lw	a4,8(a2)
 9e4:	9f2d                	addw	a4,a4,a1
 9e6:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 9ea:	6398                	ld	a4,0(a5)
 9ec:	6310                	ld	a2,0(a4)
 9ee:	a83d                	j	a2c <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 9f0:	ff852703          	lw	a4,-8(a0)
 9f4:	9f31                	addw	a4,a4,a2
 9f6:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 9f8:	ff053683          	ld	a3,-16(a0)
 9fc:	a091                	j	a40 <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 9fe:	6398                	ld	a4,0(a5)
 a00:	00e7e463          	bltu	a5,a4,a08 <free+0x3a>
 a04:	00e6ea63          	bltu	a3,a4,a18 <free+0x4a>
{
 a08:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 a0a:	fed7fae3          	bgeu	a5,a3,9fe <free+0x30>
 a0e:	6398                	ld	a4,0(a5)
 a10:	00e6e463          	bltu	a3,a4,a18 <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 a14:	fee7eae3          	bltu	a5,a4,a08 <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 a18:	ff852583          	lw	a1,-8(a0)
 a1c:	6390                	ld	a2,0(a5)
 a1e:	02059813          	slli	a6,a1,0x20
 a22:	01c85713          	srli	a4,a6,0x1c
 a26:	9736                	add	a4,a4,a3
 a28:	fae60de3          	beq	a2,a4,9e2 <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 a2c:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 a30:	4790                	lw	a2,8(a5)
 a32:	02061593          	slli	a1,a2,0x20
 a36:	01c5d713          	srli	a4,a1,0x1c
 a3a:	973e                	add	a4,a4,a5
 a3c:	fae68ae3          	beq	a3,a4,9f0 <free+0x22>
    p->s.ptr = bp->s.ptr;
 a40:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 a42:	00001717          	auipc	a4,0x1
 a46:	5af73f23          	sd	a5,1470(a4) # 2000 <freep>
}
 a4a:	6422                	ld	s0,8(sp)
 a4c:	0141                	addi	sp,sp,16
 a4e:	8082                	ret

0000000000000a50 <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 a50:	7139                	addi	sp,sp,-64
 a52:	fc06                	sd	ra,56(sp)
 a54:	f822                	sd	s0,48(sp)
 a56:	f426                	sd	s1,40(sp)
 a58:	ec4e                	sd	s3,24(sp)
 a5a:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 a5c:	02051493          	slli	s1,a0,0x20
 a60:	9081                	srli	s1,s1,0x20
 a62:	04bd                	addi	s1,s1,15
 a64:	8091                	srli	s1,s1,0x4
 a66:	0014899b          	addiw	s3,s1,1
 a6a:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 a6c:	00001517          	auipc	a0,0x1
 a70:	59453503          	ld	a0,1428(a0) # 2000 <freep>
 a74:	c915                	beqz	a0,aa8 <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 a76:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 a78:	4798                	lw	a4,8(a5)
 a7a:	08977a63          	bgeu	a4,s1,b0e <malloc+0xbe>
 a7e:	f04a                	sd	s2,32(sp)
 a80:	e852                	sd	s4,16(sp)
 a82:	e456                	sd	s5,8(sp)
 a84:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 a86:	8a4e                	mv	s4,s3
 a88:	0009871b          	sext.w	a4,s3
 a8c:	6685                	lui	a3,0x1
 a8e:	00d77363          	bgeu	a4,a3,a94 <malloc+0x44>
 a92:	6a05                	lui	s4,0x1
 a94:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 a98:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 a9c:	00001917          	auipc	s2,0x1
 aa0:	56490913          	addi	s2,s2,1380 # 2000 <freep>
  if(p == SBRK_ERROR)
 aa4:	5afd                	li	s5,-1
 aa6:	a081                	j	ae6 <malloc+0x96>
 aa8:	f04a                	sd	s2,32(sp)
 aaa:	e852                	sd	s4,16(sp)
 aac:	e456                	sd	s5,8(sp)
 aae:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 ab0:	00001797          	auipc	a5,0x1
 ab4:	56078793          	addi	a5,a5,1376 # 2010 <base>
 ab8:	00001717          	auipc	a4,0x1
 abc:	54f73423          	sd	a5,1352(a4) # 2000 <freep>
 ac0:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 ac2:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 ac6:	b7c1                	j	a86 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 ac8:	6398                	ld	a4,0(a5)
 aca:	e118                	sd	a4,0(a0)
 acc:	a8a9                	j	b26 <malloc+0xd6>
  hp->s.size = nu;
 ace:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 ad2:	0541                	addi	a0,a0,16
 ad4:	efbff0ef          	jal	9ce <free>
  return freep;
 ad8:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 adc:	c12d                	beqz	a0,b3e <malloc+0xee>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 ade:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 ae0:	4798                	lw	a4,8(a5)
 ae2:	02977263          	bgeu	a4,s1,b06 <malloc+0xb6>
    if(p == freep)
 ae6:	00093703          	ld	a4,0(s2)
 aea:	853e                	mv	a0,a5
 aec:	fef719e3          	bne	a4,a5,ade <malloc+0x8e>
  p = sbrk(nu * sizeof(Header));
 af0:	8552                	mv	a0,s4
 af2:	a27ff0ef          	jal	518 <sbrk>
  if(p == SBRK_ERROR)
 af6:	fd551ce3          	bne	a0,s5,ace <malloc+0x7e>
        return 0;
 afa:	4501                	li	a0,0
 afc:	7902                	ld	s2,32(sp)
 afe:	6a42                	ld	s4,16(sp)
 b00:	6aa2                	ld	s5,8(sp)
 b02:	6b02                	ld	s6,0(sp)
 b04:	a03d                	j	b32 <malloc+0xe2>
 b06:	7902                	ld	s2,32(sp)
 b08:	6a42                	ld	s4,16(sp)
 b0a:	6aa2                	ld	s5,8(sp)
 b0c:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 b0e:	fae48de3          	beq	s1,a4,ac8 <malloc+0x78>
        p->s.size -= nunits;
 b12:	4137073b          	subw	a4,a4,s3
 b16:	c798                	sw	a4,8(a5)
        p += p->s.size;
 b18:	02071693          	slli	a3,a4,0x20
 b1c:	01c6d713          	srli	a4,a3,0x1c
 b20:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 b22:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 b26:	00001717          	auipc	a4,0x1
 b2a:	4ca73d23          	sd	a0,1242(a4) # 2000 <freep>
      return (void*)(p + 1);
 b2e:	01078513          	addi	a0,a5,16
  }
}
 b32:	70e2                	ld	ra,56(sp)
 b34:	7442                	ld	s0,48(sp)
 b36:	74a2                	ld	s1,40(sp)
 b38:	69e2                	ld	s3,24(sp)
 b3a:	6121                	addi	sp,sp,64
 b3c:	8082                	ret
 b3e:	7902                	ld	s2,32(sp)
 b40:	6a42                	ld	s4,16(sp)
 b42:	6aa2                	ld	s5,8(sp)
 b44:	6b02                	ld	s6,0(sp)
 b46:	b7f5                	j	b32 <malloc+0xe2>
