"""Find the bytes that follow a battle unit's selection, read-only. 2026-10-14, the selection marker hunt.

    tp_sel_diff.py <out.json> <name>=<hex addr>:<hex size> [...]

Flips the selection through the bridge (zz_tp_sel_on.lua / zz_tp_sel_off.lua) three times and reads each
region on both sides. Keeps the offsets whose bytes agree in every selected read, agree in every deselected
read, and differ between the two. Ends with the unit selected."""
import json
import subprocess
import sys
import time

import memscan

CYCLES, SETTLE = 3, 0.6


def send(lua):
    r = subprocess.run([sys.executable, "send.py", lua, "15"], capture_output=True, text=True)
    if '"ok"' not in r.stdout:
        raise SystemExit("bridge: " + lua + " -> " + r.stdout.strip())


def main(argv):
    out, regions = argv[0], []
    for spec in argv[1:]:
        name, rest = spec.split("=")
        addr, size = rest.split(":")
        regions.append((name, int(addr, 16), int(size, 16)))
    h = memscan.open_game()
    reads = {"on": [], "off": []}
    for _ in range(CYCLES):
        for side, lua in (("off", "zz_tp_sel_off.lua"), ("on", "zz_tp_sel_on.lua")):
            send(lua)
            time.sleep(SETTLE)
            reads[side].append({n: memscan.read(h, a, s) for n, a, s in regions})
    found = {}
    for n, a, s in regions:
        hits = []
        for o in range(s):
            on = {r[n][o] for r in reads["on"]}
            off = {r[n][o] for r in reads["off"]}
            if len(on) == 1 and len(off) == 1 and on != off:
                hits.append({"off": hex(o), "addr": hex(a + o), "on": on.pop(), "deselected": off.pop()})
        found[n] = hits
        print(n, len(hits), "bytes follow the selection")
        for x in hits[:40]:
            print("  ", x["off"], "selected", x["on"], "deselected", x["deselected"])
    json.dump(found, open(out, "w"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1:])
