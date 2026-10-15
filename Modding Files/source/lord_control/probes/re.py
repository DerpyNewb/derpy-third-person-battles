"""Reverse-engineering helper for Warhammer3.exe, reading the live process (read-only).

    re.py q    <hex addr> [n]          n qwords (default 8)
    re.py dis  <hex addr> [n]          disassemble n instructions (default 60); calls/jumps annotated
    re.py str  <hex addr>              the C string at an address
    re.py --selftest

Addresses inside the exe (0x140000000..) are shown as exe+RVA. Uses memscan.py's reader.
"""
import struct
import sys

import capstone
import memscan

BASE = 0x140000000


def rd(h, a, n):
    b = memscan.read(h, a, n)
    if b is None:
        raise OSError("cannot read %x" % a)
    return b


def tag(a):
    return "exe+%x" % (a - BASE) if BASE <= a < BASE + 0x8000000 else "%x" % a


def dis(h, a, n, out=print):
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
    md.detail = False
    code = rd(h, a, n * 15)
    lines = []
    for ins in md.disasm(code, a):
        note = ""
        if ins.mnemonic in ("call", "jmp") or ins.mnemonic.startswith("j"):
            try:
                note = "  -> " + tag(int(ins.op_str, 16))
            except ValueError:
                pass
        if "rip +" in ins.op_str or "rip -" in ins.op_str:
            disp = int(ins.op_str.split("rip ")[1].split("]")[0].replace(" ", ""), 16)
            note = "  [%s]" % tag(ins.address + ins.size + disp)
        lines.append("%s  %-8s %s%s" % (tag(ins.address), ins.mnemonic, ins.op_str, note))
        if len(lines) >= n:
            break
    for line in lines:
        out(line)
    return lines


def main(argv):
    if argv[:1] == ["--selftest"]:
        md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
        ins = next(md.disasm(bytes.fromhex("e800000000"), 0x140001000))
        assert ins.mnemonic == "call" and int(ins.op_str, 16) == 0x140001005, ins.op_str
        assert tag(0x140001005) == "exe+1005"
        print("selftest ok")
        return 0
    h = memscan.open_game()
    a = int(argv[1], 16)
    if argv[0] == "q":
        n = int(argv[2]) if len(argv) > 2 else 8
        raw = rd(h, a, n * 8)
        for i in range(n):
            print("+0x%02x  %016x  %s" % (i * 8, struct.unpack_from("<Q", raw, i * 8)[0], tag(struct.unpack_from("<Q", raw, i * 8)[0])))
    elif argv[0] == "dis":
        dis(h, a, int(argv[2]) if len(argv) > 2 else 60)
    elif argv[0] == "str":
        raw = rd(h, a, 256)
        print(raw.split(b"\0")[0].decode("latin-1"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
