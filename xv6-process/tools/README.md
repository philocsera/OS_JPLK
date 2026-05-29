# LLM Advisor Host Bridge (local open model, no API key)

`bridge.py` is the **host side** of the xv6 "LLM advisor" (report sec 01/04,
option-a). It turns the advisor into a *real* LLM running locally — free, no
API key, fully offline — instead of the in-guest hardcoded heuristic.

```
QEMU stdout  --@@WL frames-->  bridge.py  --HTTP-->  Ollama (local open model)
QEMU stdin   <--"setcls .."--  bridge.py  <--JSON--  classification
```

The kernel never knows an LLM exists: `wlagent` only *exports* procstat, and
the decision is applied through the existing `setclass` syscall via `setcls`.

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

## Fork-bomb cap (sec 06)

`GROUP_PROC_LIMIT` (param.h) bounds live procs per job/group; `fbomb` shows a
runaway job capped while the shell stays responsive. Enforced in `kfork`.

## How it stays safe (fail-static)

- LLM unreachable / timeout / bad JSON  -> fall back to the same heuristic the
  in-guest `advisord` uses (no behavior cliff).
- Out-of-range class -> the kernel's `setclass` rejects it (-1); the LLM only
  *advises*, the kernel always range-checks.
- Bridge dies -> guest keeps the last class it was given (the original design).

## Pieces

| where | file | role |
|-------|------|------|
| guest | `user/wlagent.c` | background daemon; emits `@@WL [json]` procstat frames |
| guest | `user/setcls.c`  | `setcls <pid> <class>` — applies a decision via setclass |
| host  | `tools/bridge.py`| reads frames, calls local LLM, injects setcls |

## Options

`--model` (default `qwen2.5:0.5b`, try `llama3.2:1b`/`llama3.2:3b` for more
accuracy), `--ollama-host` (`localhost:11434`), `--timeout`, `--poll`
(wlagent tick interval), `--duration`, `--cpus`, `--workload`, `--no-llm`.
