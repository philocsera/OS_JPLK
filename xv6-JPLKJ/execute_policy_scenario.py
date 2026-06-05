#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path

import pexpect

from collect_swap_scenario import Tee
from collect_swap_scenario import extract_memstat_lines
from collect_swap_scenario import stop_qemu


def run_command(command):
    result = subprocess.run(
        command,
        text=True,
        capture_output=True,
        check=False,
    )

    if result.stdout:
        print(result.stdout, end="")

    if result.stderr:
        print(result.stderr, end="")

    return result


def write_jsonl(path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )


def write_proposal(path, target_pid, swapout_pages):
    proposal = {
        "action": "swapout",
        "target_pid": target_pid,
        "target_quota": None,
        "swapout_pages": swapout_pages,
        "reason": (
            "apply a conservative runtime swap-out policy "
            "and verify system safety after workload execution"
        ),
        "confidence": "medium",
    }

    path.write_text(
        json.dumps(proposal, indent=2) + "\n",
        encoding="utf-8",
    )

    return proposal


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--approve", action="store_true")
    parser.add_argument("--pages", type=int, default=8)
    parser.add_argument("--swapout-pages", type=int, default=4)
    parser.add_argument("--delay", type=int, default=1000)
    parser.add_argument("--ticks", type=int, default=20)
    parser.add_argument("--interval", type=int, default=100)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument(
        "--log-dir",
        default="logs/policy_scenario",
    )
    args = parser.parse_args()

    if args.pages <= 0:
        raise SystemExit("[execute] ERROR: pages must be positive")

    if args.swapout_pages <= 0:
        raise SystemExit(
            "[execute] ERROR: swapout-pages must be positive"
        )

    log_dir = Path(args.log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)

    baseline_log = log_dir / "baseline.jsonl"
    workload_log = log_dir / "workload.jsonl"
    transcript_path = log_dir / "qemu.log"
    proposal_path = log_dir / "runtime_proposal.json"
    verifier_result = log_dir / "hard_verifier_result.json"

    print("[execute] starting QEMU")

    child = pexpect.spawn(
        "make",
        ["qemu", "CPUS=1"],
        encoding="utf-8",
        timeout=args.timeout,
    )

    transcript_file = transcript_path.open(
        "w",
        encoding="utf-8",
    )

    child.logfile = Tee(sys.stdout, transcript_file)

    try:
        child.expect_exact("$ ")

        memhold_command = f"memhold {args.pages} {args.delay} &"
        print(f"[execute] xv6 command: {memhold_command}")
        child.sendline(memhold_command)

        child.expect(
            r"memhold ready pid=(\d+) pages=\d+ delay=\d+"
        )

        target_pid = int(child.match.group(1))
        print(f"[execute] detected target pid: {target_pid}")

        print("[execute] collecting baseline snapshot")
        child.sendline("memwatch json 1 0")
        child.expect_exact("$ ", timeout=args.timeout)

        baseline_lines = extract_memstat_lines(child.before)

        if not baseline_lines:
            raise RuntimeError("baseline memwatch JSON not found")

        write_jsonl(baseline_log, baseline_lines)

        reset_result = run_command(
            ["python3", "bridge.py", "--reset"]
        )

        if reset_result.returncode != 0:
            raise RuntimeError("bridge state reset failed")

        bridge_result = run_command(
            ["python3", "bridge.py", "--file", str(baseline_log)]
        )

        if bridge_result.returncode != 0:
            raise RuntimeError("bridge baseline analysis failed")

        proposal = write_proposal(
            proposal_path,
            target_pid,
            args.swapout_pages,
        )

        print("[execute] generated runtime proposal")
        print(json.dumps(proposal, indent=2))

        print("[execute] validating proposal")

        guard_result = run_command(
            [
                "python3",
                "proposal_guard.py",
                "--proposal",
                str(proposal_path),
            ]
        )

        if guard_result.returncode != 0:
            raise RuntimeError("proposal rejected by guard")

        if not args.approve:
            print("[execute] status: PENDING_APPROVAL")
            print("[execute] no xv6 policy command executed")
            return

        swapctl_command = (
            f"swapctl {target_pid} {args.swapout_pages}"
        )

        print(f"[execute] approved xv6 command: {swapctl_command}")
        child.sendline(swapctl_command)

        child.expect(
            rf"swapctl pid={target_pid} "
            rf"requested={args.swapout_pages} "
            rf"success=(\d+)"
        )

        success = int(child.match.group(1))

        if success <= 0:
            raise RuntimeError("swapctl did not swap out any page")

        child.expect_exact("$ ", timeout=args.timeout)

        memwatch_command = (
            f"memwatch json {args.ticks} {args.interval}"
        )

        print(f"[execute] xv6 command: {memwatch_command}")
        child.sendline(memwatch_command)

        child.expect_exact("$ ", timeout=args.timeout)
        workload_lines = extract_memstat_lines(child.before)

        if not workload_lines:
            raise RuntimeError("workload memwatch JSON not found")

        write_jsonl(workload_log, workload_lines)

    except Exception as error:
        print(f"[execute] ERROR: {error}")
        raise SystemExit(1)

    finally:
        stop_qemu(child)
        transcript_file.close()

    print("[execute] running hard verifier")

    verifier = run_command(
        [
            "python3",
            "hard_verifier.py",
            "--log",
            str(workload_log),
            "--transcript",
            str(transcript_path),
            "--require-swap-activity",
            "--out",
            str(verifier_result),
        ]
    )

    if verifier.returncode != 0:
        print("[execute] result: HARD_VERIFIER_FAILED")
        raise SystemExit(verifier.returncode)

    print("[execute] result: POLICY_APPLIED_AND_VERIFIED")
    print(f"[execute] proposal: {proposal_path}")
    print(f"[execute] workload log: {workload_log}")
    print(f"[execute] transcript: {transcript_path}")
    print(f"[execute] verifier result: {verifier_result}")


if __name__ == "__main__":
    main()
