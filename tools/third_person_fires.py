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
# CHARGE, FLY_CHARGE_AIR_TO_AIR: the sprint's clip. It does not loop (measured 2026-10-18: Harald's 0.8 s), so combat.lua
# sends it again at its length; a fixed 0.6 s cut every longer one mid-stride, the Great Unclean One's 1.9 s at a third
CHARGES = (135, 102)
BIN = "animations/database/battle/bin/"
# ATTACK_1-10, the swings combat.lua plays, and the tag a played one hits with: a clip whose .anm.meta has no
# SPLASH_ATTACK hits nothing when the script plays it (the author, 2026-10-25; Celestial Dragon Guard's four carry
# IMPACT_POS alone - a player, 2026-10-24: "didnt manage to kill a single unit"). Read 2026-10-25: of 3,819 units with
# attack clips, 2,676 have a splash on every one, 729 on some, 414 on none
ATTACKS = tuple(range(454, 464))
# FLY_ATTACK_1-10 (off the body that flies), RIDER_ATTACK_1-10 and RIDER_FLY_ATTACK_1-10 (off the rider's own bin): the
# swings combat.lua plays in the air and on a rider with no mount of his own, each with its own IMPACT_POS. Read
# 2026-11-01: 580, 711 and 15 land units have one (a blow without one landed 2.5 m ahead)
FLY_ATTACKS, RIDER_ATTACKS, RIDER_FLY_ATTACKS = tuple(range(494, 504)), tuple(range(1901, 1911)), tuple(range(1941, 1951))
# fire on the move: MOVING_FIRE_FORWARD_LEVEL, _LEFT_, _RIGHT_, _BACKWARD_LEVEL, then a rider's RIDER_FIRE_FORWARD_, _LEFT_,
# _RIGHT_, _BACK_LEVEL (9.0 ids). Read 2026-11-01: of 870 missile units 348 carry CA's fire whilst moving (the
# mounted_fire_move attribute); 139 of them have the first, 180 the rider's. 58 more have a MOVING_FIRE slot without the
# attribute, some of it the standing fire clip under that slot (the sorcerer-prophet set), so the attribute gates it
MOVING_FIRES = (1570, 1572, 1573, 1574, 2105, 2108, 2111, 2114)
FIRE_MOVE = "mounted_fire_move"
SPLASH = b"\x0d\x00SPLASH_ATTACK"
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


def fire_pos(meta, name=b"FIRE_POS"):
    """Every FIRE_POS event in .anm.meta bytes, in time order, as (start, x, y, z). A v10 tag: u16 name length, the
    name, u32 version, f32 start, f32 end, string filter (u16 byte count), i32 id, then its Vector3 Position
    (TheAssetEditor's FirePos_v10: "measured from the unit's animroot bone, in meters"). Other versions: time only.
    name: another tag of that shape (IMPACT_POS)."""
    out, i, tag = [], 0, struct.pack("<H", len(name)) + name
    while True:
        i = meta.find(tag, i)
        if i < 0:
            return sorted(out)
        base = i + len(tag)
        ver, t = struct.unpack_from("<If", meta, base)
        if ver == 10:
            n, = struct.unpack_from("<H", meta, base + 12)
            x, y, z = struct.unpack_from("<fff", meta, base + 14 + n + 4)
            out.append((round(t, 3), round(x, 3), round(y, 3), round(z, 3)))
        else:
            out.append((round(t, 3),))
        i = base


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

    def size(self, path):
        """Its byte count, None when no pack read here holds it; only a tiny entry is unpacked to count it."""
        v = self.at.get(path.replace("\\", "/").lower())
        if v is None or isinstance(v, bytes):
            return None if v is None else len(v)
        return len(self.get(path)) if v[2] < 64 else v[2]


