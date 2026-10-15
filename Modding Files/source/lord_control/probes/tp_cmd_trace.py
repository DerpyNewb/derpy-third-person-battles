"""Trace one model's walking-command fields from outside the game, read-only. 2026-10-14, F2 drift.

    tp_cmd_trace.py <model hex> <secs> <out.json>

Polls about every 5 ms and keeps a row only when a field changed. Fields are model offsets; the
command embedded at +0x330 is noted as cmd+N. Battle model ticks are 100 ms, so most rows mark a tick."""
import json
import struct
import sys
import time

import memscan

FIELDS = [  # name, model offset, struct format
    ("x", 0x88, "<f"), ("z", 0x90, "<f"), ("face", 0xb0, "<H"), ("state", 0x318, "<i"), ("vt", 0x330, "<Q"),
    ("done", 0x340, "<B"), ("c30", 0x360, "<i"), ("px", 0x368, "<f"), ("pz", 0x370, "<f"), ("run", 0x390, "<i"),
    ("speed", 0x394, "<f"), ("head", 0x398, "<H"), ("c6c", 0x39c, "<i"), ("b7c", 0x3ac, "<B"), ("b7d", 0x3ad, "<B"),
    ("gait", 0x3ae, "<B"), ("b7f", 0x3af, "<B"), ("b81", 0x3b1, "<B"), ("b82", 0x3b2, "<B"), ("init", 0x3c0, "<B"),
    ("b91", 0x3c1, "<B"), ("loco", 0x710, "<i"),
]


def snap(h, m):
    blob = memscan.read(h, m, 0x720)
    if blob is None:
        return None
    return {n: struct.unpack_from(f, blob, o)[0] for n, o, f in FIELDS}


def main(argv):
    m, secs, out = int(argv[0], 16), float(argv[1]), argv[2]
    h = memscan.open_game()
    rows, last, t0 = [], None, time.perf_counter()
    while time.perf_counter() - t0 < secs:
        s = snap(h, m)
        if s is None:
            break
        if s != last:
            last = s
            rows.append(dict(s, t=round((time.perf_counter() - t0) * 1000), vt="%x" % (s["vt"] - 0x140000000)))
        time.sleep(0.004)
    json.dump(rows, open(out, "w"), indent=0)
    print("%d rows over %.1f s" % (len(rows), secs))


if __name__ == "__main__":
    main(sys.argv[1:])
