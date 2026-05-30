# LLM Advisor Host Bridge (local open model, no API key)

`bridge.py` is the **host side** of the xv6 "LLM advisor" (report sec 01/04,
option-a). It turns the advisor into a *real* LLM running locally — free, no
API key, fully offline — instead of the in-guest hardcoded heuristic.

```
virtio-console  --@@WL frames-->  bridge.py  --HTTP-->  Ollama (local open model)
(unix socket)   <--"setcls .."--  bridge.py  <--JSON--  classification
```

The kernel never knows an LLM exists: the `advd` daemon only *exports* procstat,
and the decision is applied through the existing `setclass` syscall.

### Dedicated channel (report Plan A)

The advisor protocol runs over a **dedicated virtio-console device**, not the
shared UART. A second virtio-mmio slot (`0x10002000`, IRQ 2) is driven by
`kernel/virtio_console.c` and exposed to user space as the device file
`/advisor`; QEMU backs it with a unix socket. The guest daemon `advd` writes
`@@WL` frames and reads `setcls`/`setjprio` command lines on `/advisor`; the
host bridge connects to the socket and speaks the same line protocol (each
command is answered with an `@@OK`/`@@ERR` ack).

Because frames and commands no longer travel on the UART, they **never
interleave with the human shell** — the problem the earlier console-shared
design (Plan B) had. The UART is used only to boot and to launch the workload +
`advd` once. (Verified: a UART capture during a live bridge run shows zero
`@@WL`/`@@OK`/`setcls` traffic — `tools/test_advd.py` is the end-to-end check.)

## 1. One-time setup (the only step that needs network)

```sh
brew install ollama          # local LLM runtime, HTTP server on :11434
brew services start ollama   # run the daemon persistently
ollama pull qwen2.5:3b       # ~2GB; reliable on this structured task (default)
# qwen2.5:0.5b / llama3.2:1b/3b are too brittle for batched classification.
```

Smoke-test the model (no key, offline after pull):

```sh
curl -s http://localhost:11434/api/chat -d '{
  "model":"qwen2.5:0.5b","stream":false,"format":"json",
  "messages":[{"role":"user","content":"Reply JSON {\"ok\":true}"}]}'
```

## 2. Build xv6 (from the repo root `xv6-process/`)

```sh
make TOOLPREFIX=riscv64-elf- kernel/kernel fs.img
```

## 3. Run the advisor bridge (sec 01/04)

```sh
# Multi-workload, real local LLM (spin=CPU, iohog=IO, cc=CPU-but-build-name):
python3 tools/bridge.py --workload "spin,iohog,cc" --duration 40

# Hybrid: classify each process ONCE at cold-start (after min-life ticks),
# then 0 LLM calls in steady state — fast:
python3 tools/bridge.py --hybrid --min-life 10 --workload "spin,iohog,cc"

# Plumbing only, no LLM (heuristic fallback) — works without Ollama:
python3 tools/bridge.py --no-llm --workload spin --duration 20
```

You'll see the local LLM distinguish workloads — note `cc` becomes BATCH purely
from its build-tool name, while the identical-behavior `spin` is CPU_BOUND:

```
[bridge]   pid=4 name=spin  NORMAL -> CPU_BOUND via LLM
[bridge]   pid=6 name=iohog NORMAL -> IO_BOUND  via LLM
[bridge]   pid=8 name=cc    NORMAL -> BATCH     via LLM
```

## 4. Panic post-mortem (sec 07)

`crashme` builds an incident (fork-bomb spike) then panics; the kernel dumps a
`@@PANIC/@@EV` timeline that a local LLM turns into a plain-language root cause:

```sh
python3 tools/diagnose.py --workload crashme        # boots QEMU, crashes, explains
python3 tools/diagnose.py --logfile /tmp/crash.log  # offline, from a saved dump
```

## Fork-bomb defense (sec 06) — kernel cap + LLM pre-emption

Two layers:

1. **Kernel cap (hard backstop).** `GROUP_PROC_LIMIT` (param.h) bounds live
   procs per job/group; `fbomb` shows a runaway job capped while the shell
   stays responsive. Enforced in `kfork`.
2. **Bridge pre-emption (LLM).** On top of the cap, the bridge watches each
   job-group's size and asks the LLM *"legit parallel build vs runaway fork
   bomb?"*. If it judges a bomb, it demotes the whole job with
   `setjprio <group> 19` — throttling it on the scheduler *before* the cap is
   the deciding factor, without killing it.

```sh
# ftree spawns a wide, resident job-group; the bridge judges + pre-empts it:
python3 tools/bridge.py --workload "ftree 14" --duration 16 --bomb-threshold 6
#  [bridge] group 5: 13 proc(s) ['ftree'] run~0 ... -> bomb via LLM
#  [bridge]   PRE-EMPT fork-bomb: setjprio 5 19
```

`ftree` (vs `fbomb`) keeps its children resident so the bridge's ~500ms poll
can actually observe the balloon. Disable the layer with `--no-defend`.

## Prior persistence (sec 04)

The kernel's exit-stats learning table is reboot-volatile. `priors save` dumps
it to a file and `priors load` restores it (init runs `priors load /priors.db`
at boot), so learned classes survive reboots:

```sh
# inside xv6:
wl ; priors save        # learn wl->CPU_BOUND, persist to /priors.db
# reboot QEMU (same fs.img) -> init auto-loads; wl now starts CPU_BOUND
```

## How it stays safe (fail-static)

- LLM unreachable / timeout / bad JSON  -> fall back to the same heuristic the
  in-guest `advisord` uses (no behavior cliff).
- Out-of-range class -> the kernel's `setclass` rejects it (-1); the LLM only
  *advises*, the kernel always range-checks.
- Bridge dies -> guest keeps the last class it was given (the original design).

## Pieces

| where | file | role |
|-------|------|------|
| kernel| `kernel/virtio_console.c` | virtio-console driver for the dedicated channel; exposes `/advisor` (major `ADVISOR`) |
| guest | `user/advd.c`    | daemon on `/advisor`: writer child emits `@@WL` frames, reader parent applies `setcls`/`setjprio` and acks `@@OK` |
| guest | `user/setcls.c`  | `setcls <pid> <class>` — standalone console executor (Plan B / manual use) |
| guest | `user/setjprio.c`| `setjprio <group> <prio>` — standalone console executor (sec 06) |
| guest | `user/wlagent.c` | legacy console-shared frame emitter (Plan B); superseded by `advd` |
| guest | `user/ftree.c`   | resident wide fork-tree workload for the pre-emption demo |
| guest | `user/priors.c`  | dump / `save` / `load` the learned prior table (sec 04 persistence) |
| host  | `tools/bridge.py`| connects the socket, classifies + judges build-vs-bomb via local LLM, sends setcls/setjprio |
| host  | `tools/test_advd.py`| end-to-end channel test (frames + setcls + ack over the socket) |
| host  | `tools/diagnose.py`| feeds a `@@PANIC` timeline to the LLM for a NL post-mortem (sec 07) |

## Options

`--model` (default `qwen2.5:3b`; smaller models are too brittle here),
`--ollama-host` (`localhost:11434`), `--timeout`, `--poll` (advd tick
interval), `--sock` (virtio-console unix socket path, default
`/tmp/xv6advisor.sock`), `--duration`, `--cpus`, `--workload`, `--no-llm`,
`--hybrid` / `--min-life` (one-shot cold-start classification). Sec-06 defense:
`--no-defend`, `--bomb-threshold` (group size that triggers a judgment,
default 6), `--bomb-prio` (demotion priority, default 19).
