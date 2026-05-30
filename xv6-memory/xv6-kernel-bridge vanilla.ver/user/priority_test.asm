
user/_priority_test:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <burn>:
#include "user/user.h"

/* Burn CPU for a while so scheduling differences are observable */
static void
burn(int iterations)
{
   0:	1101                	addi	sp,sp,-32
   2:	ec22                	sd	s0,24(sp)
   4:	1000                	addi	s0,sp,32
  volatile int x = 0;
   6:	fe042623          	sw	zero,-20(s0)
  for (int i = 0; i < iterations; i++)
   a:	00a05b63          	blez	a0,20 <burn+0x20>
   e:	4781                	li	a5,0
    x += i;
  10:	fec42703          	lw	a4,-20(s0)
  14:	9f3d                	addw	a4,a4,a5
  16:	fee42623          	sw	a4,-20(s0)
  for (int i = 0; i < iterations; i++)
  1a:	2785                	addiw	a5,a5,1
  1c:	fef51ae3          	bne	a0,a5,10 <burn+0x10>
}
  20:	6462                	ld	s0,24(sp)
  22:	6105                	addi	sp,sp,32
  24:	8082                	ret

0000000000000026 <main>:
  printf("Test 3 PASSED\n\n");
}

int
main(int argc, char *argv[])
{
  26:	7179                	addi	sp,sp,-48
  28:	f406                	sd	ra,40(sp)
  2a:	f022                	sd	s0,32(sp)
  2c:	ec26                	sd	s1,24(sp)
  2e:	e84a                	sd	s2,16(sp)
  30:	1800                	addi	s0,sp,48
  printf("=== Priority Scheduler Test ===\n\n");
  32:	00001517          	auipc	a0,0x1
  36:	b1e50513          	addi	a0,a0,-1250 # b50 <malloc+0x106>
  3a:	15d000ef          	jal	996 <printf>
  int pid = getpid();
  3e:	588000ef          	jal	5c6 <getpid>
  42:	84aa                	mv	s1,a0
  printf("--- Test 1: setpriority/getpriority ---\n");
  44:	00001517          	auipc	a0,0x1
  48:	b3450513          	addi	a0,a0,-1228 # b78 <malloc+0x12e>
  4c:	14b000ef          	jal	996 <printf>
  prio = getpriority(pid);
  50:	8526                	mv	a0,s1
  52:	5a4000ef          	jal	5f6 <getpriority>
  56:	892a                	mv	s2,a0
  printf("PID %d: default priority = %d\n", pid, prio);
  58:	862a                	mv	a2,a0
  5a:	85a6                	mv	a1,s1
  5c:	00001517          	auipc	a0,0x1
  60:	b4c50513          	addi	a0,a0,-1204 # ba8 <malloc+0x15e>
  64:	133000ef          	jal	996 <printf>
  if (prio != 10) {
  68:	47a9                	li	a5,10
  6a:	0ef91463          	bne	s2,a5,152 <main+0x12c>
  if (setpriority(pid, 5) != 0) {
  6e:	4595                	li	a1,5
  70:	8526                	mv	a0,s1
  72:	57c000ef          	jal	5ee <setpriority>
  76:	0e051863          	bnez	a0,166 <main+0x140>
  prio = getpriority(pid);
  7a:	8526                	mv	a0,s1
  7c:	57a000ef          	jal	5f6 <getpriority>
  80:	892a                	mv	s2,a0
  printf("PID %d: after setpriority(%d, 5), priority = %d\n", pid, pid, prio);
  82:	86aa                	mv	a3,a0
  84:	8626                	mv	a2,s1
  86:	85a6                	mv	a1,s1
  88:	00001517          	auipc	a0,0x1
  8c:	b9850513          	addi	a0,a0,-1128 # c20 <malloc+0x1d6>
  90:	107000ef          	jal	996 <printf>
  if (prio != 5) {
  94:	4795                	li	a5,5
  96:	0ef91163          	bne	s2,a5,178 <main+0x152>
  int r1 = setpriority(pid, -1);
  9a:	55fd                	li	a1,-1
  9c:	8526                	mv	a0,s1
  9e:	550000ef          	jal	5ee <setpriority>
  a2:	892a                	mv	s2,a0
  printf("setpriority with invalid priority (-1): returned %d (OK)\n", r1);
  a4:	85aa                	mv	a1,a0
  a6:	00001517          	auipc	a0,0x1
  aa:	bda50513          	addi	a0,a0,-1062 # c80 <malloc+0x236>
  ae:	0e9000ef          	jal	996 <printf>
  if (r1 != -1) {
  b2:	57fd                	li	a5,-1
  b4:	0cf91c63          	bne	s2,a5,18c <main+0x166>
  int r2 = setpriority(pid, 21);
  b8:	45d5                	li	a1,21
  ba:	8526                	mv	a0,s1
  bc:	532000ef          	jal	5ee <setpriority>
  c0:	892a                	mv	s2,a0
  printf("setpriority with invalid priority (21): returned %d (OK)\n", r2);
  c2:	85aa                	mv	a1,a0
  c4:	00001517          	auipc	a0,0x1
  c8:	c1c50513          	addi	a0,a0,-996 # ce0 <malloc+0x296>
  cc:	0cb000ef          	jal	996 <printf>
  if (r2 != -1) {
  d0:	57fd                	li	a5,-1
  d2:	0cf91663          	bne	s2,a5,19e <main+0x178>
  setpriority(pid, 10);
  d6:	45a9                	li	a1,10
  d8:	8526                	mv	a0,s1
  da:	514000ef          	jal	5ee <setpriority>
  printf("Test 1 PASSED\n\n");
  de:	00001517          	auipc	a0,0x1
  e2:	c4250513          	addi	a0,a0,-958 # d20 <malloc+0x2d6>
  e6:	0b1000ef          	jal	996 <printf>
  printf("--- Test 2: Priority inheritance via fork ---\n");
  ea:	00001517          	auipc	a0,0x1
  ee:	c4650513          	addi	a0,a0,-954 # d30 <malloc+0x2e6>
  f2:	0a5000ef          	jal	996 <printf>
  setpriority(getpid(), 3);
  f6:	4d0000ef          	jal	5c6 <getpid>
  fa:	458d                	li	a1,3
  fc:	4f2000ef          	jal	5ee <setpriority>
  printf("Parent priority = %d\n", getpriority(getpid()));
 100:	4c6000ef          	jal	5c6 <getpid>
 104:	4f2000ef          	jal	5f6 <getpriority>
 108:	85aa                	mv	a1,a0
 10a:	00001517          	auipc	a0,0x1
 10e:	c5650513          	addi	a0,a0,-938 # d60 <malloc+0x316>
 112:	085000ef          	jal	996 <printf>
  int pid = fork();
 116:	428000ef          	jal	53e <fork>
  if (pid < 0) {
 11a:	08054b63          	bltz	a0,1b0 <main+0x18a>
  if (pid == 0) {
 11e:	e54d                	bnez	a0,1c8 <main+0x1a2>
    int cprio = getpriority(getpid());
 120:	4a6000ef          	jal	5c6 <getpid>
 124:	4d2000ef          	jal	5f6 <getpriority>
 128:	84aa                	mv	s1,a0
    printf("Child priority = %d\n", cprio);
 12a:	85aa                	mv	a1,a0
 12c:	00001517          	auipc	a0,0x1
 130:	c6450513          	addi	a0,a0,-924 # d90 <malloc+0x346>
 134:	063000ef          	jal	996 <printf>
    if (cprio != 3) {
 138:	478d                	li	a5,3
 13a:	08f48463          	beq	s1,a5,1c2 <main+0x19c>
      printf("FAIL: child expected priority 3, got %d\n", cprio);
 13e:	85a6                	mv	a1,s1
 140:	00001517          	auipc	a0,0x1
 144:	c6850513          	addi	a0,a0,-920 # da8 <malloc+0x35e>
 148:	04f000ef          	jal	996 <printf>
      exit(1);
 14c:	4505                	li	a0,1
 14e:	3f8000ef          	jal	546 <exit>
    printf("FAIL: expected default priority 10, got %d\n", prio);
 152:	85ca                	mv	a1,s2
 154:	00001517          	auipc	a0,0x1
 158:	a7450513          	addi	a0,a0,-1420 # bc8 <malloc+0x17e>
 15c:	03b000ef          	jal	996 <printf>
    exit(1);
 160:	4505                	li	a0,1
 162:	3e4000ef          	jal	546 <exit>
    printf("FAIL: setpriority returned error\n");
 166:	00001517          	auipc	a0,0x1
 16a:	a9250513          	addi	a0,a0,-1390 # bf8 <malloc+0x1ae>
 16e:	029000ef          	jal	996 <printf>
    exit(1);
 172:	4505                	li	a0,1
 174:	3d2000ef          	jal	546 <exit>
    printf("FAIL: expected priority 5, got %d\n", prio);
 178:	85ca                	mv	a1,s2
 17a:	00001517          	auipc	a0,0x1
 17e:	ade50513          	addi	a0,a0,-1314 # c58 <malloc+0x20e>
 182:	015000ef          	jal	996 <printf>
    exit(1);
 186:	4505                	li	a0,1
 188:	3be000ef          	jal	546 <exit>
    printf("FAIL: should have returned -1\n");
 18c:	00001517          	auipc	a0,0x1
 190:	b3450513          	addi	a0,a0,-1228 # cc0 <malloc+0x276>
 194:	003000ef          	jal	996 <printf>
    exit(1);
 198:	4505                	li	a0,1
 19a:	3ac000ef          	jal	546 <exit>
    printf("FAIL: should have returned -1\n");
 19e:	00001517          	auipc	a0,0x1
 1a2:	b2250513          	addi	a0,a0,-1246 # cc0 <malloc+0x276>
 1a6:	7f0000ef          	jal	996 <printf>
    exit(1);
 1aa:	4505                	li	a0,1
 1ac:	39a000ef          	jal	546 <exit>
    printf("FAIL: fork failed\n");
 1b0:	00001517          	auipc	a0,0x1
 1b4:	bc850513          	addi	a0,a0,-1080 # d78 <malloc+0x32e>
 1b8:	7de000ef          	jal	996 <printf>
    exit(1);
 1bc:	4505                	li	a0,1
 1be:	388000ef          	jal	546 <exit>
    exit(0);
 1c2:	4501                	li	a0,0
 1c4:	382000ef          	jal	546 <exit>
  wait(&status);
 1c8:	fdc40513          	addi	a0,s0,-36
 1cc:	382000ef          	jal	54e <wait>
  setpriority(getpid(), 10);
 1d0:	3f6000ef          	jal	5c6 <getpid>
 1d4:	45a9                	li	a1,10
 1d6:	418000ef          	jal	5ee <setpriority>
  printf("Test 2 PASSED\n\n");
 1da:	00001517          	auipc	a0,0x1
 1de:	bfe50513          	addi	a0,a0,-1026 # dd8 <malloc+0x38e>
 1e2:	7b4000ef          	jal	996 <printf>
  printf("--- Test 3: High-priority process runs first ---\n");
 1e6:	00001517          	auipc	a0,0x1
 1ea:	c0250513          	addi	a0,a0,-1022 # de8 <malloc+0x39e>
 1ee:	7a8000ef          	jal	996 <printf>
  pids[0] = fork();
 1f2:	34c000ef          	jal	53e <fork>
  if (pids[0] == 0) {
 1f6:	c131                	beqz	a0,23a <main+0x214>
  pids[1] = fork();
 1f8:	346000ef          	jal	53e <fork>
  if (pids[1] == 0) {
 1fc:	c13d                	beqz	a0,262 <main+0x23c>
  pids[2] = fork();
 1fe:	340000ef          	jal	53e <fork>
  if (pids[2] == 0) {
 202:	c541                	beqz	a0,28a <main+0x264>
    wait(&status);
 204:	fdc40513          	addi	a0,s0,-36
 208:	346000ef          	jal	54e <wait>
 20c:	fdc40513          	addi	a0,s0,-36
 210:	33e000ef          	jal	54e <wait>
 214:	fdc40513          	addi	a0,s0,-36
 218:	336000ef          	jal	54e <wait>
  printf("Test 3 PASSED\n\n");
 21c:	00001517          	auipc	a0,0x1
 220:	c5c50513          	addi	a0,a0,-932 # e78 <malloc+0x42e>
 224:	772000ef          	jal	996 <printf>

  test_basic();
  test_inheritance();
  test_scheduling_order();

  printf("All tests passed!\n");
 228:	00001517          	auipc	a0,0x1
 22c:	c6050513          	addi	a0,a0,-928 # e88 <malloc+0x43e>
 230:	766000ef          	jal	996 <printf>
  exit(0);
 234:	4501                	li	a0,0
 236:	310000ef          	jal	546 <exit>
    setpriority(getpid(), 19);
 23a:	38c000ef          	jal	5c6 <getpid>
 23e:	45cd                	li	a1,19
 240:	3ae000ef          	jal	5ee <setpriority>
    burn(5000000);
 244:	004c5537          	lui	a0,0x4c5
 248:	b4050513          	addi	a0,a0,-1216 # 4c4b40 <base+0x4c2b30>
 24c:	db5ff0ef          	jal	0 <burn>
    printf("[LOW  prio=19] finished\n");
 250:	00001517          	auipc	a0,0x1
 254:	bd050513          	addi	a0,a0,-1072 # e20 <malloc+0x3d6>
 258:	73e000ef          	jal	996 <printf>
    exit(0);
 25c:	4501                	li	a0,0
 25e:	2e8000ef          	jal	546 <exit>
    setpriority(getpid(), 10);
 262:	364000ef          	jal	5c6 <getpid>
 266:	45a9                	li	a1,10
 268:	386000ef          	jal	5ee <setpriority>
    burn(5000000);
 26c:	004c5537          	lui	a0,0x4c5
 270:	b4050513          	addi	a0,a0,-1216 # 4c4b40 <base+0x4c2b30>
 274:	d8dff0ef          	jal	0 <burn>
    printf("[MED  prio=10] finished\n");
 278:	00001517          	auipc	a0,0x1
 27c:	bc850513          	addi	a0,a0,-1080 # e40 <malloc+0x3f6>
 280:	716000ef          	jal	996 <printf>
    exit(0);
 284:	4501                	li	a0,0
 286:	2c0000ef          	jal	546 <exit>
    setpriority(getpid(), 1);
 28a:	33c000ef          	jal	5c6 <getpid>
 28e:	4585                	li	a1,1
 290:	35e000ef          	jal	5ee <setpriority>
    burn(50000000);
 294:	02faf537          	lui	a0,0x2faf
 298:	08050513          	addi	a0,a0,128 # 2faf080 <base+0x2fad070>
 29c:	d65ff0ef          	jal	0 <burn>
    printf("[HIGH prio=1] finished\n");
 2a0:	00001517          	auipc	a0,0x1
 2a4:	bc050513          	addi	a0,a0,-1088 # e60 <malloc+0x416>
 2a8:	6ee000ef          	jal	996 <printf>
    exit(0);
 2ac:	4501                	li	a0,0
 2ae:	298000ef          	jal	546 <exit>

00000000000002b2 <start>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
start(int argc, char **argv)
{
 2b2:	1141                	addi	sp,sp,-16
 2b4:	e406                	sd	ra,8(sp)
 2b6:	e022                	sd	s0,0(sp)
 2b8:	0800                	addi	s0,sp,16
  int r;
  extern int main(int argc, char **argv);
  r = main(argc, argv);
 2ba:	d6dff0ef          	jal	26 <main>
  exit(r);
 2be:	288000ef          	jal	546 <exit>

00000000000002c2 <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 2c2:	1141                	addi	sp,sp,-16
 2c4:	e422                	sd	s0,8(sp)
 2c6:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 2c8:	87aa                	mv	a5,a0
 2ca:	0585                	addi	a1,a1,1
 2cc:	0785                	addi	a5,a5,1
 2ce:	fff5c703          	lbu	a4,-1(a1)
 2d2:	fee78fa3          	sb	a4,-1(a5)
 2d6:	fb75                	bnez	a4,2ca <strcpy+0x8>
    ;
  return os;
}
 2d8:	6422                	ld	s0,8(sp)
 2da:	0141                	addi	sp,sp,16
 2dc:	8082                	ret

00000000000002de <strcmp>:

int
strcmp(const char *p, const char *q)
{
 2de:	1141                	addi	sp,sp,-16
 2e0:	e422                	sd	s0,8(sp)
 2e2:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 2e4:	00054783          	lbu	a5,0(a0)
 2e8:	cb91                	beqz	a5,2fc <strcmp+0x1e>
 2ea:	0005c703          	lbu	a4,0(a1)
 2ee:	00f71763          	bne	a4,a5,2fc <strcmp+0x1e>
    p++, q++;
 2f2:	0505                	addi	a0,a0,1
 2f4:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 2f6:	00054783          	lbu	a5,0(a0)
 2fa:	fbe5                	bnez	a5,2ea <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 2fc:	0005c503          	lbu	a0,0(a1)
}
 300:	40a7853b          	subw	a0,a5,a0
 304:	6422                	ld	s0,8(sp)
 306:	0141                	addi	sp,sp,16
 308:	8082                	ret

000000000000030a <strlen>:

uint
strlen(const char *s)
{
 30a:	1141                	addi	sp,sp,-16
 30c:	e422                	sd	s0,8(sp)
 30e:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 310:	00054783          	lbu	a5,0(a0)
 314:	cf91                	beqz	a5,330 <strlen+0x26>
 316:	0505                	addi	a0,a0,1
 318:	87aa                	mv	a5,a0
 31a:	86be                	mv	a3,a5
 31c:	0785                	addi	a5,a5,1
 31e:	fff7c703          	lbu	a4,-1(a5)
 322:	ff65                	bnez	a4,31a <strlen+0x10>
 324:	40a6853b          	subw	a0,a3,a0
 328:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 32a:	6422                	ld	s0,8(sp)
 32c:	0141                	addi	sp,sp,16
 32e:	8082                	ret
  for(n = 0; s[n]; n++)
 330:	4501                	li	a0,0
 332:	bfe5                	j	32a <strlen+0x20>

0000000000000334 <memset>:

void*
memset(void *dst, int c, uint n)
{
 334:	1141                	addi	sp,sp,-16
 336:	e422                	sd	s0,8(sp)
 338:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 33a:	ca19                	beqz	a2,350 <memset+0x1c>
 33c:	87aa                	mv	a5,a0
 33e:	1602                	slli	a2,a2,0x20
 340:	9201                	srli	a2,a2,0x20
 342:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 346:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 34a:	0785                	addi	a5,a5,1
 34c:	fee79de3          	bne	a5,a4,346 <memset+0x12>
  }
  return dst;
}
 350:	6422                	ld	s0,8(sp)
 352:	0141                	addi	sp,sp,16
 354:	8082                	ret

0000000000000356 <strchr>:

char*
strchr(const char *s, char c)
{
 356:	1141                	addi	sp,sp,-16
 358:	e422                	sd	s0,8(sp)
 35a:	0800                	addi	s0,sp,16
  for(; *s; s++)
 35c:	00054783          	lbu	a5,0(a0)
 360:	cb99                	beqz	a5,376 <strchr+0x20>
    if(*s == c)
 362:	00f58763          	beq	a1,a5,370 <strchr+0x1a>
  for(; *s; s++)
 366:	0505                	addi	a0,a0,1
 368:	00054783          	lbu	a5,0(a0)
 36c:	fbfd                	bnez	a5,362 <strchr+0xc>
      return (char*)s;
  return 0;
 36e:	4501                	li	a0,0
}
 370:	6422                	ld	s0,8(sp)
 372:	0141                	addi	sp,sp,16
 374:	8082                	ret
  return 0;
 376:	4501                	li	a0,0
 378:	bfe5                	j	370 <strchr+0x1a>

000000000000037a <gets>:

char*
gets(char *buf, int max)
{
 37a:	711d                	addi	sp,sp,-96
 37c:	ec86                	sd	ra,88(sp)
 37e:	e8a2                	sd	s0,80(sp)
 380:	e4a6                	sd	s1,72(sp)
 382:	e0ca                	sd	s2,64(sp)
 384:	fc4e                	sd	s3,56(sp)
 386:	f852                	sd	s4,48(sp)
 388:	f456                	sd	s5,40(sp)
 38a:	f05a                	sd	s6,32(sp)
 38c:	ec5e                	sd	s7,24(sp)
 38e:	1080                	addi	s0,sp,96
 390:	8baa                	mv	s7,a0
 392:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 394:	892a                	mv	s2,a0
 396:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 398:	4aa9                	li	s5,10
 39a:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 39c:	89a6                	mv	s3,s1
 39e:	2485                	addiw	s1,s1,1
 3a0:	0344d663          	bge	s1,s4,3cc <gets+0x52>
    cc = read(0, &c, 1);
 3a4:	4605                	li	a2,1
 3a6:	faf40593          	addi	a1,s0,-81
 3aa:	4501                	li	a0,0
 3ac:	1b2000ef          	jal	55e <read>
    if(cc < 1)
 3b0:	00a05e63          	blez	a0,3cc <gets+0x52>
    buf[i++] = c;
 3b4:	faf44783          	lbu	a5,-81(s0)
 3b8:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 3bc:	01578763          	beq	a5,s5,3ca <gets+0x50>
 3c0:	0905                	addi	s2,s2,1
 3c2:	fd679de3          	bne	a5,s6,39c <gets+0x22>
    buf[i++] = c;
 3c6:	89a6                	mv	s3,s1
 3c8:	a011                	j	3cc <gets+0x52>
 3ca:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 3cc:	99de                	add	s3,s3,s7
 3ce:	00098023          	sb	zero,0(s3)
  return buf;
}
 3d2:	855e                	mv	a0,s7
 3d4:	60e6                	ld	ra,88(sp)
 3d6:	6446                	ld	s0,80(sp)
 3d8:	64a6                	ld	s1,72(sp)
 3da:	6906                	ld	s2,64(sp)
 3dc:	79e2                	ld	s3,56(sp)
 3de:	7a42                	ld	s4,48(sp)
 3e0:	7aa2                	ld	s5,40(sp)
 3e2:	7b02                	ld	s6,32(sp)
 3e4:	6be2                	ld	s7,24(sp)
 3e6:	6125                	addi	sp,sp,96
 3e8:	8082                	ret

00000000000003ea <stat>:

int
stat(const char *n, struct stat *st)
{
 3ea:	1101                	addi	sp,sp,-32
 3ec:	ec06                	sd	ra,24(sp)
 3ee:	e822                	sd	s0,16(sp)
 3f0:	e04a                	sd	s2,0(sp)
 3f2:	1000                	addi	s0,sp,32
 3f4:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 3f6:	4581                	li	a1,0
 3f8:	18e000ef          	jal	586 <open>
  if(fd < 0)
 3fc:	02054263          	bltz	a0,420 <stat+0x36>
 400:	e426                	sd	s1,8(sp)
 402:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 404:	85ca                	mv	a1,s2
 406:	198000ef          	jal	59e <fstat>
 40a:	892a                	mv	s2,a0
  close(fd);
 40c:	8526                	mv	a0,s1
 40e:	160000ef          	jal	56e <close>
  return r;
 412:	64a2                	ld	s1,8(sp)
}
 414:	854a                	mv	a0,s2
 416:	60e2                	ld	ra,24(sp)
 418:	6442                	ld	s0,16(sp)
 41a:	6902                	ld	s2,0(sp)
 41c:	6105                	addi	sp,sp,32
 41e:	8082                	ret
    return -1;
 420:	597d                	li	s2,-1
 422:	bfcd                	j	414 <stat+0x2a>

0000000000000424 <atoi>:

int
atoi(const char *s)
{
 424:	1141                	addi	sp,sp,-16
 426:	e422                	sd	s0,8(sp)
 428:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 42a:	00054683          	lbu	a3,0(a0)
 42e:	fd06879b          	addiw	a5,a3,-48
 432:	0ff7f793          	zext.b	a5,a5
 436:	4625                	li	a2,9
 438:	02f66863          	bltu	a2,a5,468 <atoi+0x44>
 43c:	872a                	mv	a4,a0
  n = 0;
 43e:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 440:	0705                	addi	a4,a4,1
 442:	0025179b          	slliw	a5,a0,0x2
 446:	9fa9                	addw	a5,a5,a0
 448:	0017979b          	slliw	a5,a5,0x1
 44c:	9fb5                	addw	a5,a5,a3
 44e:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 452:	00074683          	lbu	a3,0(a4)
 456:	fd06879b          	addiw	a5,a3,-48
 45a:	0ff7f793          	zext.b	a5,a5
 45e:	fef671e3          	bgeu	a2,a5,440 <atoi+0x1c>
  return n;
}
 462:	6422                	ld	s0,8(sp)
 464:	0141                	addi	sp,sp,16
 466:	8082                	ret
  n = 0;
 468:	4501                	li	a0,0
 46a:	bfe5                	j	462 <atoi+0x3e>

000000000000046c <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 46c:	1141                	addi	sp,sp,-16
 46e:	e422                	sd	s0,8(sp)
 470:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 472:	02b57463          	bgeu	a0,a1,49a <memmove+0x2e>
    while(n-- > 0)
 476:	00c05f63          	blez	a2,494 <memmove+0x28>
 47a:	1602                	slli	a2,a2,0x20
 47c:	9201                	srli	a2,a2,0x20
 47e:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 482:	872a                	mv	a4,a0
      *dst++ = *src++;
 484:	0585                	addi	a1,a1,1
 486:	0705                	addi	a4,a4,1
 488:	fff5c683          	lbu	a3,-1(a1)
 48c:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 490:	fef71ae3          	bne	a4,a5,484 <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 494:	6422                	ld	s0,8(sp)
 496:	0141                	addi	sp,sp,16
 498:	8082                	ret
    dst += n;
 49a:	00c50733          	add	a4,a0,a2
    src += n;
 49e:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 4a0:	fec05ae3          	blez	a2,494 <memmove+0x28>
 4a4:	fff6079b          	addiw	a5,a2,-1
 4a8:	1782                	slli	a5,a5,0x20
 4aa:	9381                	srli	a5,a5,0x20
 4ac:	fff7c793          	not	a5,a5
 4b0:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 4b2:	15fd                	addi	a1,a1,-1
 4b4:	177d                	addi	a4,a4,-1
 4b6:	0005c683          	lbu	a3,0(a1)
 4ba:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 4be:	fee79ae3          	bne	a5,a4,4b2 <memmove+0x46>
 4c2:	bfc9                	j	494 <memmove+0x28>

00000000000004c4 <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 4c4:	1141                	addi	sp,sp,-16
 4c6:	e422                	sd	s0,8(sp)
 4c8:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 4ca:	ca05                	beqz	a2,4fa <memcmp+0x36>
 4cc:	fff6069b          	addiw	a3,a2,-1
 4d0:	1682                	slli	a3,a3,0x20
 4d2:	9281                	srli	a3,a3,0x20
 4d4:	0685                	addi	a3,a3,1
 4d6:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 4d8:	00054783          	lbu	a5,0(a0)
 4dc:	0005c703          	lbu	a4,0(a1)
 4e0:	00e79863          	bne	a5,a4,4f0 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 4e4:	0505                	addi	a0,a0,1
    p2++;
 4e6:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 4e8:	fed518e3          	bne	a0,a3,4d8 <memcmp+0x14>
  }
  return 0;
 4ec:	4501                	li	a0,0
 4ee:	a019                	j	4f4 <memcmp+0x30>
      return *p1 - *p2;
 4f0:	40e7853b          	subw	a0,a5,a4
}
 4f4:	6422                	ld	s0,8(sp)
 4f6:	0141                	addi	sp,sp,16
 4f8:	8082                	ret
  return 0;
 4fa:	4501                	li	a0,0
 4fc:	bfe5                	j	4f4 <memcmp+0x30>

00000000000004fe <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 4fe:	1141                	addi	sp,sp,-16
 500:	e406                	sd	ra,8(sp)
 502:	e022                	sd	s0,0(sp)
 504:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 506:	f67ff0ef          	jal	46c <memmove>
}
 50a:	60a2                	ld	ra,8(sp)
 50c:	6402                	ld	s0,0(sp)
 50e:	0141                	addi	sp,sp,16
 510:	8082                	ret

0000000000000512 <sbrk>:

char *
sbrk(int n) {
 512:	1141                	addi	sp,sp,-16
 514:	e406                	sd	ra,8(sp)
 516:	e022                	sd	s0,0(sp)
 518:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_EAGER);
 51a:	4585                	li	a1,1
 51c:	0b2000ef          	jal	5ce <sys_sbrk>
}
 520:	60a2                	ld	ra,8(sp)
 522:	6402                	ld	s0,0(sp)
 524:	0141                	addi	sp,sp,16
 526:	8082                	ret

0000000000000528 <sbrklazy>:

char *
sbrklazy(int n) {
 528:	1141                	addi	sp,sp,-16
 52a:	e406                	sd	ra,8(sp)
 52c:	e022                	sd	s0,0(sp)
 52e:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_LAZY);
 530:	4589                	li	a1,2
 532:	09c000ef          	jal	5ce <sys_sbrk>
}
 536:	60a2                	ld	ra,8(sp)
 538:	6402                	ld	s0,0(sp)
 53a:	0141                	addi	sp,sp,16
 53c:	8082                	ret

000000000000053e <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 53e:	4885                	li	a7,1
 ecall
 540:	00000073          	ecall
 ret
 544:	8082                	ret

0000000000000546 <exit>:
.global exit
exit:
 li a7, SYS_exit
 546:	4889                	li	a7,2
 ecall
 548:	00000073          	ecall
 ret
 54c:	8082                	ret

000000000000054e <wait>:
.global wait
wait:
 li a7, SYS_wait
 54e:	488d                	li	a7,3
 ecall
 550:	00000073          	ecall
 ret
 554:	8082                	ret

0000000000000556 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 556:	4891                	li	a7,4
 ecall
 558:	00000073          	ecall
 ret
 55c:	8082                	ret

000000000000055e <read>:
.global read
read:
 li a7, SYS_read
 55e:	4895                	li	a7,5
 ecall
 560:	00000073          	ecall
 ret
 564:	8082                	ret

0000000000000566 <write>:
.global write
write:
 li a7, SYS_write
 566:	48c1                	li	a7,16
 ecall
 568:	00000073          	ecall
 ret
 56c:	8082                	ret

000000000000056e <close>:
.global close
close:
 li a7, SYS_close
 56e:	48d5                	li	a7,21
 ecall
 570:	00000073          	ecall
 ret
 574:	8082                	ret

0000000000000576 <kill>:
.global kill
kill:
 li a7, SYS_kill
 576:	4899                	li	a7,6
 ecall
 578:	00000073          	ecall
 ret
 57c:	8082                	ret

000000000000057e <exec>:
.global exec
exec:
 li a7, SYS_exec
 57e:	489d                	li	a7,7
 ecall
 580:	00000073          	ecall
 ret
 584:	8082                	ret

0000000000000586 <open>:
.global open
open:
 li a7, SYS_open
 586:	48bd                	li	a7,15
 ecall
 588:	00000073          	ecall
 ret
 58c:	8082                	ret

000000000000058e <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 58e:	48c5                	li	a7,17
 ecall
 590:	00000073          	ecall
 ret
 594:	8082                	ret

0000000000000596 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 596:	48c9                	li	a7,18
 ecall
 598:	00000073          	ecall
 ret
 59c:	8082                	ret

000000000000059e <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 59e:	48a1                	li	a7,8
 ecall
 5a0:	00000073          	ecall
 ret
 5a4:	8082                	ret

00000000000005a6 <link>:
.global link
link:
 li a7, SYS_link
 5a6:	48cd                	li	a7,19
 ecall
 5a8:	00000073          	ecall
 ret
 5ac:	8082                	ret

00000000000005ae <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 5ae:	48d1                	li	a7,20
 ecall
 5b0:	00000073          	ecall
 ret
 5b4:	8082                	ret

00000000000005b6 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 5b6:	48a5                	li	a7,9
 ecall
 5b8:	00000073          	ecall
 ret
 5bc:	8082                	ret

00000000000005be <dup>:
.global dup
dup:
 li a7, SYS_dup
 5be:	48a9                	li	a7,10
 ecall
 5c0:	00000073          	ecall
 ret
 5c4:	8082                	ret

00000000000005c6 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 5c6:	48ad                	li	a7,11
 ecall
 5c8:	00000073          	ecall
 ret
 5cc:	8082                	ret

00000000000005ce <sys_sbrk>:
.global sys_sbrk
sys_sbrk:
 li a7, SYS_sbrk
 5ce:	48b1                	li	a7,12
 ecall
 5d0:	00000073          	ecall
 ret
 5d4:	8082                	ret

00000000000005d6 <pause>:
.global pause
pause:
 li a7, SYS_pause
 5d6:	48b5                	li	a7,13
 ecall
 5d8:	00000073          	ecall
 ret
 5dc:	8082                	ret

00000000000005de <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 5de:	48b9                	li	a7,14
 ecall
 5e0:	00000073          	ecall
 ret
 5e4:	8082                	ret

00000000000005e6 <trace>:
.global trace
trace:
 li a7, SYS_trace
 5e6:	48d9                	li	a7,22
 ecall
 5e8:	00000073          	ecall
 ret
 5ec:	8082                	ret

00000000000005ee <setpriority>:
.global setpriority
setpriority:
 li a7, SYS_setpriority
 5ee:	48dd                	li	a7,23
 ecall
 5f0:	00000073          	ecall
 ret
 5f4:	8082                	ret

00000000000005f6 <getpriority>:
.global getpriority
getpriority:
 li a7, SYS_getpriority
 5f6:	48e1                	li	a7,24
 ecall
 5f8:	00000073          	ecall
 ret
 5fc:	8082                	ret

00000000000005fe <getmemstat>:
.global getmemstat
getmemstat:
 li a7, SYS_getmemstat
 5fe:	48e5                	li	a7,25
 ecall
 600:	00000073          	ecall
 ret
 604:	8082                	ret

0000000000000606 <setmemquota>:
.global setmemquota
setmemquota:
 li a7, SYS_setmemquota
 606:	48e9                	li	a7,26
 ecall
 608:	00000073          	ecall
 ret
 60c:	8082                	ret

000000000000060e <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 60e:	1101                	addi	sp,sp,-32
 610:	ec06                	sd	ra,24(sp)
 612:	e822                	sd	s0,16(sp)
 614:	1000                	addi	s0,sp,32
 616:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 61a:	4605                	li	a2,1
 61c:	fef40593          	addi	a1,s0,-17
 620:	f47ff0ef          	jal	566 <write>
}
 624:	60e2                	ld	ra,24(sp)
 626:	6442                	ld	s0,16(sp)
 628:	6105                	addi	sp,sp,32
 62a:	8082                	ret

000000000000062c <printint>:

static void
printint(int fd, long long xx, int base, int sgn)
{
 62c:	715d                	addi	sp,sp,-80
 62e:	e486                	sd	ra,72(sp)
 630:	e0a2                	sd	s0,64(sp)
 632:	f84a                	sd	s2,48(sp)
 634:	0880                	addi	s0,sp,80
 636:	892a                	mv	s2,a0
  char buf[20];
  int i, neg;
  unsigned long long x;

  neg = 0;
  if(sgn && xx < 0){
 638:	c299                	beqz	a3,63e <printint+0x12>
 63a:	0805c363          	bltz	a1,6c0 <printint+0x94>
  neg = 0;
 63e:	4881                	li	a7,0
 640:	fb840693          	addi	a3,s0,-72
    x = -xx;
  } else {
    x = xx;
  }

  i = 0;
 644:	4781                	li	a5,0
  do{
    buf[i++] = digits[x % base];
 646:	00001517          	auipc	a0,0x1
 64a:	86250513          	addi	a0,a0,-1950 # ea8 <digits>
 64e:	883e                	mv	a6,a5
 650:	2785                	addiw	a5,a5,1
 652:	02c5f733          	remu	a4,a1,a2
 656:	972a                	add	a4,a4,a0
 658:	00074703          	lbu	a4,0(a4)
 65c:	00e68023          	sb	a4,0(a3)
  }while((x /= base) != 0);
 660:	872e                	mv	a4,a1
 662:	02c5d5b3          	divu	a1,a1,a2
 666:	0685                	addi	a3,a3,1
 668:	fec773e3          	bgeu	a4,a2,64e <printint+0x22>
  if(neg)
 66c:	00088b63          	beqz	a7,682 <printint+0x56>
    buf[i++] = '-';
 670:	fd078793          	addi	a5,a5,-48
 674:	97a2                	add	a5,a5,s0
 676:	02d00713          	li	a4,45
 67a:	fee78423          	sb	a4,-24(a5)
 67e:	0028079b          	addiw	a5,a6,2

  while(--i >= 0)
 682:	02f05a63          	blez	a5,6b6 <printint+0x8a>
 686:	fc26                	sd	s1,56(sp)
 688:	f44e                	sd	s3,40(sp)
 68a:	fb840713          	addi	a4,s0,-72
 68e:	00f704b3          	add	s1,a4,a5
 692:	fff70993          	addi	s3,a4,-1
 696:	99be                	add	s3,s3,a5
 698:	37fd                	addiw	a5,a5,-1
 69a:	1782                	slli	a5,a5,0x20
 69c:	9381                	srli	a5,a5,0x20
 69e:	40f989b3          	sub	s3,s3,a5
    putc(fd, buf[i]);
 6a2:	fff4c583          	lbu	a1,-1(s1)
 6a6:	854a                	mv	a0,s2
 6a8:	f67ff0ef          	jal	60e <putc>
  while(--i >= 0)
 6ac:	14fd                	addi	s1,s1,-1
 6ae:	ff349ae3          	bne	s1,s3,6a2 <printint+0x76>
 6b2:	74e2                	ld	s1,56(sp)
 6b4:	79a2                	ld	s3,40(sp)
}
 6b6:	60a6                	ld	ra,72(sp)
 6b8:	6406                	ld	s0,64(sp)
 6ba:	7942                	ld	s2,48(sp)
 6bc:	6161                	addi	sp,sp,80
 6be:	8082                	ret
    x = -xx;
 6c0:	40b005b3          	neg	a1,a1
    neg = 1;
 6c4:	4885                	li	a7,1
    x = -xx;
 6c6:	bfad                	j	640 <printint+0x14>

00000000000006c8 <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %c, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 6c8:	711d                	addi	sp,sp,-96
 6ca:	ec86                	sd	ra,88(sp)
 6cc:	e8a2                	sd	s0,80(sp)
 6ce:	e0ca                	sd	s2,64(sp)
 6d0:	1080                	addi	s0,sp,96
  char *s;
  int c0, c1, c2, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 6d2:	0005c903          	lbu	s2,0(a1)
 6d6:	28090663          	beqz	s2,962 <vprintf+0x29a>
 6da:	e4a6                	sd	s1,72(sp)
 6dc:	fc4e                	sd	s3,56(sp)
 6de:	f852                	sd	s4,48(sp)
 6e0:	f456                	sd	s5,40(sp)
 6e2:	f05a                	sd	s6,32(sp)
 6e4:	ec5e                	sd	s7,24(sp)
 6e6:	e862                	sd	s8,16(sp)
 6e8:	e466                	sd	s9,8(sp)
 6ea:	8b2a                	mv	s6,a0
 6ec:	8a2e                	mv	s4,a1
 6ee:	8bb2                	mv	s7,a2
  state = 0;
 6f0:	4981                	li	s3,0
  for(i = 0; fmt[i]; i++){
 6f2:	4481                	li	s1,0
 6f4:	4701                	li	a4,0
      if(c0 == '%'){
        state = '%';
      } else {
        putc(fd, c0);
      }
    } else if(state == '%'){
 6f6:	02500a93          	li	s5,37
      c1 = c2 = 0;
      if(c0) c1 = fmt[i+1] & 0xff;
      if(c1) c2 = fmt[i+2] & 0xff;
      if(c0 == 'd'){
 6fa:	06400c13          	li	s8,100
        printint(fd, va_arg(ap, int), 10, 1);
      } else if(c0 == 'l' && c1 == 'd'){
 6fe:	06c00c93          	li	s9,108
 702:	a005                	j	722 <vprintf+0x5a>
        putc(fd, c0);
 704:	85ca                	mv	a1,s2
 706:	855a                	mv	a0,s6
 708:	f07ff0ef          	jal	60e <putc>
 70c:	a019                	j	712 <vprintf+0x4a>
    } else if(state == '%'){
 70e:	03598263          	beq	s3,s5,732 <vprintf+0x6a>
  for(i = 0; fmt[i]; i++){
 712:	2485                	addiw	s1,s1,1
 714:	8726                	mv	a4,s1
 716:	009a07b3          	add	a5,s4,s1
 71a:	0007c903          	lbu	s2,0(a5)
 71e:	22090a63          	beqz	s2,952 <vprintf+0x28a>
    c0 = fmt[i] & 0xff;
 722:	0009079b          	sext.w	a5,s2
    if(state == 0){
 726:	fe0994e3          	bnez	s3,70e <vprintf+0x46>
      if(c0 == '%'){
 72a:	fd579de3          	bne	a5,s5,704 <vprintf+0x3c>
        state = '%';
 72e:	89be                	mv	s3,a5
 730:	b7cd                	j	712 <vprintf+0x4a>
      if(c0) c1 = fmt[i+1] & 0xff;
 732:	00ea06b3          	add	a3,s4,a4
 736:	0016c683          	lbu	a3,1(a3)
      c1 = c2 = 0;
 73a:	8636                	mv	a2,a3
      if(c1) c2 = fmt[i+2] & 0xff;
 73c:	c681                	beqz	a3,744 <vprintf+0x7c>
 73e:	9752                	add	a4,a4,s4
 740:	00274603          	lbu	a2,2(a4)
      if(c0 == 'd'){
 744:	05878363          	beq	a5,s8,78a <vprintf+0xc2>
      } else if(c0 == 'l' && c1 == 'd'){
 748:	05978d63          	beq	a5,s9,7a2 <vprintf+0xda>
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 2;
      } else if(c0 == 'u'){
 74c:	07500713          	li	a4,117
 750:	0ee78763          	beq	a5,a4,83e <vprintf+0x176>
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 2;
      } else if(c0 == 'x'){
 754:	07800713          	li	a4,120
 758:	12e78963          	beq	a5,a4,88a <vprintf+0x1c2>
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 2;
      } else if(c0 == 'p'){
 75c:	07000713          	li	a4,112
 760:	14e78e63          	beq	a5,a4,8bc <vprintf+0x1f4>
        printptr(fd, va_arg(ap, uint64));
      } else if(c0 == 'c'){
 764:	06300713          	li	a4,99
 768:	18e78e63          	beq	a5,a4,904 <vprintf+0x23c>
        putc(fd, va_arg(ap, uint32));
      } else if(c0 == 's'){
 76c:	07300713          	li	a4,115
 770:	1ae78463          	beq	a5,a4,918 <vprintf+0x250>
        if((s = va_arg(ap, char*)) == 0)
          s = "(null)";
        for(; *s; s++)
          putc(fd, *s);
      } else if(c0 == '%'){
 774:	02500713          	li	a4,37
 778:	04e79563          	bne	a5,a4,7c2 <vprintf+0xfa>
        putc(fd, '%');
 77c:	02500593          	li	a1,37
 780:	855a                	mv	a0,s6
 782:	e8dff0ef          	jal	60e <putc>
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c0);
      }

      state = 0;
 786:	4981                	li	s3,0
 788:	b769                	j	712 <vprintf+0x4a>
        printint(fd, va_arg(ap, int), 10, 1);
 78a:	008b8913          	addi	s2,s7,8
 78e:	4685                	li	a3,1
 790:	4629                	li	a2,10
 792:	000ba583          	lw	a1,0(s7)
 796:	855a                	mv	a0,s6
 798:	e95ff0ef          	jal	62c <printint>
 79c:	8bca                	mv	s7,s2
      state = 0;
 79e:	4981                	li	s3,0
 7a0:	bf8d                	j	712 <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'd'){
 7a2:	06400793          	li	a5,100
 7a6:	02f68963          	beq	a3,a5,7d8 <vprintf+0x110>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 7aa:	06c00793          	li	a5,108
 7ae:	04f68263          	beq	a3,a5,7f2 <vprintf+0x12a>
      } else if(c0 == 'l' && c1 == 'u'){
 7b2:	07500793          	li	a5,117
 7b6:	0af68063          	beq	a3,a5,856 <vprintf+0x18e>
      } else if(c0 == 'l' && c1 == 'x'){
 7ba:	07800793          	li	a5,120
 7be:	0ef68263          	beq	a3,a5,8a2 <vprintf+0x1da>
        putc(fd, '%');
 7c2:	02500593          	li	a1,37
 7c6:	855a                	mv	a0,s6
 7c8:	e47ff0ef          	jal	60e <putc>
        putc(fd, c0);
 7cc:	85ca                	mv	a1,s2
 7ce:	855a                	mv	a0,s6
 7d0:	e3fff0ef          	jal	60e <putc>
      state = 0;
 7d4:	4981                	li	s3,0
 7d6:	bf35                	j	712 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 7d8:	008b8913          	addi	s2,s7,8
 7dc:	4685                	li	a3,1
 7de:	4629                	li	a2,10
 7e0:	000bb583          	ld	a1,0(s7)
 7e4:	855a                	mv	a0,s6
 7e6:	e47ff0ef          	jal	62c <printint>
        i += 1;
 7ea:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 1);
 7ec:	8bca                	mv	s7,s2
      state = 0;
 7ee:	4981                	li	s3,0
        i += 1;
 7f0:	b70d                	j	712 <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 7f2:	06400793          	li	a5,100
 7f6:	02f60763          	beq	a2,a5,824 <vprintf+0x15c>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
 7fa:	07500793          	li	a5,117
 7fe:	06f60963          	beq	a2,a5,870 <vprintf+0x1a8>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
 802:	07800793          	li	a5,120
 806:	faf61ee3          	bne	a2,a5,7c2 <vprintf+0xfa>
        printint(fd, va_arg(ap, uint64), 16, 0);
 80a:	008b8913          	addi	s2,s7,8
 80e:	4681                	li	a3,0
 810:	4641                	li	a2,16
 812:	000bb583          	ld	a1,0(s7)
 816:	855a                	mv	a0,s6
 818:	e15ff0ef          	jal	62c <printint>
        i += 2;
 81c:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 16, 0);
 81e:	8bca                	mv	s7,s2
      state = 0;
 820:	4981                	li	s3,0
        i += 2;
 822:	bdc5                	j	712 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 824:	008b8913          	addi	s2,s7,8
 828:	4685                	li	a3,1
 82a:	4629                	li	a2,10
 82c:	000bb583          	ld	a1,0(s7)
 830:	855a                	mv	a0,s6
 832:	dfbff0ef          	jal	62c <printint>
        i += 2;
 836:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 1);
 838:	8bca                	mv	s7,s2
      state = 0;
 83a:	4981                	li	s3,0
        i += 2;
 83c:	bdd9                	j	712 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 10, 0);
 83e:	008b8913          	addi	s2,s7,8
 842:	4681                	li	a3,0
 844:	4629                	li	a2,10
 846:	000be583          	lwu	a1,0(s7)
 84a:	855a                	mv	a0,s6
 84c:	de1ff0ef          	jal	62c <printint>
 850:	8bca                	mv	s7,s2
      state = 0;
 852:	4981                	li	s3,0
 854:	bd7d                	j	712 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 856:	008b8913          	addi	s2,s7,8
 85a:	4681                	li	a3,0
 85c:	4629                	li	a2,10
 85e:	000bb583          	ld	a1,0(s7)
 862:	855a                	mv	a0,s6
 864:	dc9ff0ef          	jal	62c <printint>
        i += 1;
 868:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 0);
 86a:	8bca                	mv	s7,s2
      state = 0;
 86c:	4981                	li	s3,0
        i += 1;
 86e:	b555                	j	712 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 870:	008b8913          	addi	s2,s7,8
 874:	4681                	li	a3,0
 876:	4629                	li	a2,10
 878:	000bb583          	ld	a1,0(s7)
 87c:	855a                	mv	a0,s6
 87e:	dafff0ef          	jal	62c <printint>
        i += 2;
 882:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 0);
 884:	8bca                	mv	s7,s2
      state = 0;
 886:	4981                	li	s3,0
        i += 2;
 888:	b569                	j	712 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 16, 0);
 88a:	008b8913          	addi	s2,s7,8
 88e:	4681                	li	a3,0
 890:	4641                	li	a2,16
 892:	000be583          	lwu	a1,0(s7)
 896:	855a                	mv	a0,s6
 898:	d95ff0ef          	jal	62c <printint>
 89c:	8bca                	mv	s7,s2
      state = 0;
 89e:	4981                	li	s3,0
 8a0:	bd8d                	j	712 <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 16, 0);
 8a2:	008b8913          	addi	s2,s7,8
 8a6:	4681                	li	a3,0
 8a8:	4641                	li	a2,16
 8aa:	000bb583          	ld	a1,0(s7)
 8ae:	855a                	mv	a0,s6
 8b0:	d7dff0ef          	jal	62c <printint>
        i += 1;
 8b4:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 16, 0);
 8b6:	8bca                	mv	s7,s2
      state = 0;
 8b8:	4981                	li	s3,0
        i += 1;
 8ba:	bda1                	j	712 <vprintf+0x4a>
 8bc:	e06a                	sd	s10,0(sp)
        printptr(fd, va_arg(ap, uint64));
 8be:	008b8d13          	addi	s10,s7,8
 8c2:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 8c6:	03000593          	li	a1,48
 8ca:	855a                	mv	a0,s6
 8cc:	d43ff0ef          	jal	60e <putc>
  putc(fd, 'x');
 8d0:	07800593          	li	a1,120
 8d4:	855a                	mv	a0,s6
 8d6:	d39ff0ef          	jal	60e <putc>
 8da:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 8dc:	00000b97          	auipc	s7,0x0
 8e0:	5ccb8b93          	addi	s7,s7,1484 # ea8 <digits>
 8e4:	03c9d793          	srli	a5,s3,0x3c
 8e8:	97de                	add	a5,a5,s7
 8ea:	0007c583          	lbu	a1,0(a5)
 8ee:	855a                	mv	a0,s6
 8f0:	d1fff0ef          	jal	60e <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 8f4:	0992                	slli	s3,s3,0x4
 8f6:	397d                	addiw	s2,s2,-1
 8f8:	fe0916e3          	bnez	s2,8e4 <vprintf+0x21c>
        printptr(fd, va_arg(ap, uint64));
 8fc:	8bea                	mv	s7,s10
      state = 0;
 8fe:	4981                	li	s3,0
 900:	6d02                	ld	s10,0(sp)
 902:	bd01                	j	712 <vprintf+0x4a>
        putc(fd, va_arg(ap, uint32));
 904:	008b8913          	addi	s2,s7,8
 908:	000bc583          	lbu	a1,0(s7)
 90c:	855a                	mv	a0,s6
 90e:	d01ff0ef          	jal	60e <putc>
 912:	8bca                	mv	s7,s2
      state = 0;
 914:	4981                	li	s3,0
 916:	bbf5                	j	712 <vprintf+0x4a>
        if((s = va_arg(ap, char*)) == 0)
 918:	008b8993          	addi	s3,s7,8
 91c:	000bb903          	ld	s2,0(s7)
 920:	00090f63          	beqz	s2,93e <vprintf+0x276>
        for(; *s; s++)
 924:	00094583          	lbu	a1,0(s2)
 928:	c195                	beqz	a1,94c <vprintf+0x284>
          putc(fd, *s);
 92a:	855a                	mv	a0,s6
 92c:	ce3ff0ef          	jal	60e <putc>
        for(; *s; s++)
 930:	0905                	addi	s2,s2,1
 932:	00094583          	lbu	a1,0(s2)
 936:	f9f5                	bnez	a1,92a <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 938:	8bce                	mv	s7,s3
      state = 0;
 93a:	4981                	li	s3,0
 93c:	bbd9                	j	712 <vprintf+0x4a>
          s = "(null)";
 93e:	00000917          	auipc	s2,0x0
 942:	56290913          	addi	s2,s2,1378 # ea0 <malloc+0x456>
        for(; *s; s++)
 946:	02800593          	li	a1,40
 94a:	b7c5                	j	92a <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 94c:	8bce                	mv	s7,s3
      state = 0;
 94e:	4981                	li	s3,0
 950:	b3c9                	j	712 <vprintf+0x4a>
 952:	64a6                	ld	s1,72(sp)
 954:	79e2                	ld	s3,56(sp)
 956:	7a42                	ld	s4,48(sp)
 958:	7aa2                	ld	s5,40(sp)
 95a:	7b02                	ld	s6,32(sp)
 95c:	6be2                	ld	s7,24(sp)
 95e:	6c42                	ld	s8,16(sp)
 960:	6ca2                	ld	s9,8(sp)
    }
  }
}
 962:	60e6                	ld	ra,88(sp)
 964:	6446                	ld	s0,80(sp)
 966:	6906                	ld	s2,64(sp)
 968:	6125                	addi	sp,sp,96
 96a:	8082                	ret

