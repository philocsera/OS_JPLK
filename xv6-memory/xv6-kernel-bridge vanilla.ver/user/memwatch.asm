
user/_memwatch:     file format elf64-littleriscv


Disassembly of section .text:

0000000000000000 <print_json>:
  }
}

static void
print_json(int tick)
{
   0:	81010113          	addi	sp,sp,-2032
   4:	7e113423          	sd	ra,2024(sp)
   8:	7e813023          	sd	s0,2016(sp)
   c:	7c913c23          	sd	s1,2008(sp)
  10:	7d213823          	sd	s2,2000(sp)
  14:	7d313423          	sd	s3,1992(sp)
  18:	7d413023          	sd	s4,1984(sp)
  1c:	7b513c23          	sd	s5,1976(sp)
  20:	7b613823          	sd	s6,1968(sp)
  24:	7b713423          	sd	s7,1960(sp)
  28:	7b813023          	sd	s8,1952(sp)
  2c:	7f010413          	addi	s0,sp,2032
  30:	da010113          	addi	sp,sp,-608
  34:	84aa                	mv	s1,a0
  struct memstat stats[MEMSTAT_MAX];
  int n;
  int i;

  n = getmemstat(stats, MEMSTAT_MAX);
  36:	757d                	lui	a0,0xfffff
  38:	04000593          	li	a1,64
  3c:	5b050793          	addi	a5,a0,1456 # fffffffffffff5b0 <base+0xffffffffffffd5a0>
  40:	00878533          	add	a0,a5,s0
  44:	5d6000ef          	jal	61a <getmemstat>

  if(n < 0){
  48:	02054d63          	bltz	a0,82 <print_json+0x82>
  4c:	8aaa                	mv	s5,a0
    printf("{\"type\":\"memstat\",\"error\":\"getmemstat failed\"}\n");
    return;
  }

  printf("{\"type\":\"memstat\",\"tick\":%d,\"processes\":[", tick);
  4e:	85a6                	mv	a1,s1
  50:	00001517          	auipc	a0,0x1
  54:	b4050513          	addi	a0,a0,-1216 # b90 <malloc+0x12a>
  58:	15b000ef          	jal	9b2 <printf>

  for(i = 0; i < n; i++){
  5c:	07505f63          	blez	s5,da <print_json+0xda>
  60:	79fd                	lui	s3,0xfffff
  62:	5c898793          	addi	a5,s3,1480 # fffffffffffff5c8 <base+0xffffffffffffd5b8>
  66:	008789b3          	add	s3,a5,s0
  6a:	4a01                	li	s4,0
  return (int)((sz * 100) / quota);
  6c:	06400b93          	li	s7,100
    int usage = usage_percent(stats[i].sz, stats[i].mem_quota);

    if(i > 0)
      printf(",");
  70:	00001c17          	auipc	s8,0x1
  74:	b50c0c13          	addi	s8,s8,-1200 # bc0 <malloc+0x15a>

    printf("{\"pid\":%d,\"state\":%d,\"name\":\"%s\",\"sz\":%d,\"quota\":%d,\"usage\":%d}",
  78:	00001b17          	auipc	s6,0x1
  7c:	b50b0b13          	addi	s6,s6,-1200 # bc8 <malloc+0x162>
  80:	a825                	j	b8 <print_json+0xb8>
    printf("{\"type\":\"memstat\",\"error\":\"getmemstat failed\"}\n");
  82:	00001517          	auipc	a0,0x1
  86:	ade50513          	addi	a0,a0,-1314 # b60 <malloc+0xfa>
  8a:	129000ef          	jal	9b2 <printf>
    return;
  8e:	a8a1                	j	e6 <print_json+0xe6>
    return -1;
  90:	54fd                	li	s1,-1
  92:	a835                	j	ce <print_json+0xce>
    printf("{\"pid\":%d,\"state\":%d,\"name\":\"%s\",\"sz\":%d,\"quota\":%d,\"usage\":%d}",
  94:	8826                	mv	a6,s1
  96:	ff892783          	lw	a5,-8(s2)
  9a:	ff092703          	lw	a4,-16(s2)
  9e:	86ca                	mv	a3,s2
  a0:	fec92603          	lw	a2,-20(s2)
  a4:	fe892583          	lw	a1,-24(s2)
  a8:	855a                	mv	a0,s6
  aa:	109000ef          	jal	9b2 <printf>
  for(i = 0; i < n; i++){
  ae:	2a05                	addiw	s4,s4,1
  b0:	02898993          	addi	s3,s3,40
  b4:	034a8363          	beq	s5,s4,da <print_json+0xda>
    int usage = usage_percent(stats[i].sz, stats[i].mem_quota);
  b8:	894e                	mv	s2,s3
  ba:	ff09b483          	ld	s1,-16(s3)
  be:	ff89b783          	ld	a5,-8(s3)
  if(quota == 0)
  c2:	d7f9                	beqz	a5,90 <print_json+0x90>
  return (int)((sz * 100) / quota);
  c4:	037484b3          	mul	s1,s1,s7
  c8:	02f4d4b3          	divu	s1,s1,a5
  cc:	2481                	sext.w	s1,s1
    if(i > 0)
  ce:	fd4053e3          	blez	s4,94 <print_json+0x94>
      printf(",");
  d2:	8562                	mv	a0,s8
  d4:	0df000ef          	jal	9b2 <printf>
  d8:	bf75                	j	94 <print_json+0x94>
      (int)stats[i].sz,
      (int)stats[i].mem_quota,
      usage);
  }

  printf("]}\n");
  da:	00001517          	auipc	a0,0x1
  de:	b2e50513          	addi	a0,a0,-1234 # c08 <malloc+0x1a2>
  e2:	0d1000ef          	jal	9b2 <printf>
}
  e6:	26010113          	addi	sp,sp,608
  ea:	7e813083          	ld	ra,2024(sp)
  ee:	7e013403          	ld	s0,2016(sp)
  f2:	7d813483          	ld	s1,2008(sp)
  f6:	7d013903          	ld	s2,2000(sp)
  fa:	7c813983          	ld	s3,1992(sp)
  fe:	7c013a03          	ld	s4,1984(sp)
 102:	7b813a83          	ld	s5,1976(sp)
 106:	7b013b03          	ld	s6,1968(sp)
 10a:	7a813b83          	ld	s7,1960(sp)
 10e:	7a013c03          	ld	s8,1952(sp)
 112:	7f010113          	addi	sp,sp,2032
 116:	8082                	ret

0000000000000118 <print_table>:
{
 118:	81010113          	addi	sp,sp,-2032
 11c:	7e113423          	sd	ra,2024(sp)
 120:	7e813023          	sd	s0,2016(sp)
 124:	7c913c23          	sd	s1,2008(sp)
 128:	7d213823          	sd	s2,2000(sp)
 12c:	7d313423          	sd	s3,1992(sp)
 130:	7d413023          	sd	s4,1984(sp)
 134:	7b513c23          	sd	s5,1976(sp)
 138:	7f010413          	addi	s0,sp,2032
 13c:	db010113          	addi	sp,sp,-592
 140:	84aa                	mv	s1,a0
  n = getmemstat(stats, MEMSTAT_MAX);
 142:	757d                	lui	a0,0xfffff
 144:	04000593          	li	a1,64
 148:	5c050793          	addi	a5,a0,1472 # fffffffffffff5c0 <base+0xffffffffffffd5b0>
 14c:	00878533          	add	a0,a5,s0
 150:	4ca000ef          	jal	61a <getmemstat>
  if(n < 0){
 154:	04054763          	bltz	a0,1a2 <print_table+0x8a>
 158:	89aa                	mv	s3,a0
  printf("\n[tick %d]\n", tick);
 15a:	85a6                	mv	a1,s1
 15c:	00001517          	auipc	a0,0x1
 160:	acc50513          	addi	a0,a0,-1332 # c28 <malloc+0x1c2>
 164:	04f000ef          	jal	9b2 <printf>
  printf("pid\tstate\tsz\tquota\tusage\tname\n");
 168:	00001517          	auipc	a0,0x1
 16c:	ad050513          	addi	a0,a0,-1328 # c38 <malloc+0x1d2>
 170:	043000ef          	jal	9b2 <printf>
  for(i = 0; i < n; i++){
 174:	03305d63          	blez	s3,1ae <print_table+0x96>
 178:	74fd                	lui	s1,0xfffff
 17a:	5d848793          	addi	a5,s1,1496 # fffffffffffff5d8 <base+0xffffffffffffd5c8>
 17e:	008784b3          	add	s1,a5,s0
 182:	00299913          	slli	s2,s3,0x2
 186:	994e                	add	s2,s2,s3
 188:	090e                	slli	s2,s2,0x3
 18a:	9926                	add	s2,s2,s1
      printf("%d\t%d\t%d\t%d\t-\t%s\n",
 18c:	00001a97          	auipc	s5,0x1
 190:	acca8a93          	addi	s5,s5,-1332 # c58 <malloc+0x1f2>
  return (int)((sz * 100) / quota);
 194:	06400993          	li	s3,100
      printf("%d\t%d\t%d\t%d\t%d%%\t%s\n",
 198:	00001a17          	auipc	s4,0x1
 19c:	ad8a0a13          	addi	s4,s4,-1320 # c70 <malloc+0x20a>
 1a0:	a881                	j	1f0 <print_table+0xd8>
    printf("getmemstat failed\n");
 1a2:	00001517          	auipc	a0,0x1
 1a6:	a6e50513          	addi	a0,a0,-1426 # c10 <malloc+0x1aa>
 1aa:	009000ef          	jal	9b2 <printf>
}
 1ae:	25010113          	addi	sp,sp,592
 1b2:	7e813083          	ld	ra,2024(sp)
 1b6:	7e013403          	ld	s0,2016(sp)
 1ba:	7d813483          	ld	s1,2008(sp)
 1be:	7d013903          	ld	s2,2000(sp)
 1c2:	7c813983          	ld	s3,1992(sp)
 1c6:	7c013a03          	ld	s4,1984(sp)
 1ca:	7b813a83          	ld	s5,1976(sp)
 1ce:	7f010113          	addi	sp,sp,2032
 1d2:	8082                	ret
      printf("%d\t%d\t%d\t%d\t-\t%s\n",
 1d4:	87c2                	mv	a5,a6
 1d6:	2701                	sext.w	a4,a4
 1d8:	2681                	sext.w	a3,a3
 1da:	fec82603          	lw	a2,-20(a6)
 1de:	fe882583          	lw	a1,-24(a6)
 1e2:	8556                	mv	a0,s5
 1e4:	7ce000ef          	jal	9b2 <printf>
  for(i = 0; i < n; i++){
 1e8:	02848493          	addi	s1,s1,40
 1ec:	fd2481e3          	beq	s1,s2,1ae <print_table+0x96>
    int usage = usage_percent(stats[i].sz, stats[i].mem_quota);
 1f0:	8826                	mv	a6,s1
 1f2:	ff04b683          	ld	a3,-16(s1)
 1f6:	ff84b703          	ld	a4,-8(s1)
  if(quota == 0)
 1fa:	df69                	beqz	a4,1d4 <print_table+0xbc>
  return (int)((sz * 100) / quota);
 1fc:	033687b3          	mul	a5,a3,s3
 200:	02e7d7b3          	divu	a5,a5,a4
 204:	2781                	sext.w	a5,a5
    if(usage < 0){
 206:	fc07c7e3          	bltz	a5,1d4 <print_table+0xbc>
      printf("%d\t%d\t%d\t%d\t%d%%\t%s\n",
 20a:	2701                	sext.w	a4,a4
 20c:	2681                	sext.w	a3,a3
 20e:	fec4a603          	lw	a2,-20(s1)
 212:	fe84a583          	lw	a1,-24(s1)
 216:	8552                	mv	a0,s4
 218:	79a000ef          	jal	9b2 <printf>
 21c:	b7f1                	j	1e8 <print_table+0xd0>

000000000000021e <main>:

int
main(int argc, char *argv[])
{
 21e:	7139                	addi	sp,sp,-64
 220:	fc06                	sd	ra,56(sp)
 222:	f822                	sd	s0,48(sp)
 224:	f426                	sd	s1,40(sp)
 226:	f04a                	sd	s2,32(sp)
 228:	ec4e                	sd	s3,24(sp)
 22a:	e852                	sd	s4,16(sp)
 22c:	e456                	sd	s5,8(sp)
 22e:	e05a                	sd	s6,0(sp)
 230:	0080                	addi	s0,sp,64
  int ticks = 5;
  int interval = 10;
  int argi = 1;
  int t;

  if(argc >= 2 && strcmp(argv[1], "json") == 0){
 232:	4785                	li	a5,1
  int json = 0;
 234:	4a01                	li	s4,0
  if(argc >= 2 && strcmp(argv[1], "json") == 0){
 236:	02a7c263          	blt	a5,a0,25a <main+0x3c>
  int interval = 10;
 23a:	4995                	li	s3,5
 23c:	4529                	li	a0,10

  if(argc > argi){
    interval = atoi(argv[argi]);
  }

  if(ticks <= 0)
 23e:	894e                	mv	s2,s3
 240:	07305163          	blez	s3,2a2 <main+0x84>
 244:	00090a9b          	sext.w	s5,s2
    ticks = 1;

  if(interval < 0)
 248:	fff54793          	not	a5,a0
 24c:	97fd                	srai	a5,a5,0x3f
 24e:	8d7d                	and	a0,a0,a5
 250:	0005099b          	sext.w	s3,a0
    interval = 0;

  for(t = 0; t < ticks; t++){
 254:	4481                	li	s1,0
    if(json)
      print_json(t);
    else
      print_table(t);

    if(t != ticks - 1)
 256:	397d                	addiw	s2,s2,-1
 258:	a095                	j	2bc <main+0x9e>
 25a:	892a                	mv	s2,a0
 25c:	84ae                	mv	s1,a1
  if(argc >= 2 && strcmp(argv[1], "json") == 0){
 25e:	00001597          	auipc	a1,0x1
 262:	a2a58593          	addi	a1,a1,-1494 # c88 <malloc+0x222>
 266:	6488                	ld	a0,8(s1)
 268:	092000ef          	jal	2fa <strcmp>
 26c:	e519                	bnez	a0,27a <main+0x5c>
  if(argc > argi){
 26e:	4789                	li	a5,2
 270:	4a05                	li	s4,1
 272:	4a89                	li	s5,2
 274:	fd27d3e3          	bge	a5,s2,23a <main+0x1c>
 278:	a019                	j	27e <main+0x60>
  int argi = 1;
 27a:	4a85                	li	s5,1
  int json = 0;
 27c:	4a01                	li	s4,0
    ticks = atoi(argv[argi]);
 27e:	003a9b13          	slli	s6,s5,0x3
 282:	016487b3          	add	a5,s1,s6
 286:	6388                	ld	a0,0(a5)
 288:	1b8000ef          	jal	440 <atoi>
 28c:	89aa                	mv	s3,a0
  if(argc > argi){
 28e:	0a85                	addi	s5,s5,1
 290:	012ad763          	bge	s5,s2,29e <main+0x80>
    interval = atoi(argv[argi]);
 294:	94da                	add	s1,s1,s6
 296:	6488                	ld	a0,8(s1)
 298:	1a8000ef          	jal	440 <atoi>
 29c:	b74d                	j	23e <main+0x20>
  int interval = 10;
 29e:	4529                	li	a0,10
 2a0:	bf79                	j	23e <main+0x20>
  if(ticks <= 0)
 2a2:	4905                	li	s2,1
 2a4:	b745                	j	244 <main+0x26>
      print_table(t);
 2a6:	8526                	mv	a0,s1
 2a8:	e71ff0ef          	jal	118 <print_table>
    if(t != ticks - 1)
 2ac:	00990563          	beq	s2,s1,2b6 <main+0x98>
      pause(interval);
 2b0:	854e                	mv	a0,s3
 2b2:	340000ef          	jal	5f2 <pause>
  for(t = 0; t < ticks; t++){
 2b6:	2485                	addiw	s1,s1,1
 2b8:	009a8863          	beq	s5,s1,2c8 <main+0xaa>
    if(json)
 2bc:	fe0a05e3          	beqz	s4,2a6 <main+0x88>
      print_json(t);
 2c0:	8526                	mv	a0,s1
 2c2:	d3fff0ef          	jal	0 <print_json>
 2c6:	b7dd                	j	2ac <main+0x8e>
  }

  exit(0);
 2c8:	4501                	li	a0,0
 2ca:	298000ef          	jal	562 <exit>

00000000000002ce <start>:
//
// wrapper so that it's OK if main() does not call exit().
//
void
start(int argc, char **argv)
{
 2ce:	1141                	addi	sp,sp,-16
 2d0:	e406                	sd	ra,8(sp)
 2d2:	e022                	sd	s0,0(sp)
 2d4:	0800                	addi	s0,sp,16
  int r;
  extern int main(int argc, char **argv);
  r = main(argc, argv);
 2d6:	f49ff0ef          	jal	21e <main>
  exit(r);
 2da:	288000ef          	jal	562 <exit>

00000000000002de <strcpy>:
}

char*
strcpy(char *s, const char *t)
{
 2de:	1141                	addi	sp,sp,-16
 2e0:	e422                	sd	s0,8(sp)
 2e2:	0800                	addi	s0,sp,16
  char *os;

  os = s;
  while((*s++ = *t++) != 0)
 2e4:	87aa                	mv	a5,a0
 2e6:	0585                	addi	a1,a1,1
 2e8:	0785                	addi	a5,a5,1
 2ea:	fff5c703          	lbu	a4,-1(a1)
 2ee:	fee78fa3          	sb	a4,-1(a5)
 2f2:	fb75                	bnez	a4,2e6 <strcpy+0x8>
    ;
  return os;
}
 2f4:	6422                	ld	s0,8(sp)
 2f6:	0141                	addi	sp,sp,16
 2f8:	8082                	ret

00000000000002fa <strcmp>:

int
strcmp(const char *p, const char *q)
{
 2fa:	1141                	addi	sp,sp,-16
 2fc:	e422                	sd	s0,8(sp)
 2fe:	0800                	addi	s0,sp,16
  while(*p && *p == *q)
 300:	00054783          	lbu	a5,0(a0)
 304:	cb91                	beqz	a5,318 <strcmp+0x1e>
 306:	0005c703          	lbu	a4,0(a1)
 30a:	00f71763          	bne	a4,a5,318 <strcmp+0x1e>
    p++, q++;
 30e:	0505                	addi	a0,a0,1
 310:	0585                	addi	a1,a1,1
  while(*p && *p == *q)
 312:	00054783          	lbu	a5,0(a0)
 316:	fbe5                	bnez	a5,306 <strcmp+0xc>
  return (uchar)*p - (uchar)*q;
 318:	0005c503          	lbu	a0,0(a1)
}
 31c:	40a7853b          	subw	a0,a5,a0
 320:	6422                	ld	s0,8(sp)
 322:	0141                	addi	sp,sp,16
 324:	8082                	ret

0000000000000326 <strlen>:

uint
strlen(const char *s)
{
 326:	1141                	addi	sp,sp,-16
 328:	e422                	sd	s0,8(sp)
 32a:	0800                	addi	s0,sp,16
  int n;

  for(n = 0; s[n]; n++)
 32c:	00054783          	lbu	a5,0(a0)
 330:	cf91                	beqz	a5,34c <strlen+0x26>
 332:	0505                	addi	a0,a0,1
 334:	87aa                	mv	a5,a0
 336:	86be                	mv	a3,a5
 338:	0785                	addi	a5,a5,1
 33a:	fff7c703          	lbu	a4,-1(a5)
 33e:	ff65                	bnez	a4,336 <strlen+0x10>
 340:	40a6853b          	subw	a0,a3,a0
 344:	2505                	addiw	a0,a0,1
    ;
  return n;
}
 346:	6422                	ld	s0,8(sp)
 348:	0141                	addi	sp,sp,16
 34a:	8082                	ret
  for(n = 0; s[n]; n++)
 34c:	4501                	li	a0,0
 34e:	bfe5                	j	346 <strlen+0x20>

0000000000000350 <memset>:

void*
memset(void *dst, int c, uint n)
{
 350:	1141                	addi	sp,sp,-16
 352:	e422                	sd	s0,8(sp)
 354:	0800                	addi	s0,sp,16
  char *cdst = (char *) dst;
  int i;
  for(i = 0; i < n; i++){
 356:	ca19                	beqz	a2,36c <memset+0x1c>
 358:	87aa                	mv	a5,a0
 35a:	1602                	slli	a2,a2,0x20
 35c:	9201                	srli	a2,a2,0x20
 35e:	00a60733          	add	a4,a2,a0
    cdst[i] = c;
 362:	00b78023          	sb	a1,0(a5)
  for(i = 0; i < n; i++){
 366:	0785                	addi	a5,a5,1
 368:	fee79de3          	bne	a5,a4,362 <memset+0x12>
  }
  return dst;
}
 36c:	6422                	ld	s0,8(sp)
 36e:	0141                	addi	sp,sp,16
 370:	8082                	ret

0000000000000372 <strchr>:

char*
strchr(const char *s, char c)
{
 372:	1141                	addi	sp,sp,-16
 374:	e422                	sd	s0,8(sp)
 376:	0800                	addi	s0,sp,16
  for(; *s; s++)
 378:	00054783          	lbu	a5,0(a0)
 37c:	cb99                	beqz	a5,392 <strchr+0x20>
    if(*s == c)
 37e:	00f58763          	beq	a1,a5,38c <strchr+0x1a>
  for(; *s; s++)
 382:	0505                	addi	a0,a0,1
 384:	00054783          	lbu	a5,0(a0)
 388:	fbfd                	bnez	a5,37e <strchr+0xc>
      return (char*)s;
  return 0;
 38a:	4501                	li	a0,0
}
 38c:	6422                	ld	s0,8(sp)
 38e:	0141                	addi	sp,sp,16
 390:	8082                	ret
  return 0;
 392:	4501                	li	a0,0
 394:	bfe5                	j	38c <strchr+0x1a>

0000000000000396 <gets>:

char*
gets(char *buf, int max)
{
 396:	711d                	addi	sp,sp,-96
 398:	ec86                	sd	ra,88(sp)
 39a:	e8a2                	sd	s0,80(sp)
 39c:	e4a6                	sd	s1,72(sp)
 39e:	e0ca                	sd	s2,64(sp)
 3a0:	fc4e                	sd	s3,56(sp)
 3a2:	f852                	sd	s4,48(sp)
 3a4:	f456                	sd	s5,40(sp)
 3a6:	f05a                	sd	s6,32(sp)
 3a8:	ec5e                	sd	s7,24(sp)
 3aa:	1080                	addi	s0,sp,96
 3ac:	8baa                	mv	s7,a0
 3ae:	8a2e                	mv	s4,a1
  int i, cc;
  char c;

  for(i=0; i+1 < max; ){
 3b0:	892a                	mv	s2,a0
 3b2:	4481                	li	s1,0
    cc = read(0, &c, 1);
    if(cc < 1)
      break;
    buf[i++] = c;
    if(c == '\n' || c == '\r')
 3b4:	4aa9                	li	s5,10
 3b6:	4b35                	li	s6,13
  for(i=0; i+1 < max; ){
 3b8:	89a6                	mv	s3,s1
 3ba:	2485                	addiw	s1,s1,1
 3bc:	0344d663          	bge	s1,s4,3e8 <gets+0x52>
    cc = read(0, &c, 1);
 3c0:	4605                	li	a2,1
 3c2:	faf40593          	addi	a1,s0,-81
 3c6:	4501                	li	a0,0
 3c8:	1b2000ef          	jal	57a <read>
    if(cc < 1)
 3cc:	00a05e63          	blez	a0,3e8 <gets+0x52>
    buf[i++] = c;
 3d0:	faf44783          	lbu	a5,-81(s0)
 3d4:	00f90023          	sb	a5,0(s2)
    if(c == '\n' || c == '\r')
 3d8:	01578763          	beq	a5,s5,3e6 <gets+0x50>
 3dc:	0905                	addi	s2,s2,1
 3de:	fd679de3          	bne	a5,s6,3b8 <gets+0x22>
    buf[i++] = c;
 3e2:	89a6                	mv	s3,s1
 3e4:	a011                	j	3e8 <gets+0x52>
 3e6:	89a6                	mv	s3,s1
      break;
  }
  buf[i] = '\0';
 3e8:	99de                	add	s3,s3,s7
 3ea:	00098023          	sb	zero,0(s3)
  return buf;
}
 3ee:	855e                	mv	a0,s7
 3f0:	60e6                	ld	ra,88(sp)
 3f2:	6446                	ld	s0,80(sp)
 3f4:	64a6                	ld	s1,72(sp)
 3f6:	6906                	ld	s2,64(sp)
 3f8:	79e2                	ld	s3,56(sp)
 3fa:	7a42                	ld	s4,48(sp)
 3fc:	7aa2                	ld	s5,40(sp)
 3fe:	7b02                	ld	s6,32(sp)
 400:	6be2                	ld	s7,24(sp)
 402:	6125                	addi	sp,sp,96
 404:	8082                	ret

0000000000000406 <stat>:

int
stat(const char *n, struct stat *st)
{
 406:	1101                	addi	sp,sp,-32
 408:	ec06                	sd	ra,24(sp)
 40a:	e822                	sd	s0,16(sp)
 40c:	e04a                	sd	s2,0(sp)
 40e:	1000                	addi	s0,sp,32
 410:	892e                	mv	s2,a1
  int fd;
  int r;

  fd = open(n, O_RDONLY);
 412:	4581                	li	a1,0
 414:	18e000ef          	jal	5a2 <open>
  if(fd < 0)
 418:	02054263          	bltz	a0,43c <stat+0x36>
 41c:	e426                	sd	s1,8(sp)
 41e:	84aa                	mv	s1,a0
    return -1;
  r = fstat(fd, st);
 420:	85ca                	mv	a1,s2
 422:	198000ef          	jal	5ba <fstat>
 426:	892a                	mv	s2,a0
  close(fd);
 428:	8526                	mv	a0,s1
 42a:	160000ef          	jal	58a <close>
  return r;
 42e:	64a2                	ld	s1,8(sp)
}
 430:	854a                	mv	a0,s2
 432:	60e2                	ld	ra,24(sp)
 434:	6442                	ld	s0,16(sp)
 436:	6902                	ld	s2,0(sp)
 438:	6105                	addi	sp,sp,32
 43a:	8082                	ret
    return -1;
 43c:	597d                	li	s2,-1
 43e:	bfcd                	j	430 <stat+0x2a>

0000000000000440 <atoi>:

int
atoi(const char *s)
{
 440:	1141                	addi	sp,sp,-16
 442:	e422                	sd	s0,8(sp)
 444:	0800                	addi	s0,sp,16
  int n;

  n = 0;
  while('0' <= *s && *s <= '9')
 446:	00054683          	lbu	a3,0(a0)
 44a:	fd06879b          	addiw	a5,a3,-48
 44e:	0ff7f793          	zext.b	a5,a5
 452:	4625                	li	a2,9
 454:	02f66863          	bltu	a2,a5,484 <atoi+0x44>
 458:	872a                	mv	a4,a0
  n = 0;
 45a:	4501                	li	a0,0
    n = n*10 + *s++ - '0';
 45c:	0705                	addi	a4,a4,1
 45e:	0025179b          	slliw	a5,a0,0x2
 462:	9fa9                	addw	a5,a5,a0
 464:	0017979b          	slliw	a5,a5,0x1
 468:	9fb5                	addw	a5,a5,a3
 46a:	fd07851b          	addiw	a0,a5,-48
  while('0' <= *s && *s <= '9')
 46e:	00074683          	lbu	a3,0(a4)
 472:	fd06879b          	addiw	a5,a3,-48
 476:	0ff7f793          	zext.b	a5,a5
 47a:	fef671e3          	bgeu	a2,a5,45c <atoi+0x1c>
  return n;
}
 47e:	6422                	ld	s0,8(sp)
 480:	0141                	addi	sp,sp,16
 482:	8082                	ret
  n = 0;
 484:	4501                	li	a0,0
 486:	bfe5                	j	47e <atoi+0x3e>

0000000000000488 <memmove>:

void*
memmove(void *vdst, const void *vsrc, int n)
{
 488:	1141                	addi	sp,sp,-16
 48a:	e422                	sd	s0,8(sp)
 48c:	0800                	addi	s0,sp,16
  char *dst;
  const char *src;

  dst = vdst;
  src = vsrc;
  if (src > dst) {
 48e:	02b57463          	bgeu	a0,a1,4b6 <memmove+0x2e>
    while(n-- > 0)
 492:	00c05f63          	blez	a2,4b0 <memmove+0x28>
 496:	1602                	slli	a2,a2,0x20
 498:	9201                	srli	a2,a2,0x20
 49a:	00c507b3          	add	a5,a0,a2
  dst = vdst;
 49e:	872a                	mv	a4,a0
      *dst++ = *src++;
 4a0:	0585                	addi	a1,a1,1
 4a2:	0705                	addi	a4,a4,1
 4a4:	fff5c683          	lbu	a3,-1(a1)
 4a8:	fed70fa3          	sb	a3,-1(a4)
    while(n-- > 0)
 4ac:	fef71ae3          	bne	a4,a5,4a0 <memmove+0x18>
    src += n;
    while(n-- > 0)
      *--dst = *--src;
  }
  return vdst;
}
 4b0:	6422                	ld	s0,8(sp)
 4b2:	0141                	addi	sp,sp,16
 4b4:	8082                	ret
    dst += n;
 4b6:	00c50733          	add	a4,a0,a2
    src += n;
 4ba:	95b2                	add	a1,a1,a2
    while(n-- > 0)
 4bc:	fec05ae3          	blez	a2,4b0 <memmove+0x28>
 4c0:	fff6079b          	addiw	a5,a2,-1
 4c4:	1782                	slli	a5,a5,0x20
 4c6:	9381                	srli	a5,a5,0x20
 4c8:	fff7c793          	not	a5,a5
 4cc:	97ba                	add	a5,a5,a4
      *--dst = *--src;
 4ce:	15fd                	addi	a1,a1,-1
 4d0:	177d                	addi	a4,a4,-1
 4d2:	0005c683          	lbu	a3,0(a1)
 4d6:	00d70023          	sb	a3,0(a4)
    while(n-- > 0)
 4da:	fee79ae3          	bne	a5,a4,4ce <memmove+0x46>
 4de:	bfc9                	j	4b0 <memmove+0x28>

00000000000004e0 <memcmp>:

int
memcmp(const void *s1, const void *s2, uint n)
{
 4e0:	1141                	addi	sp,sp,-16
 4e2:	e422                	sd	s0,8(sp)
 4e4:	0800                	addi	s0,sp,16
  const char *p1 = s1, *p2 = s2;
  while (n-- > 0) {
 4e6:	ca05                	beqz	a2,516 <memcmp+0x36>
 4e8:	fff6069b          	addiw	a3,a2,-1
 4ec:	1682                	slli	a3,a3,0x20
 4ee:	9281                	srli	a3,a3,0x20
 4f0:	0685                	addi	a3,a3,1
 4f2:	96aa                	add	a3,a3,a0
    if (*p1 != *p2) {
 4f4:	00054783          	lbu	a5,0(a0)
 4f8:	0005c703          	lbu	a4,0(a1)
 4fc:	00e79863          	bne	a5,a4,50c <memcmp+0x2c>
      return *p1 - *p2;
    }
    p1++;
 500:	0505                	addi	a0,a0,1
    p2++;
 502:	0585                	addi	a1,a1,1
  while (n-- > 0) {
 504:	fed518e3          	bne	a0,a3,4f4 <memcmp+0x14>
  }
  return 0;
 508:	4501                	li	a0,0
 50a:	a019                	j	510 <memcmp+0x30>
      return *p1 - *p2;
 50c:	40e7853b          	subw	a0,a5,a4
}
 510:	6422                	ld	s0,8(sp)
 512:	0141                	addi	sp,sp,16
 514:	8082                	ret
  return 0;
 516:	4501                	li	a0,0
 518:	bfe5                	j	510 <memcmp+0x30>

000000000000051a <memcpy>:

void *
memcpy(void *dst, const void *src, uint n)
{
 51a:	1141                	addi	sp,sp,-16
 51c:	e406                	sd	ra,8(sp)
 51e:	e022                	sd	s0,0(sp)
 520:	0800                	addi	s0,sp,16
  return memmove(dst, src, n);
 522:	f67ff0ef          	jal	488 <memmove>
}
 526:	60a2                	ld	ra,8(sp)
 528:	6402                	ld	s0,0(sp)
 52a:	0141                	addi	sp,sp,16
 52c:	8082                	ret

000000000000052e <sbrk>:

char *
sbrk(int n) {
 52e:	1141                	addi	sp,sp,-16
 530:	e406                	sd	ra,8(sp)
 532:	e022                	sd	s0,0(sp)
 534:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_EAGER);
 536:	4585                	li	a1,1
 538:	0b2000ef          	jal	5ea <sys_sbrk>
}
 53c:	60a2                	ld	ra,8(sp)
 53e:	6402                	ld	s0,0(sp)
 540:	0141                	addi	sp,sp,16
 542:	8082                	ret

0000000000000544 <sbrklazy>:

char *
sbrklazy(int n) {
 544:	1141                	addi	sp,sp,-16
 546:	e406                	sd	ra,8(sp)
 548:	e022                	sd	s0,0(sp)
 54a:	0800                	addi	s0,sp,16
  return sys_sbrk(n, SBRK_LAZY);
 54c:	4589                	li	a1,2
 54e:	09c000ef          	jal	5ea <sys_sbrk>
}
 552:	60a2                	ld	ra,8(sp)
 554:	6402                	ld	s0,0(sp)
 556:	0141                	addi	sp,sp,16
 558:	8082                	ret

000000000000055a <fork>:
# generated by usys.pl - do not edit
#include "kernel/syscall.h"
#include "kernel/syscall.h"
.global fork
fork:
 li a7, SYS_fork
 55a:	4885                	li	a7,1
 ecall
 55c:	00000073          	ecall
 ret
 560:	8082                	ret

0000000000000562 <exit>:
.global exit
exit:
 li a7, SYS_exit
 562:	4889                	li	a7,2
 ecall
 564:	00000073          	ecall
 ret
 568:	8082                	ret

000000000000056a <wait>:
.global wait
wait:
 li a7, SYS_wait
 56a:	488d                	li	a7,3
 ecall
 56c:	00000073          	ecall
 ret
 570:	8082                	ret

0000000000000572 <pipe>:
.global pipe
pipe:
 li a7, SYS_pipe
 572:	4891                	li	a7,4
 ecall
 574:	00000073          	ecall
 ret
 578:	8082                	ret

000000000000057a <read>:
.global read
read:
 li a7, SYS_read
 57a:	4895                	li	a7,5
 ecall
 57c:	00000073          	ecall
 ret
 580:	8082                	ret

0000000000000582 <write>:
.global write
write:
 li a7, SYS_write
 582:	48c1                	li	a7,16
 ecall
 584:	00000073          	ecall
 ret
 588:	8082                	ret

000000000000058a <close>:
.global close
close:
 li a7, SYS_close
 58a:	48d5                	li	a7,21
 ecall
 58c:	00000073          	ecall
 ret
 590:	8082                	ret

0000000000000592 <kill>:
.global kill
kill:
 li a7, SYS_kill
 592:	4899                	li	a7,6
 ecall
 594:	00000073          	ecall
 ret
 598:	8082                	ret

000000000000059a <exec>:
.global exec
exec:
 li a7, SYS_exec
 59a:	489d                	li	a7,7
 ecall
 59c:	00000073          	ecall
 ret
 5a0:	8082                	ret

00000000000005a2 <open>:
.global open
open:
 li a7, SYS_open
 5a2:	48bd                	li	a7,15
 ecall
 5a4:	00000073          	ecall
 ret
 5a8:	8082                	ret

00000000000005aa <mknod>:
.global mknod
mknod:
 li a7, SYS_mknod
 5aa:	48c5                	li	a7,17
 ecall
 5ac:	00000073          	ecall
 ret
 5b0:	8082                	ret

00000000000005b2 <unlink>:
.global unlink
unlink:
 li a7, SYS_unlink
 5b2:	48c9                	li	a7,18
 ecall
 5b4:	00000073          	ecall
 ret
 5b8:	8082                	ret

00000000000005ba <fstat>:
.global fstat
fstat:
 li a7, SYS_fstat
 5ba:	48a1                	li	a7,8
 ecall
 5bc:	00000073          	ecall
 ret
 5c0:	8082                	ret

00000000000005c2 <link>:
.global link
link:
 li a7, SYS_link
 5c2:	48cd                	li	a7,19
 ecall
 5c4:	00000073          	ecall
 ret
 5c8:	8082                	ret

00000000000005ca <mkdir>:
.global mkdir
mkdir:
 li a7, SYS_mkdir
 5ca:	48d1                	li	a7,20
 ecall
 5cc:	00000073          	ecall
 ret
 5d0:	8082                	ret

00000000000005d2 <chdir>:
.global chdir
chdir:
 li a7, SYS_chdir
 5d2:	48a5                	li	a7,9
 ecall
 5d4:	00000073          	ecall
 ret
 5d8:	8082                	ret

00000000000005da <dup>:
.global dup
dup:
 li a7, SYS_dup
 5da:	48a9                	li	a7,10
 ecall
 5dc:	00000073          	ecall
 ret
 5e0:	8082                	ret

00000000000005e2 <getpid>:
.global getpid
getpid:
 li a7, SYS_getpid
 5e2:	48ad                	li	a7,11
 ecall
 5e4:	00000073          	ecall
 ret
 5e8:	8082                	ret

00000000000005ea <sys_sbrk>:
.global sys_sbrk
sys_sbrk:
 li a7, SYS_sbrk
 5ea:	48b1                	li	a7,12
 ecall
 5ec:	00000073          	ecall
 ret
 5f0:	8082                	ret

00000000000005f2 <pause>:
.global pause
pause:
 li a7, SYS_pause
 5f2:	48b5                	li	a7,13
 ecall
 5f4:	00000073          	ecall
 ret
 5f8:	8082                	ret

00000000000005fa <uptime>:
.global uptime
uptime:
 li a7, SYS_uptime
 5fa:	48b9                	li	a7,14
 ecall
 5fc:	00000073          	ecall
 ret
 600:	8082                	ret

0000000000000602 <trace>:
.global trace
trace:
 li a7, SYS_trace
 602:	48d9                	li	a7,22
 ecall
 604:	00000073          	ecall
 ret
 608:	8082                	ret

000000000000060a <setpriority>:
.global setpriority
setpriority:
 li a7, SYS_setpriority
 60a:	48dd                	li	a7,23
 ecall
 60c:	00000073          	ecall
 ret
 610:	8082                	ret

0000000000000612 <getpriority>:
.global getpriority
getpriority:
 li a7, SYS_getpriority
 612:	48e1                	li	a7,24
 ecall
 614:	00000073          	ecall
 ret
 618:	8082                	ret

000000000000061a <getmemstat>:
.global getmemstat
getmemstat:
 li a7, SYS_getmemstat
 61a:	48e5                	li	a7,25
 ecall
 61c:	00000073          	ecall
 ret
 620:	8082                	ret

0000000000000622 <setmemquota>:
.global setmemquota
setmemquota:
 li a7, SYS_setmemquota
 622:	48e9                	li	a7,26
 ecall
 624:	00000073          	ecall
 ret
 628:	8082                	ret

000000000000062a <putc>:

static char digits[] = "0123456789ABCDEF";

static void
putc(int fd, char c)
{
 62a:	1101                	addi	sp,sp,-32
 62c:	ec06                	sd	ra,24(sp)
 62e:	e822                	sd	s0,16(sp)
 630:	1000                	addi	s0,sp,32
 632:	feb407a3          	sb	a1,-17(s0)
  write(fd, &c, 1);
 636:	4605                	li	a2,1
 638:	fef40593          	addi	a1,s0,-17
 63c:	f47ff0ef          	jal	582 <write>
}
 640:	60e2                	ld	ra,24(sp)
 642:	6442                	ld	s0,16(sp)
 644:	6105                	addi	sp,sp,32
 646:	8082                	ret

0000000000000648 <printint>:

static void
printint(int fd, long long xx, int base, int sgn)
{
 648:	715d                	addi	sp,sp,-80
 64a:	e486                	sd	ra,72(sp)
 64c:	e0a2                	sd	s0,64(sp)
 64e:	f84a                	sd	s2,48(sp)
 650:	0880                	addi	s0,sp,80
 652:	892a                	mv	s2,a0
  char buf[20];
  int i, neg;
  unsigned long long x;

  neg = 0;
  if(sgn && xx < 0){
 654:	c299                	beqz	a3,65a <printint+0x12>
 656:	0805c363          	bltz	a1,6dc <printint+0x94>
  neg = 0;
 65a:	4881                	li	a7,0
 65c:	fb840693          	addi	a3,s0,-72
    x = -xx;
  } else {
    x = xx;
  }

  i = 0;
 660:	4781                	li	a5,0
  do{
    buf[i++] = digits[x % base];
 662:	00000517          	auipc	a0,0x0
 666:	63650513          	addi	a0,a0,1590 # c98 <digits>
 66a:	883e                	mv	a6,a5
 66c:	2785                	addiw	a5,a5,1
 66e:	02c5f733          	remu	a4,a1,a2
 672:	972a                	add	a4,a4,a0
 674:	00074703          	lbu	a4,0(a4)
 678:	00e68023          	sb	a4,0(a3)
  }while((x /= base) != 0);
 67c:	872e                	mv	a4,a1
 67e:	02c5d5b3          	divu	a1,a1,a2
 682:	0685                	addi	a3,a3,1
 684:	fec773e3          	bgeu	a4,a2,66a <printint+0x22>
  if(neg)
 688:	00088b63          	beqz	a7,69e <printint+0x56>
    buf[i++] = '-';
 68c:	fd078793          	addi	a5,a5,-48
 690:	97a2                	add	a5,a5,s0
 692:	02d00713          	li	a4,45
 696:	fee78423          	sb	a4,-24(a5)
 69a:	0028079b          	addiw	a5,a6,2

  while(--i >= 0)
 69e:	02f05a63          	blez	a5,6d2 <printint+0x8a>
 6a2:	fc26                	sd	s1,56(sp)
 6a4:	f44e                	sd	s3,40(sp)
 6a6:	fb840713          	addi	a4,s0,-72
 6aa:	00f704b3          	add	s1,a4,a5
 6ae:	fff70993          	addi	s3,a4,-1
 6b2:	99be                	add	s3,s3,a5
 6b4:	37fd                	addiw	a5,a5,-1
 6b6:	1782                	slli	a5,a5,0x20
 6b8:	9381                	srli	a5,a5,0x20
 6ba:	40f989b3          	sub	s3,s3,a5
    putc(fd, buf[i]);
 6be:	fff4c583          	lbu	a1,-1(s1)
 6c2:	854a                	mv	a0,s2
 6c4:	f67ff0ef          	jal	62a <putc>
  while(--i >= 0)
 6c8:	14fd                	addi	s1,s1,-1
 6ca:	ff349ae3          	bne	s1,s3,6be <printint+0x76>
 6ce:	74e2                	ld	s1,56(sp)
 6d0:	79a2                	ld	s3,40(sp)
}
 6d2:	60a6                	ld	ra,72(sp)
 6d4:	6406                	ld	s0,64(sp)
 6d6:	7942                	ld	s2,48(sp)
 6d8:	6161                	addi	sp,sp,80
 6da:	8082                	ret
    x = -xx;
 6dc:	40b005b3          	neg	a1,a1
    neg = 1;
 6e0:	4885                	li	a7,1
    x = -xx;
 6e2:	bfad                	j	65c <printint+0x14>

00000000000006e4 <vprintf>:
}

// Print to the given fd. Only understands %d, %x, %p, %c, %s.
void
vprintf(int fd, const char *fmt, va_list ap)
{
 6e4:	711d                	addi	sp,sp,-96
 6e6:	ec86                	sd	ra,88(sp)
 6e8:	e8a2                	sd	s0,80(sp)
 6ea:	e0ca                	sd	s2,64(sp)
 6ec:	1080                	addi	s0,sp,96
  char *s;
  int c0, c1, c2, i, state;

  state = 0;
  for(i = 0; fmt[i]; i++){
 6ee:	0005c903          	lbu	s2,0(a1)
 6f2:	28090663          	beqz	s2,97e <vprintf+0x29a>
 6f6:	e4a6                	sd	s1,72(sp)
 6f8:	fc4e                	sd	s3,56(sp)
 6fa:	f852                	sd	s4,48(sp)
 6fc:	f456                	sd	s5,40(sp)
 6fe:	f05a                	sd	s6,32(sp)
 700:	ec5e                	sd	s7,24(sp)
 702:	e862                	sd	s8,16(sp)
 704:	e466                	sd	s9,8(sp)
 706:	8b2a                	mv	s6,a0
 708:	8a2e                	mv	s4,a1
 70a:	8bb2                	mv	s7,a2
  state = 0;
 70c:	4981                	li	s3,0
  for(i = 0; fmt[i]; i++){
 70e:	4481                	li	s1,0
 710:	4701                	li	a4,0
      if(c0 == '%'){
        state = '%';
      } else {
        putc(fd, c0);
      }
    } else if(state == '%'){
 712:	02500a93          	li	s5,37
      c1 = c2 = 0;
      if(c0) c1 = fmt[i+1] & 0xff;
      if(c1) c2 = fmt[i+2] & 0xff;
      if(c0 == 'd'){
 716:	06400c13          	li	s8,100
        printint(fd, va_arg(ap, int), 10, 1);
      } else if(c0 == 'l' && c1 == 'd'){
 71a:	06c00c93          	li	s9,108
 71e:	a005                	j	73e <vprintf+0x5a>
        putc(fd, c0);
 720:	85ca                	mv	a1,s2
 722:	855a                	mv	a0,s6
 724:	f07ff0ef          	jal	62a <putc>
 728:	a019                	j	72e <vprintf+0x4a>
    } else if(state == '%'){
 72a:	03598263          	beq	s3,s5,74e <vprintf+0x6a>
  for(i = 0; fmt[i]; i++){
 72e:	2485                	addiw	s1,s1,1
 730:	8726                	mv	a4,s1
 732:	009a07b3          	add	a5,s4,s1
 736:	0007c903          	lbu	s2,0(a5)
 73a:	22090a63          	beqz	s2,96e <vprintf+0x28a>
    c0 = fmt[i] & 0xff;
 73e:	0009079b          	sext.w	a5,s2
    if(state == 0){
 742:	fe0994e3          	bnez	s3,72a <vprintf+0x46>
      if(c0 == '%'){
 746:	fd579de3          	bne	a5,s5,720 <vprintf+0x3c>
        state = '%';
 74a:	89be                	mv	s3,a5
 74c:	b7cd                	j	72e <vprintf+0x4a>
      if(c0) c1 = fmt[i+1] & 0xff;
 74e:	00ea06b3          	add	a3,s4,a4
 752:	0016c683          	lbu	a3,1(a3)
      c1 = c2 = 0;
 756:	8636                	mv	a2,a3
      if(c1) c2 = fmt[i+2] & 0xff;
 758:	c681                	beqz	a3,760 <vprintf+0x7c>
 75a:	9752                	add	a4,a4,s4
 75c:	00274603          	lbu	a2,2(a4)
      if(c0 == 'd'){
 760:	05878363          	beq	a5,s8,7a6 <vprintf+0xc2>
      } else if(c0 == 'l' && c1 == 'd'){
 764:	05978d63          	beq	a5,s9,7be <vprintf+0xda>
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
        printint(fd, va_arg(ap, uint64), 10, 1);
        i += 2;
      } else if(c0 == 'u'){
 768:	07500713          	li	a4,117
 76c:	0ee78763          	beq	a5,a4,85a <vprintf+0x176>
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
        printint(fd, va_arg(ap, uint64), 10, 0);
        i += 2;
      } else if(c0 == 'x'){
 770:	07800713          	li	a4,120
 774:	12e78963          	beq	a5,a4,8a6 <vprintf+0x1c2>
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 1;
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
        printint(fd, va_arg(ap, uint64), 16, 0);
        i += 2;
      } else if(c0 == 'p'){
 778:	07000713          	li	a4,112
 77c:	14e78e63          	beq	a5,a4,8d8 <vprintf+0x1f4>
        printptr(fd, va_arg(ap, uint64));
      } else if(c0 == 'c'){
 780:	06300713          	li	a4,99
 784:	18e78e63          	beq	a5,a4,920 <vprintf+0x23c>
        putc(fd, va_arg(ap, uint32));
      } else if(c0 == 's'){
 788:	07300713          	li	a4,115
 78c:	1ae78463          	beq	a5,a4,934 <vprintf+0x250>
        if((s = va_arg(ap, char*)) == 0)
          s = "(null)";
        for(; *s; s++)
          putc(fd, *s);
      } else if(c0 == '%'){
 790:	02500713          	li	a4,37
 794:	04e79563          	bne	a5,a4,7de <vprintf+0xfa>
        putc(fd, '%');
 798:	02500593          	li	a1,37
 79c:	855a                	mv	a0,s6
 79e:	e8dff0ef          	jal	62a <putc>
        // Unknown % sequence.  Print it to draw attention.
        putc(fd, '%');
        putc(fd, c0);
      }

      state = 0;
 7a2:	4981                	li	s3,0
 7a4:	b769                	j	72e <vprintf+0x4a>
        printint(fd, va_arg(ap, int), 10, 1);
 7a6:	008b8913          	addi	s2,s7,8
 7aa:	4685                	li	a3,1
 7ac:	4629                	li	a2,10
 7ae:	000ba583          	lw	a1,0(s7)
 7b2:	855a                	mv	a0,s6
 7b4:	e95ff0ef          	jal	648 <printint>
 7b8:	8bca                	mv	s7,s2
      state = 0;
 7ba:	4981                	li	s3,0
 7bc:	bf8d                	j	72e <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'd'){
 7be:	06400793          	li	a5,100
 7c2:	02f68963          	beq	a3,a5,7f4 <vprintf+0x110>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 7c6:	06c00793          	li	a5,108
 7ca:	04f68263          	beq	a3,a5,80e <vprintf+0x12a>
      } else if(c0 == 'l' && c1 == 'u'){
 7ce:	07500793          	li	a5,117
 7d2:	0af68063          	beq	a3,a5,872 <vprintf+0x18e>
      } else if(c0 == 'l' && c1 == 'x'){
 7d6:	07800793          	li	a5,120
 7da:	0ef68263          	beq	a3,a5,8be <vprintf+0x1da>
        putc(fd, '%');
 7de:	02500593          	li	a1,37
 7e2:	855a                	mv	a0,s6
 7e4:	e47ff0ef          	jal	62a <putc>
        putc(fd, c0);
 7e8:	85ca                	mv	a1,s2
 7ea:	855a                	mv	a0,s6
 7ec:	e3fff0ef          	jal	62a <putc>
      state = 0;
 7f0:	4981                	li	s3,0
 7f2:	bf35                	j	72e <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 7f4:	008b8913          	addi	s2,s7,8
 7f8:	4685                	li	a3,1
 7fa:	4629                	li	a2,10
 7fc:	000bb583          	ld	a1,0(s7)
 800:	855a                	mv	a0,s6
 802:	e47ff0ef          	jal	648 <printint>
        i += 1;
 806:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 1);
 808:	8bca                	mv	s7,s2
      state = 0;
 80a:	4981                	li	s3,0
        i += 1;
 80c:	b70d                	j	72e <vprintf+0x4a>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'd'){
 80e:	06400793          	li	a5,100
 812:	02f60763          	beq	a2,a5,840 <vprintf+0x15c>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'u'){
 816:	07500793          	li	a5,117
 81a:	06f60963          	beq	a2,a5,88c <vprintf+0x1a8>
      } else if(c0 == 'l' && c1 == 'l' && c2 == 'x'){
 81e:	07800793          	li	a5,120
 822:	faf61ee3          	bne	a2,a5,7de <vprintf+0xfa>
        printint(fd, va_arg(ap, uint64), 16, 0);
 826:	008b8913          	addi	s2,s7,8
 82a:	4681                	li	a3,0
 82c:	4641                	li	a2,16
 82e:	000bb583          	ld	a1,0(s7)
 832:	855a                	mv	a0,s6
 834:	e15ff0ef          	jal	648 <printint>
        i += 2;
 838:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 16, 0);
 83a:	8bca                	mv	s7,s2
      state = 0;
 83c:	4981                	li	s3,0
        i += 2;
 83e:	bdc5                	j	72e <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 1);
 840:	008b8913          	addi	s2,s7,8
 844:	4685                	li	a3,1
 846:	4629                	li	a2,10
 848:	000bb583          	ld	a1,0(s7)
 84c:	855a                	mv	a0,s6
 84e:	dfbff0ef          	jal	648 <printint>
        i += 2;
 852:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 1);
 854:	8bca                	mv	s7,s2
      state = 0;
 856:	4981                	li	s3,0
        i += 2;
 858:	bdd9                	j	72e <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 10, 0);
 85a:	008b8913          	addi	s2,s7,8
 85e:	4681                	li	a3,0
 860:	4629                	li	a2,10
 862:	000be583          	lwu	a1,0(s7)
 866:	855a                	mv	a0,s6
 868:	de1ff0ef          	jal	648 <printint>
 86c:	8bca                	mv	s7,s2
      state = 0;
 86e:	4981                	li	s3,0
 870:	bd7d                	j	72e <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 872:	008b8913          	addi	s2,s7,8
 876:	4681                	li	a3,0
 878:	4629                	li	a2,10
 87a:	000bb583          	ld	a1,0(s7)
 87e:	855a                	mv	a0,s6
 880:	dc9ff0ef          	jal	648 <printint>
        i += 1;
 884:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 10, 0);
 886:	8bca                	mv	s7,s2
      state = 0;
 888:	4981                	li	s3,0
        i += 1;
 88a:	b555                	j	72e <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 10, 0);
 88c:	008b8913          	addi	s2,s7,8
 890:	4681                	li	a3,0
 892:	4629                	li	a2,10
 894:	000bb583          	ld	a1,0(s7)
 898:	855a                	mv	a0,s6
 89a:	dafff0ef          	jal	648 <printint>
        i += 2;
 89e:	2489                	addiw	s1,s1,2
        printint(fd, va_arg(ap, uint64), 10, 0);
 8a0:	8bca                	mv	s7,s2
      state = 0;
 8a2:	4981                	li	s3,0
        i += 2;
 8a4:	b569                	j	72e <vprintf+0x4a>
        printint(fd, va_arg(ap, uint32), 16, 0);
 8a6:	008b8913          	addi	s2,s7,8
 8aa:	4681                	li	a3,0
 8ac:	4641                	li	a2,16
 8ae:	000be583          	lwu	a1,0(s7)
 8b2:	855a                	mv	a0,s6
 8b4:	d95ff0ef          	jal	648 <printint>
 8b8:	8bca                	mv	s7,s2
      state = 0;
 8ba:	4981                	li	s3,0
 8bc:	bd8d                	j	72e <vprintf+0x4a>
        printint(fd, va_arg(ap, uint64), 16, 0);
 8be:	008b8913          	addi	s2,s7,8
 8c2:	4681                	li	a3,0
 8c4:	4641                	li	a2,16
 8c6:	000bb583          	ld	a1,0(s7)
 8ca:	855a                	mv	a0,s6
 8cc:	d7dff0ef          	jal	648 <printint>
        i += 1;
 8d0:	2485                	addiw	s1,s1,1
        printint(fd, va_arg(ap, uint64), 16, 0);
 8d2:	8bca                	mv	s7,s2
      state = 0;
 8d4:	4981                	li	s3,0
        i += 1;
 8d6:	bda1                	j	72e <vprintf+0x4a>
 8d8:	e06a                	sd	s10,0(sp)
        printptr(fd, va_arg(ap, uint64));
 8da:	008b8d13          	addi	s10,s7,8
 8de:	000bb983          	ld	s3,0(s7)
  putc(fd, '0');
 8e2:	03000593          	li	a1,48
 8e6:	855a                	mv	a0,s6
 8e8:	d43ff0ef          	jal	62a <putc>
  putc(fd, 'x');
 8ec:	07800593          	li	a1,120
 8f0:	855a                	mv	a0,s6
 8f2:	d39ff0ef          	jal	62a <putc>
 8f6:	4941                	li	s2,16
    putc(fd, digits[x >> (sizeof(uint64) * 8 - 4)]);
 8f8:	00000b97          	auipc	s7,0x0
 8fc:	3a0b8b93          	addi	s7,s7,928 # c98 <digits>
 900:	03c9d793          	srli	a5,s3,0x3c
 904:	97de                	add	a5,a5,s7
 906:	0007c583          	lbu	a1,0(a5)
 90a:	855a                	mv	a0,s6
 90c:	d1fff0ef          	jal	62a <putc>
  for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
 910:	0992                	slli	s3,s3,0x4
 912:	397d                	addiw	s2,s2,-1
 914:	fe0916e3          	bnez	s2,900 <vprintf+0x21c>
        printptr(fd, va_arg(ap, uint64));
 918:	8bea                	mv	s7,s10
      state = 0;
 91a:	4981                	li	s3,0
 91c:	6d02                	ld	s10,0(sp)
 91e:	bd01                	j	72e <vprintf+0x4a>
        putc(fd, va_arg(ap, uint32));
 920:	008b8913          	addi	s2,s7,8
 924:	000bc583          	lbu	a1,0(s7)
 928:	855a                	mv	a0,s6
 92a:	d01ff0ef          	jal	62a <putc>
 92e:	8bca                	mv	s7,s2
      state = 0;
 930:	4981                	li	s3,0
 932:	bbf5                	j	72e <vprintf+0x4a>
        if((s = va_arg(ap, char*)) == 0)
 934:	008b8993          	addi	s3,s7,8
 938:	000bb903          	ld	s2,0(s7)
 93c:	00090f63          	beqz	s2,95a <vprintf+0x276>
        for(; *s; s++)
 940:	00094583          	lbu	a1,0(s2)
 944:	c195                	beqz	a1,968 <vprintf+0x284>
          putc(fd, *s);
 946:	855a                	mv	a0,s6
 948:	ce3ff0ef          	jal	62a <putc>
        for(; *s; s++)
 94c:	0905                	addi	s2,s2,1
 94e:	00094583          	lbu	a1,0(s2)
 952:	f9f5                	bnez	a1,946 <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 954:	8bce                	mv	s7,s3
      state = 0;
 956:	4981                	li	s3,0
 958:	bbd9                	j	72e <vprintf+0x4a>
          s = "(null)";
 95a:	00000917          	auipc	s2,0x0
 95e:	33690913          	addi	s2,s2,822 # c90 <malloc+0x22a>
        for(; *s; s++)
 962:	02800593          	li	a1,40
 966:	b7c5                	j	946 <vprintf+0x262>
        if((s = va_arg(ap, char*)) == 0)
 968:	8bce                	mv	s7,s3
      state = 0;
 96a:	4981                	li	s3,0
 96c:	b3c9                	j	72e <vprintf+0x4a>
 96e:	64a6                	ld	s1,72(sp)
 970:	79e2                	ld	s3,56(sp)
 972:	7a42                	ld	s4,48(sp)
 974:	7aa2                	ld	s5,40(sp)
 976:	7b02                	ld	s6,32(sp)
 978:	6be2                	ld	s7,24(sp)
 97a:	6c42                	ld	s8,16(sp)
 97c:	6ca2                	ld	s9,8(sp)
    }
  }
}
 97e:	60e6                	ld	ra,88(sp)
 980:	6446                	ld	s0,80(sp)
 982:	6906                	ld	s2,64(sp)
 984:	6125                	addi	sp,sp,96
 986:	8082                	ret

0000000000000988 <fprintf>:

void
fprintf(int fd, const char *fmt, ...)
{
 988:	715d                	addi	sp,sp,-80
 98a:	ec06                	sd	ra,24(sp)
 98c:	e822                	sd	s0,16(sp)
 98e:	1000                	addi	s0,sp,32
 990:	e010                	sd	a2,0(s0)
 992:	e414                	sd	a3,8(s0)
 994:	e818                	sd	a4,16(s0)
 996:	ec1c                	sd	a5,24(s0)
 998:	03043023          	sd	a6,32(s0)
 99c:	03143423          	sd	a7,40(s0)
  va_list ap;

  va_start(ap, fmt);
 9a0:	fe843423          	sd	s0,-24(s0)
  vprintf(fd, fmt, ap);
 9a4:	8622                	mv	a2,s0
 9a6:	d3fff0ef          	jal	6e4 <vprintf>
}
 9aa:	60e2                	ld	ra,24(sp)
 9ac:	6442                	ld	s0,16(sp)
 9ae:	6161                	addi	sp,sp,80
 9b0:	8082                	ret

00000000000009b2 <printf>:

void
printf(const char *fmt, ...)
{
 9b2:	711d                	addi	sp,sp,-96
 9b4:	ec06                	sd	ra,24(sp)
 9b6:	e822                	sd	s0,16(sp)
 9b8:	1000                	addi	s0,sp,32
 9ba:	e40c                	sd	a1,8(s0)
 9bc:	e810                	sd	a2,16(s0)
 9be:	ec14                	sd	a3,24(s0)
 9c0:	f018                	sd	a4,32(s0)
 9c2:	f41c                	sd	a5,40(s0)
 9c4:	03043823          	sd	a6,48(s0)
 9c8:	03143c23          	sd	a7,56(s0)
  va_list ap;

  va_start(ap, fmt);
 9cc:	00840613          	addi	a2,s0,8
 9d0:	fec43423          	sd	a2,-24(s0)
  vprintf(1, fmt, ap);
 9d4:	85aa                	mv	a1,a0
 9d6:	4505                	li	a0,1
 9d8:	d0dff0ef          	jal	6e4 <vprintf>
}
 9dc:	60e2                	ld	ra,24(sp)
 9de:	6442                	ld	s0,16(sp)
 9e0:	6125                	addi	sp,sp,96
 9e2:	8082                	ret

00000000000009e4 <free>:
static Header base;
static Header *freep;

void
free(void *ap)
{
 9e4:	1141                	addi	sp,sp,-16
 9e6:	e422                	sd	s0,8(sp)
 9e8:	0800                	addi	s0,sp,16
  Header *bp, *p;

  bp = (Header*)ap - 1;
 9ea:	ff050693          	addi	a3,a0,-16
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 9ee:	00001797          	auipc	a5,0x1
 9f2:	6127b783          	ld	a5,1554(a5) # 2000 <freep>
 9f6:	a02d                	j	a20 <free+0x3c>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;
  if(bp + bp->s.size == p->s.ptr){
    bp->s.size += p->s.ptr->s.size;
 9f8:	4618                	lw	a4,8(a2)
 9fa:	9f2d                	addw	a4,a4,a1
 9fc:	fee52c23          	sw	a4,-8(a0)
    bp->s.ptr = p->s.ptr->s.ptr;
 a00:	6398                	ld	a4,0(a5)
 a02:	6310                	ld	a2,0(a4)
 a04:	a83d                	j	a42 <free+0x5e>
  } else
    bp->s.ptr = p->s.ptr;
  if(p + p->s.size == bp){
    p->s.size += bp->s.size;
 a06:	ff852703          	lw	a4,-8(a0)
 a0a:	9f31                	addw	a4,a4,a2
 a0c:	c798                	sw	a4,8(a5)
    p->s.ptr = bp->s.ptr;
 a0e:	ff053683          	ld	a3,-16(a0)
 a12:	a091                	j	a56 <free+0x72>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 a14:	6398                	ld	a4,0(a5)
 a16:	00e7e463          	bltu	a5,a4,a1e <free+0x3a>
 a1a:	00e6ea63          	bltu	a3,a4,a2e <free+0x4a>
{
 a1e:	87ba                	mv	a5,a4
  for(p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
 a20:	fed7fae3          	bgeu	a5,a3,a14 <free+0x30>
 a24:	6398                	ld	a4,0(a5)
 a26:	00e6e463          	bltu	a3,a4,a2e <free+0x4a>
    if(p >= p->s.ptr && (bp > p || bp < p->s.ptr))
 a2a:	fee7eae3          	bltu	a5,a4,a1e <free+0x3a>
  if(bp + bp->s.size == p->s.ptr){
 a2e:	ff852583          	lw	a1,-8(a0)
 a32:	6390                	ld	a2,0(a5)
 a34:	02059813          	slli	a6,a1,0x20
 a38:	01c85713          	srli	a4,a6,0x1c
 a3c:	9736                	add	a4,a4,a3
 a3e:	fae60de3          	beq	a2,a4,9f8 <free+0x14>
    bp->s.ptr = p->s.ptr->s.ptr;
 a42:	fec53823          	sd	a2,-16(a0)
  if(p + p->s.size == bp){
 a46:	4790                	lw	a2,8(a5)
 a48:	02061593          	slli	a1,a2,0x20
 a4c:	01c5d713          	srli	a4,a1,0x1c
 a50:	973e                	add	a4,a4,a5
 a52:	fae68ae3          	beq	a3,a4,a06 <free+0x22>
    p->s.ptr = bp->s.ptr;
 a56:	e394                	sd	a3,0(a5)
  } else
    p->s.ptr = bp;
  freep = p;
 a58:	00001717          	auipc	a4,0x1
 a5c:	5af73423          	sd	a5,1448(a4) # 2000 <freep>
}
 a60:	6422                	ld	s0,8(sp)
 a62:	0141                	addi	sp,sp,16
 a64:	8082                	ret

0000000000000a66 <malloc>:
  return freep;
}

void*
malloc(uint nbytes)
{
 a66:	7139                	addi	sp,sp,-64
 a68:	fc06                	sd	ra,56(sp)
 a6a:	f822                	sd	s0,48(sp)
 a6c:	f426                	sd	s1,40(sp)
 a6e:	ec4e                	sd	s3,24(sp)
 a70:	0080                	addi	s0,sp,64
  Header *p, *prevp;
  uint nunits;

  nunits = (nbytes + sizeof(Header) - 1)/sizeof(Header) + 1;
 a72:	02051493          	slli	s1,a0,0x20
 a76:	9081                	srli	s1,s1,0x20
 a78:	04bd                	addi	s1,s1,15
 a7a:	8091                	srli	s1,s1,0x4
 a7c:	0014899b          	addiw	s3,s1,1
 a80:	0485                	addi	s1,s1,1
  if((prevp = freep) == 0){
 a82:	00001517          	auipc	a0,0x1
 a86:	57e53503          	ld	a0,1406(a0) # 2000 <freep>
 a8a:	c915                	beqz	a0,abe <malloc+0x58>
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 a8c:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 a8e:	4798                	lw	a4,8(a5)
 a90:	08977a63          	bgeu	a4,s1,b24 <malloc+0xbe>
 a94:	f04a                	sd	s2,32(sp)
 a96:	e852                	sd	s4,16(sp)
 a98:	e456                	sd	s5,8(sp)
 a9a:	e05a                	sd	s6,0(sp)
  if(nu < 4096)
 a9c:	8a4e                	mv	s4,s3
 a9e:	0009871b          	sext.w	a4,s3
 aa2:	6685                	lui	a3,0x1
 aa4:	00d77363          	bgeu	a4,a3,aaa <malloc+0x44>
 aa8:	6a05                	lui	s4,0x1
 aaa:	000a0b1b          	sext.w	s6,s4
  p = sbrk(nu * sizeof(Header));
 aae:	004a1a1b          	slliw	s4,s4,0x4
        p->s.size = nunits;
      }
      freep = prevp;
      return (void*)(p + 1);
    }
    if(p == freep)
 ab2:	00001917          	auipc	s2,0x1
 ab6:	54e90913          	addi	s2,s2,1358 # 2000 <freep>
  if(p == SBRK_ERROR)
 aba:	5afd                	li	s5,-1
 abc:	a081                	j	afc <malloc+0x96>
 abe:	f04a                	sd	s2,32(sp)
 ac0:	e852                	sd	s4,16(sp)
 ac2:	e456                	sd	s5,8(sp)
 ac4:	e05a                	sd	s6,0(sp)
    base.s.ptr = freep = prevp = &base;
 ac6:	00001797          	auipc	a5,0x1
 aca:	54a78793          	addi	a5,a5,1354 # 2010 <base>
 ace:	00001717          	auipc	a4,0x1
 ad2:	52f73923          	sd	a5,1330(a4) # 2000 <freep>
 ad6:	e39c                	sd	a5,0(a5)
    base.s.size = 0;
 ad8:	0007a423          	sw	zero,8(a5)
    if(p->s.size >= nunits){
 adc:	b7c1                	j	a9c <malloc+0x36>
        prevp->s.ptr = p->s.ptr;
 ade:	6398                	ld	a4,0(a5)
 ae0:	e118                	sd	a4,0(a0)
 ae2:	a8a9                	j	b3c <malloc+0xd6>
  hp->s.size = nu;
 ae4:	01652423          	sw	s6,8(a0)
  free((void*)(hp + 1));
 ae8:	0541                	addi	a0,a0,16
 aea:	efbff0ef          	jal	9e4 <free>
  return freep;
 aee:	00093503          	ld	a0,0(s2)
      if((p = morecore(nunits)) == 0)
 af2:	c12d                	beqz	a0,b54 <malloc+0xee>
  for(p = prevp->s.ptr; ; prevp = p, p = p->s.ptr){
 af4:	611c                	ld	a5,0(a0)
    if(p->s.size >= nunits){
 af6:	4798                	lw	a4,8(a5)
 af8:	02977263          	bgeu	a4,s1,b1c <malloc+0xb6>
    if(p == freep)
 afc:	00093703          	ld	a4,0(s2)
 b00:	853e                	mv	a0,a5
 b02:	fef719e3          	bne	a4,a5,af4 <malloc+0x8e>
  p = sbrk(nu * sizeof(Header));
 b06:	8552                	mv	a0,s4
 b08:	a27ff0ef          	jal	52e <sbrk>
  if(p == SBRK_ERROR)
 b0c:	fd551ce3          	bne	a0,s5,ae4 <malloc+0x7e>
        return 0;
 b10:	4501                	li	a0,0
 b12:	7902                	ld	s2,32(sp)
 b14:	6a42                	ld	s4,16(sp)
 b16:	6aa2                	ld	s5,8(sp)
 b18:	6b02                	ld	s6,0(sp)
 b1a:	a03d                	j	b48 <malloc+0xe2>
 b1c:	7902                	ld	s2,32(sp)
 b1e:	6a42                	ld	s4,16(sp)
 b20:	6aa2                	ld	s5,8(sp)
 b22:	6b02                	ld	s6,0(sp)
      if(p->s.size == nunits)
 b24:	fae48de3          	beq	s1,a4,ade <malloc+0x78>
        p->s.size -= nunits;
 b28:	4137073b          	subw	a4,a4,s3
 b2c:	c798                	sw	a4,8(a5)
        p += p->s.size;
 b2e:	02071693          	slli	a3,a4,0x20
 b32:	01c6d713          	srli	a4,a3,0x1c
 b36:	97ba                	add	a5,a5,a4
        p->s.size = nunits;
 b38:	0137a423          	sw	s3,8(a5)
      freep = prevp;
 b3c:	00001717          	auipc	a4,0x1
 b40:	4ca73223          	sd	a0,1220(a4) # 2000 <freep>
      return (void*)(p + 1);
 b44:	01078513          	addi	a0,a5,16
  }
}
 b48:	70e2                	ld	ra,56(sp)
 b4a:	7442                	ld	s0,48(sp)
 b4c:	74a2                	ld	s1,40(sp)
 b4e:	69e2                	ld	s3,24(sp)
 b50:	6121                	addi	sp,sp,64
 b52:	8082                	ret
 b54:	7902                	ld	s2,32(sp)
 b56:	6a42                	ld	s4,16(sp)
 b58:	6aa2                	ld	s5,8(sp)
 b5a:	6b02                	ld	s6,0(sp)
 b5c:	b7f5                	j	b48 <malloc+0xe2>
