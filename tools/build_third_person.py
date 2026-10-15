"""Build and check derpy_third_person.pack - third-person battle control.

    py tools/build_third_person.py --gen        write script/derpy_tp/data.lua from db.pack (RPFM may be shut)
    py tools/build_third_person.py --selftest   compile checks, the Lua harness, data.lua, the loc keys and the HUD files
    py tools/build_third_person.py --bridge     write probes/zz_tp_load.lua, which loads the modules into a running battle
    py tools/build_third_person.py              selftest, then pack through RPFM (needs RPFM open) and read it back

The source tree Modding Files/source/third_person/ mirrors the pack. The harness RUNS the shipped
modules under Lua 5.1.5 against a stubbed battle (tools/third_person_harness.lua) - it does not
re-implement them. Spec: docs/superpowers/specs/2026-10-13-third-person-pack-design.md.
Plan: docs/superpowers/plans/2026-10-13-third-person-pack-core.md.
"""
import json
import os
import re
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Modding Files", "source", "third_person")
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"
LUAC = r"C:\Program Files (x86)\Lua\5.1\luac.exe"
HARNESS = os.path.join(ROOT, "tools", "third_person_harness.lua")
TESTS = os.path.join(ROOT, "tools", "third_person_tests.lua")
EXE = r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\Warhammer3.exe"
PACK = os.path.join(ROOT, "Modding Files", "Modpacks", "derpy_third_person.pack")
BRIDGE_OUT = os.path.join(ROOT, "Modding Files", "source", "lord_control", "probes", "zz_tp_load.lua")
FRAG = "derpy_third_person"

# Every message the mod shows; E.say(key) in the Lua must name one of these and nothing else.
LOC = {
    "derpy_tp_needs_memreader": "Third-Person Battles needs the mod memreader Plus. Subscribe to it, then restart the game.",
    "derpy_tp_multiplayer": "Third-Person Battles is off in multiplayer battles and replays.",
    "derpy_tp_switched_off": "Third-Person Battles ran into three errors and is off until this battle ends. The script log has the details.",
}


def lua_files():
    """[(full path, pack path)] for every .lua under the source tree, sorted by pack path."""
    out = []
    for d, _dirs, files in os.walk(SRC):
        for f in files:
            if f.endswith(".lua"):
                full = os.path.join(d, f)
                out.append((full, os.path.relpath(full, SRC).replace(os.sep, "/")))
    return sorted(out, key=lambda x: x[1])


def pack_files():
    """[(full path, pack path)] for every .lua and .twui.xml under the source tree, sorted by pack path."""
    out = []
    for d, _dirs, files in os.walk(SRC):
        for f in files:
            if f.endswith(".lua") or f.endswith(".twui.xml"):
                full = os.path.join(d, f)
                out.append((full, os.path.relpath(full, SRC).replace(os.sep, "/")))
    return sorted(out, key=lambda x: x[1])


def run_harness(only=None):
    cmd = [LUA, HARNESS, SRC.replace(os.sep, "/"), TESTS] + ([only] if only else [])
    r = subprocess.run(cmd, capture_output=True, text=True)
    print(r.stdout, end="")
    if r.stderr:
        print(r.stderr, end="")
    return r.returncode == 0


