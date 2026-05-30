#!/usr/bin/env python3
"""
test_advd.py — end-to-end test of the dedicated virtio-console advisor channel.

Console (pexpect) is used ONLY for boot + one-time workload/daemon launch. The
advisor protocol (@@WL frames out, setcls command in, @@OK ack back) runs
entirely over the unix socket — proving the channel separation (Plan A).
"""
import json, os, re, socket, sys, time
import pexpect

SOCK = "/tmp/xv6advisor_test.sock"
FRAME_RE = re.compile(r"@@WL\s+(\[.*\])\s*$")

if os.path.exists(SOCK):
    os.unlink(SOCK)

cmd = (
    "qemu-system-riscv64 -machine virt -bios none -kernel kernel/kernel "
    "-m 128M -smp 3 -nographic "
    "-global virtio-mmio.force-legacy=false "
    "-drive file=fs.img,if=none,format=raw,id=x0 "
    "-device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 "
    f"-chardev socket,path={SOCK},server=on,wait=off,id=br0 "
    "-device virtio-serial-device,bus=virtio-mmio-bus.1 "
    "-device virtconsole,chardev=br0"
)
print("[test] spawning qemu", flush=True)
child = pexpect.spawn(cmd, encoding="utf-8", timeout=60)

child.expect("init: starting sh")
child.expect(r"\$ ")
print("[test] booted; launching spin & advd on console", flush=True)
child.sendline("spin &")
child.expect(r"\$ ")
child.sendline("advd 3 &")
child.expect(r"\$ ")

# connect the socket AFTER advd is up, so frames start flowing to us.
for _ in range(100):
    if os.path.exists(SOCK):
        break
    time.sleep(0.05)
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(SOCK)
s.settimeout(20)
print("[test] socket connected; reading frames...", flush=True)

buf = ""
spin_pid = None
ok_ack = False
saw_new_class = False
sent = False
deadline = time.time() + 25

def readlines():
    global buf
    try:
        data = s.recv(4096).decode(errors="replace")
    except socket.timeout:
        return []
    if not data:
        return []
    buf += data
    lines = buf.split("\n")
    buf = lines[-1]
    return lines[:-1]

while time.time() < deadline:
    for line in readlines():
        line = line.strip()
        if not line:
            continue
        m = FRAME_RE.match(line)
        if m:
            try:
                procs = json.loads(m.group(1))
            except json.JSONDecodeError:
                continue
            for p in procs:
                if p["name"] == "spin":
                    spin_pid = p["pid"]
                    if sent and p["class"] == 3:
                        saw_new_class = True
            if spin_pid and not sent:
                print(f"[test] found spin pid={spin_pid} class="
                      f"{procs[0].get('class')}; sending setcls over SOCKET", flush=True)
                s.sendall(f"setcls {spin_pid} 3\n".encode())
                sent = True
        elif line.startswith("@@OK setcls"):
            print(f"[test] got ack on socket: {line}", flush=True)
            ok_ack = True
        elif line.startswith("@@"):
            print(f"[test] channel: {line}", flush=True)
    if ok_ack and saw_new_class:
        break

print()
print(f"[test] frames received : {'YES' if spin_pid else 'NO'}")
print(f"[test] setcls ack       : {'YES' if ok_ack else 'NO'}")
print(f"[test] class applied(=3): {'YES' if saw_new_class else 'NO'}")
ok = bool(spin_pid) and ok_ack and saw_new_class
print(f"[test] {'PASS' if ok else 'FAIL'}")

s.close()
try:
    child.sendcontrol("a"); child.send("x")
    child.expect(pexpect.EOF, timeout=5)
except (pexpect.TIMEOUT, pexpect.EOF):
    child.close(force=True)
sys.exit(0 if ok else 1)
