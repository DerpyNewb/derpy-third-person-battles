"""Crude stack scan of a minidump's faulting thread: registers, then every qword on the stack from RSP that
points into a loaded module, as module+offset. Usage: stackscan.py <dump.mdmp> [bytes]"""
import struct
import sys

path = sys.argv[1]
span = int(sys.argv[2]) if len(sys.argv) > 2 else 0x3000
d = open(path, "rb").read()
_, _, n, dirva = struct.unpack_from("<4sIII", d, 0)
streams = {}
for i in range(n):
    t, size, rva = struct.unpack_from("<III", d, dirva + i * 12)
    streams.setdefault(t, (size, rva))

# modules
mods = []
_, rva = streams[4]
cnt = struct.unpack_from("<I", d, rva)[0]
for i in range(cnt):
    r = rva + 4 + i * 108
    base, size = struct.unpack_from("<QI", d, r)
    nrva = struct.unpack_from("<I", d, r + 20)[0]
    ln = struct.unpack_from("<I", d, nrva)[0]
    name = d[nrva + 4:nrva + 4 + ln].decode("utf-16le").split("\\")[-1]
    mods.append((base, size, name))


def where(a):
    for base, size, name in mods:
        if base <= a < base + size:
            return "%s+0x%x" % (name, a - base)
    return None


# exception
_, rva = streams[6]
tid = struct.unpack_from("<I", d, rva)[0]
code, flags, rec, addr = struct.unpack_from("<IIQQ", d, rva + 8)
csize, crva = struct.unpack_from("<II", d, rva + 160)
regs = ["rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15", "rip"]
vals = struct.unpack_from("<17Q", d, crva + 0x78)
print("thread %d, code 0x%x at %s" % (tid, code, where(addr)))
for r, v in zip(regs, vals):
    print("  %-3s %016x %s" % (r, v, where(v) or ""))
rsp = vals[4]

# thread list: which index is the faulting thread, and its stack memory
_, rva = streams[3]
cnt = struct.unpack_from("<I", d, rva)[0]
for i in range(cnt):
    r = rva + 4 + i * 48
    t = struct.unpack_from("<I", d, r)[0]
    start, dsize, mrva = struct.unpack_from("<QII", d, r + 24)
    if t == tid:
        print("faulting thread is #%d of %d threads (#0 is usually the main thread)" % (i, cnt))
        off = rsp - start
        seen = 0
        for o in range(max(0, off), min(dsize, off + span), 8):
            v = struct.unpack_from("<Q", d, mrva + o)[0]
            w = where(v)
            if w and not w.lower().startswith(("ntdll", "kernel")):
                print("  [rsp+0x%04x] %s" % (o - off, w))
                seen += 1
        print("%d module pointers in 0x%x bytes" % (seen, span))
