#!/usr/bin/env python3
"""
bridge.py — host side of the xv6 "LLM advisor" (report sec 01/04, option-a).

This is the piece that makes the advisor a *real* LLM instead of a hardcoded
heuristic, using a FREE LOCAL open model (no API key, fully offline):

    QEMU stdout  --@@WL frames-->  bridge.py  --HTTP-->  Ollama (local LLM)
    QEMU stdin   <--"setcls .."--  bridge.py  <--JSON--  classification

Flow:
  1. Spawn xv6 in QEMU (pexpect owns its stdio), boot, launch `wlagent &`.
  2. Read each `@@WL [...]` procstat frame the guest emits.
  3. Ask a local open LLM (Ollama, e.g. qwen2.5:0.5b) to classify each
     process into one of the 6 scheduler classes.
  4. For every process whose class changed, type `setcls <pid> <id>` into
     the shell — applying the LLM's decision through the real setclass syscall.

Fork-bomb pre-emption (report sec 06): the kernel's per-job fork cap is a
hard numeric backstop. On top of it, the bridge watches each job-GROUP's size
and asks the LLM "legit parallel build vs runaway fork bomb?". If the LLM says
bomb, the bridge pre-emptively demotes the whole group with `setjprio <group>
19` — throttling it on the scheduler before the cap is the deciding factor,
without killing it. Disable with --no-defend.

Fail-static safety (mirrors the kernel design): if the LLM is unreachable,
times out, or returns garbage, we fall back to the same heuristic the in-guest
advisord uses, and never send an out-of-range class (the kernel would reject
it anyway). The LLM only *advises*; the kernel still range-checks.

Requires: pexpect (installed), Python 3.8+. Ollama optional (use --no-llm to
test the plumbing with the heuristic only).
"""

import argparse
import json
import re
import sys
import time
import urllib.request
import urllib.error

import pexpect

# Mirror kernel/procstat.h CLASS_* ids.
CLASS_NAMES = {
    0: "INTERACTIVE",
    1: "IO_BOUND",
    2: "NORMAL",
    3: "CPU_BOUND",
    4: "BATCH",
    5: "SYSTEM",
}
NAME_TO_ID = {v: k for k, v in CLASS_NAMES.items()}

FRAME_RE = re.compile(r"@@WL\s+(\[.*\])\s*$")

# Names we treat as batch-y build tools when CPU-heavy (a tiny "name prior").
BATCH_NAMES = {"make", "cc", "gcc", "ld", "build", "grind"}


# --------------------------------------------------------------------------
# Fallback heuristic — identical policy to proc.c:classify_stats /
# advisord.c:classify, so behavior degrades gracefully to the existing
# advisor when the LLM is unavailable.
# --------------------------------------------------------------------------
def heuristic(p):
    run, slp, life = p["run"], p["sleep"], p["life"]
    active = run + slp
    if life < 3 or active == 0:
        return 2  # NORMAL
    if slp * 2 > active:
        return 0 if p["name"] == "sh" else 1  # INTERACTIVE / IO_BOUND
    if run * 4 > active:
        return 4 if p["name"] in BATCH_NAMES else 3  # BATCH / CPU_BOUND
    return 2


# --------------------------------------------------------------------------
# Fork-bomb pre-emption (report sec 06): judge a whole job-GROUP as a legit
# parallel build or a runaway fork bomb, then (if bomb) demote it via setjprio.
# --------------------------------------------------------------------------
def group_features(members):
    """Aggregate one job-group's @@WL members into the signal the judge needs."""
    n = len(members)
    return {
        "group": members[0].get("group", members[0]["pid"]),
        "count": n,
        "names": [m["name"] for m in members],
        "avg_run": sum(m["run"] for m in members) // n,
        "avg_sleep": sum(m["sleep"] for m in members) // n,
        "min_life": min(m["life"] for m in members),
    }


def heuristic_group(info):
    """Fallback verdict when the LLM is unavailable. Mirrors the prompt's rule:
    a legit build is a few build-tool procs doing real CPU work; a bomb is many
    near-idle clones spawned almost simultaneously."""
    names = info["names"]
    distinct = len(set(names))
    if info["count"] < 3:
        return "build"
    # build tools actually compiling (real CPU work) -> legit
    if any(n in BATCH_NAMES for n in names) and info["avg_run"] >= 3:
        return "build"
    # a swarm of same-named, near-idle, freshly-spawned procs -> bomb
    if info["count"] >= 6 and info["avg_run"] < 3 and distinct <= 2:
        return "bomb"
    if info["count"] >= 10:
        return "bomb"
    return "build"