000000000000096c <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 96c:	715d                	addi	sp,sp,-80
 96e:	ec06                	sd	ra,24(sp)
 970:	e822                	sd	s0,16(sp)
 972:	1000                	addi	s0,sp,32
 974:	e010                	sd	a2,0(s0)
 976:	e414                	sd	a3,8(s0)
 978:	e818                	sd	a4,16(s0)
 97a:	ec1c                	sd	a5,24(s0)
 97c:	03043023          	sd	a6,32(s0)
 980:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 984:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 988:	8622                	mv	a2,s0
 98a:	d3fff0ef          	jal	6c8 <vprintf>
}
 98e:	60e2                	ld	ra,24(sp)
 990:	6442                	ld	s0,16(sp)
 992:	6161                	addi	sp,sp,80
 994:	8082                	ret

0000000000000996 <printf>:

void
printf(const char *fmt, ...)
{
 996:	711d                	addi	sp,sp,-96
 998:	ec06                	sd	ra,24(sp)
 99a:	e822                	sd	s0,16(sp)
 99c:	1000                	addi	s0,sp,32
 99e:	e40c                	sd	a1,8(s0)
 9a0:	e810                	sd	a2,16(s0)
 9a2:	ec14                	sd	a3,24(s0)
 9a4:	f018                	sd	a4,32(s0)
 9a6:	f41c                	sd	a5,40(s0)
 9a8:	03043823          	sd	a6,48(s0)
 9ac:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 9b0:	00840613          	addi	a2,s0,8
 9b4:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 9b8:	85aa                	mv	a1,a0
 9ba:	4505                	li	a0,1
 9bc:	d0dff0ef          	jal	6c8 <vprintf>
}
 9c0:	60e2                	ld	ra,24(sp)
 9c2:	6442                	ld	s0,16(sp)
 9c4:	6125                	addi	sp,sp,96
 9c6:	8082                	ret

