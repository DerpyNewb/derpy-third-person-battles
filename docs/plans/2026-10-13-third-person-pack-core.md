# Third-Person Battles, core pack - Implementation Plan (1 of 2)

**Current execution state, 2026-10-13:** read [the latest handoff](../../sessions/HANDOFF_20261013_THIRD_PERSON_HELD_FIRE_MOUNTED_IDLE.md) before resuming Tasks 13-16. Maintained source supersedes the original code listings below: no unconditional command-point writes, no movement nudges, no reload-factor timer, runtime animation support/completion, and one attack command to a mount. Bridge loading now uses 12 chunks plus run. F2 idle movement remains unresolved; latest experimental source is 106 tests passed/1 failed. No pack built or deployed.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the live probe `zz_follow_on.lua` into `derpy_third_person.pack`: F2 plays any unit from behind, with WASD movement, swings, hold-to-fire, one man of a regiment acting alone, ability keys 1-0, every key in MCT, and per-feature fallbacks when a patch moves an address.

**Architecture:** One auto-loaded entry file loads ten modules from `script/derpy_tp/`. `platform.lua` holds every address and memreader call; the others (`keys`, `settings`, `data`, `rig`, `move`, `combat`, `abilities`, `main`) talk to the game only through it and CA's documented API. An offline harness runs the shipped modules under Lua 5.1.5 against a stubbed battle and a fake platform. Live checks go through the wh3-mcp bridge.

