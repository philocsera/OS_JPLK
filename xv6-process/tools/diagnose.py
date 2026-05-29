#!/usr/bin/env python3
"""
diagnose.py — host-side natural-language panic post-mortem (report sec 07).

Boots xv6, runs a workload that panics, captures the kernel's @@PANIC/@@EV
timeline, and asks a local open LLM (Ollama, no API key) to explain in plain
language what happened and the likely root cause.

This is the sec-07 idea made real: the kernel can only emit a structured
register/event soup; the *natural-language diagnosis* is produced by an LLM
sitting on the host (the kernel never calls it). The LLM only explains — it
does not decide anything.

Usage:
    python3 tools/diagnose.py --workload crashme
    python3 tools/diagnose.py --logfile /tmp/crash_raw.log   # offline, no QEMU
"""

import argparse
import json
import re
import sys
import urllib.request

import pexpect

PANIC_START = re.compile(r"@@PANIC\b")


def qemu_command(kernel, fsimg, cpus):
    return (
        f"qemu-system-riscv64 -machine virt -bios none -kernel {kernel} "
        f"-m 128M -smp {cpus} -nographic "
        f"-global virtio-mmio.force-legacy=false "
        f"-drive file={fsimg},if=none,format=raw,id=x0 "
        f"-device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0"
    )


def capture_timeline(args):
    """Run the workload in QEMU and return the @@PANIC..@@PANIC_END block."""
    cmd = qemu_command(args.kernel, args.fsimg, args.cpus)
    child = pexpect.spawn(cmd, encoding="utf-8", timeout=60)
    child.expect("init: starting sh")
    child.expect(r"\$ ")
    child.sendline(args.workload)
    child.expect(r"@@PANIC_END", timeout=40)
    block = "@@PANIC" + child.before.split("@@PANIC", 1)[-1] + "@@PANIC_END"
    # the panic freezes the kernel; just kill QEMU
    child.close(force=True)
    # strip CRs and keep only the panic + event lines
    lines = [l.strip("\r") for l in block.splitlines()
             if l.startswith("@@") or l.startswith("panic:")]
    return "\n".join(lines)


SYS_PROMPT = (
    "You are an operating-system post-mortem analyst for a teaching OS (xv6) "
    "whose scheduler is job-aware and has a built-in anti-fork-bomb defense. "
    "You receive a kernel panic timeline; read it precisely.\n"
    "\n"
    "Line formats:\n"
    "- @@PANIC reason=\"...\" tick=T events=N  -- the panic itself. `reason` is "
    "the exact kernel panic string; tie your root cause to it verbatim.\n"
    "- @@EV tick=T type=TYPE pid=P name=NAME d1=X d2=Y msg=M  -- one event.\n"
    "\n"
    "Event types and what d1/d2 mean:\n"
    "- NOTE: a userspace breadcrumb (note() syscall). msg = the text.\n"
    "- EXIT: process NAME (pid P) exited. d1 = total run-ticks, d2 = total "
    "sleep-ticks. High run with ~0 sleep = CPU-bound/spinning; high sleep = "
    "I/O- or sleep-bound.\n"
    "- FORKFAIL: the kernel REFUSED a fork(). This is the per-job process cap "
    "(GROUP_PROC_LIMIT) working AS DESIGNED -- it is NOT out-of-memory, NOT "
    "'insufficient resources', and NOT a kernel bug. pid P (name NAME) tried "
    "to fork while its job-group already held the maximum live processes. "
    "d1 = the job-group id, d2 = live procs in that group at the refusal "
    "(equals the cap), msg=cap confirms the cap fired. A burst of FORKFAIL "
    "sharing one d1 is a fork bomb being contained.\n"
    "- CLASS: the advisor reclassified a process. d1 = old class, d2 = new.\n"
    "\n"
    "Write a plain-language post-mortem in 3-5 sentences: (1) the sequence of "
    "events that led to the panic, citing concrete evidence (names, ticks, the "
    "FORKFAIL pattern, EXIT run/sleep counts); (2) the most likely root cause, "
    "tied to the exact @@PANIC reason string. Never call FORKFAIL "
    "'insufficient memory/resources' -- it is a deliberate cap. If FORKFAILs "
    "precede the panic, say the fork-bomb defense was engaged and judge whether "
    "the panic is caused by that load or is independent of it."
)

