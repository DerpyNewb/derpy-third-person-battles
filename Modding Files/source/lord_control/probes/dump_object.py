"""Read an object out of a minidump's captured memory: dumpobj.py <dump> <hex address> <hex length> [hex needle]
Prints the floats/ints at the offsets the third-person mod writes, and every offset holding the needle dword."""
import struct
import sys

d = open(sys.argv[1], "rb").read()
addr, length = int(sys.argv[2], 16), int(sys.argv[3], 16)
needle = int(sys.argv[4], 16) if len(sys.argv) > 4 else None
_, _, n, dirva = struct.unpack_from("<4sIII", d, 0)
ranges = []
for i in range(n):
    t, size, rva = struct.unpack_from("<III", d, dirva + i * 12)
    if t == 9:  # Memory64List: count u64, base rva u64, then {start u64, size u64}
        cnt, base = struct.unpack_from("<QQ", d, rva)
        off = base
        for k in range(cnt):
            start, sz = struct.unpack_from("<QQ", d, rva + 16 + k * 16)
            ranges.append((start, sz, off))
            off += sz
    elif t == 5:  # MemoryList: count u32, then {start u64, size u32, rva u32}
        cnt = struct.unpack_from("<I", d, rva)[0]
        for k in range(cnt):
            start, sz, mrva = struct.unpack_from("<QII", d, rva + 4 + k * 16)
            ranges.append((start, sz, mrva))
print("%d memory ranges captured" % len(ranges))


def read(a, k):
    for start, sz, off in ranges:
        if start <= a and a + k <= start + sz:
            return d[off + a - start:off + a - start + k]
    return None


blob = read(addr, length)
if blob is None:
    near = sorted(ranges, key=lambda r: abs(r[0] - addr))[:3]
    print("0x%x not captured; nearest ranges: %s" % (addr, ", ".join("0x%x+0x%x" % (s, z) for s, z, _ in near)))
    sys.exit(1)
for name, o in (("pos x", 0x88), ("pos y", 0x8c), ("pos z", 0x90), ("steer1 x", 0x1e0), ("steer1 z", 0x1e8),
                ("steer2 x", 0x194), ("steer2 z", 0x198), ("steer3 x", 0x368), ("steer3 z", 0x370),
                ("state", 0x318), ("0x93c", 0x93c), ("0x964", 0x964)):
    if o + 4 <= length:
        i, = struct.unpack_from("<I", blob, o)
        f, = struct.unpack_from("<f", blob, o)
        print("  +0x%03x %-9s 0x%08x  %g" % (o, name, i, f))
print("  vtable 0x%x" % struct.unpack_from("<Q", blob, 0)[0])
if needle is not None:
    hits = [o for o in range(0, length - 3, 4) if struct.unpack_from("<I", blob, o)[0] == needle]
    print("needle 0x%08x at: %s" % (needle, ", ".join("+0x%x" % o for o in hits) or "nowhere"))
