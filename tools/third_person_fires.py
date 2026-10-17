"""When and where each unit's fire clip spawns its shots: land unit key -> FIRE_POS events in time order, each
(s from the clip's start, x, y, z): the muzzle in metres from his animroot, x right, y up, z ahead.

    py tools/third_person_fires.py <land unit key> ...   print the times found for those units
    py tools/third_person_fires.py --selftest            the meta and slash handling on made-up bytes

build_third_person.py --gen writes the result into data.lua's fires. The engine spawns one shot per FIRE_POS event in the
fire clip's .anm.meta (measured 2026-10-15: a rocket barrage carries 18, 1.0 to 5.25 s, and CA's ratling gun the same;
the ironbreakers' blasting charge one, at 2.3 s), and no script call or context exposes them, so they are read here:

    land_units.man_animation -> animations/database/battle/bin/<man_animation>.bin (loose in anim2.pack, inside a
    mod's .animpack) -> its FIRE_LEVEL row (slot 1557), else its GRENADIER row (949), else its RIDER_FIRE_FORWARD_LEVEL
    row (2105) -> each anim's .anm.meta -> its FIRE_POS events. GRENADIER is the throw of a man with no FIRE_LEVEL
    (measured 2026-10-15: Exalted Plaguebearers' Death's Head, hu04d_plaguebearer_favoured_missile_attack_grenadier_01,
    FIRE_POS at 1.962 s; 25 units of 827 throw from it alone); RIDER_FIRE_FORWARD_LEVEL the shot of a rider with
    neither (measured 2026-10-17: 165 mounted missile units, Kislev's Horse Archers among them)

Mods are read too: every pack in the Workshop folder and every non-CA pack in data/, so the units of the mods installed
where the pack is built are covered; a unit of a mod not installed there gets one shot (combat.lua). A path a mod ships
wins over CA's, the first mod in name order over the rest. A table's meta path may carry backslashes.
"""
import glob
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from read_pack_index import entries  # noqa: E402
from read_vanilla_db import load, DB_PACK  # noqa: E402
import read_animpack as RA  # noqa: E402

DATA = os.path.dirname(DB_PACK)
WORKSHOP = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(DATA))), "workshop", "content", "1142710")
FIRE, GRENADIER, RIDER_FIRE = 1557, 949, 2105  # FIRE_LEVEL, the fire clip combat.lua plays; else the throw; else a rider's
# FIRE_LOW, FIRE_HIGH: played instead of FIRE_LEVEL for a shot that leaves low or high, each with its own muzzle
# (measured 2026-10-15: 413 and 421 of 864 missile units have them; the drakegun's muzzle 0.40, 0.86, 1.18 m up)
FIRE_LOW, FIRE_HIGH = 1556, 1558
# SHOOT_READY_TO_AIM_LOW, _LEVEL, _HIGH: the raise before each pair's fire. Their play time is read too: combat.lua sends
# the fire clip just before the raise ends, and a raise it had to learn the length of left him in his idle for a model tick
# on the first shot (the author, 2026-10-16: "twitching when aiming high")
RAISES = (1553, 1554, 1555)
# MOVING_ATTACK_1-2, the charge attack (the only two any unit has): steered, the engine never reports its end, so
# combat.lua ends it at its length (measured 2026-10-16)
RUNS = (484, 485)
BIN = "animations/database/battle/bin/"
CA_ANIM = ("anim2.pack", "anim.pack", "anim_3.pack")
# CA's own packs in data/: everything but these prefixes is a mod
CA_PREFIX = ("anim", "audio", "boot", "data", "db", "local_", "models", "movies", "shaders", "terrain", "text", "tile",
             "ui", "variants", "warmscape", "derpy_third_person")


def unpack(b, comp):
    """A pack entry's bytes: CA's are a u32 size then an LZ4 frame or a zstd frame."""
    if not comp:
        return b
    body = b[4:]
    if body[:4] == b"\x04\x22\x4d\x18":
        import lz4.frame
        return lz4.frame.decompress(body)
    import zstandard
    return zstandard.ZstdDecompressor().decompress(body, max_output_size=1 << 28)


def fire_pos(meta):
    """Every FIRE_POS event in .anm.meta bytes, in time order, as (start, x, y, z). A v10 tag: u16 name length 8, the
    name, u32 version, f32 start, f32 end, string filter (u16 byte count), i32 id, then its Vector3 Position
    (TheAssetEditor's FirePos_v10: "measured from the unit's animroot bone, in meters"). Other versions: time only."""
    out, i = [], 0
    while True:
        i = meta.find(b"\x08\x00FIRE_POS", i)
        if i < 0:
            return sorted(out)
        ver, t = struct.unpack_from("<If", meta, i + 10)
        if ver == 10:
            n, = struct.unpack_from("<H", meta, i + 22)
            x, y, z = struct.unpack_from("<fff", meta, i + 24 + n + 4)
            out.append((round(t, 3), round(x, 3), round(y, 3), round(z, 3)))
        else:
            out.append((round(t, 3),))
        i += 10


def anim_length(b):
    """An .anim's play time, s: u32 version, u32 1, f32 frame rate, the skeleton's name (u16 length, then its bytes),
    u32 0, then f32 seconds (read 2026-10-16 off v8 files, against the game: the Streltsi's raise 1.1 s and Akshina's
    Ambushers' 0.8 s, as the script log saw them play). None when the bytes are not that shape."""
    if not b or len(b) < 14:
        return None
    _ver, one = struct.unpack_from("<II", b, 0)
    n, = struct.unpack_from("<H", b, 12)
    if one != 1 or len(b) < 14 + n + 8:
        return None
    zero, t = struct.unpack_from("<If", b, 14 + n)
    return round(t, 3) if zero == 0 and 0 < t < 60 else None


