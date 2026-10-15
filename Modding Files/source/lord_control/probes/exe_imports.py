"""List Warhammer3.exe's imports and their IAT RVAs, stdlib only.

    exe_imports.py [name ...]     print the IAT RVA of each named import (default: mouse/key calls)
    exe_imports.py --selftest

At run time the IAT slot at base + RVA holds the function's address, which memreader's
read_pointer(add(base, rva)) gives - the route to calling a Windows API from Lua.
"""
import struct
import sys

EXE = r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\Warhammer3.exe"
DEFAULT = ["GetCursorPos", "GetAsyncKeyState", "GetKeyState", "ScreenToClient", "GetForegroundWindow",
           "SetCursorPos", "ClipCursor", "ShowCursor", "GetClientRect", "GetActiveWindow"]


def imports(path):
    f = open(path, "rb")

    def at(off, n):
        f.seek(off)
        return f.read(n)

    pe = struct.unpack("<I", at(0x3C, 4))[0]
    assert at(pe, 4) == b"PE\0\0", "not a PE file"
    nsec, opt_size = struct.unpack("<H", at(pe + 6, 2))[0], struct.unpack("<H", at(pe + 20, 2))[0]
    opt = pe + 24
    assert struct.unpack("<H", at(opt, 2))[0] == 0x20B, "not PE32+"
    imp_rva = struct.unpack("<I", at(opt + 112 + 8, 4))[0]
    secs = []
    for i in range(nsec):
        s = at(opt + opt_size + i * 40, 40)
        vsize, vaddr, rsize, raddr = struct.unpack("<IIII", s[8:24])
        secs.append((vaddr, max(vsize, rsize), raddr))

    def off(rva):
        for vaddr, size, raddr in secs:
            if vaddr <= rva < vaddr + size:
                return rva - vaddr + raddr
        raise ValueError("rva %x in no section" % rva)

    def cstr(rva):
        f.seek(off(rva))
        b = b""
        while not b.endswith(b"\0"):
            b += f.read(64)
        return b[: b.index(b"\0")].decode("ascii", "replace")

    out, d = [], off(imp_rva)
    while True:
        oft, _, _, name_rva, ft = struct.unpack("<IIIII", at(d, 20))
        if not name_rva:
            break
        dll, k = cstr(name_rva), 0
        while True:
            thunk = struct.unpack("<Q", at(off(oft or ft) + 8 * k, 8))[0]
            if not thunk:
                break
            name = "#%d" % (thunk & 0xFFFF) if thunk >> 63 else cstr((thunk & 0x7FFFFFFF) + 2)  # skip the u16 hint
            out.append((dll, name, ft + 8 * k))
            k += 1
        d += 20
    return out


def main(argv):
    if argv[:1] == ["--selftest"]:
        names = {n for _, n, _ in imports(EXE)}
        assert "ExitProcess" in names or "GetModuleHandleW" in names, "kernel32 imports not parsed"
        print("selftest ok,", len(names), "imports")
        return 0
    want = argv or DEFAULT
    for dll, name, rva in imports(EXE):
        if name in want:
            print("%-22s %-14s IAT rva 0x%x" % (name, dll, rva))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