def blank_slots(files, man_animation):
    """The slots of his bin whose every clip is an empty file: the slot is in his fragment, so P.has_slot finds it, and the
    engine plays nothing (measured 2026-10-18: CA's Great Unclean One's JUMPING_ATTACK_1, hu09b_sw_jump_attack_01.anim,
    0 bytes - "clip 489 never played" four times in the author's log; the only one of 1,899 bins). A clip no pack read
    here holds is not counted: it may be in one these do not read."""
    b = files.get(BIN + man_animation + ".bin")
    if not b:
        return None
    try:
        _h, rows = RA.read_bin(b)
    except (ValueError, struct.error):
        return None
    out = sorted({r["slot"] for r in rows if r["anims"] and all(files.size(a) == 0 for a, _m, _s in r["anims"])})
    return out or None


def dull_slots(files, man_animation):
    """His bin's ATTACK_1-10 slots with a clip whose .anm.meta has no SPLASH_ATTACK (or no meta): played, it may hit
    nothing. None when every slot has one, or the bin is not read here."""
    b = files.get(BIN + man_animation + ".bin")
    if not b:
        return None
    try:
        _h, rows = RA.read_bin(b)
    except (ValueError, struct.error):
        return None
    out = set()
    for r in rows:
        if r["slot"] in ATTACKS:
            for _anim, meta, _snd in r["anims"]:
                m = meta and files.get(meta)
                if not m or SPLASH not in m:
                    out.add(r["slot"])
    return sorted(out) or None


def impact_slots(files, man_animation, slots=ATTACKS):
    """His bin's ATTACK_1-10 slots (or slots) -> where the blow lands, (x right, z ahead) in m from his animroot: the first
    IMPACT_POS of the slot's first clip that has one. The engine launches a swing once that point reaches its target's edge
    (exe+325fca4) and lands the blow at its time (docs/BATTLE_ENGINE_RE.md section 12); combat.lua picks the man a blow
    lands on by it. Most land 1.6-3.6 m ahead, a giant's or a troll's up to 7 m out and to the side (read 2026-10-29).
    ponytail: the slot's first clip only, the engine picks among them. None when no slot has one."""
    b = files.get(BIN + man_animation + ".bin")
    if not b:
        return None
    try:
        _h, rows = RA.read_bin(b)
    except (ValueError, struct.error):
        return None
    out = {}
    for r in rows:
        if r["slot"] in slots and r["slot"] not in out:
            for _anim, meta, _snd in r["anims"]:
                m = meta and files.get(meta)
                p = [e for e in (fire_pos(m, b"IMPACT_POS") if m else ()) if len(e) == 4]
                if p:
                    out[r["slot"]] = (round(p[0][1], 1), round(p[0][3], 1))
                    break
    return out or None


def lands(packs, table="land_units"):
    """land unit key -> row, a mod's row over CA's (or another table's key -> row)."""
    out = {}
    for p in packs + [DB_PACK]:
        try:
            for _p, _v, rows in load(p, table + "_tables"):
                for r in rows:
                    out.setdefault(r["key"], r)
        except Exception:  # a pack with no such table, or a table version RPFM's schema does not know
            pass
    return out


def fire_moves(packs, units):
    """The keys of units (land unit key -> row) that carry CA's fire whilst moving: their attribute_group holds
    mounted_fire_move in unit_attributes_to_groups_junctions, the mods' rows beside CA's. Its key column is the
    attribute, so lands() cannot read it."""
    groups = set()
    for p in packs + [DB_PACK]:
        try:
            for _p, _v, rows in load(p, "unit_attributes_to_groups_junctions_tables"):
                groups.update(r["attribute_group"] for r in rows if r["attribute"] == FIRE_MOVE)
        except Exception:  # a pack with no such table, or a table version RPFM's schema does not know
            pass
    return {k for k, r in units.items() if r.get("attribute_group") in groups}


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


