"""Float search over Warhammer3.exe's writable memory, from outside the game. Only `wf` writes.

    memscan.py scan  <out.json> <f> [f ...]   every address where these float32s sit back to back
    memscan.py near32|near64 <out.json> <tol> <f> [f ...]   adjacent float32/float64s within tol
    memscan.py check <in.json> <out.json> <f> [f ...]   keep the addresses that now hold these values
    memscan.py watch <in.json> <secs>         poll each address's 12 bytes ~every 5 ms; how often each changed
    memscan.py dump  <hex addr> <count>       count float32s from an address (with their hex)
    memscan.py wf    <hex addr> <f>           WRITE one float32 (single player, exploration only)
    memscan.py --selftest

Reads only (PROCESS_VM_READ). Used to find the battle camera, which the script wrapper does not
point at: scan for the camera's x/y/z with the camera still, move it, check for the new x/y/z.
"""
import ctypes
import ctypes.wintypes as W
import json
import struct
import subprocess
import sys

K32 = ctypes.WinDLL("kernel32", use_last_error=True)
RW = {0x04, 0x08, 0x40, 0x80}  # READWRITE, WRITECOPY, EXECUTE_READWRITE, EXECUTE_WRITECOPY


class MBI(ctypes.Structure):
    _fields_ = [("BaseAddress", ctypes.c_ulonglong), ("AllocationBase", ctypes.c_ulonglong),
                ("AllocationProtect", W.DWORD), ("PartitionId", W.WORD), ("RegionSize", ctypes.c_ulonglong),
                ("State", W.DWORD), ("Protect", W.DWORD), ("Type", W.DWORD)]


K32.VirtualQueryEx.argtypes = [W.HANDLE, ctypes.c_void_p, ctypes.POINTER(MBI), ctypes.c_size_t]
K32.ReadProcessMemory.argtypes = [W.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
K32.OpenProcess.restype = W.HANDLE
K32.WriteProcessMemory.argtypes = [W.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p]


def open_game():
    out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Warhammer3.exe", "/FO", "CSV", "/NH"],
                         capture_output=True, text=True).stdout
    pid = int(out.split('","')[1])
    h = K32.OpenProcess(0x0410, False, pid)  # QUERY_INFORMATION | VM_READ
    if not h:
        raise OSError("OpenProcess failed: %d" % ctypes.get_last_error())
    return h


def read(h, addr, n):
    buf = ctypes.create_string_buffer(n)
    got = ctypes.c_size_t()
    if not K32.ReadProcessMemory(h, ctypes.c_void_p(addr), buf, n, ctypes.byref(got)):
        return None
    return buf.raw[:got.value]


def regions(h):
    addr, mbi = 0, MBI()
    while K32.VirtualQueryEx(h, ctypes.c_void_p(addr), ctypes.byref(mbi), ctypes.sizeof(mbi)):
        if mbi.State == 0x1000 and (mbi.Protect & 0xFF) in RW and not mbi.Protect & 0x100:
            yield mbi.BaseAddress, mbi.RegionSize
        addr = mbi.BaseAddress + mbi.RegionSize
        if addr >= 0x7FFFFFFFFFFF:
            break


def pattern(vals):
    return struct.pack("<%df" % len(vals), *vals)


def find_all(blob, pat):
    i = blob.find(pat)
    while i != -1:
        if i % 4 == 0:
            yield i
        i = blob.find(pat, i + 1)


def scan(h, pat, chunk=1 << 26):
    hits = []
    for base, size in regions(h):
        off = 0
        while off < size:
            n = min(chunk, size - off)
            blob = read(h, base + off, n + len(pat) - 1 if off + n < size else n)
            if blob:
                hits.extend(base + off + i for i in find_all(blob, pat) if i < n)
            off += n
    return hits


