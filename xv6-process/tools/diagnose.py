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


def diagnose(timeline, model, host, timeout):
    sys_prompt = (
        "You are an operating-system post-mortem analyst. You are given a "
        "kernel panic timeline from a teaching OS (xv6). Each @@EV line is an "
        "event with a tick (time), a type (NOTE=app breadcrumb, EXIT=process "
        "exited with d1=run-ticks d2=sleep-ticks, FORKFAIL=a fork was denied "
        "with d1=job-group d2=live-procs-in-job, CLASS=reclassified). The "
        "@@PANIC line gives the panic reason.\n"
        "Explain in plain language, in 3-5 sentences: what sequence of events "
        "led to the panic, and the most likely root cause. Be concrete and "
        "reference the evidence (process names, the FORKFAIL pattern, the "
        "panic reason)."
    )
    body = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": sys_prompt},
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
