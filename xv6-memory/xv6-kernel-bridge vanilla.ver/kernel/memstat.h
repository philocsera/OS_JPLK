#ifndef XV6_MEMSTAT_H
#define XV6_MEMSTAT_H

#define MEMSTAT_MAX 64
#define MEMSTAT_NAME_LEN 16

struct memstat {
  int pid;
  int state;
  uint64 sz;
  uint64 mem_quota;
  uint64 quota_denied_count;
  uint64 swapout_count;
  uint64 swapin_count;
  char name[MEMSTAT_NAME_LEN];
};

#endif