"""Breadth-first pointer walk from known objects to target addresses, read-only. 2026-10-14, marker hunt.

    tp_ptr_path.py <depth> <targets hex,hex,...> <start>=<hex addr>:<hex size> [...]

Follows every 8-aligned qword that points into the heap (0x10000000..0x7ff000000000, not the exe image) and
reads the first 0x400 bytes of each object it reaches. Prints each path that ends ON a target or inside
the 0x200 bytes before one, as start+off -> +off -> ... (offsets from the object read at each level)."""
import struct
import sys

import memscan

STEP = 0x400


def heap(q):
    return 0x10000000 <= q < 0x7ff000000000 and not 0x140000000 <= q < 0x145000000 and q % 8 == 0


def main(argv):
    depth = int(argv[0])
    targets = [int(t, 16) for t in argv[1].split(",")]
    starts = []
    for spec in argv[2:]:
        name, rest = spec.split("=")
        a, s = rest.split(":")
        starts.append((name, int(a, 16), int(s, 16)))
    h = memscan.open_game()
    seen = set()
    frontier = [(name, a, s, name) for name, a, s in starts]
    for level in range(depth):
        nxt = []
        for _name, a, s, path in frontier:
            b = memscan.read(h, a, s)
            if not b:
                continue
            for o in range(0, len(b) - 7, 8):
                q = struct.unpack_from("<Q", b, o)[0]
                if not heap(q):
                    continue
                for t in targets:
                    if t - 0x200 <= q <= t:
                        print("level %d: %s+%#x -> %#x (target %#x%+#x)" % (level + 1, path, o, q, t, q - t))
                if q not in seen:
                    seen.add(q)
                    nxt.append((None, q, STEP, "%s+%#x" % (path, o)))
        frontier = nxt
        print("level %d done, %d objects next" % (level + 1, len(frontier)), file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
