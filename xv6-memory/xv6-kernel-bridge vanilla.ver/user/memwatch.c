#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/memstat.h"
#include "kernel/swapstat.h"
#include "user/user.h"

// MEMSTAT_MAX * sizeof(struct memstat)가 한 페이지 이상이므로
// user stack overflow를 피하기 위해 전역 영역에 둔다.
static struct memstat stats[MEMSTAT_MAX];
static struct swapstat swap_stats;

static int
usage_percent(uint64 sz, uint64 quota)
{
  if(quota == 0)
    return -1;

  return (int)((sz * 100) / quota);
}

static void
print_table(int tick)
{
  int n;
  int i;

  n = getmemstat(stats, MEMSTAT_MAX);

  if(n < 0){
    printf("getmemstat failed\n");
    return;
  }

  if(getswapstat(&swap_stats) < 0){
    swap_stats.used_slots = -1;
    swap_stats.total_slots = -1;
  }

  printf("\n[tick %d]\n", tick);
  printf("[swap] used_slots=%d total_slots=%d\n",
    swap_stats.used_slots,
    swap_stats.total_slots);
  printf("pid\tstate\tsz\tquota\tusage\tqdeny\tswapout\tswapin\tname\n");

  for(i = 0; i < n; i++){
    int usage = usage_percent(stats[i].sz, stats[i].mem_quota);

    if(usage < 0){
      printf("%d\t%d\t%d\t%d\t-\t%d\t%d\t%d\t%s\n",
        stats[i].pid,
        stats[i].state,
        (int)stats[i].sz,
        (int)stats[i].mem_quota,
        (int)stats[i].quota_denied_count,
        (int)stats[i].swapout_count,
        (int)stats[i].swapin_count,
        stats[i].name);
    } else {
      printf("%d\t%d\t%d\t%d\t%d%%\t%d\t%d\t%d\t%s\n",
        stats[i].pid,
        stats[i].state,
        (int)stats[i].sz,
        (int)stats[i].mem_quota,
        usage,
        (int)stats[i].quota_denied_count,
        (int)stats[i].swapout_count,
        (int)stats[i].swapin_count,
        stats[i].name);
    }
  }
}

static void
print_json(int tick)
{
  int n;
  int i;

  n = getmemstat(stats, MEMSTAT_MAX);

  if(n < 0){
    printf("{\"type\":\"memstat\",\"error\":\"getmemstat failed\"}\n");
    return;
  }

  if(getswapstat(&swap_stats) < 0){
    swap_stats.used_slots = -1;
    swap_stats.total_slots = -1;
  }

  printf("{\"type\":\"memstat\",\"tick\":%d,", tick);
  printf("\"swap\":{\"used_slots\":%d,\"total_slots\":%d},",
    swap_stats.used_slots,
    swap_stats.total_slots);
  printf("\"processes\":[");

  for(i = 0; i < n; i++){
    int usage = usage_percent(stats[i].sz, stats[i].mem_quota);

    if(i > 0)
      printf(",");

    printf("{\"pid\":%d,\"state\":%d,\"name\":\"%s\","
           "\"sz\":%d,\"quota\":%d,\"usage\":%d,"
           "\"quota_denied_count\":%d,"
           "\"swapout_count\":%d,\"swapin_count\":%d}",
      stats[i].pid,
      stats[i].state,
      stats[i].name,
      (int)stats[i].sz,
      (int)stats[i].mem_quota,
      usage,
      (int)stats[i].quota_denied_count,
      (int)stats[i].swapout_count,
      (int)stats[i].swapin_count);
  }

  printf("]}\n");
}

int
main(int argc, char *argv[])
{
  int json = 0;
  int ticks = 5;
  int interval = 10;
  int argi = 1;
  int t;

  if(argc >= 2 && strcmp(argv[1], "json") == 0){
    json = 1;
    argi = 2;
  }

  if(argc > argi){
    ticks = atoi(argv[argi]);
    argi++;
  }

  if(argc > argi){
    interval = atoi(argv[argi]);
  }

  if(ticks <= 0)
    ticks = 1;

  if(interval < 0)
    interval = 0;

  for(t = 0; t < ticks; t++){
    if(json)
      print_json(t);
    else
      print_table(t);

    if(t != ticks - 1)
      pause(interval);
  }

  exit(0);
}