# One-shot example with DIFFERENT surface details than crashme, so the model
# learns the field mapping (esp. FORKFAIL = cap, not OOM) rather than parroting.
FEWSHOT_TIMELINE = (
    "@@PANIC reason=\"kerneltrap\" tick=210 events=6\n"
    "@@EV tick=12 type=NOTE pid=4 name=server d1=0 d2=0 msg=accepting\n"
    "@@EV tick=40 type=EXIT pid=5 name=worker d1=31 d2=2 msg=\n"
    "@@EV tick=88 type=FORKFAIL pid=6 name=flood d1=6 d2=16 msg=cap\n"
    "@@EV tick=89 type=FORKFAIL pid=6 name=flood d1=6 d2=16 msg=cap\n"
    "@@EV tick=90 type=FORKFAIL pid=6 name=flood d1=6 d2=16 msg=cap\n"
    "@@EV tick=205 type=NOTE pid=6 name=flood d1=0 d2=0 msg=still spawning\n"
    "@@PANIC_END"
)
FEWSHOT_ANSWER = (
    "At tick 12 a process `server` (pid 4) logged that it was accepting work, "
    "and a short CPU-heavy `worker` (pid 5, 31 run-ticks vs 2 sleep) exited "
    "normally at tick 40. From tick 88 on, pid 6 `flood` repeatedly hit "
    "FORKFAIL on job-group 6, each time with 16 live procs (d2) and msg=cap -- "
    "the per-job fork-bomb cap was refusing its excess forks exactly as "
    "designed, so this is containment, not memory exhaustion. Its 'still "
    "spawning' breadcrumb at tick 205 shows it kept hammering fork despite the "
    "cap. The panic reason 'kerneltrap' at tick 210 indicates a faulting "
    "kernel instruction rather than the cap itself, so the most likely root "
    "cause is a kernel bug exposed under the fork-storm load -- the cap was "
    "working and merely bounded the runaway tree."
)


def diagnose(timeline, model, host, timeout):
    body = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": SYS_PROMPT},
            {"role": "user", "content": FEWSHOT_TIMELINE},
            {"role": "assistant", "content": FEWSHOT_ANSWER},
            {"role": "user", "content": timeline},
        ],
        "stream": False,
        "options": {"temperature": 0.2},
    }).encode()
    req = urllib.request.Request(
        f"http://{host}/api/chat", data=body,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())["message"]["content"]


def main():
    ap = argparse.ArgumentParser(description="xv6 LLM panic post-mortem")
    ap.add_argument("--kernel", default="kernel/kernel")
    ap.add_argument("--fsimg", default="fs.img")
    ap.add_argument("--cpus", type=int, default=3)
    ap.add_argument("--model", default="qwen2.5:3b")
    ap.add_argument("--ollama-host", default="localhost:11434")
    ap.add_argument("--timeout", type=float, default=60.0)
    ap.add_argument("--workload", default="crashme")
    ap.add_argument("--logfile", help="read a captured timeline instead of "
                                      "booting QEMU")
    args = ap.parse_args()

    if args.logfile:
        with open(args.logfile) as f:
            lines = [l.rstrip("\n").rstrip("\r") for l in f
                     if l.startswith("@@") or l.startswith("panic:")]
        timeline = "\n".join(lines)
    else:
        timeline = capture_timeline(args)

    print("==== kernel panic timeline ====")
    print(timeline)
    print("\n==== LLM diagnosis (%s) ====" % args.model)
    try:
        print(diagnose(timeline, args.model, args.ollama_host, args.timeout))
    except Exception as e:  # noqa
        print(f"[diagnose] LLM unavailable: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
