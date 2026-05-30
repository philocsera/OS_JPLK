
user/_memstress:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <main>:
#include "kernel/stat.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
   0:	7139                	addi	sp,sp,-64
   2:	fc06                	sd	ra,56(sp)
   4:	f822                	sd	s0,48(sp)
   6:	f426                	sd	s1,40(sp)
   8:	f04a                	sd	s2,32(sp)
   a:	ec4e                	sd	s3,24(sp)
   c:	e852                	sd	s4,16(sp)
   e:	e456                	sd	s5,8(sp)
  10:	0080                	addi	s0,sp,64
  12:	892a                	mv	s2,a0
  14:	8a2e                	mv	s4,a1
  int pid = getpid();
  16:	408000ef          	jal	41e <getpid>
  1a:	89aa                	mv	s3,a0
  int step = 4096;
  int total = 0;
  int i = 0;
  char *p;

  if(argc >= 2){
  1c:	4785                	li	a5,1
  1e:	0327c363          	blt	a5,s2,44 <main+0x44>
  if(step <= 0){
    printf("step must be positive\n");
    exit(1);
  }

  printf("memstress start pid=%d quota=%d step=%d\n", pid, quota, step);
  22:	6685                	lui	a3,0x1
  24:	4601                	li	a2,0
  26:	85aa                	mv	a1,a0
  28:	00001517          	auipc	a0,0x1
  2c:	99050513          	addi	a0,a0,-1648 # 9b8 <malloc+0x116>
  30:	7be000ef          	jal	7ee <printf>
  int step = 4096;
  34:	6485                	lui	s1,0x1
    if(setmemquota(pid, quota) < 0){
      printf("setmemquota failed\n");
      exit(1);
    }
  } else {
    printf("quota disabled\n");
  36:	00001517          	auipc	a0,0x1
  3a:	9ca50513          	addi	a0,a0,-1590 # a00 <malloc+0x15e>
  3e:	7b0000ef          	jal	7ee <printf>
  42:	a81d                	j	78 <main+0x78>
    quota = atoi(argv[1]);
  44:	008a3503          	ld	a0,8(s4)
  48:	234000ef          	jal	27c <atoi>
  4c:	8aaa                	mv	s5,a0
  if(argc >= 3){
  4e:	4789                	li	a5,2
  int step = 4096;
  50:	6485                	lui	s1,0x1
  if(argc >= 3){
  52:	0727c163          	blt	a5,s2,b4 <main+0xb4>
  printf("memstress start pid=%d quota=%d step=%d\n", pid, quota, step);
  56:	86a6                	mv	a3,s1
  58:	8656                	mv	a2,s5
  5a:	85ce                	mv	a1,s3
  5c:	00001517          	auipc	a0,0x1
  60:	95c50513          	addi	a0,a0,-1700 # 9b8 <malloc+0x116>
  64:	78a000ef          	jal	7ee <printf>
  if(quota > 0){
  68:	fd5057e3          	blez	s5,36 <main+0x36>
    if(setmemquota(pid, quota) < 0){
  6c:	85d6                	mv	a1,s5
  6e:	854e                	mv	a0,s3
  70:	3ee000ef          	jal	45e <setmemquota>
  74:	06054163          	bltz	a0,d6 <main+0xd6>
  78:	e05a                	sd	s6,0(sp)
  int step = 4096;
  7a:	4901                	li	s2,0
  7c:	4981                	li	s3,0
  }

  while(1){
    p = sbrk(step);

    if(p == (char*)-1){
  7e:	5afd                	li	s5,-1
      printf("sbrk failed after total allocated=%d bytes\n", total);
      break;
    }

    // 실제 페이지가 할당되도록 메모리에 접근
    p[0] = 1;
  80:	4a05                	li	s4,1

    total += step;
    i++;

    if(i % 4 == 0){
      printf("allocated=%d bytes\n", total);
  82:	00001b17          	auipc	s6,0x1
  86:	9a6b0b13          	addi	s6,s6,-1626 # a28 <malloc+0x186>
    p = sbrk(step);
  8a:	8526                	mv	a0,s1
  8c:	2de000ef          	jal	36a <sbrk>
    if(p == (char*)-1){
  90:	05550d63          	beq	a0,s5,ea <main+0xea>
    p[0] = 1;
  94:	01450023          	sb	s4,0(a0)
    p[step - 1] = 1;
  98:	9526                	add	a0,a0,s1
  9a:	ff450fa3          	sb	s4,-1(a0)
    total += step;
  9e:	013489bb          	addw	s3,s1,s3
    i++;
  a2:	2905                	addiw	s2,s2,1
    if(i % 4 == 0){
  a4:	00397793          	andi	a5,s2,3
  a8:	f3ed                	bnez	a5,8a <main+0x8a>
      printf("allocated=%d bytes\n", total);
  aa:	85ce                	mv	a1,s3
  ac:	855a                	mv	a0,s6
  ae:	740000ef          	jal	7ee <printf>
  b2:	bfe1                	j	8a <main+0x8a>
    step = atoi(argv[2]);
  b4:	010a3503          	ld	a0,16(s4)
  b8:	1c4000ef          	jal	27c <atoi>
  bc:	84aa                	mv	s1,a0
  if(step <= 0){
  be:	f8a04ce3          	bgtz	a0,56 <main+0x56>
  c2:	e05a                	sd	s6,0(sp)
    printf("step must be positive\n");
  c4:	00001517          	auipc	a0,0x1
  c8:	8dc50513          	addi	a0,a0,-1828 # 9a0 <malloc+0xfe>
  cc:	722000ef          	jal	7ee <printf>
    exit(1);
  d0:	4505                	li	a0,1
  d2:	2cc000ef          	jal	39e <exit>
  d6:	e05a                	sd	s6,0(sp)
      printf("setmemquota failed\n");
  d8:	00001517          	auipc	a0,0x1
  dc:	91050513          	addi	a0,a0,-1776 # 9e8 <malloc+0x146>
  e0:	70e000ef          	jal	7ee <printf>
      exit(1);
  e4:	4505                	li	a0,1
  e6:	2b8000ef          	jal	39e <exit>
      printf("sbrk failed after total allocated=%d bytes\n", total);
  ea:	85ce                	mv	a1,s3
  ec:	00001517          	auipc	a0,0x1
  f0:	92450513          	addi	a0,a0,-1756 # a10 <malloc+0x16e>
  f4:	6fa000ef          	jal	7ee <printf>
    }
  }

  printf("memstress done\n");
  f8:	00001517          	auipc	a0,0x1
  fc:	94850513          	addi	a0,a0,-1720 # a40 <malloc+0x19e>
 100:	6ee000ef          	jal	7ee <printf>
  exit(0);
 104:	4501                	li	a0,0
 106:	298000ef          	jal	39e <exit>

000000000000010a <start>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
start(int argc, char **argv)
{
 10a:	1141                	addi	sp,sp,-16
 10c:	e406                	sd	ra,8(sp)
 10e:	e022                	sd	s0,0(sp)
 110:	0800                	addi	s0,sp,16
  int r;
  extern int main(int argc, char **argv);
  r = main(argc, argv);
 112:	eefff0ef          	jal	0 <main>
  exit(r);
 116:	288000ef          	jal	39e <exit>

000000000000011a <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 11a:	1141                	addi	sp,sp,-16
 11c:	e422                	sd	s0,8(sp)
 11e:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 120:	87aa                	mv	a5,a0
 122:	0585                	addi	a1,a1,1
 124:	0785                	addi	a5,a5,1
 126:	fff5c703          	lbu	a4,-1(a1)
 12a:	fee78fa3          	sb	a4,-1(a5)
 12e:	fb75                	bnez	a4,122 <strcpy+0x8>
    ;
  return os;
}
 130:	6422                	ld	s0,8(sp)
 132:	0141                	addi	sp,sp,16
 134:	8082                	ret

0000000000000136 <strcmp>:

int
strcmp(const char *p, const char *q)
{
 136:	1141                	addi	sp,sp,-16
 138:	e422                	sd	s0,8(sp)
 13a:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 13c:	00054783          	lbu	a5,0(a0)
 140:	cb91                	beqz	a5,154 <strcmp+0x1e>
 142:	0005c703          	lbu	a4,0(a1)
 146:	00f71763          	bne	a4,a5,154 <strcmp+0x1e>
    p++, q++;
 14a:	0505                	addi	a0,a0,1
 14c:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 14e:	00054783          	lbu	a5,0(a0)
 152:	fbe5                	bnez	a5,142 <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 154:	0005c503          	lbu	a0,0(a1)
}
 158:	40a7853b          	subw	a0,a5,a0
 15c:	6422                	ld	s0,8(sp)
 15e:	0141                	addi	sp,sp,16
 160:	8082                	ret

0000000000000162 <strlen>:

uint
strlen(const char *s)
{
 162:	1141                	addi	sp,sp,-16
 164:	e422                	sd	s0,8(sp)
 166:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 168:	00054783          	lbu	a5,0(a0)
 16c:	cf91                	beqz	a5,188 <strlen+0x26>
 16e:	0505                	addi	a0,a0,1
 170:	87aa                	mv	a5,a0
 172:	86be                	mv	a3,a5
 174:	0785                	addi	a5,a5,1
 176:	fff7c703          	lbu	a4,-1(a5)
 17a:	ff65                	bnez	a4,172 <strlen+0x10>
 17c:	40a6853b          	subw	a0,a3,a0
 180:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 182:	6422                	ld	s0,8(sp)
 184:	0141                	addi	sp,sp,16
 186:	8082                	ret
  for(n = 0; s[n]; n++)
 188:	4501                	li	a0,0
 18a:	bfe5                	j	182 <strlen+0x20>

000000000000018c <memset>:

void*
memset(void *dst, int c, uint n)
{
 18c:	1141                	addi	sp,sp,-16
 18e:	e422                	sd	s0,8(sp)
 190:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 192:	ca19                	beqz	a2,1a8 <memset+0x1c>
 194:	87aa                	mv	a5,a0
 196:	1602                	slli	a2,a2,0x20
 198:	9201                	srli	a2,a2,0x20
 19a:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 19e:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 1a2:	0785                	addi	a5,a5,1
 1a4:	fee79de3          	bne	a5,a4,19e <memset+0x12>
  }
  return dst;
}
 1a8:	6422                	ld	s0,8(sp)
 1aa:	0141                	addi	sp,sp,16
 1ac:	8082                	ret

00000000000001ae <strchr>:

char*
strchr(const char *s, char c)
{
 1ae:	1141                	addi	sp,sp,-16
 1b0:	e422                	sd	s0,8(sp)
 1b2:	0800                	addi	s0,sp,16
  for(; *s; s++)
 1b4:	00054783          	lbu	a5,0(a0)
 1b8:	cb99                	beqz	a5,1ce <strchr+0x20>
    if(*s == c)
 1ba:	00f58763          	beq	a1,a5,1c8 <strchr+0x1a>
  for(; *s; s++)
 1be:	0505                	addi	a0,a0,1
 1c0:	00054783          	lbu	a5,0(a0)
 1c4:	fbfd                	bnez	a5,1ba <strchr+0xc>
      return (char*)s;
  return 0;
 1c6:	4501                	li	a0,0
}
 1c8:	6422                	ld	s0,8(sp)
 1ca:	0141                	addi	sp,sp,16
 1cc:	8082                	ret
  return 0;
 1ce:	4501                	li	a0,0
 1d0:	bfe5                	j	1c8 <strchr+0x1a>

00000000000001d2 <gets>:

char*
gets(char *buf, int max)
{
 1d2:	711d                	addi	sp,sp,-96
 1d4:	ec86                	sd	ra,88(sp)
 1d6:	e8a2                	sd	s0,80(sp)
 1d8:	e4a6                	sd	s1,72(sp)
 1da:	e0ca                	sd	s2,64(sp)
 1dc:	fc4e                	sd	s3,56(sp)
 1de:	f852                	sd	s4,48(sp)
 1e0:	f456                	sd	s5,40(sp)
 1e2:	f05a                	sd	s6,32(sp)
 1e4:	ec5e                	sd	s7,24(sp)
 1e6:	1080                	addi	s0,sp,96
 1e8:	8baa                	mv	s7,a0
 1ea:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 1ec:	892a                	mv	s2,a0
 1ee:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 1f0:	4aa9                	li	s5,10
 1f2:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 1f4:	89a6                	mv	s3,s1
 1f6:	2485                	addiw	s1,s1,1 # 1001 <freep+0x1>
 1f8:	0344d663          	bge	s1,s4,224 <gets+0x52>
    cc = read(0, &c, 1);
 1fc:	4605                	li	a2,1
 1fe:	faf40593          	addi	a1,s0,-81
 202:	4501                	li	a0,0
 204:	1b2000ef          	jal	3b6 <read>
    if(cc < 1)
 208:	00a05e63          	blez	a0,224 <gets+0x52>
    buf[i++] = c;
 20c:	faf44783          	lbu	a5,-81(s0)
 210:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 214:	01578763          	beq	a5,s5,222 <gets+0x50>
 218:	0905                	addi	s2,s2,1
 21a:	fd679de3          	bne	a5,s6,1f4 <gets+0x22>
    buf[i++] = c;
 21e:	89a6                	mv	s3,s1
 220:	a011                	j	224 <gets+0x52>
 222:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 224:	99de                	add	s3,s3,s7
 226:	00098023          	sb	zero,0(s3)
  return buf;
}
 22a:	855e                	mv	a0,s7
 22c:	60e6                	ld	ra,88(sp)
 22e:	6446                	ld	s0,80(sp)
 230:	64a6                	ld	s1,72(sp)
 232:	6906                	ld	s2,64(sp)
 234:	79e2                	ld	s3,56(sp)
 236:	7a42                	ld	s4,48(sp)
 238:	7aa2                	ld	s5,40(sp)
 23a:	7b02                	ld	s6,32(sp)
 23c:	6be2                	ld	s7,24(sp)
 23e:	6125                	addi	sp,sp,96
 240:	8082                	ret

0000000000000242 <stat>:

int
stat(const char *n, struct stat *st)
{
 242:	1101                	addi	sp,sp,-32
 244:	ec06                	sd	ra,24(sp)
 246:	e822                	sd	s0,16(sp)
 248:	e04a                	sd	s2,0(sp)
 24a:	1000                	addi	s0,sp,32
 24c:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 24e:	4581                	li	a1,0
 250:	18e000ef          	jal	3de <open>
  if(fd < 0)
 254:	02054263          	bltz	a0,278 <stat+0x36>
 258:	e426                	sd	s1,8(sp)
 25a:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 25c:	85ca                	mv	a1,s2
 25e:	198000ef          	jal	3f6 <fstat>
 262:	892a                	mv	s2,a0
  close(fd);
 264:	8526                	mv	a0,s1
 266:	160000ef          	jal	3c6 <close>
  return r;
 26a:	64a2                	ld	s1,8(sp)
}
 26c:	854a                	mv	a0,s2
 26e:	60e2                	ld	ra,24(sp)
 270:	6442                	ld	s0,16(sp)
 272:	6902                	ld	s2,0(sp)
 274:	6105                	addi	sp,sp,32
 276:	8082                	ret
    return -1;
 278:	597d                	li	s2,-1
 27a:	bfcd                	j	26c <stat+0x2a>

000000000000027c <atoi>:

int
atoi(const char *s)
{
 27c:	1141                	addi	sp,sp,-16
 27e:	e422                	sd	s0,8(sp)
 280:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 282:	00054683          	lbu	a3,0(a0)
 286:	fd06879b          	addiw	a5,a3,-48 # fd0 <digits+0x578>
 28a:	0ff7f793          	zext.b	a5,a5
 28e:	4625                	li	a2,9
 290:	02f66863          	bltu	a2,a5,2c0 <atoi+0x44>
 294:	872a                	mv	a4,a0
  n = 0;
 296:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 298:	0705                	addi	a4,a4,1
 29a:	0025179b          	slliw	a5,a0,0x2
 29e:	9fa9                	addw	a5,a5,a0
 2a0:	0017979b          	slliw	a5,a5,0x1
 2a4:	9fb5                	addw	a5,a5,a3
 2a6:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 2aa:	00074683          	lbu	a3,0(a4)
 2ae:	fd06879b          	addiw	a5,a3,-48
 2b2:	0ff7f793          	zext.b	a5,a5
 2b6:	fef671e3          	bgeu	a2,a5,298 <atoi+0x1c>
  return n;
}
 2ba:	6422                	ld	s0,8(sp)
 2bc:	0141                	addi	sp,sp,16
 2be:	8082                	ret
  n = 0;
 2c0:	4501                	li	a0,0
 2c2:	bfe5                	j	2ba <atoi+0x3e>

00000000000002c4 <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 2c4:	1141                	addi	sp,sp,-16
 2c6:	e422                	sd	s0,8(sp)
 2c8:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 2ca:	02b57463          	bgeu	a0,a1,2f2 <memmove+0x2e>
    while(n-- > 0)
 2ce:	00c05f63          	blez	a2,2ec <memmove+0x28>
 2d2:	1602                	slli	a2,a2,0x20
 2d4:	9201                	srli	a2,a2,0x20
 2d6:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 2da:	872a                	mv	a4,a0
      *dst++ = *src++;
 2dc:	0585                	addi	a1,a1,1
 2de:	0705                	addi	a4,a4,1
 2e0:	fff5c683          	lbu	a3,-1(a1)
 2e4:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 2e8:	fef71ae3          	bne	a4,a5,2dc <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 2ec:	6422                	ld	s0,8(sp)
 2ee:	0141                	addi	sp,sp,16
 2f0:	8082                	ret
    dst += n;
 2f2:	00c50733          	add	a4,a0,a2
    src += n;
 2f6:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 2f8:	fec05ae3          	blez	a2,2ec <memmove+0x28>
 2fc:	fff6079b          	addiw	a5,a2,-1
 300:	1782                	slli	a5,a5,0x20
 302:	9381                	srli	a5,a5,0x20
 304:	fff7c793          	not	a5,a5
 308:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 30a:	15fd                	addi	a1,a1,-1
 30c:	177d                	addi	a4,a4,-1
 30e:	0005c683          	lbu	a3,0(a1)
 312:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 316:	fee79ae3          	bne	a5,a4,30a <memmove+0x46>
 31a:	bfc9                	j	2ec <memmove+0x28>

000000000000031c <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 31c:	1141                	addi	sp,sp,-16
 31e:	e422                	sd	s0,8(sp)
 320:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 322:	ca05                	beqz	a2,352 <memcmp+0x36>
 324:	fff6069b          	addiw	a3,a2,-1
 328:	1682                	slli	a3,a3,0x20
 32a:	9281                	srli	a3,a3,0x20
 32c:	0685                	addi	a3,a3,1
 32e:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 330:	00054783          	lbu	a5,0(a0)
 334:	0005c703          	lbu	a4,0(a1)
 338:	00e79863          	bne	a5,a4,348 <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 33c:	0505                	addi	a0,a0,1
    p2++;
 33e:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 340:	fed518e3          	bne	a0,a3,330 <memcmp+0x14>
  }
  return 0;
 344:	4501                	li	a0,0
 346:	a019                	j	34c <memcmp+0x30>
      return *p1 - *p2;
 348:	40e7853b          	subw	a0,a5,a4
}
 34c:	6422                	ld	s0,8(sp)
 34e:	0141                	addi	sp,sp,16
 350:	8082                	ret
  return 0;
 352:	4501                	li	a0,0
 354:	bfe5                	j	34c <memcmp+0x30>

0000000000000356 <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 356:	1141                	addi	sp,sp,-16
 358:	e406                	sd	ra,8(sp)
 35a:	e022                	sd	s0,0(sp)
 35c:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 35e:	f67ff0ef          	jal	2c4 <memmove>
}
 362:	60a2                	ld	ra,8(sp)
 364:	6402                	ld	s0,0(sp)
 366:	0141                	addi	sp,sp,16
 368:	8082                	ret

000000000000036a <sbrk>:

char *
sbrk(int n) {
 36a:	1141                	addi	sp,sp,-16
 36c:	e406                	sd	ra,8(sp)
 36e:	e022                	sd	s0,0(sp)
 370:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_EAGER);
 372:	4585                	li	a1,1
 374:	0b2000ef          	jal	426 <sys_sbrk>
}
 378:	60a2                	ld	ra,8(sp)
 37a:	6402                	ld	s0,0(sp)
 37c:	0141                	addi	sp,sp,16
 37e:	8082                	ret

0000000000000380 <sbrklazy>:

char *
sbrklazy(int n) {
 380:	1141                	addi	sp,sp,-16
 382:	e406                	sd	ra,8(sp)
 384:	e022                	sd	s0,0(sp)
 386:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_LAZY);
 388:	4589                	li	a1,2
 38a:	09c000ef          	jal	426 <sys_sbrk>
}
 38e:	60a2                	ld	ra,8(sp)
 390:	6402                	ld	s0,0(sp)
 392:	0141                	addi	sp,sp,16
 394:	8082                	ret

0000000000000396 <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 396:	4885                	li	a7,1
 ecall
 398:	00000073          	ecall
 ret
 39c:	8082                	ret

000000000000039e <exit>:
.global exit
exit:
 li a7, SYS_exit
 39e:	4889                	li	a7,2
 ecall
 3a0:	00000073          	ecall
 ret
 3a4:	8082                	ret

00000000000003a6 <wait>:
.global wait
wait:
 li a7, SYS_wait
 3a6:	488d                	li	a7,3
 ecall
 3a8:	00000073          	ecall
 ret
 3ac:	8082                	ret

00000000000003ae <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 3ae:	4891                	li	a7,4
 ecall
 3b0:	00000073          	ecall
 ret
 3b4:	8082                	ret

00000000000003b6 <read>:
.global read
read:
 li a7, SYS_read
 3b6:	4895                	li	a7,5
 ecall
 3b8:	00000073          	ecall
 ret
 3bc:	8082                	ret

00000000000003be <write>:
.global write
write:
 li a7, SYS_write
 3be:	48c1                	li	a7,16
 ecall
 3c0:	00000073          	ecall
 ret
 3c4:	8082                	ret

00000000000003c6 <close>:
.global close
close:
 li a7, SYS_close
 3c6:	48d5                	li	a7,21
 ecall
 3c8:	00000073          	ecall
 ret
 3cc:	8082                	ret

00000000000003ce <kill>:
.global kill
kill:
 li a7, SYS_kill
 3ce:	4899                	li	a7,6
 ecall
 3d0:	00000073          	ecall
 ret
 3d4:	8082                	ret

00000000000003d6 <exec>:
.global exec
exec:
 li a7, SYS_exec
 3d6:	489d                	li	a7,7
 ecall
 3d8:	00000073          	ecall
 ret
 3dc:	8082                	ret

00000000000003de <open>:
.global open
open:
 li a7, SYS_open
 3de:	48bd                	li	a7,15
 ecall
 3e0:	00000073          	ecall
 ret
 3e4:	8082                	ret

00000000000003e6 <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 3e6:	48c5                	li	a7,17
 ecall
 3e8:	00000073          	ecall
 ret
 3ec:	8082                	ret

00000000000003ee <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 3ee:	48c9                	li	a7,18
 ecall
 3f0:	00000073          	ecall
 ret
 3f4:	8082                	ret

00000000000003f6 <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 3f6:	48a1                	li	a7,8
 ecall
 3f8:	00000073          	ecall
 ret
 3fc:	8082                	ret

00000000000003fe <link>:
.global link
link:
 li a7, SYS_link
 3fe:	48cd                	li	a7,19
 ecall
 400:	00000073          	ecall
 ret
 404:	8082                	ret

0000000000000406 <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 406:	48d1                	li	a7,20
 ecall
 408:	00000073          	ecall
 ret
 40c:	8082                	ret

000000000000040e <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 40e:	48a5                	li	a7,9
 ecall
 410:	00000073          	ecall
 ret
 414:	8082                	ret

0000000000000416 <dup>:
.global dup
dup:
 li a7, SYS_dup
 416:	48a9                	li	a7,10
 ecall
 418:	00000073          	ecall
 ret
 41c:	8082                	ret

000000000000041e <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 41e:	48ad                	li	a7,11
 ecall
 420:	00000073          	ecall
 ret
 424:	8082                	ret

0000000000000426 <sys_sbrk>:
.global sys_sbrk
sys_sbrk:
 li a7, SYS_sbrk
 426:	48b1                	li	a7,12
 ecall
 428:	00000073          	ecall
 ret
 42c:	8082                	ret

000000000000042e <pause>:
.global pause
pause:
 li a7, SYS_pause
 42e:	48b5                	li	a7,13
 ecall
 430:	00000073          	ecall
 ret
 434:	8082                	ret

0000000000000436 <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 436:	48b9                	li	a7,14
 ecall
 438:	00000073          	ecall
 ret
 43c:	8082                	ret

000000000000043e <trace>:
.global trace
trace:
 li a7, SYS_trace
 43e:	48d9                	li	a7,22
 ecall
 440:	00000073          	ecall
 ret
 444:	8082                	ret

0000000000000446 <setpriority>:
.global setpriority
setpriority:
 li a7, SYS_setpriority
 446:	48dd                	li	a7,23
 ecall
 448:	00000073          	ecall
 ret
 44c:	8082                	ret

000000000000044e <getpriority>:
.global getpriority
getpriority:
 li a7, SYS_getpriority
 44e:	48e1                	li	a7,24
 ecall
 450:	00000073          	ecall
 ret
 454:	8082                	ret

0000000000000456 <getmemstat>:
.global getmemstat
getmemstat:
 li a7, SYS_getmemstat
 456:	48e5                	li	a7,25
 ecall
 458:	00000073          	ecall
 ret
 45c:	8082                	ret

000000000000045e <setmemquota>:
.global setmemquota
setmemquota:
 li a7, SYS_setmemquota
 45e:	48e9                	li	a7,26
 ecall
 460:	00000073          	ecall
 ret
 464:	8082                	ret

0000000000000466 <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 466:	1101                	addi	sp,sp,-32
 468:	ec06                	sd	ra,24(sp)
 46a:	e822                	sd	s0,16(sp)
 46c:	1000                	addi	s0,sp,32
 46e:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 472:	4605                	li	a2,1
 474:	fef40593          	addi	a1,s0,-17
 478:	f47ff0ef          	jal	3be <write>
}
 47c:	60e2                	ld	ra,24(sp)
 47e:	6442                	ld	s0,16(sp)
 480:	6105                	addi	sp,sp,32
 482:	8082                	ret

0000000000000484 <printint>:

static void
printint(int fd, long long xx, int base, int sgn)
{
 484:	715d                	addi	sp,sp,-80
 486:	e486                	sd	ra,72(sp)
 488:	e0a2                	sd	s0,64(sp)
 48a:	f84a                	sd	s2,48(sp)
 48c:	0880                	addi	s0,sp,80
 48e:	892a                	mv	s2,a0
  char buf[20];
  int i, neg;
  unsigned long long x;

  neg = 0;
  if(sgn && xx < 0){
 490:	c299                	beqz	a3,496 <printint+0x12>
 492:	0805c363          	bltz	a1,518 <printint+0x94>
  neg = 0;
 496:	4881                	li	a7,0
 498:	fb840693          	addi	a3,s0,-72
    x = -xx;
  } else {
    x = xx;
  }

  i = 0;
 49c:	4781                	li	a5,0
  do{
    buf[i++] = digits[x % base];
 49e:	00000517          	auipc	a0,0x0
 4a2:	5ba50513          	addi	a0,a0,1466 # a58 <digits>
 4a6:	883e                	mv	a6,a5
 4a8:	2785                	addiw	a5,a5,1
 4aa:	02c5f733          	remu	a4,a1,a2
 4ae:	972a                	add	a4,a4,a0
 4b0:	00074703          	lbu	a4,0(a4)
 4b4:	00e68023          	sb	a4,0(a3)
  }while((x /= base) != 0);
 4b8:	872e                	mv	a4,a1
 4ba:	02c5d5b3          	divu	a1,a1,a2
 4be:	0685                	addi	a3,a3,1
 4c0:	fec773e3          	bgeu	a4,a2,4a6 <printint+0x22>
  if(neg)
 4c4:	00088b63          	beqz	a7,4da <printint+0x56>
    buf[i++] = '-';
 4c8:	fd078793          	addi	a5,a5,-48
 4cc:	97a2                	add	a5,a5,s0
 4ce:	02d00713          	li	a4,45
 4d2:	fee78423          	sb	a4,-24(a5)
 4d6:	0028079b          	addiw	a5,a6,2

  while(--i >= 0)
 4da:	02f05a63          	blez	a5,50e <printint+0x8a>
 4de:	fc26                	sd	s1,56(sp)
 4e0:	f44e                	sd	s3,40(sp)
 4e2:	fb840713          	addi	a4,s0,-72
 4e6:	00f704b3          	add	s1,a4,a5
 4ea:	fff70993          	addi	s3,a4,-1
 4ee:	99be                	add	s3,s3,a5
 4f0:	37fd                	addiw	a5,a5,-1
 4f2:	1782                	slli	a5,a5,0x20
 4f4:	9381                	srli	a5,a5,0x20
 4f6:	40f989b3          	sub	s3,s3,a5
    putc(fd, buf[i]);
 4fa:	fff4c583          	lbu	a1,-1(s1)
 4fe:	854a                	mv	a0,s2
 500:	f67ff0ef          	jal	466 <putc>
  while(--i >= 0)
 504:	14fd                	addi	s1,s1,-1
 506:	ff349ae3          	bne	s1,s3,4fa <printint+0x76>
 50a:	74e2                	ld	s1,56(sp)
 50c:	79a2                	ld	s3,40(sp)
}
 50e:	60a6                	ld	ra,72(sp)
 510:	6406                	ld	s0,64(sp)
 512:	7942                	ld	s2,48(sp)
 514:	6161                	addi	sp,sp,80
 516:	8082                	ret
    x = -xx;
 518:	40b005b3          	neg	a1,a1
    neg = 1;
 51c:	4885                	li	a7,1
    x = -xx;
 51e:	bfad                	j	498 <printint+0x14>

0000000000000520 <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %c, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 520:	711d                	addi	sp,sp,-96
 522:	ec86                	sd	ra,88(sp)
 524:	e8a2                	sd	s0,80(sp)
 526:	e0ca                	sd	s2,64(sp)
 528:	1080                	addi	s0,sp,96
  char *s;
  int c0, c1, c2, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 52a:	0005c903          	lbu	s2,0(a1)
 52e:	28090663          	beqz	s2,7ba <vprintf+0x29a>
 532:	e4a6                	sd	s1,72(sp)
 534:	fc4e                	sd	s3,56(sp)
 536:	f852                	sd	s4,48(sp)
 538:	f456                	sd	s5,40(sp)
 53a:	f05a                	sd	s6,32(sp)
 53c:	ec5e                	sd	s7,24(sp)
 53e:	e862                	sd	s8,16(sp)
 540:	e466                	sd	s9,8(sp)
 542:	8b2a                	mv	s6,a0
 544:	8a2e                	mv	s4,a1
 546:	8bb2                	mv	s7,a2
  state = 0;
 548:	4981                	li	s3,0
  for(i = 0; fmt[i]; i++){
 54a:	4481                	li	s1,0
 54c:	4701                	li	a4,0
      if(c0 == '%'){
        state = '%';
      } else {
        putc(fd, c0);
      }
    } else if(state == '%'){
 54e:	02500a93          	li	s5,37
      c1 = c2 = 0;
      if(c0) c1 = fmt[i+1] & 0xff;
      if(c1) c2 = fmt[i+2] & 0xff;
      if(c0 == 'd'){
 552:	06400c13          	li	s8,100
        printint(fd, va_arg(ap, int), 10, 1);
      } else if(c0 == 'l' && c1 == 'd'){
 556:	06c00c93          	li	s9,108
 55a:	a005                	j	57a <vprintf+0x5a>
        putc(fd, c0);
 55c:	85ca                	mv	a1,s2
 55e:	855a                	mv	a0,s6
 560:	f07ff0ef          	jal	466 <putc>
 564:	a019                	j	56a <vprintf+0x4a>
    } else if(state == '%'){
 566:	03598263          	beq	s3,s5,58a <vprintf+0x6a>
  for(i = 0; fmt[i]; i++){
 56a:	2485                	addiw	s1,s1,1
 56c:	8726                	mv	a4,s1
 56e:	009a07b3          	add	a5,s4,s1
 572:	0007c903          	lbu	s2,0(a5)
 576:	22090a63          	beqz	s2,7aa <vprintf+0x28a>
    c0 = fmt[i] & 0xff;
 57a:	0009079b          	sext.w	a5,s2
    if(state == 0){
 57e:	fe0994e3          	bnez	s3,566 <vprintf+0x46>
      if(c0 == '%'){
 582:	fd579de3          	bne	a5,s5,55c <vprintf+0x3c>
        state = '%';
 586:	89be                	mv	s3,a5
 588:	b7cd                	j	56a <vprintf+0x4a>
      if(c0) c1 = fmt[i+1] & 0xff;
 58a:	00ea06b3          	add	a3,s4,a4
 58e:	0016c683          	lbu	a3,1(a3)
      c1 = c2 = 0;
 592:	8636                	mv	a2,a3
      if(c1) c2 = fmt[i+2] & 0xff;
 594:	c681                	beqz	a3,59c <vprintf+0x7c>
 596:	9752                	add	a4,a4,s4
 598:	00274603          	lbu	a2,2(a4)
      if(c0 == 'd'){
 59c:	05878363          	beq	a5,s8,5e2 <vprintf+0xc2>
      } else if(c0 == 'l' && c1 == 'd'){
 5a0:	05978d63          	beq	a5,s9,5fa <vprintf+0xda>
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 2;
      } else if(c0 == 'u'){
 5a4:	07500713          	li	a4,117
 5a8:	0ee78763          	beq	a5,a4,696 <vprintf+0x176>
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 2;
      } else if(c0 == 'x'){
 5ac:	07800713          	li	a4,120
 5b0:	12e78963          	beq	a5,a4,6e2 <vprintf+0x1c2>
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 2;
      } else if(c0 == 'p'){
 5b4:	07000713          	li	a4,112
 5b8:	14e78e63          	beq	a5,a4,714 <vprintf+0x1f4>
        printptr(fd, va_arg(ap, uint64));
      } else if(c0 == 'c'){
 5bc:	06300713          	li	a4,99
 5c0:	18e78e63          	beq	a5,a4,75c <vprintf+0x23c>
        putc(fd, va_arg(ap, uint32));
      } else if(c0 == 's'){
 5c4:	07300713          	li	a4,115
 5c8:	1ae78463          	beq	a5,a4,770 <vprintf+0x250>
        if((s = va_arg(ap, char*)) == 0)
          s = "(null)";
        for(; *s; s++)
          putc(fd, *s);
      } else if(c0 == '%'){
 5cc:	02500713          	li	a4,37
 5d0:	04e79563          	bne	a5,a4,61a <vprintf+0xfa>
        putc(fd, '%');
 5d4:	02500593          	li	a1,37
 5d8:	855a                	mv	a0,s6
 5da:	e8dff0ef          	jal	466 <putc>
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c0);
      }

      state = 0;
 5de:	4981                	li	s3,0
 5e0:	b769                	j	56a <vprintf+0x4a>
        printint(fd, va_arg(ap, int), 10, 1);
 5e2:	008b8913          	addi	s2,s7,8
 5e6:	4685                	li	a3,1
 5e8:	4629                	li	a2,10
 5ea:	000ba583          	lw	a1,0(s7)
 5ee:	855a                	mv	a0,s6
 5f0:	e95ff0ef          	jal	484 <printint>
 5f4:	8bca                	mv	s7,s2
      state = 0;
 5f6:	4981                	li	s3,0
 5f8:	bf8d                	j	56a <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'd'){
 5fa:	06400793          	li	a5,100
 5fe:	02f68963          	beq	a3,a5,630 <vprintf+0x110>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 602:	06c00793          	li	a5,108
 606:	04f68263          	beq	a3,a5,64a <vprintf+0x12a>
      } else if(c0 == 'l' && c1 == 'u'){
 60a:	07500793          	li	a5,117
 60e:	0af68063          	beq	a3,a5,6ae <vprintf+0x18e>
      } else if(c0 == 'l' && c1 == 'x'){
 612:	07800793          	li	a5,120
 616:	0ef68263          	beq	a3,a5,6fa <vprintf+0x1da>
        putc(fd, '%');
 61a:	02500593          	li	a1,37
 61e:	855a                	mv	a0,s6
 620:	e47ff0ef          	jal	466 <putc>
        putc(fd, c0);
 624:	85ca                	mv	a1,s2
 626:	855a                	mv	a0,s6
 628:	e3fff0ef          	jal	466 <putc>
      state = 0;
 62c:	4981                	li	s3,0
 62e:	bf35                	j	56a <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 630:	008b8913          	addi	s2,s7,8
 634:	4685                	li	a3,1
 636:	4629                	li	a2,10
 638:	000bb583          	ld	a1,0(s7)
 63c:	855a                	mv	a0,s6
 63e:	e47ff0ef          	jal	484 <printint>
        i += 1;
 642:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 1);
 644:	8bca                	mv	s7,s2
      state = 0;
 646:	4981                	li	s3,0
        i += 1;
 648:	b70d                	j	56a <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 64a:	06400793          	li	a5,100
 64e:	02f60763          	beq	a2,a5,67c <vprintf+0x15c>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
 652:	07500793          	li	a5,117
 656:	06f60963          	beq	a2,a5,6c8 <vprintf+0x1a8>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
 65a:	07800793          	li	a5,120
 65e:	faf61ee3          	bne	a2,a5,61a <vprintf+0xfa>
        printint(fd, va_arg(ap, uint64), 16, 0);
 662:	008b8913          	addi	s2,s7,8
 666:	4681                	li	a3,0
 668:	4641                	li	a2,16
 66a:	000bb583          	ld	a1,0(s7)
 66e:	855a                	mv	a0,s6
 670:	e15ff0ef          	jal	484 <printint>
        i += 2;
 674:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 16, 0);
 676:	8bca                	mv	s7,s2
      state = 0;
 678:	4981                	li	s3,0
        i += 2;
 67a:	bdc5                	j	56a <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 67c:	008b8913          	addi	s2,s7,8
 680:	4685                	li	a3,1
 682:	4629                	li	a2,10
 684:	000bb583          	ld	a1,0(s7)
 688:	855a                	mv	a0,s6
 68a:	dfbff0ef          	jal	484 <printint>
        i += 2;
 68e:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 1);
 690:	8bca                	mv	s7,s2
      state = 0;
 692:	4981                	li	s3,0
        i += 2;
 694:	bdd9                	j	56a <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 10, 0);
 696:	008b8913          	addi	s2,s7,8
 69a:	4681                	li	a3,0
 69c:	4629                	li	a2,10
 69e:	000be583          	lwu	a1,0(s7)
 6a2:	855a                	mv	a0,s6
 6a4:	de1ff0ef          	jal	484 <printint>
 6a8:	8bca                	mv	s7,s2
      state = 0;
 6aa:	4981                	li	s3,0
 6ac:	bd7d                	j	56a <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 6ae:	008b8913          	addi	s2,s7,8
 6b2:	4681                	li	a3,0
 6b4:	4629                	li	a2,10
 6b6:	000bb583          	ld	a1,0(s7)
 6ba:	855a                	mv	a0,s6
 6bc:	dc9ff0ef          	jal	484 <printint>
        i += 1;
 6c0:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 0);
 6c2:	8bca                	mv	s7,s2
      state = 0;
 6c4:	4981                	li	s3,0
        i += 1;
 6c6:	b555                	j	56a <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 6c8:	008b8913          	addi	s2,s7,8
 6cc:	4681                	li	a3,0
 6ce:	4629                	li	a2,10
 6d0:	000bb583          	ld	a1,0(s7)
 6d4:	855a                	mv	a0,s6
 6d6:	dafff0ef          	jal	484 <printint>
        i += 2;
 6da:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 0);
 6dc:	8bca                	mv	s7,s2
      state = 0;
 6de:	4981                	li	s3,0
        i += 2;
 6e0:	b569                	j	56a <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 16, 0);
 6e2:	008b8913          	addi	s2,s7,8
 6e6:	4681                	li	a3,0
 6e8:	4641                	li	a2,16
 6ea:	000be583          	lwu	a1,0(s7)
 6ee:	855a                	mv	a0,s6
 6f0:	d95ff0ef          	jal	484 <printint>
 6f4:	8bca                	mv	s7,s2
      state = 0;
 6f6:	4981                	li	s3,0
 6f8:	bd8d                	j	56a <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 16, 0);
 6fa:	008b8913          	addi	s2,s7,8
 6fe:	4681                	li	a3,0
 700:	4641                	li	a2,16
 702:	000bb583          	ld	a1,0(s7)
 706:	855a                	mv	a0,s6
 708:	d7dff0ef          	jal	484 <printint>
        i += 1;
 70c:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 16, 0);
 70e:	8bca                	mv	s7,s2
      state = 0;
 710:	4981                	li	s3,0
        i += 1;
 712:	bda1                	j	56a <vprintf+0x4a>
 714:	e06a                	sd	s10,0(sp)
        printptr(fd, va_arg(ap, uint64));
 716:	008b8d13          	addi	s10,s7,8
 71a:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 71e:	03000593          	li	a1,48
 722:	855a                	mv	a0,s6
 724:	d43ff0ef          	jal	466 <putc>
  putc(fd, 'x');
 728:	07800593          	li	a1,120
 72c:	855a                	mv	a0,s6
 72e:	d39ff0ef          	jal	466 <putc>
 732:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 734:	00000b97          	auipc	s7,0x0
 738:	324b8b93          	addi	s7,s7,804 # a58 <digits>
 73c:	03c9d793          	srli	a5,s3,0x3c
 740:	97de                	add	a5,a5,s7
 742:	0007c583          	lbu	a1,0(a5)
 746:	855a                	mv	a0,s6
 748:	d1fff0ef          	jal	466 <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 74c:	0992                	slli	s3,s3,0x4
 74e:	397d                	addiw	s2,s2,-1
 750:	fe0916e3          	bnez	s2,73c <vprintf+0x21c>
        printptr(fd, va_arg(ap, uint64));
 754:	8bea                	mv	s7,s10
      state = 0;
 756:	4981                	li	s3,0
 758:	6d02                	ld	s10,0(sp)
 75a:	bd01                	j	56a <vprintf+0x4a>
        putc(fd, va_arg(ap, uint32));
 75c:	008b8913          	addi	s2,s7,8
 760:	000bc583          	lbu	a1,0(s7)
 764:	855a                	mv	a0,s6
 766:	d01ff0ef          	jal	466 <putc>
 76a:	8bca                	mv	s7,s2
      state = 0;
 76c:	4981                	li	s3,0
 76e:	bbf5                	j	56a <vprintf+0x4a>
        if((s = va_arg(ap, char*)) == 0)
 770:	008b8993          	addi	s3,s7,8
 774:	000bb903          	ld	s2,0(s7)
 778:	00090f63          	beqz	s2,796 <vprintf+0x276>
        for(; *s; s++)
 77c:	00094583          	lbu	a1,0(s2)
 780:	c195                	beqz	a1,7a4 <vprintf+0x284>
          putc(fd, *s);
 782:	855a                	mv	a0,s6
 784:	ce3ff0ef          	jal	466 <putc>
        for(; *s; s++)
 788:	0905                	addi	s2,s2,1
 78a:	00094583          	lbu	a1,0(s2)
 78e:	f9f5                	bnez	a1,782 <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 790:	8bce                	mv	s7,s3
      state = 0;
 792:	4981                	li	s3,0
 794:	bbd9                	j	56a <vprintf+0x4a>
          s = "(null)";
 796:	00000917          	auipc	s2,0x0
 79a:	2ba90913          	addi	s2,s2,698 # a50 <malloc+0x1ae>
        for(; *s; s++)
 79e:	02800593          	li	a1,40
 7a2:	b7c5                	j	782 <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 7a4:	8bce                	mv	s7,s3
      state = 0;
 7a6:	4981                	li	s3,0
 7a8:	b3c9                	j	56a <vprintf+0x4a>
 7aa:	64a6                	ld	s1,72(sp)
 7ac:	79e2                	ld	s3,56(sp)
 7ae:	7a42                	ld	s4,48(sp)
 7b0:	7aa2                	ld	s5,40(sp)
 7b2:	7b02                	ld	s6,32(sp)
 7b4:	6be2                	ld	s7,24(sp)
 7b6:	6c42                	ld	s8,16(sp)
 7b8:	6ca2                	ld	s9,8(sp)
    }
  }
}
 7ba:	60e6                	ld	ra,88(sp)
 7bc:	6446                	ld	s0,80(sp)
 7be:	6906                	ld	s2,64(sp)
 7c0:	6125                	addi	sp,sp,96
 7c2:	8082                	ret