def selftest(only=None):
    bad = []
    files = lua_files()
    for full, rel in files:
        r = subprocess.run([LUAC, "-p", full], capture_output=True, text=True)
        if r.returncode:
            bad.append("luac: %s" % (r.stderr.strip() or r.stdout.strip()))
        if "\\" in open(full, encoding="utf-8").read():
            bad.append("a backslash cannot cross the bridge loader: %s" % rel)
    for _full, rel in pack_files():
        if rel != rel.lower():
            bad.append("uppercase in a pack path crashes the game since 6.1: %s" % rel)
    bad += check_data()
    bad += check_loc()
    # the HUD panel and its layout table are generated together; a stale pair draws parts where the Lua does not look
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import gen_third_person_hud as HUDGEN
    xml, lua = HUDGEN.build()
    bad += ["HUD: %s" % b for b in HUDGEN.check(xml, lua)]
    for path, want in ((HUDGEN.UI_FILE, xml), (HUDGEN.LUA_FILE, lua)):
        if not os.path.isfile(path) or open(path, encoding="utf-8").read() != want:
            bad.append("HUD: %s is stale - run py tools/gen_third_person_hud.py" % os.path.relpath(path, ROOT))
    tools = os.path.join(ROOT, "tools")
    # CA's scripting docs are CA's and are not in the public repo: without them every call reads as undocumented
    docs = os.path.isdir(os.path.join(ROOT, "Modding Files", "reference", "ca_script_docs_wh3"))
    if files and not docs:
        print("check_lua_api.py skipped: no Modding Files/reference/ca_script_docs_wh3 (the Assembly Kit's documentation/)")
    for tool in ("check_lua_api.py", "check_lua_literal_left.py") if files else ():  # no files: they scan the campaign folder
        if tool == "check_lua_api.py" and not docs:
            continue
        r = subprocess.run([sys.executable, os.path.join(tools, tool)] + [f for f, _ in files],
                           capture_output=True, text=True)
        if r.returncode:
            bad.append("%s:\n%s" % (tool, r.stdout.strip()))
    if not run_harness(only):
        bad.append("the Lua harness reported failures")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "third_person_patterns.py")],
                       capture_output=True, text=True)
    print(r.stdout, end="")
    if r.returncode:
        bad.append("the command pattern does not check out against the exe")
    for b in bad:
        print("FINDING: %s" % b)
    return not bad


DATA = os.path.join(SRC, "script", "derpy_tp", "data.lua")


def check_data():
    """data.lua holds the rows the probe measured on 2026-10-13, and enough of them."""
    if not os.path.isfile(DATA):
        return ["data.lua is missing: run --gen"]
    probe = ('local d = dofile([[%s]]) '
             'local s = d.shots["wh3_main_cth_inf_jade_warrior_crossbowmen_1"] '
             'local g = d.shots["wh3_main_cth_inf_iron_hail_gunners_0"] '
             'local n, a = 0, 0 for _ in pairs(d.shots) do n = n + 1 end for _ in pairs(d.abilities) do a = a + 1 end '
             'print(s[1], s[2], s[3], d.shots["wh3_main_cth_inf_iron_hail_gunners_0"][3], '
             'd.shots["wh_main_emp_veh_steam_tank_driver"] and "land_key" or "main_key", '
             'd.abilities["wh_main_spell_fire_fireball"], d.abilities["wh2_dlc09_army_abilities_barrage_of_the_legion"], '
             's[4], g[4], n, a)'
             % DATA)
    r = subprocess.run([LUA, "-e", probe], capture_output=True, text=True)
    got = r.stdout.split()
    # unit:type() is a land_units key (CA's doc), and 176 main units sit on a land unit of another name:
    # the steam tank's land unit wh_main_emp_veh_steam_tank_driver is no main_units key at all
    # a scripted launch plays only the projectile's sounds; the shot itself is the weapon's audio type
    # (missile_weapons.audio_type -> audio_missile_weapon_types.fire_start_event), measured 2026-10-14
    want = ["wh3_cth_crossbow_bolt", "13", "1", "3", "land_key", "enemy", "ground",
            "Battle_Individual_Small_Arms_Crossbow_Release", "Battle_Individual_Small_Arms_Hand_Cannon_Fire"]
    bad = []
    if got[:9] != want:
        bad.append("data.lua rows: got %s, want %s %s" % (got[:9], want, r.stderr.strip()))
    elif int(got[9]) < 450 or int(got[10]) < 450:  # a broken generation, not an exact count: 493 ranged land units in 9.0
        bad.append("data.lua is too small: %s unit types, %s abilities" % (got[9], got[10]))
    return bad

