"""tp_find_walk_rvas.py: the walk fields of platform.lua's BUILDS for the Warhammer3.exe on disk (game may run or not).

A game patch moves them, and the pack then plays every regiment whole ("walking command types unknown for build").
third_person_patterns.py finds the animation fields by byte pattern; these five are found by the call graph the
previous build recorded (docs/sessions/HANDOFF_20261013_THIRD_PERSON_STEERING_COMMANDS.md), never by a guessed shift:
  walk_a, walk_b  vtables whose slot +0x10 calls a function shifted as far as the slot (the two callees 0x190 apart)
  walk_start      the one function that calls the constructor loading walk_b with model+0x328 as owner
  walk_speed      called with [model+0x2e8] and the run flag by the engine's other walk wrapper
  walk_stop       walk_start - 0xb80: reads model+0x318, calls walk_start's destroy
ANCHORS are the previous build's: after a successful run, replace them with the row it printed and the RVAs it names.
Found 2026-10-16 for 6acec6f4 from 6ac6d907's anchors. Needs capstone.
"""
import bisect
import struct
import sys

import capstone

EXE = r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\Warhammer3.exe"
# 6acec6f4 (2026-10-16): vtables, their slot +0x10 functions and those functions' callees, the walk constructor
ANCHORS = dict(walk_a=0x3919350, slot_a=0x3264b70, callee_a=0x325b008, walk_b=0x3ae2400, slot_b=0x3262850,
               callee_b=0x325ae78, ctor=0x324df58, walk_start=0x306f954)
CODE_HI = 0x33a7000

B = open(EXE, "rb").read()
pe = struct.unpack_from("<I", B, 0x3c)[0]
optsz = struct.unpack_from("<H", B, pe + 20)[0]
BASE = struct.unpack_from("<Q", B, pe + 24 + 24)[0]
STAMP = struct.unpack_from("<I", B, pe + 8)[0]
SECS = [struct.unpack_from("<8sIIII", B, pe + 24 + optsz + i * 40)[1:]
        for i in range(struct.unpack_from("<H", B, pe + 6)[0])]


def off(rva):
    for vs, va, rs, raw in SECS:
        if va <= rva < va + min(vs, rs):
            return raw + rva - va


exc, size = struct.unpack_from("<II", B, pe + 24 + 112 + 3 * 8)
FUNCS = sorted(struct.unpack_from("<II", B, off(exc) + i * 12) for i in range(size // 12))
STARTS = [f[0] for f in FUNCS]
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)


def func_of(rva):
    i = bisect.bisect_right(STARTS, rva) - 1
    return FUNCS[i] if i >= 0 and FUNCS[i][0] <= rva < FUNCS[i][1] else None


def insns(fn):
    return list(md.disasm(B[off(fn[0]):off(fn[0]) + fn[1] - fn[0]], BASE + fn[0]))


def calls(fn):
    return [int(i.op_str, 16) - BASE for i in insns(fn) if i.mnemonic == "call" and i.op_str.startswith("0x")]


def lea_rips(fn):
    out = []
    for i in insns(fn):
        if i.mnemonic == "lea" and "rip" in i.op_str:
            out.append(i.address - BASE + i.size + int(i.op_str.split("rip")[1].rstrip("]").replace(" ", ""), 16))
    return out


def slot(vt):
    p = struct.unpack_from("<Q", B, off(vt + 0x10))[0] - BASE
    return p if 0 < p < CODE_HI else None


def vtable(vt0, slot0, callee0):
    hits = []
    for vt in range(vt0 - 0x8000, vt0 + 0x8000, 8):
        f = slot(vt)
        if f is None or not -0x8000 < f - slot0 < 0x8000 or not func_of(f) or func_of(f)[0] != f:
            continue
        for c in calls(func_of(f)):
            if abs((c - callee0) - (f - slot0)) <= 0x100:
                hits.append((vt, f, c))
    return hits


def one(name, hits):
    if len(hits) != 1:
        sys.exit("%s: %d candidates %s" % (name, len(hits), [tuple(map(hex, h)) if isinstance(h, tuple) else hex(h) for h in hits]))
    return hits[0]


A = ANCHORS
# alone each window has look-alikes; the pair keeps its slot and callee gaps
(wa, sa, ca), (wb, sb, cb) = one("walk_a/walk_b", [(a, b) for a in vtable(A["walk_a"], A["slot_a"], A["callee_a"])
    for b in vtable(A["walk_b"], A["slot_b"], A["callee_b"])
    if a[1] - b[1] == A["slot_a"] - A["slot_b"] and a[2] - b[2] == A["callee_a"] - A["callee_b"]])
# more than one function loads walk_b (a copy, a destructor); the constructor is the one walk_start calls
ctors = [f[0] for f in FUNCS if abs(f[0] - A["ctor"]) < 0x8000 and wb in lea_rips(f)]
callers = [f for f in FUNCS if set(ctors) & set(calls(f))]
start = one("walk_start", [f for f in callers if "rcx + 0x328" in insns(f)[3].op_str])
ctor = one("ctor", [c for c in calls(start) if c in ctors])
callers = [f for f in FUNCS if ctor in calls(f)]
destroy = calls(start)[0]
speed = []
for f in callers:
    ins = insns(f)
    for k, i in enumerate(ins):
        if i.op_str.endswith("[rsi + 0x2e8]"):
            speed += [int(j.op_str, 16) - BASE for j in ins[k:k + 5] if j.mnemonic == "call"][:1]
speed = one("walk_speed", speed)
stop = func_of(start[0] - 0xb80)
assert stop and stop[0] == start[0] - 0xb80 and "rcx + 0x318" in " ".join(i.op_str for i in insns(stop)), "walk_stop"
assert destroy in calls(func_of(calls(stop)[0])), "walk_stop's callee does not destroy"
print("build %08x: walk_a = 0x%x, walk_b = 0x%x, walk_start = 0x%x, walk_speed = 0x%x, walk_stop = 0x%x"
      % (STAMP, wa, wb, start[0], speed, stop[0]))
print("next anchors: slot_a = 0x%x, callee_a = 0x%x, slot_b = 0x%x, callee_b = 0x%x, ctor = 0x%x" % (sa, ca, sb, cb, ctor))
