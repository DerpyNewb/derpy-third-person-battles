"""Static reverse engineering on Warhammer3.exe from disk (read-only; the game may be shut). Addresses are RVAs (exe+RVA).

    py tools/exe_re.py q <rva> [n]            n qwords at rva (a vtable), each tagged when it points into the code
    py tools/exe_re.py dis <rva> [n]          disassemble n instructions from rva
    py tools/exe_re.py fn <rva> [n]           disassemble from the start of the function holding rva (CC padding before it)
    py tools/exe_re.py refs <rva>             every call/jmp rel32 and RIP-relative lea/mov/cmp to rva
    py tools/exe_re.py ptrs <rva>             every place the image stores exe+rva as a pointer (its vtable slots)
    py tools/exe_re.py slotcalls <disp>       every call/jmp qword ptr [reg+disp]: who calls a virtual at that slot
    py tools/exe_re.py stores <disp>          every mov dword ptr [reg+disp], imm32, with the value: who writes a field
    py tools/exe_re.py vtmatch <vt> <rva>     the vtable holding the pointer at rva that lines up best with vtable vt
    py tools/exe_re.py --selftest             each command against a fact measured on build 6acec6f4

The exe's section names are disguised on this build (the code is ".udata" at RVA 0x1000, vtables sit in ".xcode",
".text" is a stub), so the code section is found as the one holding a known function. No RTTI: vtables run into each
other, and a scan for where one starts is a guess - vtmatch aligns against a known one instead. The on-disk bytes
equal the live ones (checked 2026-10-16), so this answers the same questions as reading the running game, safely.
What each finding means and how it was confirmed live: docs/BATTLE_ENGINE_RE.md. Needs capstone and numpy.
"""
import re
import struct
import sys

import capstone
import numpy as np

EXE = r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\Warhammer3.exe"
BASE = 0x140000000
KNOWN_CODE = 0x306edd4  # walk_stop on 6acec6f4: the section holding it is the code
_pe = None
_secs = None


def pe():
    global _pe, _secs
    if _pe is None:
        _pe = open(EXE, "rb").read()
        peo = struct.unpack_from("<I", _pe, 0x3C)[0]
        n = struct.unpack_from("<H", _pe, peo + 6)[0]
        opt = struct.unpack_from("<H", _pe, peo + 20)[0]
        _secs = []
        for i in range(n):
            s = peo + 24 + opt + 40 * i
            name = _pe[s:s + 8].rstrip(b"\0").decode()
            vsz, va, rsz, rptr = struct.unpack_from("<IIII", _pe, s + 8)
            _secs.append((name, va, vsz, rptr, rsz))
    return _pe


def off(rva):
    pe()
    for _, va, vsz, rptr, rsz in _secs:
        if va <= rva < va + rsz:
            return rptr + rva - va
    return None


def rva_of(fo):
    pe()
    for _, va, vsz, rptr, rsz in _secs:
        if rptr <= fo < rptr + rsz:
            return va + fo - rptr
    return None


def text():
    pe()
    for name, va, vsz, rptr, rsz in _secs:
        if va <= KNOWN_CODE < va + rsz:
            return va, rptr, rsz
    raise SystemExit("no code section")


def in_text(rva):
    va, _, rsz = text()
    return va <= rva < va + rsz


def q(rva, n=8):
    o = off(rva)
    out = []
    for k in range(n):
        v = struct.unpack_from("<Q", pe(), o + 8 * k)[0]
        r = v - BASE
        out.append((rva + 8 * k, v, r if 0 <= r < 0x10000000 and in_text(r) else None))
    return out


def dis(rva, n=40):
    o = off(rva)
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
    lines = []
    for ins in md.disasm(pe()[o:o + n * 15], BASE + rva):
        if len(lines) >= n:
            break
        s = ins.op_str
        for tok in s.replace(",", " ").replace("[", " ").replace("]", " ").split():
            if tok.startswith("0x14") and len(tok) == 11:
                s = s.replace(tok, "exe+%x" % (int(tok, 16) - BASE))
        lines.append("exe+%x  %-7s %s" % (ins.address - BASE, ins.mnemonic, s))
    return lines


def fstart(rva):
    """the start of the function holding rva: back to the first byte after two CC. ponytail: a function after a single
    int3 is missed (the one before it is returned); the call graph, or Ghidra, settles a doubtful one"""
    o = off(rva)
    b = pe()
    i = o
    while i > 0:
        if b[i - 1] == 0xCC and b[i - 2] == 0xCC:
            return rva - (o - i)
        i -= 1
        if o - i > 0x20000:
            return None
    return None


def code():
    va, rptr, rsz = text()
    return va, rptr, rsz, np.frombuffer(pe(), dtype=np.uint8, count=rsz, offset=rptr)


def refs(target):
    va, rptr, rsz, b = code()
    out = []

    def rel32(pos):
        x = (b[pos].astype(np.int64) | (b[pos + 1].astype(np.int64) << 8) | (b[pos + 2].astype(np.int64) << 16)
             | (b[pos + 3].astype(np.int64) << 24))
        return np.where(x >= 2 ** 31, x - 2 ** 32, x)

    n = rsz - 8
    for op, kind in ((0xE8, "call"), (0xE9, "jmp")):
        p = np.nonzero(b[:n] == op)[0]
        t = va + p + 5 + rel32(p + 1)
        for i in p[t == target]:
            out.append((kind, va + int(i)))
    # REX.W (48/4C) 8D/8B/3B/39/89 modrm rip-relative: disp at +3, next instruction at +7
    rex = np.nonzero((b[:n] == 0x48) | (b[:n] == 0x4C))[0]
    sel = np.isin(b[rex + 1], (0x8D, 0x8B, 0x3B, 0x39, 0x89)) & ((b[rex + 2] & 0xC7) == 0x05)
    p = rex[sel]
    t = va + p + 7 + rel32(p + 3)
    for i in p[t == target]:
        out.append(("riprel", va + int(i)))
    return [(k, a, fstart(a)) for k, a in sorted(out, key=lambda x: x[1])]