00000000000007c4 <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 7c4:	715d                	addi	sp,sp,-80
 7c6:	ec06                	sd	ra,24(sp)
 7c8:	e822                	sd	s0,16(sp)
 7ca:	1000                	addi	s0,sp,32
 7cc:	e010                	sd	a2,0(s0)
 7ce:	e414                	sd	a3,8(s0)
 7d0:	e818                	sd	a4,16(s0)
 7d2:	ec1c                	sd	a5,24(s0)
 7d4:	03043023          	sd	a6,32(s0)
 7d8:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 7dc:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 7e0:	8622                	mv	a2,s0
 7e2:	d3fff0ef          	jal	520 <vprintf>
}
 7e6:	60e2                	ld	ra,24(sp)
 7e8:	6442                	ld	s0,16(sp)
 7ea:	6161                	addi	sp,sp,80
 7ec:	8082                	ret

00000000000007ee <printf>:

void
printf(const char *fmt, ...)
{
 7ee:	711d                	addi	sp,sp,-96
 7f0:	ec06                	sd	ra,24(sp)
 7f2:	e822                	sd	s0,16(sp)
 7f4:	1000                	addi	s0,sp,32
 7f6:	e40c                	sd	a1,8(s0)
 7f8:	e810                	sd	a2,16(s0)
 7fa:	ec14                	sd	a3,24(s0)
 7fc:	f018                	sd	a4,32(s0)
 7fe:	f41c                	sd	a5,40(s0)
 800:	03043823          	sd	a6,48(s0)
 804:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 808:	00840613          	addi	a2,s0,8
 80c:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 810:	85aa                	mv	a1,a0
 812:	4505                	li	a0,1
 814:	d0dff0ef          	jal	520 <vprintf>
}
 818:	60e2                	ld	ra,24(sp)
 81a:	6442                	ld	s0,16(sp)
 81c:	6125                	addi	sp,sp,96
 81e:	8082                	ret

