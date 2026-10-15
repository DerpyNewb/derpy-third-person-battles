"""Per-stage summary of a zz_tp_f2_drift.lua run. tp_f2_drift.py <readback.json>

The readback is send.py's output for zz_tp_f2_drift_read.lua. Prints, per stage: the controlled man's net and
path movement, a neighbour's and the unit centre's net movement, the command types seen (rva in the exe), and
how far his command point sits from him at the stage's end."""
import json
import math
import sys

EXE = 0x140000000
NAMES = {0x3914618: "idle", 0x3912b98: "walk_a (regiment)", 0x3add278: "walk_b (own)", 0x3913a68: "fire",
         0x390d090: "state change", 0x390ce10: "390ce10"}

raw = json.load(open(sys.argv[1], encoding="utf-8"))
d = raw.get("result", raw)
if isinstance(d, dict) and "values" in d:  # send.py: {"status", "result": {"values": [returned], "count"}}
    d = d["values"][0]
if isinstance(d, str):
    d = json.loads(d)
def seq(x):  # the bridge returns a Lua array as an object keyed "1", "2", ...
    return [x[k] for k in sorted(x, key=int)] if isinstance(x, dict) else list(x or [])


print("unit", d.get("unit"), "ended", d.get("ended"), "strikes", d.get("strikes"), "error", d.get("error"))
for line in seq(d.get("log")):
    print("  ", line)
rows = []
for r in seq(d["rows"]):
    c = r.split("|")
    num = lambda s: float(s) if s else None
    rows.append({"t": int(float(c[0])), "s": c[1], "x": num(c[2]), "z": num(c[3]), "nx": num(c[4]), "nz": num(c[5]),
                 "ux": num(c[6]), "uz": num(c[7]), "cmd": int(c[8], 16) - EXE, "px": num(c[9]), "pz": num(c[10]),
                 "hold": c[11], "on": c[12] == "true"})
stages = []
for r in rows:
    if not stages or stages[-1][0] != r["s"]:
        stages.append((r["s"], []))
    stages[-1][1].append(r)


def net(a, b, kx, kz):
    if a[kx] is None or b[kx] is None:
        return float("nan")
    return math.hypot(b[kx] - a[kx], b[kz] - a[kz])


print("%-12s %5s %7s %7s %7s %7s %8s  %s" % ("stage", "secs", "man", "path", "neighb", "unit", "pt-man", "commands"))
for name, rs in stages:
    a, b = rs[0], rs[-1]
    path = sum(math.hypot(q["x"] - p["x"], q["z"] - p["z"]) for p, q in zip(rs, rs[1:]))
    cmds = []
    for r in rs:
        n = NAMES.get(r["cmd"], "%x" % r["cmd"])
        if not cmds or cmds[-1] != n:
            cmds.append(n)
    gap = math.hypot(b["px"] - b["x"], b["pz"] - b["z"]) if b["px"] is not None else float("nan")
    print("%-12s %5.1f %7.2f %7.2f %7.2f %7.2f %8.2f  %s" % (name, (b["t"] - a["t"]) / 1000, net(a, b, "x", "z"), path,
          net(a, b, "nx", "nz"), net(a, b, "ux", "uz"), gap, " > ".join(cmds)))