def ptrs(target):
    img = pe()
    arr = np.frombuffer(img[:len(img) // 8 * 8], dtype=np.uint64)
    out = []
    for align in range(8):  # vtables are 8-aligned in the image, but a file offset need not be
        a = np.frombuffer(img[align:align + (len(img) - align) // 8 * 8], dtype=np.uint64) if align else arr
        for h in np.nonzero(a == BASE + target)[0]:
            r = rva_of(int(h) * 8 + align)
            if r is not None:
                out.append(r)
    return sorted(set(out))


def slotcalls(disp):
    """call/jmp qword ptr [reg+disp]: FF /2 (call) or /4 (jmp), mod 10 (disp32) or 01 (disp8), any base but rsp"""
    va, rptr, rsz = text()
    b = pe()[rptr:rptr + rsz]
    if disp < 0x80:
        pat = rb"\xff[\x50-\x53\x55-\x57\x60-\x63\x65-\x67]" + re.escape(bytes([disp]))
    else:
        pat = rb"\xff[\x90-\x93\x95-\x97\xa0-\xa3\xa5-\xa7]" + re.escape(struct.pack("<I", disp))
    out = []
    for m in re.finditer(pat, b):
        kind = "call" if (m.group()[1] >> 3) & 7 == 2 else "jmp"
        out.append((kind, va + m.start(), fstart(va + m.start())))
    return out


def stores(disp):
    """mov dword ptr [reg+disp32], imm32: C7 /0, mod 10, any base but rsp"""
    va, rptr, rsz = text()
    b = pe()[rptr:rptr + rsz]
    out = []
    for m in re.finditer(rb"\xc7[\x80-\x83\x85-\x87]" + re.escape(struct.pack("<I", disp)) + rb"(....)", b, re.S):
        a = va + m.start()
        if m.start() > 0 and 0x40 <= b[m.start() - 1] <= 0x4F:
            a -= 1  # a REX prefix: r8-r15 base
        out.append((a, struct.unpack("<i", m.group(1))[0], fstart(a)))
    return sorted(out, key=lambda x: x[1])


def vtmatch(known, rva, n=400):
    """the base of the vtable holding rva that shares the most slots with vtable `known`: a subclass's vtable keeps
    most of its base class's entries at the same index"""
    kv = [v for _, v, _ in q(known, n)]
    best = []
    for base in range(rva - 8 * (n - 1), rva + 8, 8):
        k = (rva - base) // 8
        o = [v for _, v, _ in q(base, n)]
        best.append((sum(1 for i in range(n) if o[i] == kv[i] and i != k), base, k, kv[k] - BASE))
    best.sort(reverse=True)
    return best[:5]


def selftest():
    r = refs(0x306edf8)
    assert any(k == "call" and a == 0x306edec for k, a, _ in r), "walk_stop's call at exe+306edec not found: %r" % r
    assert dis(0x306edd4, 1), "no disassembly"
    assert 0x3915ec8 in ptrs(0x311bd24), "the subclass's clip virtual at exe+3915ec8"
    assert any(a == 0x2f7809a for _, a, _ in slotcalls(0x4a8)), "the clip action's call through slot 0x4a8"
    assert (0x306e986, 1) in [(a, v) for a, v, _ in stores(0x324)], "the order starter writing 1 to +0x324"
    assert (0x306f093, 18) in [(a, v) for a, v, _ in stores(0x324)], "the stop writing 18 to +0x324"
    top = vtmatch(0x3912950, 0x3915ec8)[0]
    assert top[1] == 0x3915a20 and top[2] == 149 and top[3] == 0x306e850, "the subclass vtable: %r" % (top,)
    print("ok: refs, dis, ptrs, slotcalls, stores and vtmatch each found what build 6acec6f4 holds")
    return 0


def main(argv):
    if argv[:1] == ["--selftest"]:
        return selftest()
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, a = argv[0], int(argv[1], 16)
    n = int(argv[2], 16) if cmd == "vtmatch" else (int(argv[2]) if len(argv) > 2 else None)
    if cmd == "q":
        for r, v, t in q(a, n or 8):
            print("exe+%x: %016x%s" % (r, v, ("  -> exe+%x" % t) if t is not None else ""))
    elif cmd == "dis":
        print("\n".join(dis(a, n or 40)))
    elif cmd == "fn":
        s = fstart(a)
        print("function at exe+%x" % s if s is not None else "no start found")
        print("\n".join(dis(s if s is not None else a, n or 60)))
    elif cmd == "refs":
        for k, r, f in refs(a):
            print("%-6s exe+%x  in fn exe+%s" % (k, r, ("%x" % f) if f is not None else "?"))
    elif cmd == "ptrs":
        for r in ptrs(a):
            print("exe+%x" % r)
    elif cmd == "slotcalls":
        for k, r, f in slotcalls(a):
            print("%-4s exe+%x  in fn exe+%s" % (k, r, ("%x" % f) if f is not None else "?"))
    elif cmd == "stores":
        for r, v, f in stores(a):
            print("exe+%x  [reg+0x%x] = %d  in fn exe+%s" % (r, a, v, ("%x" % f) if f is not None else "?"))
    elif cmd == "vtmatch":
        for same, base, k, held in vtmatch(a, n):
            print("vtable exe+%x: %d slots shared; exe+%x is slot %d (+0x%x), where the known one holds exe+%x"
                  % (base, same, n, k, k * 8, held))
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