0000000000000820 <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 820:	1141                	addi	sp,sp,-16
 822:	e422                	sd	s0,8(sp)
 824:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 826:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 82a:	00000797          	auipc	a5,0x0
 82e:	7d67b783          	ld	a5,2006(a5) # 1000 <freep>
 832:	a02d                	j	85c <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 834:	4618                	lw	a4,8(a2)
 836:	9f2d                	addw	a4,a4,a1
 838:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 83c:	6398                	ld	a4,0(a5)
 83e:	6310                	ld	a2,0(a4)
 840:	a83d                	j	87e <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 842:	ff852703          	lw	a4,-8(a0)
 846:	9f31                	addw	a4,a4,a2
 848:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 84a:	ff053683          	ld	a3,-16(a0)
 84e:	a091                	j	892 <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 850:	6398                	ld	a4,0(a5)
 852:	00e7e463          	bltu	a5,a4,85a <free+0x3a>
 856:	00e6ea63          	bltu	a3,a4,86a <free+0x4a>
{
 85a:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 85c:	fed7fae3          	bgeu	a5,a3,850 <free+0x30>
 860:	6398                	ld	a4,0(a5)
 862:	00e6e463          	bltu	a3,a4,86a <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 866:	fee7eae3          	bltu	a5,a4,85a <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 86a:	ff852583          	lw	a1,-8(a0)
 86e:	6390                	ld	a2,0(a5)
 870:	02059813          	slli	a6,a1,0x20
 874:	01c85713          	srli	a4,a6,0x1c
 878:	9736                	add	a4,a4,a3
 87a:	fae60de3          	beq	a2,a4,834 <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 87e:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 882:	4790                	lw	a2,8(a5)
 884:	02061593          	slli	a1,a2,0x20
 888:	01c5d713          	srli	a4,a1,0x1c
 88c:	973e                	add	a4,a4,a5
 88e:	fae68ae3          	beq	a3,a4,842 <free+0x22>
    p->s.ptr = bp->s.ptr;
 892:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 894:	00000717          	auipc	a4,0x0
 898:	76f73623          	sd	a5,1900(a4) # 1000 <freep>
}
 89c:	6422                	ld	s0,8(sp)
 89e:	0141                	addi	sp,sp,16
 8a0:	8082                	ret

