#ifndef POLICY_H
#define POLICY_H

#include "types.h"

// Scheduling policy identifiers.
// Used by setpolicy()/getpolicy() and clockintr().
#define POLICY_BALANCED     0   // default round-robin (~0.1s timeslice)
#define POLICY_THROUGHPUT   1   // long timeslice (~0.4s), minimise context switches
#define POLICY_INTERACTIVE  2   // short timeslice (~0.025s), maximise responsiveness
#define POLICY_BACKGROUND   3   // medium-long timeslice (~0.2s), batch-friendly

// Current active policy (defined in sysproc.c).
extern int current_policy;

// Timeslice duration in RISC-V cycle counts, indexed by policy id.
// 1,000,000 cycles ≈ 0.1s at 10 MHz (xv6 default).
extern uint64 policy_timeslice_cycles[4];

#endif // POLICY_H
