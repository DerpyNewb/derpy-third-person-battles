"""Walk battle global -> +0x2f0 -> +0xa0 -> {+0x120 -> +0xa0, +0x160 -> +0x60} and print each hop, read-only.
2026-10-14, marker hunt. tp_flag_chain.py [label]"""
import struct, sys
import memscan
B = 0x140000000
h = memscan.open_game()
def q(a):
    b = memscan.read(h, a, 8)
    return struct.unpack("<Q", b)[0] if b else None
def vt(a):
    v = q(a)
    return ("exe+%#x" % (v - B)) if v and B <= v < B + 0x5000000 else hex(v or 0)
battle = q(B + 0x4479ee0)
x = q(battle + 0x2f0); y = q(x + 0xa0)
print(sys.argv[1] if len(sys.argv) > 1 else "", "battle", hex(battle), "x", hex(x), vt(x), "y", hex(y), vt(y))
for off, last in ((0x120, 0xa0), (0x160, 0x60)):
    z = q(y + off)
    f = z and q(z + last)
    print("  y+%#x -> z %s %s -> +%#x flag object %s %s, byte +0xd8 = %s" % (off, hex(z or 0), vt(z) if z else "", last,
          hex(f or 0), vt(f) if f else "", memscan.read(h, f + 0xd8, 1)[0] if f else None))