def llm_judge_group(info, model, host, timeout):
    """Ask the local LLM to label a job-group build|bomb. Raises on failure."""
    sys_prompt = (
        "You are a scheduler guard for a teaching OS. Decide whether a process "
        "job-GROUP is a LEGITIMATE parallel build (like `make -j` launching "
        "cc/gcc/ld) or a runaway FORK BOMB that should be throttled.\n"
        "Per-group signals: count=live processes; names=their program names; "
        "avg_run=avg CPU ticks per proc; avg_sleep=avg sleep ticks; "
        "min_life=age in ticks of the youngest proc.\n"
        "Rules of thumb: a legit build = a HANDFUL of build-tool-named procs "
        "each doing REAL CPU work (avg_run high). A fork bomb = MANY procs with "
        "the SAME or generic name, each doing little real work (avg_run near 0), "
        "all spawned almost simultaneously (min_life small).\n"
        'Reply ONLY as JSON: {"verdict":"build"|"bomb","reason":"<short>"}\n'
        "Examples:\n"
        '{"count":4,"names":["cc","cc","gcc","ld"],"avg_run":22,"avg_sleep":1,'
        '"min_life":35} -> {"verdict":"build","reason":"few build tools doing real work"}\n'
        '{"count":12,"names":["ftree","ftree","ftree"],"avg_run":0,"avg_sleep":8,'
        '"min_life":2} -> {"verdict":"bomb","reason":"many idle clones spawned at once"}'
    )
    body = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": json.dumps(info)},
        ],
        "stream": False,
        "format": "json",
        "options": {"temperature": 0},
    }).encode()
    req = urllib.request.Request(
        f"http://{host}/api/chat", data=body,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        payload = json.loads(resp.read().decode())
    verdict = str(json.loads(payload["message"]["content"]).get("verdict", "")).lower()
    if verdict not in ("build", "bomb"):
        raise ValueError(f"bad verdict {verdict!r}")
    return verdict


def judge_group(info, args):
    """Return (verdict, source), preferring the LLM, falling back to heuristic."""
    if not args.no_llm:
        try:
            return llm_judge_group(info, args.model, args.ollama_host,
                                   args.timeout), "LLM"
        except (urllib.error.URLError, OSError, KeyError, ValueError,
                json.JSONDecodeError) as e:
            log(f"group judge LLM unavailable ({type(e).__name__}); heuristic")
    return heuristic_group(info), "heuristic"


# --------------------------------------------------------------------------
# Local LLM classification via Ollama's HTTP API (no key, offline).
# Returns {pid: class_id}. Raises on any failure so the caller can fall back.
# --------------------------------------------------------------------------
def llm_classify(procs, model, host, timeout):
    sys_prompt = (
        "You classify OS processes into one scheduler class for the CPU "
        "scheduler. Decide per process using run vs sleep ticks:\n"
        "- life<3 -> NORMAL (not enough data)\n"
        "- sleep > run (sleeps a lot) -> INTERACTIVE if name is sh, else "
        "IO_BOUND\n"
        "- run >= sleep (uses CPU a lot, even if sleep is 0) -> BATCH if name "
        "is a build tool (make,cc,gcc,ld,build), else CPU_BOUND\n"
        "A process with run>0 and sleep==0 is CPU-bound, NOT normal. "
        "Class MUST be one of INTERACTIVE, IO_BOUND, NORMAL, CPU_BOUND, "
        "BATCH, SYSTEM.\n"
        "Examples:\n"
        "[{pid:1,name:spin,run:28,sleep:0}] -> [{pid:1,class:CPU_BOUND}]\n"
        "[{pid:2,name:sh,run:0,sleep:30}] -> [{pid:2,class:INTERACTIVE}]\n"
        "[{pid:3,name:make,run:40,sleep:1}] -> [{pid:3,class:BATCH}]\n"
        "[{pid:4,name:cat,run:1,sleep:18}] -> [{pid:4,class:IO_BOUND}]\n"
        'Reply ONLY as JSON: {"classes":[{"pid":<int>,"class":"<CLASS>"}, ...]}'
    )
    # Send only the signal the model needs. Extra fields (ready, current
    # class) measurably degrade a small model's accuracy — it anchors on them.
    slim = [{"pid": p["pid"], "name": p["name"], "run": p["run"],
             "sleep": p["sleep"], "life": p["life"]} for p in procs]
    user_prompt = json.dumps(slim)

    body = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": sys_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "stream": False,
        "format": "json",
        "options": {"temperature": 0},
    }).encode()

    req = urllib.request.Request(
        f"http://{host}/api/chat",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        payload = json.loads(resp.read().decode())
    content = payload["message"]["content"]
    parsed = json.loads(content)

    out = {}
    for item in parsed.get("classes", []):
        pid = int(item["pid"])
        cid = NAME_TO_ID.get(str(item["class"]).strip().upper())
        if cid is not None:
            out[pid] = cid
    return out


def classify_frame(procs, args):
    """Return {pid: class_id}, preferring the LLM, falling back to heuristic."""
    if not args.no_llm:
        try:
            t0 = time.time()
            res = llm_classify(procs, args.model, args.ollama_host, args.timeout)
            dt = (time.time() - t0) * 1000
            # Fill any process the model omitted with the heuristic.
            for p in procs:
                res.setdefault(p["pid"], heuristic(p))
            log(f"LLM({args.model}) classified {len(procs)} proc(s) in {dt:.0f}ms")
            return res, "LLM"
        except (urllib.error.URLError, OSError, KeyError, ValueError,
                json.JSONDecodeError) as e:
            log(f"LLM unavailable/invalid ({type(e).__name__}: {e}); "
                f"falling back to heuristic")
    return {p["pid"]: heuristic(p) for p in procs}, "heuristic"


def log(msg):
    print(f"[bridge] {msg}", file=sys.stderr, flush=True)


def qemu_command(kernel, fsimg, cpus):
    return (
        f"qemu-system-riscv64 -machine virt -bios none -kernel {kernel} "
        f"-m 128M -smp {cpus} -nographic "
        f"-global virtio-mmio.force-legacy=false "
        f"-drive file={fsimg},if=none,format=raw,id=x0 "
        f"-device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0"
    )


def main():
    ap = argparse.ArgumentParser(description="xv6 LLM advisor host bridge")
    ap.add_argument("--kernel", default="kernel/kernel")
    ap.add_argument("--fsimg", default="fs.img")
    ap.add_argument("--cpus", type=int, default=3)
    ap.add_argument("--model", default="qwen2.5:3b")
    ap.add_argument("--ollama-host", default="localhost:11434")
    ap.add_argument("--timeout", type=float, default=20.0,
                    help="LLM HTTP timeout (s); first call cold-loads the model")
    ap.add_argument("--poll", type=int, default=5,
                    help="wlagent poll interval in ticks")
    ap.add_argument("--duration", type=float, default=30.0,
                    help="run this many seconds then quit")
    ap.add_argument("--no-llm", action="store_true",
                    help="skip the LLM, use the heuristic only (plumbing test)")
    ap.add_argument("--hybrid", action="store_true",
                    help="cold-start only: call the LLM once per process (when "
                         "first seen), then stop calling it. Steady state = 0 "
                         "LLM calls. Matches the 'classify at first instant' goal.")
    ap.add_argument("--min-life", type=int, default=10,
                    help="hybrid: wait until a process has this many ticks of "
                         "history before its one-shot LLM classification, so the "
                         "model classifies on real signal not startup noise")
    ap.add_argument("--workload", default="spin",
                    help="comma-separated guest commands to launch in the "
                         "background first (e.g. spin,iohog,cc)")
    ap.add_argument("--no-defend", action="store_true",
                    help="disable LLM fork-bomb pre-emption (sec 06)")
    ap.add_argument("--bomb-threshold", type=int, default=6,
                    help="job-group size that triggers a build-vs-bomb judgment")
    ap.add_argument("--bomb-prio", type=int, default=19,
                    help="priority a judged fork-bomb group is demoted to (0..20)")
    args = ap.parse_args()

    cmd = qemu_command(args.kernel, args.fsimg, args.cpus)
    log(f"spawning: {cmd}")
    child = pexpect.spawn(cmd, encoding="utf-8", timeout=60)

    child.expect("init: starting sh")
    child.expect(r"\$ ")
    for w in [w.strip() for w in args.workload.split(",") if w.strip()]:
        child.sendline(f"{w} &")
        child.expect(r"\$ ")
    child.sendline(f"wlagent {args.poll} &")
    log("wlagent launched; entering classify loop")

    last_sent = {}        # pid -> last class_id we applied (avoid redundant setcls)
    cold_done = set()     # pids already classified by the LLM (hybrid mode)
    # sec 06 defense state. By design each group is judged ONCE (at its first
    # threshold crossing) and a 'bomb' demotion is TERMINAL — appropriate for a
    # bounded demo; a production guard would re-evaluate on continued growth and
    # lift the demotion if a group later looks legitimate.
    judged_groups = {}    # group_id -> "build"|"bomb"
    demoted_groups = set()  # groups already throttled via setjprio
    deadline = time.time() + args.duration

    while time.time() < deadline:
        try:
            child.expect(FRAME_RE, timeout=10)
        except pexpect.TIMEOUT:
            log("no frame for 10s; still waiting")
            continue
        except pexpect.EOF:
            log("QEMU exited")
            break

        raw = child.match.group(1)
        try:
            procs = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if not procs:
            continue

        # --- Fork-bomb pre-emption (sec 06): judge each ballooning group once,
        # and throttle the whole job via setjprio if the LLM calls it a bomb. ---
        if not args.no_defend:
            groups = {}
            for p in procs:
                groups.setdefault(p.get("group", p["pid"]), []).append(p)
            for g, members in groups.items():
                if g in judged_groups or len(members) < args.bomb_threshold:
                    continue
                info = group_features(members)
                verdict, jsrc = judge_group(info, args)
                judged_groups[g] = verdict
                log(f"group {g}: {info['count']} proc(s) {sorted(set(info['names']))} "
                    f"run~{info['avg_run']} life>={info['min_life']} -> {verdict} via {jsrc}")
                if verdict == "bomb":
                    demoted_groups.add(g)
                    log(f"  PRE-EMPT fork-bomb: setjprio {g} {args.bomb_prio}")
                    child.sendline(f"setjprio {g} {args.bomb_prio}")
                    try:
                        child.expect(r"setjprio: .*\r?\n", timeout=3)
                        log(f"  guest: {child.after.strip()}")
                    except (pexpect.TIMEOUT, pexpect.EOF):
                        pass

        # Hybrid: only ask the LLM about processes we have NOT classified yet
        # (their cold-start). Already-decided pids cost zero LLM calls.
        if args.hybrid:
            targets = [p for p in procs
                       if p["pid"] not in cold_done and p["life"] >= args.min_life]
            if not targets:
                continue  # steady state (or still warming up) — no LLM work
        else:
            targets = procs

        decisions, source = classify_frame(targets, args)
        if args.hybrid:
            cold_done.update(p["pid"] for p in targets)
        for p in targets:
            pid = p["pid"]
            # Don't let a class->priority nudge undo a fork-bomb demotion.
            # Key exactly as the defense pass does (same group fallback).
            if p.get("group", pid) in demoted_groups:
                continue
            new = decisions.get(pid)
            if new is None or new == p["class"] or last_sent.get(pid) == new:
                continue
            log(f"  pid={pid} name={p['name']} "
                f"{CLASS_NAMES[p['class']]} -> {CLASS_NAMES[new]} "
                f"(run={p['run']} sleep={p['sleep']}) via {source}")
            child.sendline(f"setcls {pid} {new}")
            last_sent[pid] = new
            # consume the setcls echo/output so it doesn't confuse frame parsing
            try:
                child.expect(r"setcls: .*\r?\n", timeout=3)
            except (pexpect.TIMEOUT, pexpect.EOF):
                pass

    log("duration reached; shutting down QEMU")
    try:
        child.sendcontrol("a")
        child.send("x")
        child.expect(pexpect.EOF, timeout=5)
    except (pexpect.TIMEOUT, pexpect.EOF):
        child.close(force=True)


if __name__ == "__main__":
    main()