def raise_lengths(files, man_animation, slots=RAISES, pick=min):
    """(low, level, high): each raise's play time, the shortest of its variants (the engine picks one; sent early, fire
    waits for the raise to end), 0 where his bin has none; None for none at all. slots, pick: other clips, another pick
    (the charge attack's longest)."""
    b = files.get(BIN + man_animation + ".bin")
    if not b:
        return None
    try:
        _h, rows = RA.read_bin(b)
    except (ValueError, struct.error):
        return None
    out = []
    for slot in slots:
        ts = [anim_length(files.get(a)) for r in rows if r["slot"] == slot for a, _m, _s in r["anims"]]
        ts = [t for t in ts if t]
        out.append(pick(ts) if ts else 0)
    return tuple(out) if any(out) else None


def mod_packs():
    out = sorted(glob.glob(os.path.join(WORKSHOP, "*", "*.pack")), key=os.path.basename)
    out += sorted(os.path.join(DATA, n) for n in os.listdir(DATA)
                  if n.endswith(".pack") and not n.startswith(CA_PREFIX))
    return out


class Files:
    """animations/... path -> bytes, mods first, then CA, then what the .animpacks hold."""

    def __init__(self, packs):
        self.at = {}
        for p in packs:
            try:
                f, es = entries(p)
            except (OSError, ValueError):
                continue
            f.close()
            for path, size, off, comp in es:
                k = path.lower()
                if k.startswith("animations/") and k not in self.at:
                    self.at[k] = (p, off, size, comp)
        for k in [k for k in self.at if k.endswith(".animpack")]:
            try:
                items = RA.read_animpack(self.get(k))
            except (ValueError, struct.error):
                continue
            for ip, data in items:
                self.at.setdefault(ip.lower(), data)

    def get(self, path):
        v = self.at.get(path.replace("\\", "/").lower())
        if v is None or isinstance(v, bytes):
            return v
        p, off, size, comp = v
        with open(p, "rb") as f:
            f.seek(off)
            return unpack(f.read(size), comp)


def lands(packs):
    """land unit key -> row, a mod's row over CA's."""
    out = {}
    for p in packs + [DB_PACK]:
        try:
            for _p, _v, rows in load(p, "land_units_tables"):
                for r in rows:
                    out.setdefault(r["key"], r)
        except Exception:  # a pack with no land_units, or a table version RPFM's schema does not know
            pass
    return out


def times_of(files, man_animation, slots=(FIRE, GRENADIER, RIDER_FIRE)):
    """The FIRE_POS events of the first of slots his bin has a row for."""
    b = files.get(BIN + man_animation + ".bin")
    if not b:
        return None
    try:
        _h, rows = RA.read_bin(b)
    except (ValueError, struct.error):
        return None
    row = next((r for s in slots for r in rows if r["slot"] == s), None)
    for _anim, meta, _snd in (row["anims"] if row else ()):
        t = meta and files.get(meta) and fire_pos(files.get(meta))
        if t:
            return t
    return None


def build(*specs, raises=None, runs=None):
    """land unit key -> FIRE_POS times, for every unit with a missile weapon whose fire clip carries any. specs: the
    slot lists to read, each in order of preference (default FIRE_LEVEL, else GRENADIER, else RIDER_FIRE); one dict per spec, or the
    one dict when given none or one. raises: a dict to fill with each such unit's raise_lengths. runs: one to fill with
    every land unit's longest charge attack, s."""
    specs = specs or ((FIRE, GRENADIER, RIDER_FIRE),)
    mods = mod_packs()
    files = Files(mods + [os.path.join(DATA, n) for n in CA_ANIM])
    outs = [{} for _ in specs]
    for key, r in lands(mods).items():
        if runs is not None and r.get("man_animation"):
            t = raise_lengths(files, r["man_animation"], RUNS, max)
            if t:
                runs[key] = max(t)
        if r.get("primary_missile_weapon") and r.get("man_animation"):
            for out, slots in zip(outs, specs):
                t = times_of(files, r["man_animation"], slots)
                if t:
                    out[key] = t
            if raises is not None:
                t = raise_lengths(files, r["man_animation"])
                if t:
                    raises[key] = t
    return outs if len(specs) > 1 else outs[0]


def _selftest():
    ev = lambda t: (struct.pack("<H", 8) + b"FIRE_POS" + struct.pack("<Iff", 10, t, t) + struct.pack("<H", 2) + b"ab"
                    + struct.pack("<i", 0) + struct.pack("<fff", 0.25, 1.5, 0.75))
    assert fire_pos(b"junk" + ev(1.25) + ev(1.0) + b"tail") == [(1.0, 0.25, 1.5, 0.75), (1.25, 0.25, 1.5, 0.75)], \
        "time order, and the position read past a filter string"
    assert fire_pos(b"no events") == []
    head = struct.pack("<IIfH", 8, 1, 20.0, 10) + b"humanoid01" + struct.pack("<If", 0, 1.1)
    assert anim_length(head) == 1.1, "the play time past the skeleton's name"
    assert anim_length(head[:-2]) is None and anim_length(b"x" * 30) is None, "a short or foreign file has none"
    f = Files.__new__(Files)
    f.at = {"animations/x/a.anm.meta": ev(2.3)}
    assert f.get("animations\\X\\a.anm.meta") == ev(2.3), "a backslashed, upper-case meta path is found"
    print("selftest ok")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        _selftest()
    else:
        got = build()
        for k in sys.argv[1:]:
            print(k, got.get(k))
        print("%d units, %d with several spawns" % (len(got), sum(len(v) > 1 for v in got.values())))