**Tech Stack:** Lua 5.1.5 (the game's), memreader Plus (Workshop 3811098873), MCT (Workshop 2927955021), Python 3 tools, RPFM's MCP server for packing.

**Spec:** `docs/superpowers/specs/2026-10-13-third-person-pack-design.md`. Read it with this plan. The prototype is `Modding Files/source/lord_control/probes/zz_follow_on.lua`; its findings are in `docs/sessions/HANDOFF_20261008_THIRD_PERSON_LORD_CONTROL.md` §8-§9j.

**Scope.** This plan builds spec sections 4-6, 8 and 9, plus the section 10 measurements those sections need. **Plan 2** is written after this plan's Task 1 and Task 16. It covers:
- spec section 7: the hotbar, health, mode and ammo panel beside CA's porthole, its preview tool and its HUD tests;
- spec §10.7, ability target kind and cooldown from CA's context objects, which the hotbar reads too.

Until plan 2 lands, ability keys work but nothing on screen lists them, and a modded ability casts on itself.

**Where this plan departs from the spec, on purpose:**
- **More files.** Spec §4 names four modules. Here `main.lua`'s gameplay is split into `keys`, `settings`, `rig`, `move`, `combat` and `abilities`, so each piece is tested alone and no function nears 60 upvalues.
- **Mouse API.** The platform's `mouse_delta()` becomes `look_begin()` + `look_delta()`: the cursor is parked once, then read.
- **Focus.** Focus means "the foreground window belongs to this process" (`GetWindowThreadProcessId` against `GetCurrentProcessId`, both imported). It is not compared against a window captured at load, which breaks when the battle loads while the game is in the background.
- **Key conflicts.** Spec §5 says a duplicate key is reported "on the MCT page and in the script log". Here each key's MCT tooltip states the rule, and the actual conflict goes to the script log once. A live MCT validation hook is not in CA's docs or this workspace, so it is left out until one is found.

**No git.** This workspace is not a git repository. Each task ends with the selftest green in place of a commit.

## Global Constraints

- Lua is **5.1.5**. Every shipped file passes `luac -p`, `py tools/check_lua_api.py <file>` and `py tools/check_lua_literal_left.py <file>`.
- **No function may have more than 60 upvalues** (Lua 5.1); the probe hit this on 2026-10-13.
- **No `string.find` with a plain flag or an init argument** in shipped code: one call breaks `string.sub`/`find` game-wide.
- **`SetVisible` takes a real boolean only.** `SetVisible(nil)` corrupts strings. Coerce with `x and true or false`.
- **No backslashes in any shipped `.lua` file**: the bridge loader cannot carry them.
- **Pack paths are lowercase** (since 6.1 an uppercase path crashes the game).
- **memreader passes a plain number through float32**, exact only below 2^24. Any larger offset or RVA goes through `split()` in `platform.lua`.
- **Move orders at least 0.5 s apart** (`STEER_GAP`): orders closer than 0.4 s stall a unit.
- **Every one-shot timer gets a unique id.** CA frees a one-shot's id before running it.
- **Faction, unit and ability keys fail silently.** Every key in tests comes from `db.pack` through `data.lua`.
- Player text, in MCT and in loc, is plain words: no "HUD", "AI" or "cap", and no emojis anywhere.
- The pack is `derpy_third_person.pack`. Backups go to `Modding Files/Backup/`, never `data/` or a Workshop folder. A new pack goes to `data/` only while the game is shut.

## Review Focus

1. **The regiment drops to one man while he shoots alone.** The regiment's fire-at-will comes back at once and he plays as a single entity. Pinned by `solo_regiment_down_to_one_restores_fire` (Task 10).
2. **The played man dies between his fire animation and the launch.** No projectile, no ammo taken, and the next front-centre man takes over. Pinned by `solo_dead_man_launches_nothing` (Task 10).
3. **The window loses focus while W or fire is held.** Walking stops, the committed shot finishes, and no order is left running. Pinned by `focus_loss_halts_walking` (Task 8) and `ground_fire_stops_on_focus_loss` (Task 9).
4. **A rebinding whose fallback default is also taken.** That action is left unbound and reported; nothing errors and every other key works. Pinned by `settings_default_taken_leaves_unbound` (Task 2).
5. **Ammo runs out while fire is held.** Shots stop at zero, ammo never goes negative, and the unit stays in ranged mode. Pinned by `solo_ammo_runs_out` (Task 10).

---

## File map

| Path | Role | Task |
|---|---|---|
| `Modding Files/source/third_person/script/battle/mod/derpy_third_person.lua` | entry: guards, loads modules in order | 8 |
| `.../script/derpy_tp/keys.lua` | key names to virtual-key codes, the 21 actions, defaults, labels | 2 |
| `.../script/derpy_tp/settings.lua` | MCT (or defaults) to one settings table, with conflict handling | 2 |
| `.../script/mct/settings/derpy_third_person.lua` | the MCT page | 3 |
| `.../script/derpy_tp/data.lua` | GENERATED: unit type to projectile, ability to target kind | 4 |
| `.../script/derpy_tp/platform.lua` | every address, offset and memreader call | 6 |
| `.../script/derpy_tp/rig.lua` | camera maths | 7 |
| `.../script/derpy_tp/move.lua` | walking: orders, or one man steered alone | 8 |
| `.../script/derpy_tp/main.lua` | toggle, start/stop/restore, per-frame loop, errors | 8 |
| `.../script/derpy_tp/combat.lua` | swings, ground fire, solo shot, crosshair, Manual fire | 9-11 |
| `.../script/derpy_tp/abilities.lua` | ability keys | 12 |
| `tools/build_third_person.py` | `--gen`, `--selftest`, `--bridge`, pack | 2, 4, 13, 16 |
| `tools/third_person_harness.lua` | stubbed battle + fake platform | 2 |
| `tools/third_person_tests.lua` | the offline tests | 2-12 |
| `tools/third_person_patterns.py` | checks the command pattern against the exe on disk | 5 |

`...` is `Modding Files/source/third_person`.

---

### Task 1: Measure hiding the cursor without cinematic UI (spec §10.1)

The probe hides the cursor with `bm:enable_cinematic_ui`, which also hides CA's HUD. The exe imports, on build `0x6ac6d907`, with IAT RVAs read off the exe on disk on 2026-10-13:
- `SetCursor` (`0x33a2bc0`);
- `ShowCursor` (`0x33a2c10`);
- `GetCursorInfo` (`0x33a2b20`).

Two routes, tried in this order:
- **`setcursor`:** `SetCursor(NULL)` every frame while looking. It holds no state: when we stop, the game's next `WM_SETCURSOR` draws its cursor again, so a battle that ends or is quit mid-look leaves nothing behind. Its risk is flicker, because the game may set its cursor between our calls.
- **`showcursor`:** `ShowCursor(FALSE)` until the display count is below 0. It is stateful: if the battle ends while the cursor is hidden, the count may stay negative into the campaign or menu, and the player has no cursor.

This task decides `CURSOR_ROUTE` in `platform.lua` (Task 6).

**Files:**
- Create: `Modding Files/source/lord_control/probes/zz_cursor.lua`
- Modify: `docs/sessions/HANDOFF_20261008_THIRD_PERSON_LORD_CONTROL.md` (new §9k)

**Interfaces:** Produces one value for Task 6: `CURSOR_ROUTE = "setcursor"`, `"showcursor"` or `"cinematic"`.

- [ ] **Step 1: Write the probe**

Needs a running battle, F2 off. Run `py send.py zz_follow_off.lua 8` first if the old probe is loaded.

```lua
-- spike: can the game's cursor be hidden without cinematic UI (which hides CA's HUD too)?
-- ROUTE "setcursor": SetCursor(NULL) every frame for SECONDS. Nothing to undo: the game sets its own again.
-- ROUTE "showcursor": ShowCursor(FALSE) until the count is below 0, put back after SECONDS.
-- Both sample GetCursorInfo (flags 1 = showing; hCursor null = no picture) every 6th frame into _G.DERPY_CURSOR.
-- IAT RVAs of build 0x6ac6d907, read off the exe on disk; a probe may hard-code them, the pack may not.
local ROUTE, SECONDS = "setcursor", 5
local IAT_HI, SETCURSOR, SHOWCURSOR, GETCURSORINFO = 0x3300000, 0xa2bc0, 0xa2c10, 0xa2b20
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local function iat(lo) return mr.read_pointer(mr.add(mr.add(mr.base, IAT_HI), lo)) end
	local set, show, info = iat(SETCURSOR), iat(SHOWCURSOR), iat(GETCURSORINFO)
	local ci = mr.alloc(24) -- CURSORINFO: cbSize, flags, hCursor at 8, ptScreenPos at 16
	local T = {route = ROUTE, flags = {}, null_cursor = {}}
	_G.DERPY_CURSOR = T
	if ROUTE == "showcursor" then
		local n = mr.tonumber(mr.call(show, "int32(int32)", 0))
		while n >= 0 do n = mr.tonumber(mr.call(show, "int32(int32)", 0)) end
		T.after_hide = n
	end
	local t0, frame = os.clock(), 0
	bm:remove_real_callback("derpy_cursor")
	bm:repeat_real_callback(function()
		frame = frame + 1
		if ROUTE == "setcursor" then mr.call(set, "pointer(pointer)", nil) end
		if frame % 6 == 0 and #T.flags < 60 then
			mr.write(ci, 0, mr.uint32(24))
			mr.call(info, "int32(pointer)", ci)
			T.flags[#T.flags + 1] = mr.read_int32(ci, 4)
			T.null_cursor[#T.null_cursor + 1] = mr.is_null(mr.read_pointer(ci, 8)) and 1 or 0
		end
		if os.clock() - t0 > SECONDS then
			bm:remove_real_callback("derpy_cursor")
			if ROUTE == "showcursor" then
				local m = mr.tonumber(mr.call(show, "int32(int32)", 1))
				while m < 0 do m = mr.tonumber(mr.call(show, "int32(int32)", 1)) end
				T.after_show = m
			end
			T.done = true
		end
	end, 1, "derpy_cursor")
	return {route = ROUTE}
end)
if ok then return res end
return "ERR " .. tostring(res)
```

- [ ] **Step 2: Run `setcursor`; the author moves the mouse around the battle for the 5 s**

Run: `cd "Modding Files/source/lord_control/probes"; py send.py zz_cursor.lua 8`. Six seconds later, read `_G.DERPY_CURSOR` with a one-line probe.
Expected: `done` true, and `null_cursor` mostly 1. Ask the author two things:
- whether the cursor was gone the whole time, with no flicker while the mouse moved;
- whether CA's HUD stayed drawn.

- [ ] **Step 3: Only if `setcursor` flickered or failed, run `showcursor`**

Set `ROUTE = "showcursor"` and re-run Step 2. `after_hide` should be negative and `after_show` 0 or more.

Then the quit test. Set `SECONDS = 60`, re-send, and within the minute the author quits the battle to the menu (or the campaign). Ask whether the menu has a cursor.

- [ ] **Step 4: Decide**

| Measured | `CURSOR_ROUTE` |
|---|---|
| `setcursor`: gone for the 5 s, no flicker, HUD drawn | `"setcursor"` |
| `setcursor` flickers; `showcursor`: gone, back after, HUD drawn, and the menu after a mid-hide quit has a cursor | `"showcursor"` |
| Anything else (flicker, or a quit that leaves the menu without a cursor) | `"cinematic"`. Record that plan 2's HUD is hidden while looking and needs another route |

- [ ] **Step 5: Record it**

Add §9k to the handoff: the probe, the samples, the author's observations and the chosen route. Add one line to `docs/SESSION_INDEX.md` under the third-person entry. Write a memory file for the result: `wh3-hide-cursor-route`, type reference, linked from `index-ui.md`.

---

### Task 2: Harness, keys and settings

**Files:**
- Create: `tools/third_person_harness.lua`, `tools/third_person_tests.lua`, `tools/build_third_person.py`
- Create: `Modding Files/source/third_person/script/derpy_tp/keys.lua`, `.../settings.lua`

**Interfaces:**
- Produces `keys.lua`, which returns `K = {names = {string...}, vk = {name -> int or {int, int}}, order = {21 actions}, defaults = {action -> name}, labels = {action -> text}}`.
- Produces `settings.lua`, which returns `function(mct, K) -> S`, where `S = {keys = {action -> vk or nil}, names = {action -> name}, conflicts = {{action, key, taken_by, now}}, sensitivity, invert_y, distance, shoulder (1 or -1), zoom_rate, swing_cooldown, one_man, reload_factor, debug}`.
- Produces harness globals `H.fresh(opts)`, `H.step(s)`, `H.down/up/tap(name)`, `H.count/all/last(call)`, `check(cond, msg)`, `near(a, b, tol)`.

- [ ] **Step 1: Write the harness**

`tools/third_person_harness.lua`:

```lua
-- Offline harness for derpy_third_person: CA's battle environment stubbed far enough to load the
-- SHIPPED modules and record what they do, with a fake platform layer in place of memreader.
--   lua.exe tools/third_person_harness.lua <source root> <tests file> [one test name]
-- Prints "ok <name>" or "FAIL <name>: <why>" per test and exits 1 on any failure. Not shipped.
local ROOT, TESTS, ONLY = arg[1], arg[2], arg[3]
local real_loadfile = loadfile
H = {}

local function file(rel) return ROOT .. "/" .. rel .. ".lua" end
H.file = file

-- recording ----------------------------------------------------------------------------------------
local function rec(...) H.calls[#H.calls + 1] = {...} end
H.rec = rec
function H.all(name) local t = {} for _, c in ipairs(H.calls) do if c[1] == name then t[#t + 1] = c end end return t end
function H.count(name) return #H.all(name) end
function H.last(name) local t = H.all(name) return t[#t] end
function check(cond, msg) if not cond then error(msg or "check failed", 2) end end
function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-3) end

-- the game's module loader: /script/derpy_tp/<name> resolves into the source tree; the platform is
-- the fake below unless a test asks for the real file
function loadfile(path)
	local name = path:match("^/script/derpy_tp/(.+)$")
	if name == "platform" and not H.real_platform then
		return function()
			return {build = function() return H.P end,
				split = function(n) local lo = n % 0x10000 return n - lo, lo end}
		end
	end
	if name then return real_loadfile(file("script/derpy_tp/" .. name)) end
	return real_loadfile(path)
end

-- vectors ------------------------------------------------------------------------------------------
local VEC = {}
VEC.__index = VEC
function v(x, y, z) return setmetatable({x = x, y = y, z = z}, VEC) end
function VEC:get_x() return self.x end
function VEC:get_y() return self.y end
function VEC:get_z() return self.z end
function VEC:distance_xz(o) return math.sqrt((self.x - o.x) ^ 2 + (self.z - o.z) ^ 2) end

-- units --------------------------------------------------------------------------------------------
local UNIT = {}
UNIT.__index = UNIT
function UNIT:position() if self._error then error("test: position() failed") end return v(self._x, 0, self._z) end
function UNIT:bearing() return self._bearing end
function UNIT:type() return self._type end
function UNIT:name() return self._type end
function UNIT:unique_ui_id() return self._id end
function UNIT:is_commanding_unit() return self._general end
function UNIT:is_infantry() return not self._arty end
function UNIT:is_artillery() return self._arty end
function UNIT:missile_range() return self._range end
function UNIT:ammo_left() return self._ammo end
function UNIT:starting_ammo() return self._start_ammo end
function UNIT:set_current_ammo_unary(u) rec("set_ammo", self._id, u) self._ammo = math.floor(u * self._start_ammo + 0.5) end
function UNIT:number_of_men_alive() local n = 0 for _, m in ipairs(self._models) do if m.alive ~= false then n = n + 1 end end return n end
function UNIT:is_routing() return self._routing end
function UNIT:is_valid_target() return true end
function UNIT:ordered_width() return 20 end
function UNIT:select_in_ui() rec("select_in_ui", self._id) end
function UNIT:owned_non_passive_special_abilities() return self._abilities end
function UNIT:can_perform_special_ability(key) return self._can[key] ~= false end

local next_id = 0
-- o: type, men, x, z, bearing, range, ammo, start_ammo, arty, general, abilities, can, men_ok, enemy
function H.unit(o)
	next_id = next_id + 1
	local u = setmetatable({_type = o.type or "wh_test_unit", _x = o.x or 0, _z = o.z or 0, _bearing = o.bearing or 0,
		_range = o.range or 0, _ammo = o.ammo or 0, _start_ammo = o.start_ammo or o.ammo or 0, _arty = o.arty or false,
		_general = o.general or false, _abilities = o.abilities or {}, _can = o.can or {}, _routing = false,
		_id = next_id, _models = {}, _men_ok = o.men_ok}, UNIT)
	local men = o.men or 1
	for i = 1, men do -- one rank along x, centred on the unit, facing +z (bearing 0)
		u._models[i] = {id = next_id * 1000 + i, x = u._x + (i - (men + 1) / 2), y = 0, z = u._z}
	end
	local list = o.enemy and H.enemies or H.units
	list[#list + 1] = u
	return u
end
local function listof(items) return {count = function() return #items end, item = function(_, i) return items[i] end} end

-- unit controllers record every call as "uc:<method>", unit id, args
local UC = {}
UC.__index = function(self, name)
	return function(_, ...)
		rec("uc:" .. name, self._u._id, ...)
		if name == "fire_at_will" then self._u._faw = (...) end
	end
end
function create_unitcontroller(u) return setmetatable({_u = u}, UC) end

-- the battle manager --------------------------------------------------------------------------------
local function make_bm()
	local B = {}
	function B:repeat_real_callback(fn, ms, id) H.timers[id] = {fn = fn, at = H.T + ms / 1000, every = ms / 1000} end
	function B:real_callback(fn, ms, id) H.timers[id] = {fn = fn, at = H.T + ms / 1000} end
	function B:remove_real_callback(id) H.timers[id] = nil end
	function B:camera() return H.cam end
	function B:disable_orders(b) rec("disable_orders", b) end
	function B:enable_cinematic_ui(a, b, c) rec("cinematic_ui", a, b, c) end
	function B:is_multiplayer() return H.mp end
	function B:is_replay() return H.replay end
	function B:show_subtitle(key, full, force) rec("subtitle", key, full, force) end
	function B:hide_subtitles() rec("hide_subtitles") end
	function B:trigger_projectile_launch(key, from, to) rec("launch", key, from, to) end
	function B:register_phase_change_callback(name, fn) H.phase[name] = fn end
	function B:register_unit_selection_callback(u, fn) H.selection_cbs[#H.selection_cbs + 1] = {u, fn} end
	function B:num_units_selected() return H.selected and 1 or 0 end
	function B:get_player_army() return {units = function() return listof(H.units) end} end
	function B:get_player_alliance() return {armies = function() return listof({B:get_player_army()}) end} end
	function B:get_non_player_alliance()
		return {armies = function() return listof({{units = function() return listof(H.enemies) end}}) end}
	end
	return B
end
function H.select(u)
	H.selected = u
	for _, cb in ipairs(H.selection_cbs) do if cb[1] == u then cb[2](u, true) end end
end

-- UI: components with ids and children; SetVisible refuses a non-boolean the way the game should
local COMP = {}
COMP.__index = COMP
local function comp(id, parent)
	local c = setmetatable({id = id, kids = {}, visible = true, x = 0, y = 0}, COMP)
	if parent then parent.kids[#parent.kids + 1] = c end
	return c
end
H.comp = comp
function COMP:CreateComponent(id, path)
	local c = comp(id, self)
	if path == "ui/battle ui/first_person_ui" then comp("controls_text_frame", c) comp("bl_frame", c) comp("crosshair", c) end
	return c
end
function COMP:SetVisible(b)
	if type(b) ~= "boolean" then error("SetVisible(" .. tostring(b) .. "): a non-boolean corrupts the game's strings") end
	self.visible = b
end
function COMP:Visible() return self.visible end
function COMP:ChildCount() return #self.kids end
function COMP:Find(i) return self.kids[i + 1] end
function COMP:Id() return self.id end
function COMP:Dimensions() return 32, 32 end
function COMP:MoveTo(x, y) self.x, self.y = x, y end
function COMP:SimulateLClick() rec("click", self.id) end
function UIComponent(c) return c end
function find_uicomponent(root, ...)
	local function find(c, name)
		if c.id == name then return c end
		for _, k in ipairs(c.kids) do local f = find(k, name) if f then return f end end
	end
	local c = root
	for _, name in ipairs({...}) do c = c and find(c, name) end
	return c
end
core = {get_env = function() return _G end, get_ui_root = function() return H.root end,
	get_screen_resolution = function() return 1920, 1080 end}
function out(msg) H.log[#H.log + 1] = tostring(msg) end
function H.logged(text) for _, l in ipairs(H.log) do if l:find(text, 1, true) then return true end end return false end

-- MCT: {option key -> finalized value}
function H.mct_stub(values)
	local mod = {get_option_by_key = function(_, key)
		if values[key] == nil then return nil end
		return {get_finalized_setting = function() return values[key] end}
	end}
	return {get_mod_by_key = function(_, k) if k == "derpy_third_person" then return mod end end}
end

-- the fake platform: same interface as platform.lua's build(), driven by H.keys, H.focus, H.mouse
local function fake_platform()
	local P = {features = {}, problems = {}, build = 0x6ac6d907}
	for k, val in pairs(H.features) do P.features[k] = val end
	if not P.features.input then P.problems[1] = "input: test" return P end
	local was = {}
	function P.focused() return H.focus end
	function P.held(vk)
		if vk == nil then return false end
		if type(vk) == "table" then for _, k in ipairs(vk) do if H.keys[k] then return true end end return false end
		return H.keys[vk] == true
	end
	function P.pressed(vk)
		if vk == nil then return false end
		local key = type(vk) == "table" and vk[1] or vk
		local d = P.held(vk)
		local edge = d and not was[key]
		was[key] = d
		return edge
	end
	function P.look_begin() rec("look_begin") end
	function P.look_delta() local dx, dy = H.mouse[1], H.mouse[2] H.mouse = {0, 0} return dx, dy end
	if H.cursor_route then function P.cursor(show) rec("cursor", show) end end
	function P.check_anim()
		if H.features.anim then return true end
		P.features.anim = false
		return false, "test: anim off"
	end
	function P.open_wheel()
		if not H.features.wheel then P.features.wheel = false return false, "test: wheel off" end
		function P.wheel() local n = H.wheel_notches H.wheel_notches = 0 return n end
		return true
	end
	function P.models(unit) local t = {} for _, m in ipairs(unit._models) do if m.alive ~= false then t[#t + 1] = m end end return t end
	function P.model_pos(m) return m.x, m.y, m.z end
	function P.place(m, x, z) rec("place", m.id, x, z) m.x, m.z = x, z end
	function P.steer(m, x, z) rec("steer", m.id, x, z) end
	function P.play(m, slot) rec("play", m.id, slot) return true end
	function P.alive(unit, m) return m.alive ~= false end
	function P.same(a, b) return a == b end
	function P.check_men(unit) if unit._men_ok == false then return false, "test: men off" end return true end
	return P
end

-- clock and timers: 60 frames a second; a one-shot's id is freed before it runs, as CA's is
os.clock = function() return H.T end
function H.step(seconds)
	for _ = 1, math.max(1, math.floor(seconds * 60 + 0.5)) do
		H.T = H.T + 1 / 60
		local due = {}
		for id, t in pairs(H.timers) do if H.T >= t.at - 1e-9 then due[#due + 1] = id end end
		table.sort(due)
		for _, id in ipairs(due) do
			local t = H.timers[id]
			if t then
				if t.every then t.at = H.T + t.every else H.timers[id] = nil end
				t.fn()
			end
		end
	end
end

-- keys by MCT name
local function code(name) local c = H.K.vk[name] if type(c) == "table" then return c[1] end return c end
function H.down(name) H.keys[code(name)] = true end
function H.up(name) H.keys[code(name)] = nil end
function H.tap(name) H.down(name) H.step(1 / 60) H.up(name) H.step(1 / 60) end

-- a fresh battle with the mod loaded. opts: units, enemies, mct, memreader, mp, replay, features, cursor_route
function H.fresh(opts)
	opts = opts or {}
	H.K = assert(real_loadfile(file("script/derpy_tp/keys")))()
	H.T, H.calls, H.timers, H.keys, H.focus, H.mouse, H.wheel_notches = 100, {}, {}, {}, true, {0, 0}, 0
	H.log, H.phase, H.selection_cbs, H.selected = {}, {}, {}, nil
	H.units, H.enemies, next_id = {}, {}, 0 -- ids restart, so the second unit's men are 2001, 2002...
	H.mp, H.replay = opts.mp or false, opts.replay or false
	H.features = opts.features or {input = true, anim = true, wheel = true}
	H.cursor_route = opts.cursor_route
	H.root = comp("root")
	H.eye, H.look = nil, nil
	H.cam = {
		move_to = function(_, eye, look) H.eye, H.look = eye, look end,
		enable_functionality = function(_, name, on) rec("camera_functions", name, on) end,
		position = function() return H.eye or v(0, 0, 0) end,
	}
	math.randomseed(1)
	get_mct = opts.mct and function() return H.mct_stub(opts.mct) end or nil
	_G.memreader_plus = opts.memreader ~= false and {} or nil
	_G.DERPY_TP, _G.DERPY_TP_SELECTED = nil, nil
	bm = make_bm()
	for _, o in ipairs(opts.units or {{general = true}}) do H.unit(o) end
	for _, o in ipairs(opts.enemies or {}) do o.enemy = true H.unit(o) end
	H.P = fake_platform()
	if real_loadfile(file("script/battle/mod/derpy_third_person")) then
		dofile(file("script/battle/mod/derpy_third_person"))
	end
	H.E = _G.DERPY_TP
	H.step(1 / 60)
end

-- run -----------------------------------------------------------------------------------------------
H.K = assert(real_loadfile(file("script/derpy_tp/keys")))()
local T = assert(real_loadfile(TESTS))()
local names = {}
for name in pairs(T) do if not ONLY or name == ONLY then names[#names + 1] = name end end
table.sort(names)
local failed = 0
for _, name in ipairs(names) do
	local ok, err = pcall(T[name])
	if ok then print("ok   " .. name) else failed = failed + 1 print("FAIL " .. name .. ": " .. tostring(err)) end
end
print((#names - failed) .. " passed, " .. failed .. " failed")
os.exit(failed == 0 and 0 or 1)
```

- [ ] **Step 2: Write the first tests**

`tools/third_person_tests.lua`:

```lua
-- Offline tests for derpy_third_person, run by tools/third_person_harness.lua (see that file).
-- Each test builds what it needs; later tasks add tests above the final `return T`.
local T = {}

local function settings_with(values)
	local settings = assert(loadfile("/script/derpy_tp/settings"))()
	return settings(values and H.mct_stub(values) or nil, H.K)
end

T.settings_defaults_without_mct = function()
	local S = settings_with(nil)
	check(S.keys.toggle == 0x71, "toggle is F2")
	check(S.keys.forward == 0x57 and S.keys.back == 0x53, "W and S")
	check(type(S.keys.zoom_in) == "table" and S.keys.zoom_in[1] == 0xBB and S.keys.zoom_in[2] == 0x6B, "+ is both plus keys")
	check(S.keys.ability_10 == 0x30, "ability 10 is 0")
	check(#S.conflicts == 0, "no conflicts by default")
	check(near(S.sensitivity, 0.004) and near(S.reload_factor, 0.25) and S.one_man == true, "numbers")
	check(S.shoulder == 1 and S.distance == 6 and near(S.swing_cooldown, 1.5), "camera and swing")
end

T.settings_reads_mct = function()
	local S = settings_with({key_forward = "Up", camera_sensitivity = 8, camera_shoulder = "left", combat_one_man = false})
	check(S.keys.forward == 0x26, "forward rebound to Up")
	check(near(S.sensitivity, 0.008), "sensitivity 8 -> 0.008")
	check(S.shoulder == -1 and S.one_man == false, "shoulder and one man")
end

T.settings_duplicate_falls_back = function()
	local S = settings_with({key_back = "W"})
	check(S.keys.back == 0x53, "back keeps its default S")
	local c = S.conflicts[1]
	check(c and c.action == "back" and c.key == "W" and c.taken_by == "forward" and c.now == "S", "conflict reported")
end

T.settings_default_taken_leaves_unbound = function()
	local S = settings_with({key_forward = "S"})
	check(S.keys.forward == 0x53, "forward took S")
	check(S.keys.back == nil, "back's choice and its default are both S, so it is unbound")
	local c = S.conflicts[1]
	check(c and c.action == "back" and c.now == nil, "reported as unbound")
	check(S.keys.left == 0x41 and S.keys.attack == 0x01, "the others still work")
end

T.settings_unknown_name_uses_default = function()
	local S = settings_with({key_attack = "Nonsense"})
	check(S.keys.attack == 0x01, "attack falls back to Left mouse")
	check(#S.conflicts == 0, "an unknown name is not a conflict")
end

return T
```

- [ ] **Step 3: Write the build tool's selftest**

`tools/build_third_person.py`:

```python
"""Build and check derpy_third_person.pack - third-person battle control.

    py tools/build_third_person.py --gen        write script/derpy_tp/data.lua from db.pack (RPFM may be shut)
    py tools/build_third_person.py --selftest   compile checks, the Lua harness, data.lua and the loc keys
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
        if rel != rel.lower():
            bad.append("uppercase in a pack path crashes the game since 6.1: %s" % rel)
        if "\\" in open(full, encoding="utf-8").read():
            bad.append("a backslash cannot cross the bridge loader: %s" % rel)
    tools = os.path.join(ROOT, "tools")
    for tool in ("check_lua_api.py", "check_lua_literal_left.py"):
        r = subprocess.run([sys.executable, os.path.join(tools, tool)] + [f for f, _ in files],
                           capture_output=True, text=True)
        if r.returncode:
            bad.append("%s:\n%s" % (tool, r.stdout.strip()))
    if not run_harness(only):
        bad.append("the Lua harness reported failures")
    for b in bad:
        print("FINDING: %s" % b)
    return not bad


def main(argv):
    if argv[:1] == ["--selftest"]:
        return 0 if selftest(argv[1] if len(argv) > 1 else None) else 1
    raise SystemExit("usage: build_third_person.py --gen | --selftest [test] | --bridge | (no flag: pack)")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 4: Run it to see it fail**

Run: `py tools/build_third_person.py --selftest`
Expected: the harness errors at `H.K = assert(real_loadfile(...keys...))` (no `keys.lua` yet). Exit 1.

- [ ] **Step 5: Write `keys.lua`**

```lua
-- The keys the MCT page offers, their Windows virtual-key codes, and the 21 actions with their
-- defaults and labels. The MCT page and the battle script both loadfile this, so they cannot
-- disagree. A name can stand for two keys: "+" is the main-row plus and the numpad plus.
local K = {names = {}, vk = {}}

local function add(name, code) K.names[#K.names + 1] = name K.vk[name] = code end
local function run(names, first) for i = 1, #names do add(names[i], first + i - 1) end end

add("Left mouse", 0x01) add("Right mouse", 0x02) add("Middle mouse", 0x04) add("Mouse 4", 0x05) add("Mouse 5", 0x06)
run({"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W",
	"X", "Y", "Z"}, 0x41)
run({"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}, 0x30)
run({"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"}, 0x70)
run({"Numpad 0", "Numpad 1", "Numpad 2", "Numpad 3", "Numpad 4", "Numpad 5", "Numpad 6", "Numpad 7", "Numpad 8",
	"Numpad 9"}, 0x60)
add("Shift", 0x10) add("Ctrl", 0x11) add("Alt", 0x12) add("Space", 0x20) add("Tab", 0x09) add("Caps Lock", 0x14)
add("Enter", 0x0D) add("Backspace", 0x08) add("Insert", 0x2D) add("Delete", 0x2E) add("Home", 0x24) add("End", 0x23)
add("Page Up", 0x21) add("Page Down", 0x22) add("Up", 0x26) add("Down", 0x28) add("Left", 0x25) add("Right", 0x27)
add("+", {0xBB, 0x6B}) add("-", {0xBD, 0x6D})

K.order = {"toggle", "forward", "back", "left", "right", "run", "look_free", "attack", "mode", "zoom_in", "zoom_out",
	"ability_1", "ability_2", "ability_3", "ability_4", "ability_5", "ability_6", "ability_7", "ability_8", "ability_9",
	"ability_10"}

K.defaults = {toggle = "F2", forward = "W", back = "S", left = "A", right = "D", run = "Shift",
	look_free = "Middle mouse", attack = "Left mouse", mode = "Right mouse", zoom_in = "+", zoom_out = "-",
	ability_1 = "1", ability_2 = "2", ability_3 = "3", ability_4 = "4", ability_5 = "5", ability_6 = "6",
	ability_7 = "7", ability_8 = "8", ability_9 = "9", ability_10 = "0"}

K.labels = {toggle = "Third person on and off", forward = "Walk forward", back = "Walk back", left = "Walk left",
	right = "Walk right", run = "Run (press to switch)", look_free = "Free the mouse while held",
	attack = "Attack and fire", mode = "Melee or ranged; artillery aiming", zoom_in = "Zoom in", zoom_out = "Zoom out",
	ability_1 = "Ability 1", ability_2 = "Ability 2", ability_3 = "Ability 3", ability_4 = "Ability 4",
	ability_5 = "Ability 5", ability_6 = "Ability 6", ability_7 = "Ability 7", ability_8 = "Ability 8",
	ability_9 = "Ability 9", ability_10 = "Ability 10"}

return K
```

- [ ] **Step 6: Run it to see the settings tests fail**

Run: `py tools/build_third_person.py --selftest`
Expected: 5 tests `FAIL ... cannot open .../settings.lua` (or similar). Exit 1.

- [ ] **Step 7: Write `settings.lua`**

```lua
-- One session's settings, read again at every toggle: MCT's finalized values, or the defaults when MCT
-- is absent or an option is missing. return function(mct, K) -> S.
-- Two actions on one key: the later one falls back to its own default; when that default is taken too,
-- the action stays unbound. Each case goes into S.conflicts, and main.lua logs it once.
return function(mct, K)
	local mod = mct and mct:get_mod_by_key("derpy_third_person")
	local function get(key, default)
		local o = mod and mod:get_option_by_key(key)
		local val
		if o then val = o:get_finalized_setting() end
		if val == nil then return default end
		return val
	end
	local S = {keys = {}, names = {}, conflicts = {}}
	local owner = {}
	for _, action in ipairs(K.order) do
		local name = get("key_" .. action, K.defaults[action])
		if K.vk[name] == nil then name = K.defaults[action] end
		if owner[name] then
			local fallback = K.defaults[action]
			local now = not owner[fallback] and fallback or nil
			S.conflicts[#S.conflicts + 1] = {action = action, key = name, taken_by = owner[name], now = now}
			name = now
		end
		if name then
			owner[name] = action
			S.names[action], S.keys[action] = name, K.vk[name]
		end
	end
	S.sensitivity = get("camera_sensitivity", 4) / 1000
	S.invert_y = get("camera_invert_y", false) == true
	S.distance = get("camera_distance", 6)
	S.shoulder = get("camera_shoulder", "right") == "left" and -1 or 1
	S.zoom_rate = get("camera_zoom_speed", 12) / 10
	S.swing_cooldown = get("combat_swing_cooldown", 15) / 10
	S.one_man = get("combat_one_man", true) == true
	S.reload_factor = get("combat_reload_factor", 25) / 100
	S.debug = get("debug_log", false) == true
	return S
end
```

- [ ] **Step 8: Run the tests to see them pass**

Run: `py tools/build_third_person.py --selftest`
Expected: `5 passed, 0 failed`, no `FINDING`, exit 0.

---

### Task 3: The MCT page

**Files:**
- Create: `Modding Files/source/third_person/script/mct/settings/derpy_third_person.lua`
- Modify: `tools/third_person_tests.lua` (add above `return T`)

**Interfaces:** Consumes `keys.lua` (`K.names`, `K.order`, `K.defaults`, `K.labels`). Produces the option keys `settings.lua` reads: `key_<action>`, `camera_sensitivity`, `camera_invert_y`, `camera_distance`, `camera_shoulder`, `camera_zoom_speed`, `combat_swing_cooldown`, `combat_one_man`, `combat_reload_factor`, `debug_log`.

- [ ] **Step 1: Write the failing tests**

Add above `return T`:

```lua
-- an MCT that records what the page registers
local function recording_mct()
	local R = {options = {}, order = {}, sections = {}}
	local mod = {}
	function mod:set_title(t) R.title = t end
	function mod:set_author() end
	function mod:set_description(t) R.description = t end
	function mod:add_new_section(key) R.sections[#R.sections + 1] = key end
	function mod:add_new_option(key, kind)
		local o = {key = key, kind = kind}
		R.options[key], R.order[#R.order + 1] = o, key
		function o:set_text(t) o.text = t end
		function o:set_tooltip_text(t) o.tooltip = t end
		function o:set_default_value(val) o.default = val end
		function o:set_assigned_section(s) o.section = s end
		function o:slider_set_precision() end
		function o:slider_set_min_max(a, b) o.min, o.max = a, b end
		function o:slider_set_step_size() end
		function o:add_dropdown_values(list)
			o.values = list
			for _, val in ipairs(list) do if val.is_default then o.default = val.key end end
		end
		return o
	end
	R.mct = {register_mod = function(_, key) R.key = key return mod end}
	return R
end

local function run_page()
	local R = recording_mct()
	get_mct = function() return R.mct end
	dofile(H.file("script/mct/settings/derpy_third_person"))
	get_mct = nil
	return R
end

T.mct_page_has_every_key = function()
	local R = run_page()
	check(R.key == "derpy_third_person", "registered under the key settings.lua reads")
	for _, action in ipairs(H.K.order) do
		local o = R.options["key_" .. action]
		check(o and o.kind == "dropdown", "dropdown for " .. action)
		check(o.default == H.K.defaults[action], action .. " defaults to " .. H.K.defaults[action])
		check(#o.values == #H.K.names, action .. " offers every key name")
		check(o.text and o.text ~= "", action .. " has a label")
	end
end

T.mct_defaults_agree_with_settings = function()
	local R = run_page()
	local values = {}
	for key, o in pairs(R.options) do values[key] = o.default end
	local settings = assert(loadfile("/script/derpy_tp/settings"))()
	local a, b = settings(H.mct_stub(values), H.K), settings(nil, H.K)
	for _, field in ipairs({"sensitivity", "invert_y", "distance", "shoulder", "zoom_rate", "swing_cooldown", "one_man",
		"reload_factor", "debug"}) do
		check(a[field] == b[field], field .. ": the page's default " .. tostring(a[field]) .. " against " .. tostring(b[field]))
	end
	for _, action in ipairs(H.K.order) do check(a.names[action] == b.names[action], "key " .. action) end
end

T.mct_text_is_plain = function()
	local R = run_page()
	local texts = {R.title or "", R.description or ""}
	for _, o in pairs(R.options) do texts[#texts + 1] = (o.text or "") .. " " .. (o.tooltip or "") end
	for _, t in ipairs(texts) do
		for _, word in ipairs({"HUD", "AI ", " cap", "rung"}) do check(not t:find(word, 1, true), "jargon '" .. word .. "' in: " .. t) end
	end
end
```

- [ ] **Step 2: Run to see them fail**

Run: `py tools/build_third_person.py --selftest`
Expected: 3 new FAILs (cannot open the MCT file). Exit 1.

- [ ] **Step 3: Write the page**

```lua
-- MCT page for Third-Person Battles. MCT loads every .lua under script/mct/settings/, so this runs only
-- when MCT is installed; without it every key and value keeps its default. Key names, defaults and
-- labels come from script/derpy_tp/keys, the file the battle script reads too.
local mct = get_mct and get_mct()
if not mct then return end
local chunk = loadfile("/script/derpy_tp/keys")
if not chunk then return end
local K = chunk()

local m = mct:register_mod("derpy_third_person")
m:set_title("Third-Person Battles")
m:set_author("derpy")
m:set_description("Play one unit from behind in battle. F2 takes the selected unit, or your general when none "
	.. "is selected. Keys and camera are read each time it is switched on. It does nothing in multiplayer.")

local function slider(section, key, text, tooltip, default, min, max)
	local o = m:add_new_option(key, "slider")
	o:set_text(text)
	o:set_tooltip_text(tooltip)
	o:slider_set_precision(0)
	o:slider_set_min_max(min, max)
	o:slider_set_step_size(1, 0)
	o:set_default_value(default)
	o:set_assigned_section(section)
end

local function checkbox(section, key, text, tooltip, default)
	local o = m:add_new_option(key, "checkbox")
	o:set_text(text)
	o:set_tooltip_text(tooltip)
	o:set_default_value(default)
	o:set_assigned_section(section)
end

m:add_new_section("keys", "Keys")
for _, action in ipairs(K.order) do
	local o = m:add_new_option("key_" .. action, "dropdown")
	o:set_text(K.labels[action])
	o:set_tooltip_text("Default: " .. K.defaults[action] .. ". A key already used by an action higher in this list "
		.. "is not taken twice: this action goes back to its default.")
	local list = {}
	for i, name in ipairs(K.names) do list[i] = {key = name, text = name, tt = "", is_default = name == K.defaults[action]} end
	o:add_dropdown_values(list)
	o:set_assigned_section("keys")
end

m:add_new_section("camera", "Camera")
slider("camera", "camera_sensitivity", "Mouse speed", "How far the camera turns for each pixel the mouse moves.", 4, 1, 20)
checkbox("camera", "camera_invert_y", "Invert up and down", "Moving the mouse up looks down.", false)
slider("camera", "camera_distance", "Distance behind", "Metres from the unit to the camera.", 6, 3, 15)
local side = m:add_new_option("camera_shoulder", "dropdown")
side:set_text("Aiming shoulder")
side:set_tooltip_text("Which shoulder the camera sits over in ranged mode.")
side:add_dropdown_values({{key = "right", text = "Right", tt = "", is_default = true},
	{key = "left", text = "Left", tt = "", is_default = false}})
side:set_assigned_section("camera")
slider("camera", "camera_zoom_speed", "Zoom speed", "How fast holding + or - zooms, in tenths.", 12, 5, 30)

m:add_new_section("combat", "Combat")
slider("combat", "combat_swing_cooldown", "Time between swings",
	"Tenths of a second between two attacks. Forced swings deal damage, so this keeps them fair.", 15, 5, 50)
checkbox("combat", "combat_one_man", "Play one man of a regiment",
	"On, you play the regiment's front man: he walks, swings and shoots alone while the rest hold. Off, you move the "
	.. "whole regiment as before.", true)
slider("combat", "combat_reload_factor", "One man's reload time",
	"Percent of the unit's own reload time. At 25, a crossbowman alone reloads in 3.25 seconds instead of 13.", 25, 10, 100)

m:add_new_section("debug", "Debug")
checkbox("debug", "debug_log", "Write every order to the script log", "For bug reports. Off by default.", false)
```

- [ ] **Step 4: Run to see them pass**

Run: `py tools/build_third_person.py --selftest`
Expected: `8 passed, 0 failed`, exit 0.

---

### Task 4: `data.lua`, generated from `db.pack`

**Files:**
- Modify: `tools/build_third_person.py` (add `gen()`, `check_data()`, the `--gen` flag)
- Create (generated): `Modding Files/source/third_person/script/derpy_tp/data.lua`

**Interfaces:** Produces `data.lua`, which returns `D = {shots = {[unit type] = {projectile key, base_reload_time, projectile_number}}, abilities = {[ability key] = "ground" | "enemy" | "friend" | "self"}}`. The kind rule: `ground` when any `target_ground*` is set, else `enemy` when `target_enemies` is set, else `friend` when `target_friends` is set, else `self`. Passive abilities are left out.

- [ ] **Step 1: Write the failing check**

Add to `build_third_person.py`, above `def main`:

```python
DATA = os.path.join(SRC, "script", "derpy_tp", "data.lua")


def check_data():
    """data.lua holds the rows the probe measured on 2026-10-13, and enough of them."""
    if not os.path.isfile(DATA):
        return ["data.lua is missing: run --gen"]
    probe = ('local d = dofile([[%s]]) '
             'local s = d.shots["wh3_main_cth_inf_jade_warrior_crossbowmen_1"] '
             'local n, a = 0, 0 for _ in pairs(d.shots) do n = n + 1 end for _ in pairs(d.abilities) do a = a + 1 end '
             'print(s[1], s[2], s[3], d.shots["wh3_main_cth_inf_iron_hail_gunners_0"][3], '
             'd.abilities["wh_main_spell_fire_fireball"], d.abilities["wh2_dlc09_army_abilities_barrage_of_the_legion"], n, a)'
             % DATA)
    r = subprocess.run([LUA, "-e", probe], capture_output=True, text=True)
    got = r.stdout.split()
    want = ["wh3_cth_crossbow_bolt", "13", "1", "3", "enemy", "ground"]
    bad = []
    if got[:6] != want:
        bad.append("data.lua rows: got %s, want %s %s" % (got[:6], want, r.stderr.strip()))
    elif int(got[6]) < 500 or int(got[7]) < 500:
        bad.append("data.lua is too small: %s unit types, %s abilities" % (got[6], got[7]))
    return bad
```

In `selftest()`, after the luac loop, add `bad += check_data()`.

- [ ] **Step 2: Run to see it fail**

Run: `py tools/build_third_person.py --selftest`
Expected: `FINDING: data.lua is missing: run --gen`, exit 1.

- [ ] **Step 3: Write the generator**

Add above `def main`:

```python
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
    return "self"


def gen():
    """Write data.lua from CA's db.pack: main_units -> land_units.primary_missile_weapon ->
    missile_weapons.default_projectile -> projectiles, and unit_special_abilities' target flags."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    from read_vanilla_db import load, DB_PACK

    def rows(table):
        return [r for _p, _v, rs in load(DB_PACK, table + "_tables") for r in rs]

    lu = {r["key"]: r for r in rows("land_units")}
    mw = {r["key"]: r for r in rows("missile_weapons")}
    pr = {r["key"]: r for r in rows("projectiles")}
    shots = {}
    for r in rows("main_units"):
        land = lu.get(r["land_unit"])
        weapon = land and mw.get(land["primary_missile_weapon"])
        proj = weapon and pr.get(weapon["default_projectile"])
        if proj:
            shots[r["unit"]] = (proj["key"], float(proj["base_reload_time"]), int(proj["projectile_number"]))
    kinds = {r["key"]: ability_kind(r) for r in rows("unit_special_abilities") if not r["passive"]}
    lines = ["-- GENERATED by tools/build_third_person.py --gen from db.pack, exe build 0x%08x. Do not edit." % exe_stamp(),
             "-- shots: unit type -> {projectile key, base_reload_time, projectiles per shot}",
             "-- abilities: non-passive ability key -> what it aims at: ground, enemy, friend or self",
             "return {", "\tshots = {"]
    for k in sorted(shots):
        key, reload, n = shots[k]
        lines.append('\t\t["%s"] = {"%s", %g, %d},' % (k, key, reload, n))
    lines += ["\t},", "\tabilities = {"]
    for k in sorted(kinds):
        lines.append('\t\t["%s"] = "%s",' % (k, kinds[k]))
    lines += ["\t},", "}", ""]
    with open(DATA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote %s: %d unit types, %d abilities" % (DATA, len(shots), len(kinds)))
```

In `main`, add before the usage line: `if argv[:1] == ["--gen"]: gen(); return 0`.

- [ ] **Step 4: Generate and run the selftest**

Run: `py tools/build_third_person.py --gen` then `py tools/build_third_person.py --selftest`
Expected: `wrote ...data.lua: N unit types, M abilities` with N and M above 500. Then `8 passed`, no `FINDING`, exit 0.

---

### Task 5: The command pattern, checked against the exe on disk

The exe on disk holds the same code bytes as in memory (checked 2026-10-13 against `ammo_left` at `exe+2eb9200`), so this works with the game shut. One pattern, at `exe+2efc2f8` in 9.0 inside `play_anim_for_captain`, yields:
- the command type (`lea`, disp at `+3`);
- the battle global (`mov`, disp at `+0x23`);
- the four offsets `0x468`, `0x3b0`, `0x3b1`, `0x644e8` (at `+0x2a`, `+0x31`, `+0x3a`, `+0x48`);
- the push function (`call`, rel32 at `+0x4d`).

**Files:**
- Create: `tools/third_person_patterns.py`

**Interfaces:** Reads `PATTERN` and `BUILDS` out of `platform.lua` (Task 6 writes them; this task's selftest needs neither). Exits 0 only when the pattern matches once and agrees with the build's row.

- [ ] **Step 1: Write the tool with its selftest**

```python
"""Check the third-person pack's command pattern against Warhammer3.exe ON DISK (the game may be shut).

    py tools/third_person_patterns.py              one match, and it agrees with platform.lua's BUILDS row
    py tools/third_person_patterns.py --selftest   the matcher and the rip-relative maths on a made-up blob

PATTERN and BUILDS are read out of Modding Files/source/third_person/script/derpy_tp/platform.lua, so
the Lua stays the one source. For a build the table does not know, prints the row to add (model_vt is
measured live, handoff 9e). The exe's section names are scrambled; its code is the section at RVA 0x1000.
"""
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLATFORM = os.path.join(ROOT, "Modding Files", "source", "third_person", "script", "derpy_tp", "platform.lua")
EXE = r"F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\Warhammer3.exe"
FIELDS = ("cmd_type", "battle", "cmd_push", "battle_sub", "gate_a", "gate_b", "queue")


def read_lua(text):
    block = text[text.index("local PATTERN ="):]
    block = block[:block.index("\n\n")]
    pattern = "".join(re.findall(r'"([^"]*)"', block))
    builds = {}
    for m in re.finditer(r"\[0x([0-9a-f]+)\] = \{([^}]*)\}", text):
        builds[int(m.group(1), 16)] = {k: int(v, 16) for k, v in re.findall(r"(\w+) = 0x([0-9a-f]+)", m.group(2))}
    return pattern, builds


def regex(pattern):
    return re.compile(b"".join(b"." if t == "??" else re.escape(bytes([int(t, 16)])) for t in pattern.split()), re.S)


def resolve(code, va, hit):
    def rip(off):
        return va + hit + off + 4 + struct.unpack_from("<i", code, hit + off)[0]

    def imm(off):
        return struct.unpack_from("<i", code, hit + off)[0]
    return {"cmd_type": rip(3), "battle": rip(0x23), "cmd_push": rip(0x4d),
            "battle_sub": imm(0x2a), "gate_a": imm(0x31), "gate_b": imm(0x3a), "queue": imm(0x48)}


def code_section(path):
    with open(path, "rb") as f:
        head = f.read(0x1000)
        pe = struct.unpack_from("<I", head, 0x3c)[0]
        stamp = struct.unpack_from("<I", head, pe + 8)[0]
        n = struct.unpack_from("<H", head, pe + 6)[0]
        sec = pe + 24 + struct.unpack_from("<H", head, pe + 20)[0]
        for i in range(n):
            vsz, va, rsz, raw = struct.unpack_from("<IIII", head, sec + i * 40 + 8)
            if va == 0x1000:
                f.seek(raw)
                return stamp, va, f.read(min(vsz, rsz))
    raise SystemExit("no section at RVA 0x1000 in %s" % path)


def check():
    pattern, builds = read_lua(open(PLATFORM, encoding="utf-8").read())
    stamp, va, code = code_section(EXE)
    hits = [m.start() for m in regex(pattern).finditer(code)]
    print("exe build 0x%08x: the pattern matches %d time(s)" % (stamp, len(hits)))
    if len(hits) != 1:
        return 1
    got = resolve(code, va, hits[0])
    print("  at exe+0x%x: %s" % (va + hits[0], ", ".join("%s = 0x%x" % (k, got[k]) for k in FIELDS)))
    row = builds.get(stamp)
    if row is None:
        print("unknown build - add to BUILDS once Task 13's live check passes on it:")
        print("\t[0x%x] = {%s, model_vt = <measured>}," % (stamp, ", ".join("%s = 0x%x" % (k, got[k]) for k in FIELDS)))
        return 1
    bad = ["%s: row 0x%x, exe 0x%x" % (k, row.get(k, -1), got[k]) for k in FIELDS if row.get(k) != got[k]]
    for b in bad:
        print("DISAGREES " + b)
    return 1 if bad else 0


def selftest():
    pattern = ("48 8D 05 ?? ?? ?? ?? 48 89 44 24 30 48 89 74 24 38 66 44 89 74 24 40 44 88 7C 24 42 89 7C 24 44 "
               "48 8B 05 ?? ?? ?? ?? 48 8B 88 ?? ?? ?? ?? 40 38 B9 ?? ?? ?? ?? 75 ?? 40 38 B9 ?? ?? ?? ?? 75 ?? "
               "48 8D 54 24 30 48 8B 89 ?? ?? ?? ?? E8")
    body = bytearray(int(t, 16) if t != "??" else 0 for t in pattern.split()) + bytearray(4)
    for off, val in ((3, 0x100), (0x23, -0x20), (0x2a, 0x468), (0x31, 0x3b0), (0x3a, 0x3b1), (0x48, 0x644e8), (0x4d, 0x40)):
        struct.pack_into("<i", body, off, val)
    blob = bytes(16) + bytes(body) + bytes(16)
    hits = [m.start() for m in regex(pattern).finditer(blob)]
    assert hits == [16], hits
    got = resolve(blob, 0x1000, 16)
    assert got["cmd_type"] == 0x1000 + 16 + 3 + 4 + 0x100, hex(got["cmd_type"])
    assert got["battle"] == 0x1000 + 16 + 0x23 + 4 - 0x20, hex(got["battle"])
    assert got["cmd_push"] == 0x1000 + 16 + 0x4d + 4 + 0x40, hex(got["cmd_push"])
    assert (got["battle_sub"], got["gate_a"], got["gate_b"], got["queue"]) == (0x468, 0x3b0, 0x3b1, 0x644e8), got
    assert len(list(regex(pattern).finditer(blob + blob))) == 2, "a second copy must count as two"
    text = ('local BUILDS = {\n\t[0x6ac6d907] = {cmd_type = 0x3901cd0, cmd_push = 0x2e969ac},\n}\n'
            'local PATTERN = "48 8D "\n\t.. "05 ??"\n\nlocal X = 1\n')
    p, b = read_lua(text)
    assert p == "48 8D 05 ??" and b[0x6ac6d907]["cmd_push"] == 0x2e969ac, (p, b)
    print("selftest ok")
    return 0


if __name__ == "__main__":
    sys.exit(selftest() if sys.argv[1:2] == ["--selftest"] else check())
```

- [ ] **Step 2: Run the selftest**

Run: `py tools/third_person_patterns.py --selftest`
Expected: `selftest ok`, exit 0. (The `check()` run waits for Task 6.)

---

### Task 6: `platform.lua`

Every address, offset and memreader call, behind the interface the fake platform in the harness already has. Its behaviour is checked live in Task 13; offline it gets its split maths and the pattern check.

**Files:**
- Create: `Modding Files/source/third_person/script/derpy_tp/platform.lua`
- Modify: `tools/third_person_tests.lua`, `tools/build_third_person.py` (run the pattern check in `selftest`)

**Interfaces:** Produces the module `{split = function(n) -> hi, lo, build = function(mr) -> P}`, where `P` has:

| Field | Shape |
|---|---|
| state | `features = {input, anim, wheel, men}` (booleans), `problems = {string...}`, `build` (exe stamp), `source` (`"known build"` or `"byte pattern"`) |
| input | `focused()`, `held(vk)`, `pressed(vk)`, `look_begin()`, `look_delta() -> dx, dy` |
| cursor | `cursor(show)`, only when Task 1 chose a Windows route. Safe to call every frame; `main.lua` does so |
| checks | `check_anim() -> ok, why`, `open_wheel() -> ok, why`, then `wheel() -> notches` |
| models | `models(unit) -> {m...}`, `model_pos(m) -> x, y, z`, `place(m, x, z)`, `steer(m, x, z)`, `alive(unit, m)`, `same(a, b)`, `check_men(unit) -> ok, why` |
| animation | `play(m, slot) -> bool` |

- [ ] **Step 1: Write the failing test**

Add above `return T`:

```lua
T.platform_split_is_float32_exact = function()
	H.real_platform = true
	local M = assert(loadfile("/script/derpy_tp/platform"))()
	H.real_platform = false
	for _, n in ipairs({0x3901cd0, 0x2e969ac, 0x4479ee0, -0x157dbc1, 0x644e8, 0, 0xffff, 0x10000}) do
		local hi, lo = M.split(n)
		check(hi + lo == n, "parts add back to " .. n)
		check(lo >= 0 and lo < 0x10000, "low part under 0x10000 for " .. n)
		check(hi % 0x10000 == 0, "high part a multiple of 0x10000 for " .. n)
		check(math.abs(hi / 0x10000) < 2 ^ 24, "high part has at most 24 significant bits for " .. n)
	end
end
```

In `build_third_person.py` `selftest()`, after the harness run, add:

```python
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "third_person_patterns.py")],
                       capture_output=True, text=True)
    print(r.stdout, end="")
    if r.returncode:
        bad.append("the command pattern does not check out against the exe")
```

- [ ] **Step 2: Run to see it fail**

Run: `py tools/build_third_person.py --selftest`
Expected: `FAIL platform_split_is_float32_exact` (no file), and the pattern check fails (`platform.lua` missing). Exit 1.

- [ ] **Step 3: Write `platform.lua`**

Set `CURSOR_ROUTE` to Task 1's result; the code below carries `"cinematic"`, the route the probe already proved.

```lua
-- The only file with an address, an offset or a memreader call (spec sections 4 and 8). The other
-- modules reach the game's memory through the table build() returns and never see a number. The 9.0
-- facts behind each group: docs/sessions/HANDOFF_20261008_THIRD_PERSON_LORD_CONTROL.md - the
-- animation command 9e, the wheel 9f, one man's steering 9i, the cursor 9k.
local M = {}

-- known builds by the exe's PE TimeDateStamp: RVAs and offsets measured on that build
local BUILDS = {
	[0x6ac6d907] = {cmd_type = 0x3901cd0, battle = 0x4479ee0, cmd_push = 0x2e969ac, battle_sub = 0x468, gate_a = 0x3b0, gate_b = 0x3b1, queue = 0x644e8, model_vt = 0x390d4f8},
}
-- an unknown build: play_anim_for_captain builds the command we forge (9.0: exe+2efc2f8, the only match).
-- It gives the command type (lea, disp at +3), the battle global (mov, disp at +0x23), the battle object,
-- gate and queue offsets (+0x2a, +0x31, +0x3a, +0x48) and the push call (rel32 at +0x4d).
-- tools/third_person_patterns.py checks it against the exe on disk.
local PATTERN = "48 8D 05 ?? ?? ?? ?? 48 89 44 24 30 48 89 74 24 38 66 44 89 74 24 40 44 88 7C 24 42 89 7C 24 44 "
	.. "48 8B 05 ?? ?? ?? ?? 48 8B 88 ?? ?? ?? ?? 40 38 B9 ?? ?? ?? ?? 75 ?? 40 38 B9 ?? ?? ?? ?? 75 ?? "
	.. "48 8D 54 24 30 48 8B 89 ?? ?? ?? ?? E8"

local MODELS_N, MODELS_DATA, MODEL_POS = 0xa4, 0xa8, 0x88 -- unit object: live model count and array; model: x, y, z
local STEER = {{0x1e0, 0x1e8}, {0x194, 0x198}, {0x368, 0x370}} -- one man's steering point, in three copies
local CURSOR_ROUTE = "cinematic" -- Task 1's result: "setcursor", "showcursor" or "cinematic" (main.lua's own route)
local WANT = {
	["USER32.DLL"] = {"GetAsyncKeyState", "GetCursorPos", "SetCursorPos", "GetForegroundWindow", "GetClientRect",
		"ClientToScreen", "GetWindowThreadProcessId", "SetCursor", "ShowCursor"},
	["KERNEL32.DLL"] = {"GetCurrentProcessId"},
	["DINPUT8.DLL"] = {"DirectInput8Create"},
}

-- memreader passes a plain number through float32, exact only below 2^24: a larger one goes in two
-- parts, the high one a multiple of 0x10000 (at most 24 significant bits), the low one under 0x10000
function M.split(n)
	local lo = n % 0x10000
	return n - lo, lo
end

function M.build(mr)
	local P = {features = {input = false, anim = false, wheel = false, men = false}, problems = {}}
	local base = mr.base
	local function at(p, n) local hi, lo = M.split(n) return mr.add(mr.add(p, hi), lo) end
	local function problem(group, why) P.features[group] = false P.problems[#P.problems + 1] = group .. ": " .. why end
	local function sys(p) local s = mr.tostring(p) return s >= "00007FF000000000" and s < "0000800000000000" end

	local pe = mr.read_int32(base, 0x3c)
	P.build = mr.read_int32(base, pe + 8)
	if P.build < 0 then P.build = P.build + 4294967296 end

	-- imports, parsed from the loaded image so that no build has to store them
	local function upper(c) if c >= 97 and c <= 122 then return c - 32 end return c end
	local function cstr_is(rva, s, fold)
		local p = at(base, rva)
		for i = 1, #s do
			local c = mr.read_uint8(p, i - 1)
			if fold then c = upper(c) end
			if c ~= s:byte(i) then return false end
		end
		return mr.read_uint8(p, #s) == 0
	end
	local fn = {}
	local d = mr.read_int32(base, pe + 0x90) -- PE32+ import directory
	while d ~= 0 do
		local desc = at(base, d)
		local name_rva = mr.read_int32(desc, 12)
		if name_rva == 0 then break end
		for dll, names in pairs(WANT) do
			if cstr_is(name_rva, dll, true) then
				local oft, ft = mr.read_int32(desc, 0), mr.read_int32(desc, 16)
				local k = 0
				while oft ~= 0 do
					local thunks = at(base, oft)
					local lo, hi = mr.read_int32(thunks, k * 8), mr.read_int32(thunks, k * 8 + 4)
					if lo == 0 and hi == 0 then break end
					if hi >= 0 then -- bit 63 clear: imported by name, at hint/name + 2
						for _, name in ipairs(names) do
							if not fn[name] and cstr_is(lo + 2, name) then fn[name] = mr.read_pointer(at(base, ft), k * 8) end
						end
					end
					k = k + 1
				end
			end
		end
		d = d + 20
	end

	-- input --------------------------------------------------------------------------------------------
	for _, name in ipairs({"GetAsyncKeyState", "GetCursorPos", "SetCursorPos", "GetForegroundWindow", "GetClientRect",
		"ClientToScreen", "GetWindowThreadProcessId", "GetCurrentProcessId"}) do
		if not fn[name] or not sys(fn[name]) then problem("input", name .. " not found in the import table") return P end
	end
	P.features.input = true
	local buf, rect, owner = mr.alloc(8), mr.alloc(16), mr.alloc(8)
	local pid = mr.tonumber(mr.call(fn.GetCurrentProcessId, "int32()"))
	-- focused: the foreground window belongs to this process, and it becomes the window looking parks in.
	-- Not a window captured at load: a battle loaded while the game was in the background would never focus.
	function P.focused()
		local w = mr.call(fn.GetForegroundWindow, "pointer()")
		if mr.is_null(w) then return false end
		mr.call(fn.GetWindowThreadProcessId, "int32(pointer, pointer)", w, owner)
		if mr.read_int32(owner, 0) ~= pid then return false end
		P.window = w
		return true
	end
	local function down(vk) return mr.tonumber(mr.call(fn.GetAsyncKeyState, "int16(int32)", vk)) < 0 end
	function P.held(vk)
		if vk == nil then return false end
		if type(vk) == "table" then for _, k in ipairs(vk) do if down(k) then return true end end return false end
		return down(vk)
	end
	local was = {}
	function P.pressed(vk) -- down now and up at this key's last call
		if vk == nil then return false end
		local key = type(vk) == "table" and vk[1] or vk
		local d = P.held(vk)
		local edge = d and not was[key]
		was[key] = d
		return edge
	end
	local cx, cy = 0, 0
	function P.look_begin() -- park the cursor at the window centre
		mr.call(fn.GetClientRect, "int32(pointer, pointer)", P.window, rect)
		mr.write(buf, 0, mr.int32(math.floor(mr.read_int32(rect, 8) / 2)))
		mr.write(buf, 4, mr.int32(math.floor(mr.read_int32(rect, 12) / 2)))
		mr.call(fn.ClientToScreen, "int32(pointer, pointer)", P.window, buf)
		cx, cy = mr.read_int32(buf, 0), mr.read_int32(buf, 4)
		mr.call(fn.SetCursorPos, "int32(int32, int32)", cx, cy)
	end
	function P.look_delta() -- pixels since the last park, then parked again
		mr.call(fn.GetCursorPos, "int32(pointer)", buf)
		local dx, dy = mr.read_int32(buf, 0) - cx, mr.read_int32(buf, 4) - cy
		if dx ~= 0 or dy ~= 0 then mr.call(fn.SetCursorPos, "int32(int32, int32)", cx, cy) end
		return dx, dy
	end
	-- the cursor (Task 1). P.cursor is called every frame. Without it, main.lua uses cinematic UI.
	if CURSOR_ROUTE == "setcursor" and fn.SetCursor and sys(fn.SetCursor) then
		-- no picture each frame while hidden; nothing to undo, the game's next WM_SETCURSOR draws its own
		function P.cursor(show) if not show then mr.call(fn.SetCursor, "pointer(pointer)", nil) end end
	elseif CURSOR_ROUTE == "showcursor" and fn.ShowCursor and sys(fn.ShowCursor) then
		-- ShowCursor keeps a display count and draws the cursor while it is 0 or more
		local hidden = false
		function P.cursor(show)
			show = show and true or false
			if show ~= hidden then return end
			local n = mr.tonumber(mr.call(fn.ShowCursor, "int32(int32)", show and 1 or 0))
			while (show and n < 0) or (not show and n >= 0) do n = mr.tonumber(mr.call(fn.ShowCursor, "int32(int32)", show and 1 or 0)) end
			hidden = not show
		end
	end

	-- the animation command ---------------------------------------------------------------------------
	local A
	local row = BUILDS[P.build]
	if row then
		A = {cmd_type = at(base, row.cmd_type), battle = at(base, row.battle), push = at(base, row.cmd_push),
			sub = row.battle_sub, gate_a = row.gate_a, gate_b = row.gate_b, queue = row.queue}
		P.source, P.model_vt = "known build", at(base, row.model_vt)
	else
		local hit, count = mr.find_pattern(PATTERN)
		if count == 1 then
			local function rip(o) return mr.add(mr.add(hit, o + 4), mr.read_int32(hit, o, true)) end
			A = {cmd_type = rip(3), battle = rip(0x23), push = rip(0x4d), sub = mr.read_int32(hit, 0x2a),
				gate_a = mr.read_int32(hit, 0x31), gate_b = mr.read_int32(hit, 0x3a), queue = mr.read_int32(hit, 0x48)}
			P.source = "byte pattern"
		end
	end
	local cmd = mr.alloc(32)
	local function battle_obj()
		local g = mr.read_pointer(A.battle, 0)
		if mr.is_null(g) then return nil end
		local b = mr.read_pointer(g, A.sub)
		if mr.is_null(b) then return nil end
		return b
	end
	function P.check_anim()
		if not A then problem("anim", "unknown build " .. P.build .. " and the command pattern did not match once") return false, P.problems[#P.problems] end
		local b = battle_obj()
		if not b then problem("anim", "the battle object is not reachable") return false, P.problems[#P.problems] end
		local ga, gb = mr.read_uint8(b, A.gate_a), mr.read_uint8(b, A.gate_b)
		if ga > 1 or gb > 1 then problem("anim", "gate bytes read " .. ga .. " and " .. gb) return false, P.problems[#P.problems] end
		if mr.is_null(mr.read_pointer(b, A.queue)) then problem("anim", "the command queue is null") return false, P.problems[#P.problems] end
		P.features.anim = true
		return true
	end
	function P.play(m, slot) -- push the play-animation command for one model; false while the queue is gated
		if not P.features.anim then return false end
		local b = battle_obj()
		if not b or mr.read_uint8(b, A.gate_a) ~= 0 or mr.read_uint8(b, A.gate_b) ~= 0 then return false end
		mr.write(cmd, 0, A.cmd_type)
		mr.write(cmd, 8, m)
		mr.write(cmd, 0x10, mr.uint16(slot))
		mr.write(cmd, 0x12, mr.uint8(0))
		mr.write(cmd, 0x14, mr.uint32(0))
		mr.call(A.push, "uint8(pointer, pointer)", mr.read_pointer(b, A.queue), cmd)
		return true
	end

	-- the wheel: our own DirectInput 8 mouse, one per battle, kept in a global so a reload reuses it -----
	function P.open_wheel()
		local D = _G.DERPY_TP_DI
		if not (D and D.dev) then
			local create = fn.DirectInput8Create
			if not create or not sys(create) then problem("wheel", "DirectInput8Create not imported") return false, P.problems[#P.problems] end
			local m = mr.alloc(160)
			local function bytes(off, t) for i = 1, #t do mr.write(m, off + i - 1, mr.uint8(t[i])) end end
			bytes(0, {0x31, 0x80, 0x79, 0xBF, 0x3A, 0x48, 0xA2, 0x4D, 0xAA, 0x99, 0x5D, 0x64, 0xED, 0x36, 0x97, 0x00}) -- IID_IDirectInput8W
			bytes(16, {0x60, 0x2B, 0x1D, 0x6F, 0xA0, 0xD5, 0xCF, 0x11, 0xBF, 0xC7, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00}) -- GUID_SysMouse
			bytes(32, {0xE2, 0x02, 0x6D, 0xA3, 0xF3, 0xC9, 0xCF, 0x11, 0xBF, 0xC7, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00}) -- GUID_ZAxis
			mr.write(m, 64, mr.add(m, 32)) -- DIOBJECTDATAFORMAT: pguid, dwOfs 0, DIDFT_AXIS | DIDFT_ANYINSTANCE
			mr.write(m, 76, mr.uint32(0x00FFFF03))
			mr.write(m, 96, mr.uint32(32)) -- DIDATAFORMAT: size, object size 24, DIDF_RELAXIS, 4 bytes, 1 object
			mr.write(m, 100, mr.uint32(24))
			mr.write(m, 104, mr.uint32(2))
			mr.write(m, 108, mr.uint32(4))
			mr.write(m, 112, mr.uint32(1))
			mr.write(m, 120, mr.add(m, 64))
			local function method(obj, i) return mr.read_pointer(mr.read_pointer(obj, 0), i * 8) end
			if mr.tonumber(mr.call(create, "int32(pointer, uint32, pointer, pointer, pointer)", base, 0x800, m, mr.add(m, 48), nil)) ~= 0 then
				problem("wheel", "DirectInput8Create failed") return false, P.problems[#P.problems]
			end
			local di = mr.read_pointer(m, 48)
			if mr.tonumber(mr.call(method(di, 3), "int32(pointer, pointer, pointer, pointer)", di, mr.add(m, 16), mr.add(m, 56), nil)) ~= 0 then
				problem("wheel", "CreateDevice failed") return false, P.problems[#P.problems]
			end
			local dev = mr.read_pointer(m, 56)
			if mr.tonumber(mr.call(method(dev, 11), "int32(pointer, pointer)", dev, mr.add(m, 96))) ~= 0 then
				problem("wheel", "SetDataFormat failed") return false, P.problems[#P.problems]
			end
			mr.call(method(dev, 13), "int32(pointer, pointer, uint32)", dev, P.window, 0xA) -- NONEXCLUSIVE | BACKGROUND
			mr.call(method(dev, 7), "int32(pointer)", dev)
			D = {dev = dev, acquire = method(dev, 7), state = method(dev, 9), buf = mr.add(m, 128)}
			_G.DERPY_TP_DI = D
		end
		function P.wheel() -- notches since the last call; re-acquires a lost device
			if mr.tonumber(mr.call(D.state, "int32(pointer, uint32, pointer)", D.dev, 4, D.buf)) ~= 0 then
				mr.call(D.acquire, "int32(pointer)", D.dev)
				return 0
			end
			return mr.read_int32(D.buf, 0) / 120
		end
		P.features.wheel = true
		return true
	end

	-- a unit's men -------------------------------------------------------------------------------------
	local function obj_of(unit) return mr.read_pointer(mr.ud_topointer(unit), 8) end
	function P.models(unit)
		local obj = obj_of(unit)
		local n, data = mr.read_int32(obj, MODELS_N), mr.read_pointer(obj, MODELS_DATA)
		local t = {}
		for k = 0, n - 1 do t[k + 1] = mr.read_pointer(data, k * 8) end
		return t
	end
	function P.model_pos(m) return mr.read_float(m, MODEL_POS), mr.read_float(m, MODEL_POS + 4), mr.read_float(m, MODEL_POS + 8) end
	function P.place(m, x, z) mr.write(m, MODEL_POS, x) mr.write(m, MODEL_POS + 8, z) end
	function P.steer(m, x, z) for _, f in ipairs(STEER) do mr.write(m, f[1], x) mr.write(m, f[2], z) end end
	function P.same(a, b) return mr.eq(a, b) end
	function P.alive(unit, m)
		for _, x in ipairs(P.models(unit)) do if mr.eq(x, m) then return true end end
		return false
	end
	-- the live check (spec section 8), run at every start: the count matches the men alive, every model
	-- shares one type marker (9.0's, on a known build), the models centre within 5 m of the unit, and
	-- every steering copy lies near its man
	function P.check_men(unit)
		local obj = obj_of(unit)
		local n = mr.read_int32(obj, MODELS_N)
		if n < 1 or n ~= unit:number_of_men_alive() then return false, "model count " .. n .. " against " .. unit:number_of_men_alive() .. " men" end
		local ms = P.models(unit)
		local vt = mr.read_pointer(ms[1], 0)
		if P.model_vt and not mr.eq(vt, P.model_vt) then return false, "the model type is not this build's" end
		local sx, sz = 0, 0
		for _, m in ipairs(ms) do
			if not mr.eq(mr.read_pointer(m, 0), vt) then return false, "the models of one unit differ in type" end
			local x, _, z = P.model_pos(m)
			sx, sz = sx + x, sz + z
			for _, f in ipairs(STEER) do
				local tx, tz = mr.read_float(m, f[1]), mr.read_float(m, f[2])
				if tx ~= tx or tz ~= tz or (tx - x) ^ 2 + (tz - z) ^ 2 > 90000 then return false, "a steering copy is not near its man" end
			end
		end
		local q = unit:position()
		local dx, dz = sx / n - q:get_x(), sz / n - q:get_z()
		if dx * dx + dz * dz > 25 then return false, "the models centre " .. math.floor(math.sqrt(dx * dx + dz * dz)) .. " m from the unit" end
		P.features.men = true
		return true
	end

	return P
end

return M
```

- [ ] **Step 4: Run the selftest and the pattern check**

Run: `py tools/build_third_person.py --selftest`
Expected:
- `ok platform_split_is_float32_exact`, `9 passed`;
- the pattern check prints `exe build 0x6ac6d907: the pattern matches 1 time(s)` and the seven fields;
- no `DISAGREES` line, exit 0.

---

### Task 7: The camera rig

**Files:**
- Create: `Modding Files/source/third_person/script/derpy_tp/rig.lua`
- Modify: `tools/third_person_tests.lua`

**Interfaces:**
- Consumes `E.S` (`distance`, `sensitivity`, `invert_y`, `shoulder`).
- Produces `rig(E) -> R`, with methods `start(now, x, y, z, yaw, zoom, ranged)`, `look(dx, dy)`, `zoom_by(log_steps)` and `update(now, dt, x, y, z, ranged) -> ex, ey, ez, lx, ly, lz`.
- Its readable fields are `yaw`, `pitch`, `zoom`, `ots`, `ex..lz`.

- [ ] **Step 1: Write the failing tests**

```lua
local function a_rig(S)
	local settings = assert(loadfile("/script/derpy_tp/settings"))()
	local E = {S = S or settings(nil, H.K)}
	return assert(loadfile("/script/derpy_tp/rig"))()(E), E
end

T.rig_sits_behind_and_above = function()
	local R = a_rig()
	R.start(0, 0, 0, 0, 0, 1, false)
	local ex, ey, ez = R.update(1, 1, 0, 0, 0, false)
	check(near(ex, 0) and near(ey, 2.5) and near(ez, -6), "eye 6 m behind, 2.5 up: " .. ex .. "," .. ey .. "," .. ez)
end

T.rig_plays_the_unit_back_late = function()
	local R = a_rig()
	R.start(0, 0, 0, 0, 0, 1, false)
	R.update(0.5, 0.01, 0, 0, 0, false)
	R.update(1.0, 0.01, 10, 0, 0, false) -- a new position sample at t=1
	R.update(1.2, 5, 10, 0, 0, false) -- 1.2 - 0.45 = 0.75; the t=0.5 call added no sample (x unchanged); dt 5 settles the spring
	check(near(R.sx, 7.5, 0.01), "target x=7.5, three quarters of the way from the t=0 sample to the t=1 one, got " .. R.sx)
end

T.rig_pitch_is_clamped = function()
	local R = a_rig()
	R.start(0, 0, 0, 0, 0, 1, false)
	R.look(0, 100000)
	check(near(R.pitch, 1.1), "pitch stops at 1.1")
	R.look(0, -1000000)
	check(near(R.pitch, -0.25), "pitch stops at -0.25")
end

T.rig_invert_y = function()
	local settings = assert(loadfile("/script/derpy_tp/settings"))()
	local R = a_rig(settings(H.mct_stub({camera_invert_y = true}), H.K))
	R.start(0, 0, 0, 0, 0, 1, false)
	R.look(0, 10)
	check(R.pitch < 0, "mouse down looks up when inverted")
end

T.rig_shoulder_side = function()
	local settings = assert(loadfile("/script/derpy_tp/settings"))()
	for _, side in ipairs({{"right", 1}, {"left", -1}}) do
		local R = a_rig(settings(H.mct_stub({camera_shoulder = side[1]}), H.K))
		R.start(0, 0, 0, 0, 0, 1, true)
		local ex = R.update(1, 1, 0, 0, 0, true)
		check(near(ex, side[2] * 1.0, 0.01), side[1] .. " shoulder puts the eye at x=" .. side[2] .. ", got " .. ex)
	end
end

T.rig_zoom_is_clamped = function()
	local R = a_rig()
	R.start(0, 0, 0, 0, 0, 1, false)
	R.zoom_by(100)
	check(near(R.zoom, 6), "zoom stops at 6")
	R.zoom_by(-100)
	check(near(R.zoom, 0.6), "zoom stops at 0.6")
end
```

- [ ] **Step 2: Run to see them fail**

Run: `py tools/build_third_person.py --selftest`
Expected: 6 rig FAILs. Exit 1.

- [ ] **Step 3: Write `rig.lua`**

```lua
-- The follow camera (spec section 5, handoff 9): plays the unit back DELAY s late between its position
-- samples (unit:position() steps about every 0.2 s), with a light spring on top, then sits behind at the
-- mouse's yaw and pitch; ranged mode blends to an over-the-shoulder rig. Pure maths, built per battle:
-- return function(E) -> R. Reads E.S at every call, since settings are re-read at each toggle.
local DELAY, K_POS, HEIGHT, LOOK_H, AHEAD = 0.45, 20, 2.5, 1.8, 6
local OTS_BACK, OTS_SIDE, OTS_HEIGHT, OTS_AHEAD, OTS_RATE = 3.2, 1.0, 2.0, 30, 4
local PITCH_MIN, PITCH_MAX, ZOOM_MIN, ZOOM_MAX = -0.25, 1.1, 0.6, 6

return function(E)
	local R = {}

	function R.start(now, x, y, z, yaw, zoom, ranged)
		R.samples, R.sx, R.sy, R.sz = {{now, x, y, z}}, x, y, z
		R.yaw, R.pitch, R.zoom, R.ots = yaw, 0, zoom, ranged and 1 or 0
	end

	function R.look(dx, dy) -- mouse pixels
		local S = E.S
		R.yaw = R.yaw + dx * S.sensitivity
		if S.invert_y then dy = -dy end
		R.pitch = math.max(PITCH_MIN, math.min(PITCH_MAX, R.pitch + dy * S.sensitivity))
	end

	function R.zoom_by(steps) -- natural-log steps: positive zooms out
		R.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, R.zoom * math.exp(steps)))
	end

	function R.update(now, dt, x, y, z, ranged)
		local S, Q = E.S, R.samples
		local last = Q[#Q]
		if x ~= last[2] or z ~= last[4] then
			Q[#Q + 1] = {now, x, y, z}
			if #Q > 16 then table.remove(Q, 1) end
		end
		local tp = now - DELAY
		local i = #Q
		while i > 1 and Q[i][1] > tp do i = i - 1 end
		local tx, ty, tz = Q[i][2], Q[i][3], Q[i][4]
		if Q[i][1] <= tp and i < #Q then
			local b = Q[i + 1]
			local f = (tp - Q[i][1]) / (b[1] - Q[i][1])
			tx, ty, tz = tx + (b[2] - tx) * f, ty + (b[3] - ty) * f, tz + (b[4] - tz) * f
		end
		local a = 1 - math.exp(-K_POS * dt)
		R.sx, R.sy, R.sz = R.sx + (tx - R.sx) * a, R.sy + (ty - R.sy) * a, R.sz + (tz - R.sz) * a
		local fx, fz = math.sin(R.yaw), math.cos(R.yaw)
		local zm = R.zoom
		local back, lift = S.distance * zm * math.cos(R.pitch), S.distance * zm * math.sin(R.pitch)
		local ex, ey, ez = R.sx - fx * back, R.sy + HEIGHT * zm + lift, R.sz - fz * back
		local lx, ly, lz = R.sx + fx * AHEAD * zm, R.sy + LOOK_H * zm, R.sz + fz * AHEAD * zm
		R.ots = R.ots + ((ranged and 1 or 0) - R.ots) * math.min(1, OTS_RATE * dt)
		if R.ots > 0.001 then
			local rx, rz = fz * S.shoulder, -fx * S.shoulder
			local ox, oy, oz = R.sx + (rx * OTS_SIDE - fx * OTS_BACK) * zm, R.sy + OTS_HEIGHT * zm, R.sz + (rz * OTS_SIDE - fz * OTS_BACK) * zm
			local c, sn = math.cos(R.pitch), math.sin(R.pitch)
			local ax, ay, az = ox + fx * c * OTS_AHEAD, oy - sn * OTS_AHEAD, oz + fz * c * OTS_AHEAD
			local k = R.ots
			ex, ey, ez = ex + (ox - ex) * k, ey + (oy - ey) * k, ez + (oz - ez) * k
			lx, ly, lz = lx + (ax - lx) * k, ly + (ay - ly) * k, lz + (az - lz) * k
		end
		R.ex, R.ey, R.ez, R.lx, R.ly, R.lz = ex, ey, ez, lx, ly, lz
		return ex, ey, ez, lx, ly, lz
	end

	return R
end
```

- [ ] **Step 4: Run to see them pass**

Run: `py tools/build_third_person.py --selftest`
Expected: `15 passed, 0 failed`, exit 0.

---

### Task 8: Entry, main and walking

**Files:**
- Create: `Modding Files/source/third_person/script/battle/mod/derpy_third_person.lua`, `.../script/derpy_tp/move.lua`, `.../script/derpy_tp/main.lua`
- Modify: `tools/third_person_tests.lua`, `tools/build_third_person.py` (loc check)

**Interfaces:**
- Produces `_G.DERPY_TP = E`, with:
  - state: `F` (session state), `S`, `K`, `D`, `P`;
  - modules: `rig`, `move`, `main`;
  - functions: `log(msg)`, `once(tag, msg)`, `say(key)`, `fail(err)`, `can_shoot()`;
  - persistent tables: `zoom_by_type`, `strikes`, `disabled`, `logged`.
- `move(E) -> {front_man(unit) -> m or nil, halt(), drive(now, kf, kr, run)}`.
- `main(E) -> {start(unit?), stop(why)}`. It registers the `"derpy_tp"` per-frame callback and the `Complete` phase callback.

- [ ] **Step 1: Write the failing tests**

```lua
local function general_on() H.fresh() H.tap("F2") end

T.toggle_starts_and_restores = function()
	general_on()
	check(H.E.F.on, "F2 starts third person")
	check(H.last("disable_orders")[2] == true, "player orders off")
	check(H.last("camera_functions")[3] == false, "camera input off")
	H.tap("F2")
	check(not H.E.F.on, "F2 again stops it")
	check(H.last("disable_orders")[2] == false, "player orders back")
	check(H.last("camera_functions")[3] == true, "camera input back")
end

T.picks_the_selected_unit = function()
	H.fresh({units = {{general = true}, {type = "wh_test_other", x = 20}}})
	H.select(H.units[2])
	H.tap("F2")
	check(H.E.F.unit == H.units[2], "the selected unit, not the general")
end

T.camera_follows_from_behind = function()
	general_on()
	H.step(2)
	check(H.eye and near(H.eye.z, -6, 0.05) and near(H.eye.y, 2.5, 0.05), "eye behind the general")
end

T.walking_orders_a_single_entity = function()
	general_on()
	H.down("W")
	H.step(3)
	check(H.count("uc:goto_location") == 1, "one order: the unit has not moved within 6 m of its 15 m point")
	local c = H.last("uc:goto_location")
	check(near(c[3].z, 15) and c[4] == false, "15 m ahead, walking")
	H.tap("Shift")
	check(H.count("uc:goto_location") == 2 and H.last("uc:goto_location")[4] == true, "run toggled re-orders")
	H.up("W")
	H.step(0.1)
	check(H.count("uc:halt") >= 1, "releasing W halts")
end

T.one_man_walks_alone = function()
	H.fresh({units = {{general = true}, {type = "wh_test_melee", men = 21, x = 40}}})
	H.select(H.units[2])
	H.tap("F2")
	local man = H.E.F.model
	check(man and man.id == 2011, "the front-centre man (the 11th of 21)")
	H.down("W")
	H.step(1)
	check(H.count("uc:goto_location") == 0, "the regiment gets no order")
	local s = H.last("steer")
	check(s[2] == man.id and near(s[4], 3, 0.6), "his steering point 3 m ahead")
	check(H.count("place") >= 1, "a nudge starts his walk")
	H.up("W")
	H.step(0.1)
	local hold = H.last("steer")
	check(near(hold[3], man.x) and near(hold[4], man.z), "with no key he holds his own spot")
end

T.focus_loss_halts_walking = function()
	general_on()
	H.down("W")
	H.step(1)
	H.focus = false
	H.step(0.2)
	check(H.count("uc:halt") >= 1, "losing focus halts")
	local orders = H.count("uc:goto_location")
	H.step(2)
	check(H.count("uc:goto_location") == orders, "no new order while unfocused")
end

T.mouse_turns_the_camera = function()
	general_on()
	H.step(0.1)
	H.mouse = {393, 0}
	H.step(1 / 60)
	check(near(H.E.rig.yaw, 393 * 0.004, 1e-6), "393 px at 0.004 rad/px")
	H.down("Middle mouse")
	H.step(0.1)
	check(not H.E.F.dragging, "the middle button frees the mouse")
end

T.errors_switch_it_off_after_three = function()
	general_on()
	for _ = 1, 3 do
		H.units[1]._error = true
		H.step(1 / 60)
		H.units[1]._error = nil
		H.tap("F2")
	end
	check(H.E.disabled, "three errors disable it")
	check(H.last("subtitle")[2] == "derpy_tp_switched_off", "the player is told")
	H.tap("F2")
	check(not H.E.F.on, "F2 no longer starts it")
	check(H.logged("test: position() failed"), "the error is in the script log")
end

T.multiplayer_and_replays_do_nothing = function()
	for _, opts in ipairs({{mp = true}, {replay = true}}) do
		H.fresh(opts)
		H.tap("F2")
		check(H.count("disable_orders") == 0, "nothing starts")
		check(H.last("subtitle") and H.last("subtitle")[2] == "derpy_tp_multiplayer", "the player is told")
	end
end

T.needs_memreader = function()
	H.fresh({memreader = false})
	check(H.last("subtitle") and H.last("subtitle")[2] == "derpy_tp_needs_memreader", "the player is told at load")
	H.tap("F2")
	check(H.count("disable_orders") == 0, "nothing runs")
end

T.battle_end_stops_and_locks = function()
	general_on()
	H.phase.Complete()
	check(not H.E.F.on and H.last("disable_orders")[2] == false, "restored when the battle ends")
	H.tap("F2")
	check(not H.E.F.on, "and stays off")
end

T.unit_lost_stops = function()
	general_on()
	H.units[1]._routing = true
	H.step(1 / 60)
	check(not H.E.F.on, "a routing unit ends the session")
end

T.conflicts_are_logged_once = function()
	H.fresh({mct = {key_back = "W"}})
	H.tap("F2") H.tap("F2") H.tap("F2")
	local n = 0
	for _, l in ipairs(H.log) do if l:find("key W for back", 1, true) then n = n + 1 end end
	check(n == 1, "logged once, not per toggle: " .. n)
end

T.debug_logs_every_check = function()
	H.fresh({mct = {debug_log = true}})
	H.tap("F2")
	check(H.logged("anim true") and H.logged("wheel true"), "the platform checks are logged")
	check(H.logged("men check on wh_test_unit: true"), "the men check is logged")
end

T.men_check_fails_plays_the_regiment_whole = function()
	H.fresh({units = {{general = true}, {type = "wh3_main_cth_inf_jade_warrior_crossbowmen_1", men = 20, x = 40,
		range = 160, ammo = 3960, men_ok = false}}})
	H.select(H.units[2])
	H.tap("F2")
	check(H.E.F.on and H.E.F.model == nil and not H.E.F.solo, "the regiment is played whole")
	check(H.count("uc:fire_at_will") == 0, "and keeps its own fire")
	check(H.logged("regiments are played whole: test: men off"), "the failed check is logged")
end

T.wheel_fails_zoom_on_keys = function()
	H.fresh({features = {input = true, anim = true, wheel = false}})
	H.tap("F2")
	H.step(0.1)
	check(H.logged("zoom is on the keys only"), "the failed check is logged")
	H.down("+")
	H.step(0.5)
	check(H.E.rig.zoom < 1, "+ still zooms in, got " .. H.E.rig.zoom)
end

T.input_unreadable_says_memreader = function()
	H.fresh({features = {input = false}})
	check(H.last("subtitle") and H.last("subtitle")[2] == "derpy_tp_needs_memreader", "the player is told")
	check(H.logged("no keyboard or mouse"), "the reason is logged")
end

T.one_man_regiment_with_shots_holds_fire = function()
	H.fresh({units = {{general = true}, {type = "wh3_main_cth_inf_jade_warrior_crossbowmen_1", men = 20, range = 160, ammo = 3960}}})
	H.select(H.units[2])
	H.tap("F2")
	check(H.units[2]._faw == false, "the rest of the regiment holds fire")
	H.tap("F2")
	check(H.units[2]._faw == true, "F2 off gives it back")
end
```

In `build_third_person.py` add the loc check above `def main`, and call it in `selftest()` (`bad += check_loc()`):

```python
def check_loc():
    """Every E.say key in the Lua has a loc row, and every loc row is said somewhere."""
    used = set()
    for full, _rel in lua_files():
        used |= set(re.findall(r'say\("(derpy_tp_[a-z_]+)"\)', open(full, encoding="utf-8").read()))
    bad = ["E.say('%s') has no loc row" % k for k in sorted(used - set(LOC))]
    bad += ["loc row %s is never said" % k for k in sorted(set(LOC) - used)]
    return bad
```

- [ ] **Step 2: Run to see them fail**

Run: `py tools/build_third_person.py --selftest`
Expected: the new tests FAIL (the entry file is missing, so `H.E` is nil), and the loc check reports 3 unsaid rows. Exit 1.

- [ ] **Step 3: Write the entry file**

```lua
-- Third-Person Battles. The only auto-loaded file: it loads the modules in script/derpy_tp/ itself, in
-- order, so nothing relies on the load order of script/battle/mod/. Design:
-- docs/superpowers/specs/2026-10-13-third-person-pack-design.md
local function load(name)
	local chunk, err = loadfile("/script/derpy_tp/" .. name)
	if not chunk then error("cannot load " .. name .. ": " .. tostring(err)) end
	setfenv(chunk, core:get_env())
	return chunk()
end

local ok, err = pcall(function()
	local old = _G.DERPY_TP
	if old and old.main then pcall(old.main.stop, "reloaded") end
	bm:remove_real_callback("derpy_tp")
	local E = {F = {on = false}, load = load, zoom_by_type = {}, strikes = 0, logged = {}}
	_G.DERPY_TP = E
	function E.log(msg) if E.S and E.S.debug then out("derpy_tp: " .. msg) end end
	function E.once(tag, msg) if not E.logged[tag] then E.logged[tag] = true out("derpy_tp: " .. msg) end end
	function E.say(key)
		bm:show_subtitle(key, true, true)
		bm:remove_real_callback("derpy_tp_say")
		bm:real_callback(function() bm:hide_subtitles() end, 6000, "derpy_tp_say")
	end
	E.K = load("keys")
	E.S = load("settings")(get_mct and get_mct(), E.K)
	local mr = _G.memreader_plus
	if not mr then
		E.say("derpy_tp_needs_memreader")
		E.once("memreader", "memreader Plus is not loaded; nothing runs")
		return
	end
	E.P = load("platform").build(mr)
	if not E.P.features.input then
		E.say("derpy_tp_needs_memreader")
		E.once("input", "no keyboard or mouse: " .. table.concat(E.P.problems, "; "))
		return
	end
	if bm:is_multiplayer() or bm:is_replay() then -- memory writes and scripted shots would desync
		bm:repeat_real_callback(function()
			if E.P.focused() and E.P.pressed(E.S.keys.toggle) then E.say("derpy_tp_multiplayer") end
		end, 1, "derpy_tp")
		return
	end
	E.D = load("data")
	E.rig = load("rig")(E)
	E.move = load("move")(E)
	E.main = load("main")(E)
end)
if not ok then out("derpy_tp: failed to load: " .. tostring(err)) end
```

- [ ] **Step 4: Write `move.lua`**

```lua
-- Walking (spec section 5; handoff 9b and 9i): a single entity or a whole regiment gets move orders,
-- and one man of a regiment is steered alone. Directions are relative to the camera's yaw.
-- return function(E) -> M.
local LEAD, REFRESH, STEER_DEG, STEER_GAP = 15, 6, 12, 0.5 -- m ahead; re-order within m; deg of turn; s between orders
local MAN_LEAD, MAN_NUDGE, MAN_STUCK = 3, 0.5, 0.05 -- one man: steering point m ahead; nudge m; stuck below m per 0.5 s

return function(E)
	local F, P = E.F, E.P
	local M = {}

	-- the regiment's front-centre man, where the captain stands (position_of_officer() returns nil);
	-- nil for a unit of fewer than two
	function M.front_man(unit)
		local ms = P.models(unit)
		if #ms < 2 then return nil end
		local q = unit:position()
		local b = math.rad(unit:bearing())
		local fx, fz = math.sin(b), math.cos(b)
		local best, best_score
		for _, m in ipairs(ms) do
			local x, _, z = P.model_pos(m)
			local dx, dz = x - q:get_x(), z - q:get_z()
			local score = -(dx * fx + dz * fz) + math.abs(dx * fz - dz * fx) * 0.5
			if not best_score or score < best_score then best, best_score = m, score end
		end
		return best
	end

	function M.halt()
		if F.driving then
			F.uc:halt()
			F.uc:release_control()
			F.driving = false
			E.log("halt")
		end
	end

	-- one man chases his own steering point, held every frame: MAN_LEAD ahead while a key is held, on his
	-- own spot when none is (so he does not walk back to his slot). An idle man ignores the point, so a
	-- held key that has not moved him MAN_STUCK in half a second gets a MAN_NUDGE shove of his position.
	local function man_drive(now, dx, dz)
		local m = F.model
		local x, _, z = P.model_pos(m)
		local tx, tz
		if dx == 0 and dz == 0 then
			F.man_hold = F.man_hold or {x, z}
			tx, tz, F.man_check = F.man_hold[1], F.man_hold[2], nil
		else
			F.man_hold = nil
			local c = F.man_check
			if not c or now - c[1] > 0.5 then
				if not c or (x - c[2]) ^ 2 + (z - c[3]) ^ 2 < MAN_STUCK * MAN_STUCK then
					P.place(m, x + dx * MAN_NUDGE, z + dz * MAN_NUDGE)
				end
				F.man_check = {now, x, z}
			end
			tx, tz = x + dx * MAN_LEAD, z + dz * MAN_LEAD
		end
		P.steer(m, tx, tz)
	end

	-- kf, kr: -1, 0 or 1 forward and right from the keys; run: the toggled run state
	function M.drive(now, kf, kr, run)
		local dx, dz = 0, 0
		if kf ~= 0 or kr ~= 0 then
			local fx, fz = math.sin(E.rig.yaw), math.cos(E.rig.yaw)
			dx, dz = kf * fx + kr * fz, kf * fz - kr * fx
			local n = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / n, dz / n
		end
		if F.model then man_drive(now, dx, dz) return end
		if kf == 0 and kr == 0 then M.halt() return end
		local q = F.unit:position()
		local px, py, pz = q:get_x(), q:get_y(), q:get_z()
		local need = not F.driving or kf ~= F.kf or kr ~= F.kr or run ~= F.run
			or (px - F.gx) ^ 2 + (pz - F.gz) ^ 2 < REFRESH * REFRESH
			or dx * F.dx + dz * F.dz < math.cos(math.rad(STEER_DEG)) and now - F.last_order >= STEER_GAP
		if need then
			F.gx, F.gz, F.dx, F.dz = px + dx * LEAD, pz + dz * LEAD, dx, dz
			F.uc:goto_location(v(F.gx, py, F.gz), run)
			F.uc:release_control()
			F.kf, F.kr, F.run, F.driving, F.last_order = kf, kr, run, true, now
			E.log("walk to " .. math.floor(F.gx) .. "," .. math.floor(F.gz) .. (run and " running" or ""))
		end
	end

	return M
end
```

- [ ] **Step 5: Write `main.lua`**

```lua
-- Third-person battle control: the toggle, starting and stopping one session, and the per-frame loop that
-- reads the keys and drives the rig, movement and combat (spec sections 5-8). return function(E) -> M.
local MAX_ERRORS, ZOOM_LARGE, ZOOM_NOTCH = 3, 2, 0.15

return function(E)
	local F, P = E.F, E.P
	local cam = bm:camera()
	local M = {}

	-- which player units are selected, by unique_ui_id; registered once per battle, a reload reuses it
	local SEL = _G.DERPY_TP_SELECTED or {ids = {}, set = {}}
	_G.DERPY_TP_SELECTED = SEL
	local general
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		local u = units:item(i)
		if u:is_commanding_unit() then general = u end
		local id = u:unique_ui_id()
		if not SEL.ids[id] then
			SEL.ids[id] = true
			bm:register_unit_selection_callback(u, function(unit, selected) SEL.set[unit:unique_ui_id()] = selected and unit or nil end)
		end
	end
	local function pick_unit()
		if bm:num_units_selected() == 1 then for _, u in pairs(SEL.set) do return u end end
		return general
	end

	function E.can_shoot() return F.unit:missile_range() > 0 and F.unit:ammo_left() > 0 end

	-- called every frame: the platform's Windows route when Task 1 found one (it may need re-applying each
	-- frame), else cinematic UI, switched on change only
	local function cursor(show)
		show = show and true or false
		if P.cursor then P.cursor(show) return end
		if F.cursor_shown == show then return end
		F.cursor_shown = show
		if show then bm:enable_cinematic_ui(false, true, false) else bm:enable_cinematic_ui(true, false, false) end
	end

	local function look()
		if P.held(E.S.keys.look_free) then F.dragging = false return end
		if not F.dragging then P.look_begin() F.dragging = true return end
		local dx, dy = P.look_delta()
		if dx ~= 0 or dy ~= 0 then E.rig.look(dx, dy) end
	end

	local function zoom(dt)
		local S = E.S
		local zin = P.held(S.keys.zoom_in) and 1 or 0
		local zout = P.held(S.keys.zoom_out) and 1 or 0
		local notches = P.wheel and P.wheel() or 0
		if zin ~= zout or notches ~= 0 then
			E.rig.zoom_by((zout - zin) * S.zoom_rate * dt - notches * ZOOM_NOTCH)
			E.zoom_by_type[F.utype] = E.rig.zoom
		end
	end

	local function tick(now, dt)
		local S, unit = E.S, F.unit
		if unit:number_of_men_alive() == 0 or unit:is_routing() then M.stop("unit lost") return end
		if F.model and not P.alive(unit, F.model) then -- he died: the next front-centre man, or the whole unit
			F.model, F.man_hold, F.man_check = E.move.front_man(unit), nil, nil
			if not F.model and F.held_fire then
				F.uc:fire_at_will(true)
				F.uc:release_control()
				F.held_fire, F.solo = false, false
			end
		end
		local x, y, z
		if F.model then x, y, z = P.model_pos(F.model) else local q = unit:position() x, y, z = q:get_x(), q:get_y(), q:get_z() end
		local kf, kr = 0, 0
		if P.focused() then
			look()
			cursor(not F.dragging)
			kf = (P.held(S.keys.forward) and 1 or 0) - (P.held(S.keys.back) and 1 or 0)
			kr = (P.held(S.keys.right) and 1 or 0) - (P.held(S.keys.left) and 1 or 0)
			if P.pressed(S.keys.run) then F.running = not F.running end
			zoom(dt)
		else
			F.dragging = false
			cursor(true)
		end
		if not F.firing then E.move.drive(now, kf, kr, F.running) end
		local ex, ey, ez, lx, ly, lz = E.rig.update(now, dt, x, y, z, F.ranged)
		cam:move_to(v(ex, ey, ez), v(lx, ly, lz), 0, false, -1, false)
		F.frames = F.frames + 1
	end

	function M.start(unit)
		if E.disabled or F.on then return end
		E.S = E.load("settings")(get_mct and get_mct(), E.K)
		local S = E.S
		for _, c in ipairs(S.conflicts) do
			E.once("conflict_" .. c.action, "key " .. c.key .. " for " .. c.action .. " is already used by " .. c.taken_by
				.. (c.now and ("; it uses " .. c.now .. " instead") or "; it is unbound"))
		end
		if not E.checked then
			E.checked = true
			local ok, why = P.check_anim()
			if not ok then E.once("anim", "swings become attack orders: " .. tostring(why)) end
			ok, why = P.open_wheel()
			if not ok then E.once("wheel", "zoom is on the keys only: " .. tostring(why)) end
			E.log("build " .. tostring(P.build) .. " via " .. tostring(P.source) .. ": anim " .. tostring(P.features.anim)
				.. ", wheel " .. tostring(P.features.wheel))
		end
		unit = unit or pick_unit()
		if not unit or unit:number_of_men_alive() == 0 then return end
		F.unit, F.uc, F.utype, F.arty = unit, create_unitcontroller(unit), unit:type(), unit:is_artillery()
		local men_ok, why = P.check_men(unit)
		F.men_ok = men_ok
		E.log("men check on " .. F.utype .. ": " .. tostring(men_ok))
		if not men_ok then E.once("men", "regiments are played whole: " .. tostring(why)) end
		F.model = S.one_man and men_ok and not F.arty and E.move.front_man(unit) or nil
		F.solo = F.model ~= nil and E.D.shots[F.utype] ~= nil
		F.held_fire = false
		if F.solo then F.uc:fire_at_will(false) F.uc:release_control() F.held_fire = true end
		F.ranged = E.can_shoot() and not F.arty
		F.firing, F.want_shot, F.next_shot, F.next_swing, F.swings, F.shot_n = false, false, 0, 0, 0, 0
		F.driving, F.dragging, F.running, F.cursor_shown = false, false, false, nil
		F.man_hold, F.man_check, F.frames = nil, nil, 0
		local x, y, z
		if F.model then x, y, z = P.model_pos(F.model) else local q = unit:position() x, y, z = q:get_x(), q:get_y(), q:get_z() end
		local zoom_now = E.zoom_by_type[F.utype] or (unit:is_infantry() and 1 or ZOOM_LARGE)
		E.rig.start(os.clock(), x, y, z, math.rad(unit:bearing()), zoom_now, F.ranged)
		if P.wheel then P.wheel() end -- drop what the wheel did while third person was off
		bm:disable_orders(true)
		cam:enable_functionality("CAMERA_ALL_FUNCTIONS", false)
		unit:select_in_ui()
		F.on = true
		E.log("on: " .. F.utype .. (F.model and ", one man" or "") .. (F.solo and ", shooting alone" or ""))
	end

	function M.stop(why)
		if not F.on then return end
		F.on = false
		E.move.halt()
		if F.held_fire then F.uc:fire_at_will(true) F.uc:release_control() F.held_fire = false end
		cursor(true)
		F.dragging = false
		bm:disable_orders(false)
		cam:enable_functionality("CAMERA_ALL_FUNCTIONS", true)
		E.log("off: " .. tostring(why))
	end

	function E.fail(err)
		out("derpy_tp: error: " .. tostring(err))
		pcall(M.stop, "error")
		E.strikes = E.strikes + 1
		if E.strikes >= MAX_ERRORS and not E.disabled then
			E.disabled = true
			E.say("derpy_tp_switched_off")
		end
	end

	local function frame()
		local ok, err = xpcall(function()
			local now = os.clock()
			local dt = now - (F.t or now)
			F.t = now
			if dt <= 0 or dt > 0.25 then dt = 0.016 end
			if P.focused() and P.pressed(E.S.keys.toggle) then
				if F.on then M.stop("key") else M.start() end
			elseif F.on then
				tick(now, dt)
			end
		end, debug.traceback)
		if not ok then E.fail(err) end
	end

	bm:register_phase_change_callback("Complete", function() pcall(M.stop, "battle over") E.disabled = true end)
	bm:repeat_real_callback(frame, 1, "derpy_tp")
	return M
end
```

- [ ] **Step 6: Run to see them pass**

Run: `py tools/build_third_person.py --selftest`
Expected: `33 passed, 0 failed`, the loc check clean, exit 0. If `one_man_walks_alone` fails on the man's id, print `man.id`: with 21 men in one rank the scorer picks the middle one, id `2011` (unit 2, model 11).

---

### Task 9: Combat - swings, ground fire, crosshair, mode key

**Files:**
- Create: `Modding Files/source/third_person/script/derpy_tp/combat.lua`
- Modify: the entry file (load combat), `main.lua` (`tick` and `stop`), `tools/third_person_tests.lua`

**Interfaces:**
- Consumes `E.rig` (`yaw`, `ex..lz`), `E.can_shoot()`, `E.fail`, `F.model`, `F.men_ok`, `F.uc`.
- Produces `combat(E) -> C`, with:
  - `crosshair(show)`, `aim_point(reach) -> x, y, z or nil`;
  - `melee(now, primary)`, `ground(now, clicked, held)`, `stop_fire()`;
  - `mode(now)`, `attack(now, clicked, held)`.

- [ ] **Step 1: Write the failing tests**

```lua
local function playing(o, enemies)
	H.fresh({units = {{general = true}, o}, enemies = enemies})
	H.select(H.units[2])
	H.tap("F2")
	H.step(0.1)
	return H.units[2]
end

T.swing_plays_on_one_man_with_cooldown = function()
	local u = playing({type = "wh_test_melee", men = 21, x = 40})
	H.tap("Left mouse")
	local p = H.all("play")
	check(#p == 1 and p[1][2] == 2011 and p[1][3] == 454, "ATTACK_1 on the front man only")
	H.tap("Left mouse")
	check(H.count("play") == 1, "no second swing inside 1.5 s")
	H.step(1.5)
	H.tap("Left mouse")
	check(H.count("play") == 2 and H.last("play")[3] == 455, "then ATTACK_2")
end

T.swing_falls_back_to_an_attack_order = function()
	H.fresh({features = {input = true, anim = false, wheel = true}, enemies = {{z = 30, men = 10}}})
	H.tap("F2")
	H.step(0.1)
	H.tap("Left mouse")
	check(H.count("play") == 0, "no forged swing without the animation command")
	check(H.count("uc:attack_unit") == 1 and H.last("uc:attack_unit")[3] == H.enemies[1], "an attack order on the enemy ahead")
end

T.ground_fire_commits_one_shot = function()
	local u = playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	check(H.E.F.ranged, "a unit that can shoot starts in ranged mode")
	H.tap("Left mouse")
	check(H.count("uc:attack_location") == 1, "a click orders ground fire")
	H.step(1)
	check(H.count("uc:halt") == 0, "released early, the order stays until a shot leaves")
	u._ammo = 9
	H.step(1 / 60)
	check(H.count("uc:halt") == 1, "the shot left: halted")
end

T.ground_fire_holds_while_held = function()
	local u = playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	H.down("Left mouse")
	H.step(3)
	u._ammo = 7
	H.step(1)
	check(H.count("uc:attack_location") == 1 and H.count("uc:halt") == 0, "held: the order stays, shots or not")
	H.up("Left mouse")
	H.step(1 / 60)
	check(H.count("uc:halt") == 1, "released after a shot: halted")
end

T.ground_fire_turns_first = function()
	local u = playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	H.mouse = {393, 0} -- a quarter turn of the camera
	H.step(1 / 60)
	H.tap("Left mouse")
	check(H.count("uc:goto_location_angle_width") == 1, "turns to the aim first")
	check(H.count("uc:attack_location") == 0, "and does not fire outside its arc")
end

T.ground_fire_stops_on_focus_loss = function()
	local u = playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	H.down("Left mouse")
	H.step(0.5)
	H.focus = false
	u._ammo = 9
	H.step(0.1)
	check(H.count("uc:halt") == 1, "unfocused with a shot gone: halted")
end

T.mode_switches_melee_and_ranged = function()
	playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	H.tap("Right mouse")
	check(not H.E.F.ranged, "right click: melee")
	H.tap("Right mouse")
	check(H.E.F.ranged, "and back to ranged")
end

T.crosshair_shows_in_ranged_mode_only = function()
	playing({type = "wh_test_ranged_lord", men = 1, range = 100, ammo = 10})
	local x = find_uicomponent(H.root, "derpy_tp_crosshair")
	check(x and x:Visible(), "ranged and aiming: the crosshair shows")
	check(not find_uicomponent(x, "bl_frame"):Visible(), "only the crosshair part")
	H.tap("Right mouse")
	check(not x:Visible(), "melee: hidden")
	H.tap("Right mouse")
	H.tap("F2")
	check(not x:Visible(), "F2 off: hidden")
end
```

- [ ] **Step 2: Run to see them fail**

Run: `py tools/build_third_person.py --selftest`
Expected: the 8 combat tests FAIL. Exit 1.

- [ ] **Step 3: Write `combat.lua`**

```lua
-- Fighting from third person (spec section 6): swings, ranged fire by unit kind, the crosshair, and the
-- artillery hand-over to the game's Manual fire mode. return function(E) -> C.
local SLOTS_LMB, SLOTS_RMB = {454, 455, 456, 457}, {458, 459, 460} -- ATTACK_1-4 and ATTACK_5-7
local TURN_DEG, TURN_WAIT_MS, MAX_MODELS = 25, 350, 160
local AIM_COS, AIM_RANGE, AIM_CLOSE = 0.707, 150, 8 -- a melee target: inside 45 deg and 150 m, or 8 m any way
local AIM_MIN, FIRE_REAIM, FIRE_ARC, FIRE_COMMIT, STEER_GAP = 10, 5, 20, 4, 0.5

return function(E)
	local F, P = E.F, E.P
	local C = {}

	-- the aiming dot: our own instance of the first-person layout with everything but its crosshair hidden
	function C.crosshair(show)
		show = show and true or false -- SetVisible(nil) corrupts the game's strings
		if F.xhair == show then return end
		F.xhair = show
		local root = core:get_ui_root()
		local ui = find_uicomponent(root, "derpy_tp_crosshair")
		if not ui then
			if not show then return end
			ui = UIComponent(root:CreateComponent("derpy_tp_crosshair", "ui/battle ui/first_person_ui"))
			for i = 0, ui:ChildCount() - 1 do local c = UIComponent(ui:Find(i)) c:SetVisible(c:Id() == "crosshair") end
			local x = find_uicomponent(ui, "crosshair")
			local sw, sh = core:get_screen_resolution()
			local w, h = x:Dimensions()
			x:MoveTo(math.floor(sw / 2 - w / 2), math.floor(sh / 2 - h / 2))
		end
		ui:SetVisible(show)
	end

	-- the ground under the screen centre: last frame's camera ray meets the ground at the shooter's height;
	-- looking level or up, or past reach, clamps to reach along the view. nil before the first frame.
	function C.aim_point(reach)
		local R = E.rig
		if not R.ex then return nil end
		local ux, gy, uz
		if F.model then ux, gy, uz = P.model_pos(F.model) else local q = F.unit:position() ux, gy, uz = q:get_x(), q:get_y(), q:get_z() end
		local dx, dy, dz = R.lx - R.ex, R.ly - R.ey, R.lz - R.ez
		local hx, hz, want = dx, dz, reach
		if dy < 0 then
			local t = (R.ey - gy) / -dy
			hx, hz = R.ex + dx * t - ux, R.ez + dz * t - uz
			want = math.max(AIM_MIN, math.min(reach, math.sqrt(hx * hx + hz * hz)))
		end
		local d = math.sqrt(hx * hx + hz * hz)
		if d < 0.01 then hx, hz, d = math.sin(R.yaw), math.cos(R.yaw), 1 end
		return ux + hx / d * want, gy, uz + hz / d * want
	end

	-- the enemy nearest the aim: inside AIM_COS of the camera's forward and AIM_RANGE, or AIM_CLOSE any
	-- way; distance weighted by how far off the aim it is
	local function pick_target()
		local q = F.unit:position()
		local qx, qz = q:get_x(), q:get_z()
		local fx, fz = math.sin(E.rig.yaw), math.cos(E.rig.yaw)
		local best, best_score
		local armies = bm:get_non_player_alliance():armies()
		for a = 1, armies:count() do
			local list = armies:item(a):units()
			for i = 1, list:count() do
				local e = list:item(i)
				if e:is_valid_target() and not e:is_routing() and e:number_of_men_alive() > 0 then
					local p = e:position()
					local dx, dz = p:get_x() - qx, p:get_z() - qz
					local d = math.sqrt(dx * dx + dz * dz)
					local c = (dx * fx + dz * fz) / math.max(d, 0.01)
					if d < AIM_CLOSE or (c > AIM_COS and d < AIM_RANGE) then
						local score = d * (2 - c)
						if not best_score or score < best_score then best, best_score = e, score end
					end
				end
			end
		end
		return best
	end

	-- the next attack animation of the list, on the one man or every model; a whole unit more than
	-- TURN_DEG off the camera is turned first
	local function swing(slots)
		local slot = slots[F.swings % #slots + 1]
		F.swings = F.swings + 1
		local function go()
			if F.model then P.play(F.model, slot) return end
			local ms = P.models(F.unit)
			for i = 1, math.min(#ms, MAX_MODELS) do P.play(ms[i], slot) end
		end
		local want = math.deg(E.rig.yaw) % 360
		local off = math.abs((want - F.unit:bearing() + 540) % 360 - 180)
		if off > TURN_DEG and not F.model then
			local q = F.unit:position()
			F.uc:goto_location_angle_width(v(q:get_x(), q:get_y(), q:get_z()), want, math.max(F.unit:ordered_width(), 1), false)
			F.uc:release_control()
			F.driving = false
			bm:real_callback(function()
				local ok, err = xpcall(function() if F.on then go() end end, debug.traceback)
				if not ok then E.fail(err) end
			end, TURN_WAIT_MS, "derpy_tp_swing_" .. F.swings)
		else
			go()
		end
	end

	function C.melee(now, primary)
		if now < F.next_swing then return end
		F.next_swing = now + E.S.swing_cooldown
		if P.features.anim and F.men_ok then swing(primary and SLOTS_LMB or SLOTS_RMB) return end
		local target = pick_target()
		if not target then return end
		F.uc:attack_unit(target, primary, F.running)
		F.uc:release_control()
		F.driving = false
		E.log("attack order on " .. target:type())
	end

	-- ground fire at the aim (single entities and regiments without a one-man shot): turned first when
	-- the aim is outside FIRE_ARC; re-aimed when the point moves FIRE_REAIM, no faster than STEER_GAP
	local function fire(now)
		local ax, ay, az = C.aim_point(F.unit:missile_range())
		if not ax then return end
		local q = F.unit:position()
		local want = math.deg(math.atan2(ax - q:get_x(), az - q:get_z())) % 360
		if math.abs((want - F.unit:bearing() + 540) % 360 - 180) > FIRE_ARC then
			local turned = F.turn_to and math.abs((want - F.turn_to + 540) % 360 - 180) <= FIRE_ARC / 2
			if not turned and now - (F.last_order or 0) >= STEER_GAP then
				F.uc:goto_location_angle_width(v(q:get_x(), q:get_y(), q:get_z()), want, math.max(F.unit:ordered_width(), 1), false)
				F.uc:release_control()
				F.turn_to, F.fire_at, F.last_order, F.driving = want, nil, now, false
			end
			return
		end
		F.turn_to = nil
		if F.fire_at and ((ax - F.fire_at[1]) ^ 2 + (az - F.fire_at[2]) ^ 2 < FIRE_REAIM * FIRE_REAIM or now - F.last_order < STEER_GAP) then return end
		F.uc:attack_location(v(ax, ay, az), false)
		F.uc:release_control()
		F.fire_at, F.last_order, F.driving = {ax, az}, now, false
		F.fire_order_t = F.fire_order_t or now
		E.log("ground fire at " .. math.floor(ax) .. "," .. math.floor(az))
	end

	function C.stop_fire()
		F.firing, F.fire_at, F.turn_to, F.fire_order_t = false, nil, nil, nil
		F.uc:halt()
		F.uc:release_control()
	end

	-- a click commits to one shot: the order stays until ammo drops or FIRE_COMMIT passes; held, it stays
	function C.ground(now, clicked, held)
		if clicked and not F.firing and E.can_shoot() then F.firing, F.fire_ammo = true, F.unit:ammo_left() end
		if not F.firing then return end
		local shot = F.unit:ammo_left() < F.fire_ammo
		local expired = F.fire_order_t and now - F.fire_order_t > FIRE_COMMIT
		if not E.can_shoot() or (not held and (shot or expired)) then C.stop_fire() else fire(now) end
	end

	function C.mode(now)
		if F.arty then return end
		if E.can_shoot() then
			F.ranged = not F.ranged
			if F.firing then C.stop_fire() end
			F.want_shot = false
		else
			C.melee(now, false)
		end
	end

	function C.attack(now, clicked, held)
		if F.ranged then
			C.ground(now, clicked, held)
		elseif clicked and not F.arty then
			C.melee(now, true)
		end
	end

	return C
end
```

- [ ] **Step 4: Wire it in**

In the entry file, after `E.move = load("move")(E)`, add `E.combat = load("combat")(E)`.

In `main.lua`, replace the whole `local function tick(now, dt) ... end` with:

```lua
	local function tick(now, dt)
		local S, unit = E.S, F.unit
		if unit:number_of_men_alive() == 0 or unit:is_routing() then M.stop("unit lost") return end
		if F.model and not P.alive(unit, F.model) then -- he died: the next front-centre man, or the whole unit
			F.model, F.man_hold, F.man_check = E.move.front_man(unit), nil, nil
			if not F.model and F.held_fire then
				F.uc:fire_at_will(true)
				F.uc:release_control()
				F.held_fire, F.solo = false, false
			end
		end
		local x, y, z
		if F.model then x, y, z = P.model_pos(F.model) else local q = unit:position() x, y, z = q:get_x(), q:get_y(), q:get_z() end
		local kf, kr = 0, 0
		if P.focused() then
			look()
			cursor(not F.dragging)
			kf = (P.held(S.keys.forward) and 1 or 0) - (P.held(S.keys.back) and 1 or 0)
			kr = (P.held(S.keys.right) and 1 or 0) - (P.held(S.keys.left) and 1 or 0)
			if P.pressed(S.keys.run) then F.running = not F.running end
			local clicked, held = P.pressed(S.keys.attack), P.held(S.keys.attack)
			if P.pressed(S.keys.mode) and F.dragging then E.combat.mode(now) end
			if not F.on then return end -- the mode key can hand artillery to Manual fire, which ends this session
			E.combat.attack(now, F.dragging and clicked, F.dragging and held)
			zoom(dt)
		else
			F.dragging = false
			cursor(true)
			E.combat.attack(now, false, false)
		end
		if not F.firing then E.move.drive(now, kf, kr, F.running) end
		E.combat.crosshair(F.ranged and F.dragging)
		local ex, ey, ez, lx, ly, lz = E.rig.update(now, dt, x, y, z, F.ranged)
		cam:move_to(v(ex, ey, ez), v(lx, ly, lz), 0, false, -1, false)
		F.frames = F.frames + 1
	end
```

In `M.stop`, after `E.move.halt()`, add:

```lua
		if F.firing then E.combat.stop_fire() end
		E.combat.crosshair(false)
```

- [ ] **Step 5: Run to see them pass**

Run: `py tools/build_third_person.py --selftest`
Expected: `41 passed, 0 failed`, exit 0.

---

### Task 10: One man's own shot

**Files:**
- Modify: `combat.lua` (add `solo` and change `attack`), `tools/third_person_tests.lua`

**Interfaces:**
- Consumes `E.D.shots[F.utype] = {key, reload, n}`, `E.S.reload_factor`, `P.play/alive/same/model_pos`.
- Produces `C.solo(now, clicked, held)`.
- `F.want_shot` remembers a click made during reload, so "a click always fires one shot" holds.

- [ ] **Step 1: Write the failing tests**

```lua
local XBOW = "wh3_main_cth_inf_jade_warrior_crossbowmen_1"
local function crossbowmen(extra)
	local o = {type = XBOW, men = 21, x = 40, range = 160, ammo = 3960}
	for k, val in pairs(extra or {}) do o[k] = val end
	return playing(o)
end

T.solo_click_fires_one_shot = function()
	local u = crossbowmen()
	H.tap("Left mouse")
	H.step(0.5)
	local l = H.all("launch")
	check(#l == 1 and l[1][2] == "wh3_cth_crossbow_bolt", "one crossbow bolt")
	check(near(l[1][3].y, 1.5) and near(l[1][4].y, 1), "from his chest, to 1 m above the aim")
	check(u._ammo == 3959, "one bolt off the regiment's ammo, got " .. u._ammo)
	local p = H.all("play")
	check(p[1][2] == 2011 and p[1][3] == 1557 and p[2][3] == 1564, "FIRE_LEVEL then RELOAD_1 on him only")
	check(H.count("uc:attack_location") == 0, "the regiment gets no fire order")
end

T.solo_hold_repeats_at_the_reload_pace = function()
	crossbowmen()
	H.down("Left mouse")
	H.step(7)
	check(H.count("launch") == 3, "3.25 s reload (13 x 0.25): shots near 0.3, 3.55 and 6.8 s, got " .. H.count("launch"))
end

T.solo_click_during_reload_is_kept = function()
	crossbowmen()
	H.tap("Left mouse")
	H.step(1)
	H.tap("Left mouse")
	H.step(1)
	check(H.count("launch") == 1, "the second click waits for the reload")
	H.step(2)
	check(H.count("launch") == 2, "then fires")
end

T.solo_dead_man_launches_nothing = function()
	local u = crossbowmen()
	local man = H.E.F.model
	H.tap("Left mouse")
	man.alive = false
	H.step(0.5)
	check(H.count("launch") == 0 and u._ammo == 3960, "he died in his fire animation: no bolt, no ammo")
	check(H.E.F.model and H.E.F.model ~= man, "the next front-centre man took over")
end

T.solo_ammo_runs_out = function()
	local u = crossbowmen({ammo = 1, start_ammo = 22})
	H.down("Left mouse")
	H.step(10)
	check(H.count("launch") == 1 and u._ammo == 0, "one bolt, then empty")
	check(H.E.F.ranged, "still in ranged mode")
end

T.solo_iron_hail_fires_three = function()
	playing({type = "wh3_main_cth_inf_iron_hail_gunners_0", men = 21, x = 40, range = 90, ammo = 3960})
	H.tap("Left mouse")
	H.step(0.5)
	check(H.count("launch") == 3, "projectile_number 3")
end

T.error_restores_everything = function()
	H.fresh({cursor_route = true, units = {{general = true}, {type = XBOW, men = 21, x = 40, range = 160, ammo = 3960}}})
	H.select(H.units[2])
	H.tap("F2")
	H.step(0.1)
	local x = find_uicomponent(H.root, "derpy_tp_crosshair")
	check(x and x:Visible() and H.units[2]._faw == false, "playing: crosshair up, the regiment holding fire")
	H.E.rig.update = function() error("test: rig failed") end
	H.step(1 / 60)
	check(not H.E.F.on, "stopped")
	check(H.last("disable_orders")[2] == false and H.last("camera_functions")[3] == true, "orders and camera back")
	check(H.units[2]._faw == true, "fire at will back")
	check(not x:Visible(), "crosshair hidden")
	check(H.last("cursor")[2] == true, "cursor shown")
end

T.solo_regiment_down_to_one_restores_fire = function()
	local u = crossbowmen({men = 2})
	check(u._faw == false, "holding fire")
	H.E.F.model.alive = false
	H.step(1 / 60)
	check(u._faw == true, "one man left: the unit fires at will again")
	check(H.E.F.model == nil and not H.E.F.solo, "played as a single entity")
end
```

- [ ] **Step 2: Run to see them fail**

Run: `py tools/build_third_person.py --selftest`
Expected: the solo tests FAIL (`attack_location` recorded instead of `launch`). Two may already pass, and both stay as guards:
- `solo_regiment_down_to_one_restores_fire`, since Task 9's tick already handles it;
- `error_restores_everything`, since Tasks 8-9 already restore.

Prove each guard can fail: delete the `fire_at_will(true)` line from `M.stop`, watch `error_restores_everything` fail, then put the line back. Exit 1.

- [ ] **Step 3: Add the solo shot**

In `combat.lua`, add the constants line under the others:

```lua
local SLOT_FIRE, SLOT_RELOAD = 1557, 1564 -- FIRE_LEVEL, RELOAD_1
local SHOT_DELAY_MS, SHOT_H, SHOT_FWD, SHOT_SPREAD = 300, 1.5, 0.6, 1.5 -- anim to release; m up; m forward; m jitter
```

Add above `function C.mode(now)`:

```lua
	-- one man's own shot (handoff 9j): his fire animation, then bm:trigger_projectile_launch from his chest
	-- to the aim point SHOT_DELAY_MS later, one shot off the regiment's ammo, his reload animation. The
	-- projectile has no unit behind it; the regiment's fire-at-will is off while he is played.
	local function man_shot(now)
		local s = E.D.shots[F.utype]
		local ax, ay, az = C.aim_point(F.unit:missile_range())
		if not ax then return end
		F.next_shot = now + s[2] * E.S.reload_factor
		F.shot_n = F.shot_n + 1
		local m, unit = F.model, F.unit
		P.play(m, SLOT_FIRE)
		bm:real_callback(function()
			local ok, err = xpcall(function()
				if not F.on or not F.model or not P.same(F.model, m) or not P.alive(unit, m) then return end
				local x, y, z = P.model_pos(m)
				local dx, dz = ax - x, az - z
				local d = math.max(math.sqrt(dx * dx + dz * dz), 0.01)
				local from = v(x + dx / d * SHOT_FWD, y + SHOT_H, z + dz / d * SHOT_FWD)
				for k = 1, s[3] do
					local jx, jz = 0, 0
					if k > 1 then jx, jz = (math.random() * 2 - 1) * SHOT_SPREAD, (math.random() * 2 - 1) * SHOT_SPREAD end
					bm:trigger_projectile_launch(s[1], from, v(ax + jx, ay + 1, az + jz))
				end
				local ammo, full = unit:ammo_left(), unit:starting_ammo()
				if full > 0 then unit:set_current_ammo_unary(math.max(0, ammo - 1) / full) end
				P.play(m, SLOT_RELOAD)
				E.log("shot " .. s[1])
			end, debug.traceback)
			if not ok then E.fail(err) end
		end, SHOT_DELAY_MS, "derpy_tp_shot_" .. F.shot_n)
	end

	-- a click always fires one shot, kept through a reload; held, he fires again each time he has reloaded
	function C.solo(now, clicked, held)
		if clicked then F.want_shot = true end
		if not (F.want_shot or held) then return end
		if not E.can_shoot() then F.want_shot = false return end
		if now < F.next_shot then return end
		F.want_shot = false
		man_shot(now)
	end
```

Replace `C.attack` with:

```lua
	function C.attack(now, clicked, held)
		if F.ranged then
			if F.solo then C.solo(now, clicked, held) else C.ground(now, clicked, held) end
		elseif clicked and not F.arty then
			C.melee(now, true)
		end
	end
```

- [ ] **Step 4: Run to see them pass**

Run: `py tools/build_third_person.py --selftest`
Expected: `49 passed, 0 failed`, exit 0. If `solo_dead_man_launches_nothing` fails on "the next man took over": the tick re-picks on the frame after `alive = false`, so check that the test steps at least one frame (it steps 0.5 s).

---

### Task 11: Artillery and the game's Manual fire mode

**Files:**
- Modify: `combat.lua` (`manual`, `manual_exit`, and the arty branch of `mode`), `main.lua` (`frame`), `tools/third_person_tests.lua`

**Interfaces:**
- Produces `C.manual()` and `C.manual_exit()`, and the state `E.fp = {unit, seen, clicked, t, exit_at}` while Manual fire is open.
- Consumes `E.main.start(unit)` and `E.main.stop(why)`.

- [ ] **Step 1: Write the failing tests**

```lua
local function a_battery()
	local u = playing({type = "wh_test_cannon", men = 20, x = 40, range = 400, ammo = 100, arty = true})
	local hud = H.comp("hud_battle", H.root)
	local port = H.comp("porthole_parent", hud)
	H.comp("button_unit_manual_fire", port)
	return u
end

T.artillery_mode_opens_manual_fire = function()
	local u = a_battery()
	check(not H.E.F.ranged, "artillery does not start in ranged mode")
	H.tap("Right mouse")
	check(not H.E.F.on, "control steps aside")
	check(H.last("select_in_ui")[2] == u._id, "the battery is selected, so the HUD carries its button")
	H.step(0.2)
	check(H.last("click") and H.last("click")[2] == "button_unit_manual_fire", "the button is clicked")
	local fp = H.comp("first_person_ui", H.root)
	H.step(0.2)
	fp:SetVisible(false)
	H.step(0.2)
	check(H.E.F.on and H.E.F.unit == u, "the game closed it: control comes back")
end

T.f2_leaves_manual_fire = function()
	a_battery()
	H.tap("Right mouse")
	H.step(0.2)
	H.comp("first_person_ui", H.root)
	H.step(0.2)
	H.tap("F2")
	H.step(0.5)
	check(H.count("click") == 2, "F2 clicks the button again a beat later")
	check(H.E.F.on, "and control comes back")
end

T.manual_fire_without_a_button_gives_control_back = function()
	playing({type = "wh_test_cannon", men = 20, x = 40, range = 400, ammo = 100, arty = true})
	H.tap("Right mouse")
	H.step(3.5)
	check(H.count("click") == 0 and H.E.F.on, "no button: back in control after 3 s")
	check(H.logged("no Manual fire button"), "and the reason is logged")
end
```

- [ ] **Step 2: Run to see them fail**

Run: `py tools/build_third_person.py --selftest`
Expected: 3 FAILs. Exit 1.

- [ ] **Step 3: Add the hand-over to `combat.lua`**

Add above `function C.mode(now)`:

```lua
	-- artillery: the game's own Manual fire mode (Insert), its first-person gun view (handoff 9h). Only
	-- units whose engine is in first_person_engines have it. Control stops, the unit is selected so the
	-- HUD carries its button, the button is clicked, and a watcher gives control back when the
	-- first-person UI closes (the game's own way out) or the mode key or F2 asks - those click the button
	-- again 0.25 s later, only if the mode is still open. The watcher is a repeat registered straight from
	-- the key, never inside a one-shot: CA frees a one-shot's id before running it.
	local function manual_button() return find_uicomponent(core:get_ui_root(), "hud_battle", "porthole_parent", "button_unit_manual_fire") end
	local function manual_open() local fp = find_uicomponent(core:get_ui_root(), "first_person_ui") return fp and fp:Visible() or false end

	local function watch()
		local ok, err = xpcall(function()
			local fp = E.fp
			if not fp then bm:remove_real_callback("derpy_tp_fp") return end
			local now, open = os.clock(), manual_open()
			if not fp.clicked then
				local b = manual_button()
				if b and b:Visible() then b:SimulateLClick() fp.clicked, fp.t = true, now return end
				if now - fp.t < 2 then return end
				fp.clicked = true
				E.once("fp_button_" .. fp.unit:type(), "no Manual fire button for " .. fp.unit:type())
			end
			if open then fp.seen = true end
			if open and P.pressed(E.S.keys.mode) and not fp.exit_at then fp.exit_at = now + 0.25 end
			local timed_out = not fp.seen and now - fp.t > 3
			local asked = fp.exit_at and now >= fp.exit_at
			if timed_out or asked or (fp.seen and not open) then
				bm:remove_real_callback("derpy_tp_fp")
				if open and asked then local b = manual_button() if b then b:SimulateLClick() end end
				E.fp = nil
				E.main.start(fp.unit)
			end
		end, debug.traceback)
		if not ok then bm:remove_real_callback("derpy_tp_fp") E.fp = nil E.fail(err) end
	end

	function C.manual()
		local u = F.unit
		E.main.stop("manual fire")
		u:select_in_ui()
		E.fp = {unit = u, seen = false, clicked = false, t = os.clock()}
		bm:repeat_real_callback(watch, 100, "derpy_tp_fp")
	end

	function C.manual_exit()
		if E.fp and not E.fp.exit_at then E.fp.exit_at = os.clock() + 0.25 end
	end
```

In `C.mode`, replace `if F.arty then return end` with `if F.arty then C.manual() return end`.

- [ ] **Step 4: Let F2 leave Manual fire**

In `main.lua` `frame()`, replace

```lua
				if F.on then M.stop("key") else M.start() end
```

with

```lua
				if E.fp then E.combat.manual_exit()
				elseif F.on then M.stop("key")
				else M.start() end
```

- [ ] **Step 5: Run to see them pass**

Run: `py tools/build_third_person.py --selftest`
Expected: `52 passed, 0 failed`, exit 0.

---

### Task 12: Ability keys

**Files:**
- Create: `Modding Files/source/third_person/script/derpy_tp/abilities.lua`
- Modify: the entry file, `main.lua` (`tick`), `tools/third_person_tests.lua`

**Interfaces:**
- Produces `abilities(E) -> A` with `cast(n) -> nil` (cast) or a reason string (nothing cast).
- Consumes `E.D.abilities`, `E.combat.aim_point(reach)` and `E.rig`'s ray.

- [ ] **Step 1: Write the failing tests**

```lua
local BARRAGE, FIREBALL = "wh2_dlc09_army_abilities_barrage_of_the_legion", "wh_main_spell_fire_fireball"

T.ability_ground_lands_on_the_crosshair = function()
	H.fresh({units = {{general = true, abilities = {BARRAGE}}}})
	H.tap("F2")
	H.step(0.1)
	H.tap("1")
	local c = H.last("uc:perform_special_ability_ground")
	check(c and c[3] == BARRAGE, "cast on the ground")
	check(c[4].z > 30 and c[4].z < 40 and near(c[4].x, 0, 0.01), "where the view meets the ground, ~37 m ahead: " .. c[4].z)
end

T.ability_enemy_goes_to_the_unit_on_the_ray = function()
	H.fresh({units = {{general = true, abilities = {FIREBALL}}}, enemies = {{x = 30, z = 50}, {x = 0, z = 50}}})
	H.tap("F2")
	H.step(0.1)
	H.tap("1")
	local c = H.last("uc:perform_special_ability")
	check(c and c[3] == FIREBALL and c[4] == H.enemies[2], "the enemy straight ahead, not the one 30 m aside")
end

T.ability_unknown_kind_casts_on_self = function()
	H.fresh({units = {{general = true, abilities = {"wh_test_modded_ability"}}}})
	H.tap("F2")
	H.step(0.1)
	H.tap("1")
	local c = H.last("uc:perform_special_ability")
	check(c and c[3] == "wh_test_modded_ability" and c[4] == nil, "no target")
end

T.ability_refused_or_missing_does_nothing = function()
	H.fresh({units = {{general = true, abilities = {FIREBALL}, can = {[FIREBALL] = false}}}, enemies = {{z = 50}}})
	H.tap("F2")
	H.step(0.1)
	H.tap("1")
	H.tap("2")
	check(H.count("uc:perform_special_ability") == 0 and H.count("uc:perform_special_ability_ground") == 0, "nothing cast")
end
```

- [ ] **Step 2: Run to see them fail**

Run: `py tools/build_third_person.py --selftest`
Expected: 4 FAILs. Exit 1.

- [ ] **Step 3: Write `abilities.lua`**

```lua
-- Ability keys 1-0 (spec section 6): key N casts the unit's Nth non-passive ability, aimed by its kind
-- in data.lua - the crosshair's ground point, the unit nearest the crosshair ray, or itself (a modded
-- ability data.lua does not know casts on itself). return function(E) -> A.
local RANGE = 300 -- m: farthest ground point or unit an ability is aimed at

return function(E)
	local F = E.F
	local A = {}

	-- the unit, enemy or friendly, nearest the camera's ray, in front of the camera
	local function nearest_to_ray(enemy)
		local R = E.rig
		local dx, dy, dz = R.lx - R.ex, R.ly - R.ey, R.lz - R.ez
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		dx, dy, dz = dx / len, dy / len, dz / len
		local alliance = enemy and bm:get_non_player_alliance() or bm:get_player_alliance()
		local best, best_d
		local armies = alliance:armies()
		for a = 1, armies:count() do
			local units = armies:item(a):units()
			for i = 1, units:count() do
				local u = units:item(i)
				if u:number_of_men_alive() > 0 and not u:is_routing() then
					local p = u:position()
					local px, py, pz = p:get_x() - R.ex, p:get_y() - R.ey, p:get_z() - R.ez
					local t = px * dx + py * dy + pz * dz
					if t > 0 and t < RANGE then
						local cx, cy, cz = px - dx * t, py - dy * t, pz - dz * t
						local d = cx * cx + cy * cy + cz * cz
						if not best_d or d < best_d then best, best_d = u, d end
					end
				end
			end
		end
		return best
	end

	function A.cast(n)
		local list = F.unit:owned_non_passive_special_abilities()
		local key = list and list[n]
		if not key then return "no ability in slot " .. n end
		if not F.unit:can_perform_special_ability(key) then return key .. " cannot be cast now" end
		local kind = E.D.abilities[key] or "self"
		if kind == "ground" then
			local x, y, z = E.combat.aim_point(RANGE)
			if not x then return "no aim yet" end
			F.uc:perform_special_ability_ground(key, v(x, y, z))
		elseif kind == "enemy" or kind == "friend" then
			local target = nearest_to_ray(kind == "enemy")
			if not target then return "no " .. kind .. " near the crosshair for " .. key end
			F.uc:perform_special_ability(key, target)
		else
			F.uc:perform_special_ability(key)
		end
		F.uc:release_control()
		F.driving = false
		E.log("cast " .. key .. " (" .. kind .. ")")
		return nil
	end

	return A
end
```

- [ ] **Step 4: Wire it in**

In the entry file, after `E.combat = load("combat")(E)`, add `E.abilities = load("abilities")(E)`.

In `main.lua` `tick`, after the line `E.combat.attack(now, F.dragging and clicked, F.dragging and held)`, add:

```lua
			for n = 1, 10 do
				if P.pressed(S.keys["ability_" .. n]) and F.dragging then
					local why = E.abilities.cast(n)
					if why then E.log(why) end
				end
			end
```

- [ ] **Step 5: Run to see them pass**

Run: `py tools/build_third_person.py --selftest`
Expected: `56 passed, 0 failed`, exit 0.

---

### Task 13: The bridge loader and the live platform check

The first run against the real game: memreader, the import parse, the command pattern and the model checks.

**Files:**
- Modify: `tools/build_third_person.py` (`bridge()`, the `--bridge` flag)
- Create (generated): `Modding Files/source/lord_control/probes/zz_tp_load.lua`; and by hand `.../probes/zz_tp_read.lua`

**Interfaces:** Produces `zz_tp_load.lua`, which loads every module into a running battle and returns `{loaded, build, problems}`. `zz_tp_read.lua` returns `E.P.features`, `E.P.problems`, `E.P.source` and the live `F` fields.

- [ ] **Step 1: Add `bridge()`**

```python
def bridge(keep=None):
    """Write probes/zz_tp_load.lua: every module as a long string, loadfile pointed at them for the
    entry file's run, then put back. Sent with probes/send.py into a running battle."""
    parts = ["-- GENERATED by tools/build_third_person.py --bridge. Loads the third-person modules into a running",
             "-- battle through the wh3-mcp bridge: py send.py zz_tp_load.lua 15. Not shipped.",
             "local SRC = {}"]
    entry = None
    for full, rel in lua_files():
        text = open(full, encoding="utf-8").read()
        assert "]==]" not in text and "\\" not in text, "%s cannot cross the bridge" % rel
        if rel.startswith("script/derpy_tp/"):
            parts.append('SRC["/%s"] = [==[%s]==]' % (rel[:-len(".lua")], text))
        elif rel == "script/battle/mod/derpy_third_person.lua":
            entry = text
    # the entry runs in core:get_env(), which need not be the bridge chunk's own env: override loadfile there
    parts += ["local env, base = core:get_env(), loadfile",
              "local old = rawget(env, 'loadfile')",
              "env.loadfile = function(p) if SRC[p] then return loadstring(SRC[p], p) end return base(p) end",
              "local ok, err = pcall(function() local f = assert(loadstring([==[%s]==], 'derpy_third_person')) "
              "setfenv(f, env) f() end)" % entry,
              "env.loadfile = old",
              'if not ok then return "ERR " .. tostring(err) end',
              "local E = _G.DERPY_TP",
              'return {loaded = E ~= nil and E.main ~= nil, build = E and E.P and E.P.build, '
              'problems = E and E.P and table.concat(E.P.problems, "; ") or "no platform"}', ""]
    with open(BRIDGE_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(parts))
    print("wrote %s" % BRIDGE_OUT)
```

In `main`: `if argv[:1] == ["--bridge"]: bridge(argv[1:]); return 0`. Give `bridge` the signature `def bridge(keep=None):`; `keep` is used only by the size fallback in Step 2.

Write `zz_tp_read.lua` by hand:

```lua
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local feats = {}
	for k, val in pairs(P.features) do feats[#feats + 1] = k .. "=" .. tostring(val) end
	return {features = table.concat(feats, " "), problems = table.concat(P.problems, "; "), source = P.source,
		on = F.on, unit = F.utype, one_man = F.model ~= nil, solo = F.solo, men_ok = F.men_ok, ranged = F.ranged,
		frames = F.frames, strikes = E.strikes, disabled = E.disabled}
end)
if ok then return res end
return "ERR " .. tostring(res)
```

- [ ] **Step 2: Load it into a battle**

Needs a running battle (any, out of Deployment is best) with the crossbowmen, a general and artillery. Run:

```
py tools/build_third_person.py --bridge
cd "Modding Files/source/lord_control/probes"
py send.py zz_follow_off.lua 8
py send.py zz_tp_load.lua 15
```

Expected: `{"loaded": true, "build": 1791416583, "problems": ""}`, where 1791416583 is `0x6ac6d907`.

If the bridge times out or truncates on the chunk's size (`data.lua` alone is thousands of rows), embed only this battle's rows. Give `bridge()` a `keep` argument, and pass the remaining argv from `--bridge` (the unit types and ability keys to keep):

```python
def small_data(text, keep):
    """data.lua with only the rows whose key is in keep; the shipped file is never cut."""
    out = [line for line in text.splitlines()
           if not re.match(r'\t\t\["', line) or re.match(r'\t\t\["([^"]+)"\]', line).group(1) in keep]
    return "\n".join(out) + "\n"
```

Inside `bridge()`'s loop, before the `SRC[...]` line: `if keep and rel == "script/derpy_tp/data.lua": text = small_data(text, set(keep))`. Then run, for example: `py tools/build_third_person.py --bridge wh3_main_cth_inf_jade_warrior_crossbowmen_1 wh_main_spell_fire_fireball`.

- [ ] **Step 3: The author presses F2 on the general, then on the crossbowmen; read after each**

Run: `py send.py zz_tp_read.lua 8`
Expected:
- **general:** `features` shows `input=true anim=true wheel=true men=true`, `source` is `known build`, `on` is true, `one_man` is false;
- **crossbowmen:** `one_man` is true, `solo` is true, `men_ok` is true.

Any `false` names its check in `problems`. That is a real finding: record it in the handoff, then fix the check or the offset before going on.

- [ ] **Step 4: Prove the pattern route live**

Temporarily rename the build key in `platform.lua`, from `[0x6ac6d907]` to `[0x6ac6d906]`. Re-run Steps 1-3 and expect `source` to read `byte pattern` with the same features. Then put the key back, and run `py tools/build_third_person.py --selftest` to confirm the pattern tool is green again.

- [ ] **Step 5: Record**

Add the results to handoff §9k (or a new §9l): features per unit kind, the problems seen, the pattern route verified.

---

### Task 14: One man's shot in play (spec §10.2-§10.5)

Live, through the bridge, in a battle with an enemy regiment in range. The probes go in `Modding Files/source/lord_control/probes/`.

**Files:**
- Create: `probes/zz_tp_kills.lua`, `probes/zz_tp_anim_sample.py`
- Modify (by outcome): `platform.lua`, `combat.lua`, `tools/third_person_tests.lua`, handoff

- [ ] **Step 1: §10.4 timing.** The author holds fire with the crossbowmen and watches whether the bolt leaves with the crossbow's release.

| Author reports | Change |
|---|---|
| The bolt leaves early or late | Change `SHOT_DELAY_MS` in `combat.lua` in 50 ms steps, re-run `--bridge`, re-send, repeat |
| The bolt leaves on time | Record the value in the handoff |

- [ ] **Step 2: §10.3 facing.** With the aim 60 degrees off his facing, the author fires once.

  - **He shoots sideways:** add facing. In `combat.lua` `man_shot`, before `P.play(m, SLOT_FIRE)`:

    ```lua
    		local x0, _, z0 = P.model_pos(m)
    		local fdx, fdz = ax - x0, az - z0
    		local fd = math.max(math.sqrt(fdx * fdx + fdz * fdz), 0.01)
    		P.steer(m, x0 + fdx / fd * 0.4, z0 + fdz / fd * 0.4)
    		F.face_until, F.man_hold = now + 0.3, {x0, z0}
    ```

    In `move.lua` `man_drive`, as its first line: `if F.face_until and now < F.face_until then return end`.

    Add the offline test:

    ```lua
    T.solo_turns_to_the_aim = function()
    	crossbowmen()
    	H.mouse = {196, 0} -- about 45 degrees of camera turn
    	H.step(1 / 60)
    	H.tap("Left mouse")
    	local s = H.last("steer")
    	check(s and s[3] > H.E.F.model.x, "his steering point swung toward the aim")
    end
    ```

    Re-test live. If he still does not turn, record it in the spec §10 as a limit and remove the facing code and its test.
  - **He already faces the aim:** record that.

- [ ] **Step 3: §10.2 the reload animation's length.**

  1. Write `zz_tp_anim_sample.py` as a copy of `probes/sample_men.py` that saves one man (`SPAN = 0x4000`) at 20 Hz for 8 s.
  2. Start it, and through the bridge call `E.P.play(E.F.model, 1564)` once.
  3. Look for a `u16` that reads 1564 right after the push and changes to another slot id when the animation visibly ends.

  | Found | Change |
  |---|---|
  | Yes | Add `local ANIM_SLOT = 0x<offset>` and `function P.anim_slot(m) return mr.read_uint16(m, ANIM_SLOT) end` to `platform.lua`. In `C.solo`, before `if now < F.next_shot`, add `if P.anim_slot and P.anim_slot(F.model) == SLOT_RELOAD then return end`. Add a harness test with a fake `P.anim_slot` returning 1564 for 5 s, which delays the second held shot to 5 s |
  | No | The cadence stays on the reload time alone; record it in the spec §10 |

- [ ] **Step 4: §10.5 what a scripted shot carries.** `zz_tp_kills.lua` reads, for the crossbowmen, `number_of_enemies_killed()` before and after 10 held solo shots that hit (the target's `number_of_men_alive()` drops).
  - If the regiment's kill count rose by the target's losses, scripted kills count for the regiment.
  - Then fire 5 shots with the aim behind his own ranks (look down and back), and count his regiment's men before and after.
  - Write both results, plus "buffs: not measured" if no cheap measurement turned up, into the spec §10 item 5.

- [ ] **Step 5: Run the selftest** after any code change: `py tools/build_third_person.py --selftest`, all green.

---

### Task 15: Run speed, Manual fire via shortcut, camera drift (spec §10.6, §10.8, §10.9)

**Files:**
- Create: probes as named below
- Modify (by outcome): `platform.lua`, `move.lua`, `combat.lua`, `main.lua`, tests, handoff

- [ ] **Step 1: §10.9 drift.**
  1. Through the bridge, record `P.model_pos` of a galloping cavalry lord's model on 120 consecutive frames (a repeat callback appending to a global list).
  2. Count the distinct positions.

  | Distinct positions | Change |
  |---|---|
  | 60 or more in 120 frames (the model moves smoothly) | Follow the model with no playback delay. In `main.lua`, for a single entity, take `x, y, z` from `P.model_pos(P.models(unit)[1])` when `F.men_ok`. Make `rig.lua` take a `delay` argument to `update`, 0 for a model source and `DELAY` for `unit:position()`. Add a rig test that the target equals the latest sample when `delay` is 0 |
  | Steppy | Record it as a limit in the spec |

- [ ] **Step 2: §10.8 Manual fire.** With the cannon selected, run `common.trigger_shortcut("toggle_first_person_mode")` through the bridge.
  - **Manual fire opens:** in `combat.lua` `watch()`, when `b` is nil after 0.5 s, try that shortcut once, setting `fp.clicked = true` and `fp.t = now`. Add a harness test with `common = {trigger_shortcut = function(s) H.rec("shortcut", s) end}` showing the shortcut fires when no button exists.
  - **It does not open:** record it.
  - Check the hidden-button issue (handoff §9h) again in a fresh battle.

- [ ] **Step 3: §10.6 run speed.**
  1. Sample the man's `0x180-0x23C` floats (handoff §9i: the speed values) while his regiment walks, then while it runs, through the sampler from Task 14 Step 3.
  2. Find a field that changes with the run toggle.

  | Found | Change |
  |---|---|
  | Yes | Add `P.set_run(m, on)` writing it, call it from `man_drive` with `F.running`, and add the harness assertion that `set_run` is called when Shift is toggled |
  | No | Record the limit |

- [ ] **Step 4: Selftest green**, and the handoff updated with each result.

---

### Task 16: Pack, deploy, live run, docs

**Files:**
- Modify: `tools/build_third_person.py` (`pack()`, `verify()`)
- Create: `Modding Files/Modpacks/derpy_third_person.pack`
- Modify: the handoff, `docs/SESSION_INDEX.md`, `tools/README.md` (regenerated)

- [ ] **Step 1: Write `pack()` and `verify()`**

```python
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
    files = lua_files()
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
    files = lua_files()
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
```

In `main`, replace the usage error with `return pack()` when `argv` is empty, and keep the usage error for unknown flags.

- [ ] **Step 2: Build it**

Open RPFM, check `Invoke-WebRequest http://127.0.0.1:45127/sessions -TimeoutSec 4 -UseBasicParsing` answers, then run `py tools/build_third_person.py`.
Expected: the selftest green, `saved ...derpy_third_person.pack`, `verified 11 files and 3 loc rows`.

- [ ] **Step 3: Deploy with the game shut**

Check that `Warhammer3.exe` is not running, then copy `Modding Files/Modpacks/derpy_third_person.pack` to `F:\SteamLibrary\steamapps\common\Total War WARHAMMER III\data\`. The author enables it in the Mod Manager, with memreader Plus and MCT.

- [ ] **Step 4: The live run, one battle, spec section 9 item 3**

| Unit kind | Measured, read through `zz_tp_read.lua` and by eye |
|---|---|
| Melee general | swing damage dealt; the cooldown holds |
| Ranged lord | a hold keeps fire going; release stops it after the shot |
| One man, melee | his neighbours move under 0.5 m while he walks 5 m |
| One man, ranged | shots in 10 s match the reload pace; regiment ammo drops by exactly the shots; the other men fire none; F2 off gives them their fire back |
| Artillery | Manual fire opens, closes, control comes back |
| Unknown modded regiment | the whole regiment fires (any regiment from a mod not in `data.lua`) |
| Pause, W or fire held | nothing walks, shoves or shoots after the first half second; on unpause he carries on |
| 0.5x and 2x game speed | reload and swing cooldown follow game speed (they run on model time) |
| One man walked into a wall or an enemy block, W held | he is not pushed through it (nudges only in the first second of a press) |
| F2 on a regiment in heavy melee | the men check passes, or fails cleanly to whole-regiment play (its count check) |
| F2 during Deployment | starts, and walking works or is refused cleanly |
| A battle loaded with memreader Plus off | the "needs memreader" line shows once the battle is up |
| Ranged, looking steeply down | where the shot lands (the crosshair's ground point can be behind him) |

Also check:
- whether 1-0 also selects unit groups in vanilla while third person is on; record it for plan 2;
- the MCT page: rebind forward to Up, toggle, and confirm Up walks.

- [ ] **Step 5: Docs**

- Add a handoff section with the live run table and every §10 outcome.
- Add the spec §10 outcomes as limits where they stayed open.
- Add one `docs/SESSION_INDEX.md` line for this plan.
- Run `py tools/gen_tools_index.py` (the README lists the two new tools).
- Write memory files for any new engine fact from Tasks 1, 13, 14 and 15. For example: the cursor route, whether scripted kills count, and the anim slot field.

- [ ] **Step 6: Hand over for plan 2**

Tell the author:
- what works;
- every limit recorded;
- that plan 2 (the HUD) is next, built on Task 1's cursor route.

Workshop publishing is the author's step, through the Mod Manager, after plan 2.