def near(h, vals, tol, dtype, chunk=1 << 26):
    """Addresses where len(vals) adjacent `dtype` values each sit within tol of vals."""
    import numpy as np
    size_of = np.dtype(dtype).itemsize
    hits = []
    for base, size in regions(h):
        off = 0
        while off < size:
            n = min(chunk, size - off)
            blob = read(h, base + off, n)
            if blob and len(blob) >= size_of * len(vals):
                a = np.frombuffer(blob[: len(blob) // size_of * size_of], dtype=dtype)
                with np.errstate(invalid="ignore"):
                    m = np.abs(a[: len(a) - len(vals) + 1] - vals[0]) < tol
                    for k in range(1, len(vals)):
                        m &= np.abs(a[k: len(a) - len(vals) + 1 + k] - vals[k]) < tol
                hits.extend(base + off + int(i) * size_of for i in np.nonzero(m)[0])
            off += n
    return hits


def main(argv):
    if argv[0] == "--selftest":
        blob = b"\0" * 6 + pattern([1.5, 2.5]) + b"\0\0" + pattern([1.5, 2.5])
        assert list(find_all(blob, pattern([1.5, 2.5]))) == [16], "misaligned hit kept or aligned hit lost"
        print("selftest ok")
        return 0
    h = open_game()
    if argv[0] == "scan":
        hits = scan(h, pattern([float(x) for x in argv[2:]]))
        json.dump([hex(a) for a in hits], open(argv[1], "w"))
        print(len(hits), "hits", [hex(a) for a in hits[:20]])
    elif argv[0] in ("near32", "near64"):
        hits = near(h, [float(x) for x in argv[3:]], float(argv[2]), "<f4" if argv[0] == "near32" else "<f8")
        json.dump([hex(a) for a in hits], open(argv[1], "w"))
        print(len(hits), "hits", [hex(a) for a in hits[:40]])
    elif argv[0] == "check":
        pat = pattern([float(x) for x in argv[3:]])
        keep = [a for a in json.load(open(argv[1])) if read(h, int(a, 16), len(pat)) == pat]
        json.dump(keep, open(argv[2], "w"))
        print(len(keep), "kept", keep[:40])
    elif argv[0] == "watch":
        import time
        addrs, secs = [int(a, 16) for a in json.load(open(argv[1]))], float(argv[2])
        last, changes, run, hold, reads = {}, {}, {}, {}, 0
        end = time.perf_counter() + secs
        while time.perf_counter() < end:
            for a in addrs:
                b = read(h, a, 12)
                if a in last:
                    if b != last[a]:
                        changes[a] = changes.get(a, 0) + 1
                        run[a] = 0
                    else:
                        run[a] = run.get(a, 0) + 1
                        hold[a] = max(hold.get(a, 0), run[a])
                last[a] = b
            reads += 1
            time.sleep(0.005)
        moving = sorted((changes.get(a, 0), a) for a in addrs if changes.get(a, 0))
        print(reads, "passes;", len(moving), "of", len(addrs), "changed")
        for c, a in moving[-40:]:
            print(hex(a), "changes", c, "longest hold", hold.get(a, 0), struct.unpack("<3f", last[a]))
    elif argv[0] == "wf":
        hw = K32.OpenProcess(0x0438, False, int(subprocess.run(  # VM_OPERATION | VM_READ | VM_WRITE | QUERY_INFORMATION
            ["tasklist", "/FI", "IMAGENAME eq Warhammer3.exe", "/FO", "CSV", "/NH"], capture_output=True, text=True).stdout.split('","')[1]))
        a = int(argv[1], 16)
        before = struct.unpack("<f", read(hw, a, 4))[0]
        data = struct.pack("<f", float(argv[2]))
        ok = K32.WriteProcessMemory(hw, ctypes.c_void_p(a), data, 4, None)
        print("wrote", ok, "before", before, "now", struct.unpack("<f", read(hw, a, 4))[0])
    elif argv[0] == "dump":
        a, n = int(argv[1], 16), int(argv[2])
        raw = read(h, a, n * 4) or b""
        for i in range(len(raw) // 4):
            (f,), (u,) = struct.unpack_from("<f", raw, i * 4), struct.unpack_from("<I", raw, i * 4)
            print("+0x%03x  %-14.6g %08x" % (i * 4, f, u))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