def exe_stamp():
    with open(EXE, "rb") as f:
        head = f.read(0x400)
    pe = struct.unpack_from("<I", head, 0x3c)[0]
    return struct.unpack_from("<I", head, pe + 8)[0]


def ability_kind(r):
    if r["target_ground"] or r["target_ground_under_allies"] or r["target_ground_under_enemies"]:
        return "ground"
    if r["target_enemies"]:
        return "enemy"
    if r["target_friends"]:
        return "friend"
    if r["target_self"]:
        return "self"
    # 595 of 596 such abilities target nothing: the engine refuses any unit order for them (measured 2026-10-14)
    return "none"


def gen():
    """Write data.lua from CA's db.pack: main_units -> land_units.primary_missile_weapon ->
    missile_weapons.default_projectile -> projectiles (and missile_weapons.audio_type ->
    audio_missile_weapon_types.fire_start_event), and unit_special_abilities' target flags."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    from read_vanilla_db import load, DB_PACK

    def rows(table):
        return [r for _p, _v, rs in load(DB_PACK, table + "_tables") for r in rs]

    lu = {r["key"]: r for r in rows("land_units")}
    mw = {r["key"]: r for r in rows("missile_weapons")}
    pr = {r["key"]: r for r in rows("projectiles")}
    aw = {r["key"]: r for r in rows("audio_missile_weapon_types")}
    shots = {}
    for r in rows("main_units"):
        land = lu.get(r["land_unit"])
        weapon = land and mw.get(land["primary_missile_weapon"])
        proj = weapon and pr.get(weapon["default_projectile"])
        if proj:
            # keyed by the land unit: unit:type() returns a land_units key (CA's doc), and 176 main units
            # sit on a land unit of another name; main units sharing one land unit share its weapon
            bang = (aw.get(weapon["audio_type"]) or {}).get("fire_start_event") or ""
            shots[r["land_unit"]] = (proj["key"], float(proj["base_reload_time"]), int(proj["projectile_number"]), bang)
    kinds = {r["key"]: ability_kind(r) for r in rows("unit_special_abilities") if not r["passive"]}
    lines = ["-- GENERATED by tools/build_third_person.py --gen from db.pack, exe build 0x%08x. Do not edit." % exe_stamp(),
             "-- shots: land unit key (what unit:type() returns) -> {projectile key, base_reload_time, projectiles per shot,",
             "--   the weapon's fire sound event if it has one}",
             "-- abilities: non-passive ability key -> what it aims at: ground, enemy, friend, self or none",
             "return {", "\tshots = {"]
    for k in sorted(shots):
        key, reload, n, bang = shots[k]
        lines.append('\t\t["%s"] = {"%s", %g, %d%s},' % (k, key, reload, n, ', "%s"' % bang if bang else ""))
    lines += ["\t},", "\tabilities = {"]
    for k in sorted(kinds):
        lines.append('\t\t["%s"] = "%s",' % (k, kinds[k]))
    lines += ["\t},", "}", ""]
    with open(DATA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote %s: %d unit types, %d abilities" % (DATA, len(shots), len(kinds)))


def check_loc():
    """Every E.say key in the Lua has a loc row, and every loc row is said somewhere."""
    used = set()
    for full, _rel in lua_files():
        used |= set(re.findall(r'say\("(derpy_tp_[a-z_]+)"\)', open(full, encoding="utf-8").read()))
    bad = ["E.say('%s') has no loc row" % k for k in sorted(used - set(LOC))]
    bad += ["loc row %s is never said" % k for k in sorted(set(LOC) - used)]
    return bad


def small_data(text, keep):
    """data.lua with only the rows whose key is in keep; the shipped file is never cut."""
    out = [line for line in text.splitlines()
           if not re.match(r'\t\t\["', line) or re.match(r'\t\t\["([^"]+)"\]', line).group(1) in keep]
    return "\n".join(out) + "\n"


BRIDGE_PART = 20000  # characters of source per send: a 207 KB eval crashed the game inside the bridge's parse


def bridge(keep=None):
    """Write probes/zz_tp_load_NN.lua, each appending at most BRIDGE_PART characters of the modules to
    _G.DERPY_TP_SRC, and probes/zz_tp_load_run.lua, which points loadfile at them while the entry file runs
    and then puts it back. Send them in name order with probes/send.py; returns the file names.
    One 207 KB send crashed the game on 2026-10-13 inside the bridge, before any module ran
    (wh3_mcp_debug.log: "Command file found, processing", never "Command parsed")."""
    sources = []
    for full, rel in lua_files():
        text = open(full, encoding="utf-8").read()
        assert "]==]" not in text and "\\" not in text, "%s cannot cross the bridge" % rel
        if keep and rel == "script/derpy_tp/data.lua":
            text = small_data(text, set(keep))
        if rel.startswith("script/derpy_tp/"):
            sources.append(("/" + rel[:-len(".lua")], text))
        elif rel == "script/battle/mod/derpy_third_person.lua":
            sources.append(("entry", text))
    slices = []  # (key, text) pieces, each at most BRIDGE_PART, cut at line ends
    for key, text in sources:
        piece = ""
        for line in text.splitlines(True):
            if piece and len(piece) + len(line) > BRIDGE_PART:
                slices.append((key, piece))
                piece = ""
            piece += line
        slices.append((key, piece))
    files, part, size = [], [], 0
    for key, piece in slices + [(None, "")]:
        if key is None or (part and size + len(piece) > BRIDGE_PART):
            files.append(part)
            part, size = [], 0
        if key is not None:
            part.append((key, piece))
            size += len(piece)
    for old in os.listdir(os.path.dirname(BRIDGE_OUT)):
        if old.startswith("zz_tp_load"):
            os.remove(os.path.join(os.path.dirname(BRIDGE_OUT), old))
    names = []
    for i, part in enumerate(files, 1):
        lines = ["-- GENERATED by tools/build_third_person.py --bridge: part %d of %d. Not shipped." % (i, len(files)),
                 "_G.DERPY_TP_SRC = %s" % ("{}" if i == 1 else "_G.DERPY_TP_SRC or {}"),
                 "local S = _G.DERPY_TP_SRC"]
        for key, piece in part:
            # a long string drops one leading newline: give it one to drop, so the piece stays byte-exact
            lines.append('S["%s"] = (S["%s"] or "") .. [==[\n%s]==]' % (key, key, piece))
        lines.append('return "part %d of %d"' % (i, len(files)))
        name = "zz_tp_load_%02d.lua" % i
        with open(os.path.join(os.path.dirname(BRIDGE_OUT), name), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        names.append(name)
    run = ["-- GENERATED by tools/build_third_person.py --bridge: runs the entry from the parts. Not shipped.",
           "local SRC = _G.DERPY_TP_SRC",
           "if not SRC or not SRC.entry then return 'ERR send the zz_tp_load_NN parts first' end",
           "-- the entry runs in core:get_env(), which need not be the bridge chunk's own env: override loadfile there",
           "local env, base = core:get_env(), loadfile",
           "local old = rawget(env, 'loadfile')",
           "env.loadfile = function(p) if SRC[p] then return loadstring(SRC[p], p) end return base(p) end",
           "local ok, err = pcall(function() local f = assert(loadstring(SRC.entry, 'derpy_third_person')) "
           "setfenv(f, env) f() end)",
           "env.loadfile = old",
           'if not ok then return "ERR " .. tostring(err) end',
           "local E = _G.DERPY_TP",
           'return {loaded = E ~= nil and E.main ~= nil, build = E and E.P and E.P.build, '
           'problems = E and E.P and table.concat(E.P.problems, "; ") or "no platform"}', ""]
    with open(os.path.join(os.path.dirname(BRIDGE_OUT), "zz_tp_load_run.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(run))
    names.append("zz_tp_load_run.lua")
    print("wrote %d parts and zz_tp_load_run.lua: %s" % (len(files), ", ".join(names)))
    return names


def pack():
    """Selftest, then build the pack through RPFM (needs RPFM open) and read every file back."""
    import datetime
    import shutil
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    from check_skill_trees import _rpc, _call
    if not selftest():
        raise SystemExit("selftest failed - not packing")
    _rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                        "clientInfo": {"name": "build_third_person", "version": "1"}})
    _rpc("notifications/initialized", notify=True)
    _call("set_game_selected", {"game_name": "warhammer_3", "rebuild_dependencies": False})
    if os.path.exists(PACK):
        backup = os.path.join(ROOT, "Modding Files", "Backup",
                              "derpy_third_person_%s.pack" % datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
        shutil.copy2(PACK, backup)
        print("backed up to %s" % backup)
        os.remove(PACK)
    key = _call("new_pack", {})["String"]
    _call("set_pack_file_type", {"pack_key": key, "pack_file_type": '"Mod"'})
    files = pack_files()
    _call("add_packed_files", {"pack_key": key, "source_paths": [f for f, _ in files],
                               "destination_paths": json.dumps([{"File": rel} for _, rel in files])})
    with tempfile.TemporaryDirectory() as td:
        tsv = os.path.join(td, "loc.tsv")
        with open(tsv, "w", encoding="utf-8", newline="") as f:
            f.write("key\ttext\ttooltip\n#Loc;1;text/db/%s.loc\n" % FRAG)
            for k in sorted(LOC):
                f.write("%s\t%s\tfalse\n" % (k, LOC[k]))
        loc_path = "text/db/%s.loc" % FRAG
        _call("new_packed_file", {"pack_key": key, "path": loc_path, "new_file": json.dumps({"Loc": FRAG})})
        _call("import_tsv", {"pack_key": key, "table_path": loc_path, "tsv_path": tsv})
    _call("save_pack_as", {"pack_key": key, "path": PACK})
    print("saved %s" % PACK)
    return verify(_call)


def verify(_call):
    """Re-open the SAVED pack: every Lua file byte-identical to the source, the loc with every row."""
    key = _call("open_packfiles", {"paths": [PACK]})["StringContainerInfo"][0]
    bad = []
    files = pack_files()
    loc_path = "text/db/%s.loc" % FRAG
    with tempfile.TemporaryDirectory() as td:
        _call("extract_packed_files", {"pack_key": key,
                                       "source_paths": json.dumps({"PackFile": [{"File": rel} for _, rel in files]}),
                                       "destination_path": td, "export_as_tsv": False})
        for full, rel in files:
            got = os.path.join(td, *rel.split("/"))
            if not os.path.isfile(got) or open(got, "rb").read() != open(full, "rb").read():
                bad.append("%s did not come back byte for byte" % rel)
        _call("extract_packed_files", {"pack_key": key, "source_paths": json.dumps({"PackFile": [{"File": loc_path}]}),
                                       "destination_path": td, "export_as_tsv": True})
        got = os.path.join(td, *loc_path.split("/")) + ".tsv"
        rows = open(got, encoding="utf-8").read().splitlines()[2:] if os.path.isfile(got) else []
        if sorted(r.split("\t")[0] for r in rows) != sorted(LOC):
            bad.append("the loc came back with %d rows, not %d" % (len(rows), len(LOC)))
    for b in bad:
        print("FINDING: %s" % b)
    print("verified %d files and %d loc rows" % (len(files), len(LOC)) if not bad else "pack NOT verified")
    return 0 if not bad else 1


def main(argv):
    if argv[:1] == ["--selftest"]:
        return 0 if selftest(argv[1] if len(argv) > 1 else None) else 1
    if argv[:1] == ["--bridge"]:
        bridge(argv[1:])
        return 0
    if not argv:
        return pack()
    if argv[:1] == ["--gen"]:
        gen()
        return 0
    raise SystemExit("usage: build_third_person.py --gen | --selftest [test] | --bridge | (no flag: pack)")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