00000000000009c8 <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 9c8:	1141                	addi	sp,sp,-16
 9ca:	e422                	sd	s0,8(sp)
 9cc:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 9ce:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 9d2:	00001797          	auipc	a5,0x1
 9d6:	62e7b783          	ld	a5,1582(a5) # 2000 <freep>
 9da:	a02d                	j	a04 <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 9dc:	4618                	lw	a4,8(a2)
 9de:	9f2d                	addw	a4,a4,a1
 9e0:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 9e4:	6398                	ld	a4,0(a5)
 9e6:	6310                	ld	a2,0(a4)
 9e8:	a83d                	j	a26 <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 9ea:	ff852703          	lw	a4,-8(a0)
 9ee:	9f31                	addw	a4,a4,a2
 9f0:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 9f2:	ff053683          	ld	a3,-16(a0)
 9f6:	a091                	j	a3a <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 9f8:	6398                	ld	a4,0(a5)
 9fa:	00e7e463          	bltu	a5,a4,a02 <free+0x3a>
 9fe:	00e6ea63          	bltu	a3,a4,a12 <free+0x4a>
{
 a02:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 a04:	fed7fae3          	bgeu	a5,a3,9f8 <free+0x30>
 a08:	6398                	ld	a4,0(a5)
 a0a:	00e6e463          	bltu	a3,a4,a12 <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 a0e:	fee7eae3          	bltu	a5,a4,a02 <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 a12:	ff852583          	lw	a1,-8(a0)
 a16:	6390                	ld	a2,0(a5)
 a18:	02059813          	slli	a6,a1,0x20
 a1c:	01c85713          	srli	a4,a6,0x1c
 a20:	9736                	add	a4,a4,a3
 a22:	fae60de3          	beq	a2,a4,9dc <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 a26:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 a2a:	4790                	lw	a2,8(a5)
 a2c:	02061593          	slli	a1,a2,0x20
 a30:	01c5d713          	srli	a4,a1,0x1c
 a34:	973e                	add	a4,a4,a5
 a36:	fae68ae3          	beq	a3,a4,9ea <free+0x22>
    p->s.ptr = bp->s.ptr;
 a3a:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 a3c:	00001717          	auipc	a4,0x1
 a40:	5cf73223          	sd	a5,1476(a4) # 2000 <freep>
}
 a44:	6422                	ld	s0,8(sp)
 a46:	0141                	addi	sp,sp,16
 a48:	8082                	ret

