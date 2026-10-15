"""Where a battle unit is referenced, selected against deselected, read-only. 2026-10-14, the marker hunt.

    tp_ptr_refs.py <out.json> <hex addr> [hex addr ...]

Scans writable memory for each address as a little-endian pointer with the unit selected, deselected, and
selected again (bridge: zz_tp_sel_on.lua / zz_tp_sel_off.lua). Reports the references present only while
selected (a selection list) and those present throughout (objects that hold the unit, such as its
indicator). Ends with the unit selected."""
import json
import struct
import subprocess
import sys
import time

import memscan


def send(lua):
    r = subprocess.run([sys.executable, "send.py", lua, "15"], capture_output=True, text=True)
    if '"ok"' not in r.stdout:
        raise SystemExit("bridge: " + lua + " -> " + r.stdout.strip())


def refs(h, targets):
    return {t: set(memscan.scan(h, struct.pack("<Q", t))) for t in targets}


def main(argv):
    out, targets = argv[0], [int(a, 16) for a in argv[1:]]
    h = memscan.open_game()
    send("zz_tp_sel_on.lua"); time.sleep(0.6)
    on1 = refs(h, targets)
    send("zz_tp_sel_off.lua"); time.sleep(0.6)
    off = refs(h, targets)
    send("zz_tp_sel_on.lua"); time.sleep(0.6)
    on2 = refs(h, targets)
    res = {}
    for t in targets:
        only_on = sorted(on1[t] & on2[t] - off[t])
        always = sorted(on1[t] & on2[t] & off[t])
        res[hex(t)] = {"only_selected": [hex(a) for a in only_on], "always": [hex(a) for a in always]}
        print(hex(t), "only while selected:", len(only_on), " always:", len(always))
        for a in only_on[:30]:
            print("   sel ", hex(a))
    json.dump(res, open(out, "w"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1:])