def build(*specs, raises=None, runs=None, charges=None, blanks=None, dulls=None, impacts=None, impacts_fly=None,
          impacts_rider=None, impacts_rider_fly=None, movers=None, moving=None):
    """land unit key -> FIRE_POS times, for every unit with a missile weapon whose fire clip carries any. specs: the
    slot lists to read, each in order of preference (default FIRE_LEVEL, else GRENADIER, else RIDER_FIRE); one dict per spec, or the
    one dict when given none or one. raises: a dict to fill with each such unit's raise_lengths. runs: one to fill with
    every land unit's longest charge attack, s. charges: one to fill with every land unit's (CHARGE, FLY_CHARGE) lengths,
    s, the longest of each, 0 for none; blanks: one with its blank_slots; dulls: one with its dull_slots; impacts: one
    with its impact_slots; impacts_fly: its FLY_ATTACK ones. All of these off the body combat.lua plays them on: his
    mount's bin (mounts.animation) when he rides one, else his own. impacts_rider, impacts_rider_fly: the RIDER_ATTACK and
    RIDER_FLY_ATTACK ones, off his own bin. movers: a set to fill with the missile units that fire whilst moving
    (fire_moves); moving: a dict with each one's MOVING_FIRES slot -> its FIRE_POS events, off his own bin."""
    specs = specs or ((FIRE, GRENADIER, RIDER_FIRE),)
    mods = mod_packs()
    files = Files(mods + [os.path.join(DATA, n) for n in CA_ANIM])
    bodied = charges is not None or blanks is not None or dulls is not None or impacts is not None or impacts_fly is not None
    mounts = lands(mods, "mounts") if bodied else {}
    outs = [{} for _ in specs]
    units = lands(mods)
    moves = fire_moves(mods, units) if movers is not None or moving is not None else set()
    for key, r in units.items():
        if runs is not None and r.get("man_animation"):
            t = raise_lengths(files, r["man_animation"], RUNS, max)
            if t:
                runs[key] = max(t)
        body = (mounts.get(r.get("mount")) or {}).get("animation") or r.get("man_animation")
        if charges is not None and body:
            t = raise_lengths(files, body, CHARGES, max)
            if t:
                charges[key] = t
        if blanks is not None and body:
            t = blank_slots(files, body)
            if t:
                blanks[key] = t
        if dulls is not None and body:
            t = dull_slots(files, body)
            if t:
                dulls[key] = t
        for table, anim, slots in ((impacts, body, ATTACKS), (impacts_fly, body, FLY_ATTACKS),
                                   (impacts_rider, r.get("man_animation"), RIDER_ATTACKS),
                                   (impacts_rider_fly, r.get("man_animation"), RIDER_FLY_ATTACKS)):
            if table is not None and anim:
                t = impact_slots(files, anim, slots)
                if t:
                    table[key] = t
        if r.get("primary_missile_weapon") and r.get("man_animation"):
            for out, slots in zip(outs, specs):
                t = times_of(files, r["man_animation"], slots)
                if t:
                    out[key] = t
            if raises is not None:
                t = raise_lengths(files, r["man_animation"])
                if t:
                    raises[key] = t
            if key in moves:
                if movers is not None:
                    movers.add(key)
                if moving is not None:
                    got = {s: t for s in MOVING_FIRES for t in [times_of(files, r["man_animation"], (s,))] if t}
                    if got:
                        moving[key] = got
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
    assert f.size("animations/x/A.anm.meta") == len(ev(2.3)) and f.size("animations/none.anim") is None
    f.at["animations/x/empty.anim"], f.at["animations/x/full.anim"] = b"", head
    # a bin of two rows: a slot whose only clip is empty, and one with an empty and a full variant
    f.get = lambda p: {BIN + "b.bin": "bin"}.get(p) or Files.get(f, p)
    RA.read_bin, real = (lambda b: (None, [{"slot": 489, "anims": [("animations/x/empty.anim", None, None)]},
                                           {"slot": 454, "anims": [("animations/x/empty.anim", None, None),
                                                                   ("animations/x/full.anim", None, None)]}])), RA.read_bin
    try:
        assert blank_slots(f, "b") == [489], "only a slot with nothing but empty clips: %s" % blank_slots(f, "b")
    finally:
        RA.read_bin = real
    # ATTACK_1 has a splash on both its clips, ATTACK_2 on one of two, ATTACK_3 has no meta; a slot past ATTACK_10 is not read
    f.at["animations/x/hit.anm.meta"], f.at["animations/x/dud.anm.meta"] = b"head" + SPLASH + b"tail", b"head" + b"IMPACT_POS"
    hit, dud = ("animations/x/full.anim", "animations/x/hit.anm.meta", None), ("animations/x/full.anim", "animations/x/dud.anm.meta", None)
    RA.read_bin = lambda b: (None, [{"slot": 454, "anims": [hit, hit]}, {"slot": 455, "anims": [hit, dud]},
                                    {"slot": 456, "anims": [("animations/x/full.anim", None, None)]}, {"slot": 489, "anims": [dud]}])
    try:
        assert dull_slots(f, "b") == [455, 456], "a slot with any clip short of a splash: %s" % dull_slots(f, "b")
        RA.read_bin = lambda b: (None, [{"slot": 454, "anims": [hit]}])
        assert dull_slots(f, "b") is None, "every slot with a splash: none"
    finally:
        RA.read_bin = real
    # IMPACT_POS: the same v10 shape under a longer name, read by fire_pos(meta, name); a FIRE_POS beside it is not read
    imp = lambda t, x, z: (struct.pack("<H", 10) + b"IMPACT_POS" + struct.pack("<Iff", 10, t, t) + struct.pack("<H", 0)
                           + struct.pack("<i", 0) + struct.pack("<fff", x, 0.9, z))
    assert fire_pos(ev(0.5) + imp(0.86, 0.196, 2.772), b"IMPACT_POS") == [(0.86, 0.196, 0.9, 2.772)], "IMPACT_POS, not FIRE_POS"
    # ATTACK_1: the first clip's (a second clip ignored); ATTACK_2: its first clip has none, its second does; ATTACK_3 none
    f.at["animations/x/i1.anm.meta"], f.at["animations/x/i2.anm.meta"] = imp(0.9, 0.24, 2.77), imp(0.7, -5.37, -0.14)
    i1, i2 = ("animations/x/full.anim", "animations/x/i1.anm.meta", None), ("animations/x/full.anim", "animations/x/i2.anm.meta", None)
    RA.read_bin = lambda b: (None, [{"slot": 454, "anims": [i1, i2]}, {"slot": 455, "anims": [dud, i2]}, {"slot": 456, "anims": [dud]},
                                    {"slot": 489, "anims": [i1]}])
    try:
        got = impact_slots(f, "b")
        assert got == {454: (0.2, 2.8), 455: (-5.4, -0.1)}, "x right and z ahead, 0.1 m, per ATTACK slot: %s" % got
        # FLY_ATTACK_1 (494) is read only when asked for, and ATTACK_1 then is not
        RA.read_bin = lambda b: (None, [{"slot": 454, "anims": [i1]}, {"slot": 494, "anims": [i2]}])
        got = impact_slots(f, "b", FLY_ATTACKS)
        assert got == {494: (-5.4, -0.1)}, "the FLY_ATTACK slot alone: %s" % got
        RA.read_bin = lambda b: (None, [{"slot": 454, "anims": [dud]}])
        assert impact_slots(f, "b") is None, "no IMPACT_POS anywhere: none"
    finally:
        RA.read_bin = real
    print("selftest ok")


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        _selftest()
    else:
        got = build()
        for k in sys.argv[1:]:
            print(k, got.get(k))
        print("%d units, %d with several spawns" % (len(got), sum(len(v) > 1 for v in got.values())))
