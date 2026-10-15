"""Build and check derpy_lord_control.pack - steer your general from behind in single-player battles.
    py tools/build_lord_control.py --selftest   run the shipped Lua under stubbed battle objects
    py tools/build_lord_control.py              selftest, then pack it (needs RPFM open)

REJECTED 2026-10-08 (see docs/sessions/HANDOFF_20261008_THIRD_PERSON_LORD_CONTROL.md); the script lives
in source/ so a bulk add of pack/ cannot ship it. The selftest RUNS
`Modding Files/source/lord_control/derpy_lord_control.lua` under Lua 5.1.5
against stand-ins for bm, the camera, units and unitcontrollers, presses the keys through the
recorded ShortcutPressed listener, and asserts on the orders the script issued.
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "Modding Files", "source", "lord_control", "derpy_lord_control.lua")
PACK = os.path.join(ROOT, "Modding Files", "Modpacks", "derpy_lord_control.pack")
IN_PACK = "script/battle/mod/derpy_lord_control.lua"
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"
LUAC = r"C:\Program Files (x86)\Lua\5.1\luac.exe"

HARNESS = r'''
local MULTIPLAYER = arg[1] == "1"
local LOG, LISTENERS, REPEATS, LATER, PHASES = {}, {}, {}, {}, {}
local function near(a, b) return math.abs(a - b) < 0.001 end
local function vec(x, y, z)
  return {x = x, y = y, z = z, get_x = function(s) return s.x end, get_y = function(s) return s.y end,
          get_z = function(s) return s.z end}
end
battle_vector = {new = function(_, x, y, z) return vec(x or 0, y or 0, z or 0) end}
function out(msg) LOG[#LOG + 1] = msg end
SHORTCUTS = {}
common = {trigger_shortcut = function(name) SHORTCUTS[#SHORTCUTS + 1] = name end}

local function unit(name, x, z, opts)
  opts = opts or {}
  return {name = name, pos = vec(x, 0, z), men = 1, general = opts.general, visible = opts.visible ~= false,
    position = function(s) return s.pos end,
    number_of_men_alive = function(s) return s.men end,
    is_commanding_unit = function(s) return s.general == true end,
    is_valid_target = function(s) return true end,
    is_visible_to_alliance = function(s, a) assert(a.is_alliance, "needs an alliance object"); return s.visible end,
    select_in_ui = function(s) s.selected = true end}
end
local function list(items) return {count = function() return #items end, item = function(_, i) return items[i] end} end

GENERAL = unit("general", 100, 100, {general = true})
local OTHER = unit("spearmen", 90, 100)
UC = {orders = {}}
for _, f in ipairs({"goto_location", "attack_unit", "halt", "release_control", "add_units"}) do
  UC[f] = function(self, a, b, c) self.orders[#self.orders + 1] = {f, a, b, c} end
end
local MY_ARMY = {units = function() return list({OTHER, GENERAL}) end, create_unit_controller = function() return UC end}
ENEMIES = {}
local ALLIANCES = {
  {is_alliance = true, armies = function() return list({MY_ARMY}) end},
  {is_alliance = true, armies = function() return list({{units = function() return list(ENEMIES) end}}) end},
}
CAM = {p = vec(100, 50, 0), t = vec(100, 0, 100), moves = {}}  -- looking north (+z)
function CAM.position(s) return s.p end
function CAM.target(s) return s.t end
function CAM.move_to(s, p, t, time, linear, fov) s.moves[#s.moves + 1] = {p = p, t = t, time = time, fov = fov} end

bm = {
  is_multiplayer = function() return MULTIPLAYER end,
  camera = function() return CAM end,
  get_player_army = function() return MY_ARMY end,
  alliances = function() return list(ALLIANCES) end,
  local_alliance = function() return 1 end,
  repeat_callback = function(_, f, ms, name) REPEATS[name] = f end,
  remove_process = function(_, name) REPEATS[name] = nil end,
  callback = function(_, f, ms) LATER[#LATER + 1] = f end,
  register_phase_change_callback = function(_, phase, f) PHASES[phase] = f end,
}
core = {add_listener = function(_, name, event, cond, fn, persist)
  assert(event == "ShortcutPressed" and persist == true)
  LISTENERS[#LISTENERS + 1] = {cond = cond, fn = fn}
end}

local function press(key)
  local ctx = {string = key}
  for _, l in ipairs(LISTENERS) do if l.cond(ctx) then l.fn(ctx) end end
end
local function last(kind)
  for i = #UC.orders, 1, -1 do if UC.orders[i][1] == kind then return UC.orders[i], i end end
end
local function count(kind) local n = 0 for _, o in ipairs(UC.orders) do if o[1] == kind then n = n + 1 end end return n end

dofile(SCRIPT_PATH)

if MULTIPLAYER then
  assert(#LISTENERS == 0 and next(PHASES) == nil, "multiplayer: the script must register nothing")
  print("OK multiplayer")
  return
end

-- 1. keys do nothing during deployment
press("script_F2")
assert(not GENERAL.selected and #CAM.moves == 0, "F2 acted before Deployed")
PHASES.Deployed()

-- 2. F2 selects the general (not the first unit in the army) and puts the camera behind him
press("script_F2")
assert(GENERAL.selected and not OTHER.selected, "F2 did not select the general")
local m = CAM.moves[1]
assert(near(m.t.x, 100) and near(m.t.z, 100), "chase camera not aimed at the general")
assert(near(m.p.x, 100) and near(m.p.z, 70) and near(m.p.y, 14), "chase camera not 30m behind / 14m above")
assert(REPEATS.derpy_lord_control_cam, "no follow tick started")

-- 3. the follow tick slides the camera onto the general and keeps the player's offset
CAM.p, CAM.t = vec(80, 20, 90), vec(100, 0, 110)    -- the player turned and zoomed
GENERAL.pos = vec(130, 5, 140)                        -- and the general moved
REPEATS.derpy_lord_control_cam()
m = CAM.moves[#CAM.moves]
assert(near(m.t.x, 130) and near(m.t.y, 5) and near(m.t.z, 140), "follow target is not the general")
assert(near(m.p.x, 110) and near(m.p.y, 25) and near(m.p.z, 120), "follow lost the player's camera offset")
assert(m.fov < 0, "follow must keep the current field of view")

-- 4. F3 walks the general 25m along the camera's ground heading, running, then hands control back
CAM.p, CAM.t = vec(0, 40, 0), vec(30, 0, 40)          -- heading (0.6, 0.8)
press("script_F3")
local g, gi = last("goto_location")
assert(g and near(g[2].x, 145) and near(g[2].z, 160) and near(g[2].y, 5), "walk order not 25m along the camera heading")
assert(g[3] == true, "walk order should run")
assert((UC.orders[gi + 1] or {})[1] == "release_control", "walk order not released to the player")
assert(REPEATS.derpy_lord_control_walk, "no walk tick started")
REPEATS.derpy_lord_control_walk()
assert(count("goto_location") == 2, "walk tick did not re-issue the order")

-- 5. F4 attacks the nearest VISIBLE enemy in front, ignores a closer one behind, stops walking
local behind = unit("behind", 130, 135)               -- 5m away, behind the camera's heading
local hidden = unit("hidden", 136, 148, {visible = false}) -- 10m away, in front, not visible
local front_far = unit("front_far", 160, 180)          -- 50m away, in front
local front = unit("front", 142, 156)                  -- 20m away, in front
ENEMIES = {behind, hidden, front_far, front}
press("script_F4")
local a, ai = last("attack_unit")
assert(a and a[2] == front, "F4 attacked " .. tostring(a and a[2].name) .. ", wanted front")
assert((UC.orders[ai + 1] or {})[1] == "release_control", "attack not released to the player")
assert(not REPEATS.derpy_lord_control_walk and last("halt"), "F4 left walk running")

-- 6. with nothing in front, F4 falls back to the nearest enemy anywhere
ENEMIES = {unit("far_behind", 130, 100), behind}
press("script_F4")
assert(last("attack_unit")[2] == behind, "F4 fallback did not pick the nearest enemy")

-- 7. the general dies: the next follow tick turns lord mode off
press("script_F3")
GENERAL.men = 0
local orders_before = #UC.orders
REPEATS.derpy_lord_control_cam()
assert(not REPEATS.derpy_lord_control_cam and not REPEATS.derpy_lord_control_walk, "ticks survived the general's death")
assert(#UC.orders == orders_before, "orders were issued to a dead general")
press("script_F3")
assert(#UC.orders == orders_before, "F3 worked with lord mode off")

-- 8. Shift+F2 uses the game's tracking camera instead of the script one, and F2 turns it back off
GENERAL.men = 1
local moves_before = #CAM.moves
press("script_shift_F2")
assert(#SHORTCUTS == 0 and #LATER == 1, "tracking should wait for the selection to land")
LATER[1]()
assert(SHORTCUTS[1] == "toggle_tracking", "tracking camera not switched on")
assert(not REPEATS.derpy_lord_control_cam and #CAM.moves == moves_before, "script camera ran in tracking mode")
press("script_F2")
assert(SHORTCUTS[2] == "toggle_tracking", "tracking camera not switched back off")
print("OK singleplayer")
'''


def run_lua(multiplayer):
    with tempfile.TemporaryDirectory() as td:
        harness = os.path.join(td, "h.lua")
        open(harness, "w", encoding="utf-8").write(
            "SCRIPT_PATH = %s\n" % json.dumps(SCRIPT.replace("\\", "/")) + HARNESS)
        r = subprocess.run([LUA, harness, "1" if multiplayer else "0"], capture_output=True, text=True)
        if r.returncode != 0:
            raise AssertionError("lua failed: %s" % (r.stderr.strip() or r.stdout.strip()))
        return r.stdout.strip()


def _selftest():
    for cmd in ([LUAC, "-p", SCRIPT],
                [sys.executable, os.path.join(ROOT, "tools", "check_lua_api.py"), SCRIPT],
                [sys.executable, os.path.join(ROOT, "tools", "check_lua_literal_left.py"), SCRIPT],
                [sys.executable, os.path.join(ROOT, "tools", "check_lua_undeclared.py"), SCRIPT]):
        r = subprocess.run(cmd, capture_output=True, text=True)
        assert r.returncode == 0, "%s failed:\n%s%s" % (os.path.basename(cmd[-2]), r.stdout, r.stderr)
    print(run_lua(False))
    print(run_lua(True))


def pack():
    """Create or refresh derpy_lord_control.pack, then re-open the saved pack and look for the file."""
    import datetime
    import shutil
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    from check_skill_trees import _rpc, _call

    _selftest()
    _rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                        "clientInfo": {"name": "build_lord_control", "version": "1"}})
    _rpc("notifications/initialized", notify=True)
    _call("set_game_selected", {"game_name": "warhammer_3", "rebuild_dependencies": False})

    if os.path.exists(PACK):
        stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup = os.path.join(ROOT, "Modding Files", "Backup", "derpy_lord_control.pack.bak_" + stamp)
        os.makedirs(os.path.dirname(backup), exist_ok=True)
        shutil.copy2(PACK, backup)
        key = _call("open_packfiles", {"paths": [PACK]})["StringContainerInfo"][0]
    else:
        key = _call("new_pack", {})["String"]
        assert key, "new_pack returned no key"
        _call("set_pack_file_type", {"pack_key": key, "pack_file_type": '"Mod"'})

    _call("add_packed_files", {"pack_key": key, "source_paths": [SCRIPT],
                               "destination_paths": json.dumps([{"File": IN_PACK}])})
    _call("save_pack_as", {"pack_key": key, "path": PACK})

    again = _call("open_packfiles", {"paths": [PACK]})["StringContainerInfo"][0]
    files = _call("get_packed_files_info", {"pack_key": again, "values": [IN_PACK]})["VecRFileInfo"]
    assert any(e.get("path") == IN_PACK for e in files), "%s is not in the saved pack" % IN_PACK
    print("saved and verified %s" % PACK)


if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]:
        _selftest()
    elif not sys.argv[1:]:
        pack()
    else:
        sys.exit(__doc__)