0000000000000a4a <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 a4a:	7139                	addi	sp,sp,-64
 a4c:	fc06                	sd	ra,56(sp)
 a4e:	f822                	sd	s0,48(sp)
 a50:	f426                	sd	s1,40(sp)
 a52:	ec4e                	sd	s3,24(sp)
 a54:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 a56:	02051493          	slli	s1,a0,0x20
 a5a:	9081                	srli	s1,s1,0x20
 a5c:	04bd                	addi	s1,s1,15
 a5e:	8091                	srli	s1,s1,0x4
 a60:	0014899b          	addiw	s3,s1,1
 a64:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 a66:	00001517          	auipc	a0,0x1
 a6a:	59a53503          	ld	a0,1434(a0) # 2000 <freep>
 a6e:	c915                	beqz	a0,aa2 <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 a70:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 a72:	4798                	lw	a4,8(a5)
 a74:	08977a63          	bgeu	a4,s1,b08 <malloc+0xbe>
 a78:	f04a                	sd	s2,32(sp)
 a7a:	e852                	sd	s4,16(sp)
 a7c:	e456                	sd	s5,8(sp)
 a7e:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 a80:	8a4e                	mv	s4,s3
 a82:	0009871b          	sext.w	a4,s3
 a86:	6685                	lui	a3,0x1
 a88:	00d77363          	bgeu	a4,a3,a8e <malloc+0x44>
 a8c:	6a05                	lui	s4,0x1
 a8e:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 a92:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 a96:	00001917          	auipc	s2,0x1
 a9a:	56a90913          	addi	s2,s2,1386 # 2000 <freep>
  if(p == SBRK_ERROR)
 a9e:	5afd                	li	s5,-1
 aa0:	a081                	j	ae0 <malloc+0x96>
 aa2:	f04a                	sd	s2,32(sp)
 aa4:	e852                	sd	s4,16(sp)
 aa6:	e456                	sd	s5,8(sp)
 aa8:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 aaa:	00001797          	auipc	a5,0x1
 aae:	56678793          	addi	a5,a5,1382 # 2010 <base>
 ab2:	00001717          	auipc	a4,0x1
 ab6:	54f73723          	sd	a5,1358(a4) # 2000 <freep>
 aba:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 abc:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 ac0:	b7c1                	j	a80 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 ac2:	6398                	ld	a4,0(a5)
 ac4:	e118                	sd	a4,0(a0)
 ac6:	a8a9                	j	b20 <malloc+0xd6>
  hp->s.size = nu;
 ac8:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 acc:	0541                	addi	a0,a0,16
 ace:	efbff0ef          	jal	9c8 <free>
  return freep;
 ad2:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 ad6:	c12d                	beqz	a0,b38 <malloc+0xee>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 ad8:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 ada:	4798                	lw	a4,8(a5)
 adc:	02977263          	bgeu	a4,s1,b00 <malloc+0xb6>
    if(p == freep)
 ae0:	00093703          	ld	a4,0(s2)
 ae4:	853e                	mv	a0,a5
 ae6:	fef719e3          	bne	a4,a5,ad8 <malloc+0x8e>
  p = sbrk(nu * sizeof(Header));
 aea:	8552                	mv	a0,s4
 aec:	a27ff0ef          	jal	512 <sbrk>
  if(p == SBRK_ERROR)
 af0:	fd551ce3          	bne	a0,s5,ac8 <malloc+0x7e>
        return 0;
 af4:	4501                	li	a0,0
 af6:	7902                	ld	s2,32(sp)
 af8:	6a42                	ld	s4,16(sp)
 afa:	6aa2                	ld	s5,8(sp)
 afc:	6b02                	ld	s6,0(sp)
 afe:	a03d                	j	b2c <malloc+0xe2>
 b00:	7902                	ld	s2,32(sp)
 b02:	6a42                	ld	s4,16(sp)
 b04:	6aa2                	ld	s5,8(sp)
 b06:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 b08:	fae48de3          	beq	s1,a4,ac2 <malloc+0x78>
        p->s.size -= nunits;
 b0c:	4137073b          	subw	a4,a4,s3
 b10:	c798                	sw	a4,8(a5)
        p += p->s.size;
 b12:	02071693          	slli	a3,a4,0x20
 b16:	01c6d713          	srli	a4,a3,0x1c
 b1a:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 b1c:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 b20:	00001717          	auipc	a4,0x1
 b24:	4ea73023          	sd	a0,1248(a4) # 2000 <freep>
      return (void*)(p + 1);
 b28:	01078513          	addi	a0,a5,16
  }
}
 b2c:	70e2                	ld	ra,56(sp)
 b2e:	7442                	ld	s0,48(sp)
 b30:	74a2                	ld	s1,40(sp)
 b32:	69e2                	ld	s3,24(sp)
 b34:	6121                	addi	sp,sp,64
 b36:	8082                	ret
 b38:	7902                	ld	s2,32(sp)
 b3a:	6a42                	ld	s4,16(sp)
 b3c:	6aa2                	ld	s5,8(sp)
 b3e:	6b02                	ld	s6,0(sp)
 b40:	b7f5                	j	b2c <malloc+0xe2>