00000000000008a2 <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 8a2:	7139                	addi	sp,sp,-64
 8a4:	fc06                	sd	ra,56(sp)
 8a6:	f822                	sd	s0,48(sp)
 8a8:	f426                	sd	s1,40(sp)
 8aa:	ec4e                	sd	s3,24(sp)
 8ac:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 8ae:	02051493          	slli	s1,a0,0x20
 8b2:	9081                	srli	s1,s1,0x20
 8b4:	04bd                	addi	s1,s1,15
 8b6:	8091                	srli	s1,s1,0x4
 8b8:	0014899b          	addiw	s3,s1,1
 8bc:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 8be:	00000517          	auipc	a0,0x0
 8c2:	74253503          	ld	a0,1858(a0) # 1000 <freep>
 8c6:	c915                	beqz	a0,8fa <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 8c8:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 8ca:	4798                	lw	a4,8(a5)
 8cc:	08977a63          	bgeu	a4,s1,960 <malloc+0xbe>
 8d0:	f04a                	sd	s2,32(sp)
 8d2:	e852                	sd	s4,16(sp)
 8d4:	e456                	sd	s5,8(sp)
 8d6:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 8d8:	8a4e                	mv	s4,s3
 8da:	0009871b          	sext.w	a4,s3
 8de:	6685                	lui	a3,0x1
 8e0:	00d77363          	bgeu	a4,a3,8e6 <malloc+0x44>
 8e4:	6a05                	lui	s4,0x1
 8e6:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 8ea:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 8ee:	00000917          	auipc	s2,0x0
 8f2:	71290913          	addi	s2,s2,1810 # 1000 <freep>
  if(p == SBRK_ERROR)
 8f6:	5afd                	li	s5,-1
 8f8:	a081                	j	938 <malloc+0x96>
 8fa:	f04a                	sd	s2,32(sp)
 8fc:	e852                	sd	s4,16(sp)
 8fe:	e456                	sd	s5,8(sp)
 900:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 902:	00000797          	auipc	a5,0x0
 906:	70e78793          	addi	a5,a5,1806 # 1010 <base>
 90a:	00000717          	auipc	a4,0x0
 90e:	6ef73b23          	sd	a5,1782(a4) # 1000 <freep>
 912:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 914:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 918:	b7c1                	j	8d8 <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 91a:	6398                	ld	a4,0(a5)
 91c:	e118                	sd	a4,0(a0)
 91e:	a8a9                	j	978 <malloc+0xd6>
  hp->s.size = nu;
 920:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 924:	0541                	addi	a0,a0,16
 926:	efbff0ef          	jal	820 <free>
  return freep;
 92a:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 92e:	c12d                	beqz	a0,990 <malloc+0xee>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 930:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 932:	4798                	lw	a4,8(a5)
 934:	02977263          	bgeu	a4,s1,958 <malloc+0xb6>
    if(p == freep)
 938:	00093703          	ld	a4,0(s2)
 93c:	853e                	mv	a0,a5
 93e:	fef719e3          	bne	a4,a5,930 <malloc+0x8e>
  p = sbrk(nu * sizeof(Header));
 942:	8552                	mv	a0,s4
 944:	a27ff0ef          	jal	36a <sbrk>
  if(p == SBRK_ERROR)
 948:	fd551ce3          	bne	a0,s5,920 <malloc+0x7e>
        return 0;
 94c:	4501                	li	a0,0
 94e:	7902                	ld	s2,32(sp)
 950:	6a42                	ld	s4,16(sp)
 952:	6aa2                	ld	s5,8(sp)
 954:	6b02                	ld	s6,0(sp)
 956:	a03d                	j	984 <malloc+0xe2>
 958:	7902                	ld	s2,32(sp)
 95a:	6a42                	ld	s4,16(sp)
 95c:	6aa2                	ld	s5,8(sp)
 95e:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 960:	fae48de3          	beq	s1,a4,91a <malloc+0x78>
        p->s.size -= nunits;
 964:	4137073b          	subw	a4,a4,s3
 968:	c798                	sw	a4,8(a5)
        p += p->s.size;
 96a:	02071693          	slli	a3,a4,0x20
 96e:	01c6d713          	srli	a4,a3,0x1c
 972:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 974:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 978:	00000717          	auipc	a4,0x0
 97c:	68a73423          	sd	a0,1672(a4) # 1000 <freep>
      return (void*)(p + 1);
 980:	01078513          	addi	a0,a5,16
  }
}
 984:	70e2                	ld	ra,56(sp)
 986:	7442                	ld	s0,48(sp)
 988:	74a2                	ld	s1,40(sp)
 98a:	69e2                	ld	s3,24(sp)
 98c:	6121                	addi	sp,sp,64
 98e:	8082                	ret
 990:	7902                	ld	s2,32(sp)
 992:	6a42                	ld	s4,16(sp)
 994:	6aa2                	ld	s5,8(sp)
 996:	6b02                	ld	s6,0(sp)
 998:	b7f5                	j	984 <malloc+0xe2>
