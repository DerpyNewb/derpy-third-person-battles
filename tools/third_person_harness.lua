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
	if H.block_loads then return nil, "blocked: " .. path end -- the bridge puts loadfile back after the entry ran
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
-- where the engine has him going: his own spot once halted or attacking (CA's entry for ordered_position)
function UNIT:ordered_position() local o = self._ordered return o and v(o[1], 0, o[2]) or self:position() end
function UNIT:type() return self._type end
function UNIT:name() return self._type end
function UNIT:unique_ui_id() return self._id end
function UNIT:is_commanding_unit() return self._general end
function UNIT:is_infantry() return not self._arty end
function UNIT:is_artillery() return self._arty end
function UNIT:is_war_machine() return self._war_machine or self._arty end
function UNIT:is_currently_flying() return self._flying end
function UNIT:can_fly() return self._can_fly == true end
function UNIT:trigger_sound_taunt() rec("taunt", self._id) end
function UNIT:is_in_melee() return self._melee == true end
function UNIT:missile_range() return self._range end
function UNIT:ammo_left() return self._ammo end
function UNIT:starting_ammo() return self._start_ammo end
function UNIT:set_current_ammo_unary(u) rec("set_ammo", self._id, u) self._ammo = math.floor(u * self._start_ammo + 0.5) end
function UNIT:number_of_men_alive() local n = 0 for _, m in ipairs(self._models) do if m.alive ~= false then n = n + 1 end end return n end
function UNIT:is_routing() return self._routing end
function UNIT:is_valid_target() return self._hidden ~= true end
-- fire at will is on unless the player (o.hold_fire) or a controller turned it off
function UNIT:is_behaviour_active(b)
	if b == "fire_at_will" then return self._faw ~= false end
	if b == "defend" then return self._defend == true end
	return false
end
function UNIT:can_use_behaviour(b) return b == "fire_at_will" or b == "defend" end
function UNIT:ordered_width() return 20 end
function UNIT:select_in_ui() rec("select_in_ui", self._id) H.select(self) end
function UNIT:owned_non_passive_special_abilities() return self._abilities end
function UNIT:can_perform_special_ability(key) return self._can[key] ~= false end
function UNIT:unary_hitpoints() return self._hp end
function UNIT:initial_number_of_men() return #self._models end

local next_id = 0
-- o: type, men, x, z, bearing, range, ammo, start_ammo, arty, general, abilities, can, men_ok, enemy, hp
function H.unit(o)
	next_id = next_id + 1
	local u = setmetatable({_type = o.type or "wh_test_unit", _x = o.x or 0, _z = o.z or 0, _bearing = o.bearing or 0,
		_hp = o.hp or 1,
		_range = o.range or 0, _ammo = o.ammo or 0, _start_ammo = o.start_ammo or o.ammo or 0, _arty = o.arty or false, _war_machine = o.war_machine or false,
		_general = o.general or false, _abilities = o.abilities or {}, _can = o.can or {}, _routing = false,
		_id = next_id, _models = {}, _men_ok = o.men_ok, _flying = o.flying or false, _can_fly = o.can_fly, _melee = o.melee, _prior_walk = o.prior_walk,
		_hidden = o.hidden}, UNIT)
	if o.hold_fire then u._faw = false end -- the player's own hold fire
	u._defend = o.defend == true -- the player's own guard
	local men = o.men or 1
	for i = 1, men do -- one rank along x, centred on the unit, facing +z (bearing 0)
		u._models[i] = {id = next_id * 1000 + i, x = u._x + (i - (men + 1) / 2), y = 0, z = u._z,
			slots = o.slots, reload = o.reload_slot or not u._type:find("crossbowmen") and 1564, hp = 100, hp_max = 100,
			clip_ms = o.clip_ms}
		if o.reload_slot == false then u._models[i].reload = false end
	end
	local list = o.enemy and H.enemies or H.units
	list[#list + 1] = u
	return u
end
local function listof(items) return {count = function() return #items end, item = function(_, i) return items[i] end} end

-- unit controllers record every call as "uc:<method>", unit id, args
local UC = {}
local ORDERS = {goto_location = true, goto_location_angle_width = true, attack_unit = true, attack_location = true, halt = true}
UC.__index = function(self, name)
	return function(_, ...)
		if name == "perform_special_ability" then local key, target = ... assert(getmetatable(target) == UNIT, "battle.unit expected") end
		if name:find("^perform_special_ability") and H.refuse_cast and H.refuse_cast[(...)] then
			error("calling 'perform_special_ability' on bad self (error: unit '1' does not support this special ability)")
		end
		rec("uc:" .. name, self._u._id, ...)
		-- an order within 0.5 s of the one before is dropped (the recorder, 2026-10-15: a walk 0.4 s after a halt left him
		-- ordered to his own spot, idle, for as long as W was held)
		local u = self._u
		if ORDERS[name] then
			local dropped = H.T - (u._order_t or -1e9) < 0.5 - 1e-9 -- 30 frames of 1/60 sum to under 0.5
			u._order_t = H.T
			if dropped then rec("dropped_order", u._id, name)
			elseif name == "goto_location" or name == "goto_location_angle_width" then local p = ... u._ordered = {p.x, p.z}
			else u._ordered = nil end
		end
		if name == "fire_at_will" then self._u._faw = (...) end
		if name == "change_behaviour_active" then local b, on = ... if b == "defend" then self._u._defend = on end end
		if name == "halt" then self._u._prior_walk = false end
	end
end
function create_unitcontroller(u) return setmetatable({_u = u}, UC) end

-- the battle manager --------------------------------------------------------------------------------
local function make_bm()
	local B = {}
	-- CA's trap (memory wh3-real-callback-one-shot-id-reuse): a timer registered from inside a one-shot never runs
	function B:repeat_real_callback(fn, ms, id)
		if H.in_oneshot then rec("dropped_timer", id) return end
		H.timers[id] = {fn = fn, at = H.T + ms / 1000, every = ms / 1000}
	end
	function B:real_callback(fn, ms, id)
		if H.in_oneshot then rec("dropped_timer", id) return end
		H.timers[id] = {fn = fn, at = H.T + ms / 1000}
	end
	function B:time_elapsed_ms() return H.model_ms() end -- model time: stands still while H.paused
	function B:remove_real_callback(id) H.timers[id] = nil end
	function B:camera() return H.cam end
	function B:get_terrain_height(x, z) return H.ground and H.ground(x, z) or 0 end
	function B:disable_orders(b) rec("disable_orders", b) end
	function B:enable_cinematic_ui(a, b, c) rec("cinematic_ui", a, b, c) end
	function B:disable_shortcut(name, off) rec("disable_shortcut", name, off) end
	B.battle = {enable_tooltips = function(_, b) rec("tooltips", b) end, set_banners_enabled = function(_, b) rec("banners", b) end,
		suppress_unit_voices = function(_, b) rec("voices_off", b) end} -- CA's battle interface, bm.battle
	function B:is_multiplayer() return H.mp end
	function B:is_replay() return H.replay end
	function B:show_subtitle(key, full, force) rec("subtitle", key, full, force) end
	function B:hide_subtitles() rec("hide_subtitles") end
	function B:trigger_projectile_launch(key, from, to) rec("launch", key, from, to) end
	function B:register_phase_change_callback(name, fn) H.phase[name] = fn end
	function B:register_unit_selection_callback(u, fn) H.selection_cbs[#H.selection_cbs + 1] = {u, fn} end
	function B:num_units_selected() local n = 0 for _ in pairs(H.sel) do n = n + 1 end return n end
	function B:clear_selection() rec("clear_selection") H.select(nil) end
	function B:get_player_army() return {units = function() return listof(H.units) end} end
	function B:get_player_alliance() return {armies = function() return listof({B:get_player_army()}) end} end
	function B:get_non_player_alliance()
		return {armies = function() return listof({{units = function() return listof(H.enemies) end}}) end}
	end
	return B
end
-- as a click does: the unit selected before is deselected first (nil clears the selection). H.sel is what the game
-- says is selected (num_units_selected, CcoBattleUnit.IsSelected); a shift-click adds to it
function H.select(u)
	local was = H.selected
	H.selected, H.sel = u, u and {[u] = true} or {}
	if was and was ~= u then for _, cb in ipairs(H.selection_cbs) do if cb[1] == was then cb[2](was, false) end end end
	if u then for _, cb in ipairs(H.selection_cbs) do if cb[1] == u then cb[2](u, true) end end end
end

-- UI: components with ids and children; SetVisible refuses a non-boolean the way the game should
local COMP = {}
COMP.__index = COMP
local function comp(id, parent)
	local c = setmetatable({id = id, kids = {}, visible = true, x = 0, y = 0, parent = parent}, COMP)
	if parent then parent.kids[#parent.kids + 1] = c end
	return c
end
H.comp = comp
-- our generated panel, built the way the engine builds a layout (measured 2026-10-14): the file's outermost
-- element must be <root>, which the engine drops; root's child is the component created, under the name passed,
-- and its children nest below it, each sized by its first state. A file without <root> creates nothing: nil.
local function build_twui(c, rel)
	local f = assert(io.open(ROOT .. "/" .. rel .. ".twui.xml", "rb"))
	local t = f:read("*a") f:close()
	local size = {}
	for gid, body in t:gmatch('\n\t\t<[%w_]+\n\t\t\tthis="([^"]+)"(.-)\n\t\t</') do
		local w, h = body:match('width="(%d+)"%s+height="(%d+)"')
		size[gid] = {tonumber(w), tonumber(h)}
	end
	local tree = t:match("<hierarchy>(.-)</hierarchy>")
	if tree:match("^%s*<([%w_]+)") ~= "root" then return false end
	local stack = {}
	for line in tree:gmatch("[^\n]+") do
		local name, gid, closed = line:match('^%s*<([%w_]+) this="([^"]+)"(/?)>')
		if name then
			local parent = stack[#stack]
			local node
			if not parent then node = {kids = {}} -- <root>: dropped
			elseif #stack == 1 then node = c -- root's child is the created component
			else node = comp(name, parent) node.hud = true node.w, node.h = size[gid][1], size[gid][2] end
			if closed == "" then stack[#stack + 1] = node end
		elseif line:match("^%s*</") then
			stack[#stack] = nil
		end
	end
	return true
end

function COMP:CreateComponent(id, path)
	local c = comp(id, self)
	if path == "ui/battle ui/first_person_ui" then
		comp("controls_text_frame", c) comp("bl_frame", c)
		local x = comp("crosshair", c)
		local ring = comp("reload_ring", x)
		ring.visible = false
		comp("loading_ring_L1", comp("loading_clip_L1", ring))
		comp("loading_ring_L2", comp("loading_clip_L2", ring))
	elseif path == "ui/derpy_tp/hud" then
		c.hud = true
		if H.refuse_layout or not build_twui(c, path) then table.remove(self.kids) return nil end
	end
	return c
end
function COMP:SetVisible(b)
	if type(b) ~= "boolean" then error("SetVisible(" .. tostring(b) .. "): a non-boolean corrupts the game's strings") end
	if self.hud then rec("vis", self.id, b) end
	self.visible = b
end
function COMP:Visible() return self.visible end
function COMP:ChildCount() return #self.kids end
function COMP:Find(i) return self.kids[i + 1] end
function COMP:Id() return self.id end
function COMP:Dimensions() return self.w or 32, self.h or 32 end
function COMP:Position() return self.x, self.y end
function COMP:SetImagePath(path, i) rec("img", self.id, i or 0, path) self.img = self.img or {} self.img[i or 0] = path end
function COMP:SetStateText(t, src)
	if type(t) ~= "string" then error("SetStateText(" .. tostring(t) .. ")") end
	rec("text", self.id, t) self.text = t
end
function COMP:SetCanResizeWidth(b) self.can_w = b ~= false end
function COMP:SetCanResizeHeight(b) self.can_h = b ~= false end
function COMP:Resize(w, h)
	if not (self.can_w and self.can_h) then error("Resize on " .. self.id .. " before SetCanResizeWidth/Height") end
	rec("resize", self.id, w, h) self.w, self.h = w, h
end
function COMP:SetImageRotation(i, a) rec("rot", self.id, i, a) self.rot = self.rot or {} self.rot[i] = a end
function COMP:SetInteractive(b) self.interactive = b end
function COMP:GetContextObjectId(kind) if kind == "CcoBattleUnit" then return self.cco end end
function COMP:MoveTo(x, y) self.x, self.y = x, y end
-- CA's uicomponent:Adopt(address, [index]): the child leaves its old parent; index 0-based, -1 or none the end
function COMP:Address() return self end
function COMP:Adopt(c, i)
	if type(c) ~= "table" or getmetatable(c) ~= COMP then error("Adopt takes an address") end
	rec("adopt", self.id, c.id, i)
	local old = c.parent
	if old then for k, x in ipairs(old.kids) do if x == c then table.remove(old.kids, k) break end end end
	c.parent = self
	if i and i >= 0 then table.insert(self.kids, math.min(i + 1, #self.kids + 1), c) else self.kids[#self.kids + 1] = c end
end
function COMP:SimulateLClick() rec("click", self.id) end
function COMP:GetCurrentStateImageOpacity(i) return (self.opacity or {})[i] or 255 end
function COMP:SetCurrentStateImageOpacity(i, o)
	if type(i) ~= "number" or type(o) ~= "number" then error("SetCurrentStateImageOpacity(" .. tostring(i) .. ", " .. tostring(o) .. ")") end
	self.opacity = self.opacity or {}
	self.opacity[i] = o
end
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
	get_screen_resolution = function() return H.screen[1], H.screen[2] end}
function out(msg) H.log[#H.log + 1] = tostring(msg) end
-- CA's unit context, by expression: H.cco[expr] is the value, or a function that returns it or throws
common = {get_context_value = function(kind, id, expr)
	if id == nil then -- one argument: a global expression. CA's WorldSpaceToScreenSpace answers H.w2s(x, y, z)
		rec("cco_global", kind)
		local x, y, z, f = kind:match("^WorldSpaceToScreenSpace%(ToVector4%(([^,]+),([^,]+),([^,]+),1%), false, false%)%.(%a)$")
		if not (x and H.w2s) then return nil end
		local sx, sy, sz = H.w2s(tonumber(x), tonumber(y), tonumber(z))
		return ({x = sx, y = sy, z = sz})[f]
	end
	rec("cco", kind, id, expr)
	if kind == "CcoBattleUnit" and expr == "IsSelected" then
		for u in pairs(H.sel) do if tostring(u:unique_ui_id()) == id then return true end end
		return false
	end
	local val = ((H.cco_ids or {})[id] or H.cco)[expr] -- H.cco_ids[id]: another unit's context, by its ui id
	if type(val) == "function" then return val() end
	return val
end, call_context_command = function(kind, id, expr) rec("cco_cmd", kind, id, expr) end}
function H.default_cco()
	return {IconPath = "ui/units/icons/test_card.png", Name = "Test Regiment", ["BattleAbilityList.Size"] = 0,
		ReloadPercentMax = 0, HealthValue = 900, HealthMax = 1000}
end
-- CA's lib_battle sound helpers: new_sfx(event, is_cinematic, is_vo) and play_sound(position, sfx)
function new_sfx(event, cinematic, vo) return {event = event, cinematic = cinematic, vo = vo} end
function play_sound(pos, sfx) rec("sound", sfx.event, pos, sfx.cinematic, sfx.vo) end
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
	P.features.steer = H.features.steer ~= false
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
	function P.look_begin() rec("look_begin") H.mouse = {0, 0} end -- parking the cursor drops what moved before
	function P.look_delta() local dx, dy = H.mouse[1], H.mouse[2] H.mouse = {0, 0} return dx, dy end
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
	function P.model_hp(m) return m.hp, m.hp_max end
	-- a man with no slot list has every slot under 1900 but AIM_LOW/LEVEL/HIGH (1547-1549): the shot tests before the
	-- aim hold (2026-10-16) time a raise straight into its fire; a test of the hold lists his slots
	function P.has_slot(m, slot)
		return m.slots and m.slots[slot] == true or not m.slots and slot < 1900 and (slot < 1547 or slot > 1549)
	end
	function P.reload_slot(m) if m.reload ~= false then return m.reload end end
	function P.mount(m) return m.mount end
	function P.place(m, x, z) rec("place", m.id, x, z) m.x, m.z = x, z end
	-- measured 2026-10-14 (probes/zz_tp_unclip.lua): a walk started under a running full-body clip leaves the clip
	-- latched for good, and he slides in its pose
	function P.steer(m, x, z, run, yaw, speed)
		rec("steer", m.id, x, z, run, yaw, speed)
		if P.anim_slot(m) and m.mask ~= 0 then rec("slide", m.id, m.anim_slot) m.anim_end = math.huge end
	end
	function P.hold(m, x, z, yaw) rec("hold", m.id, x, z, yaw) end
	function P.command(m) return m.command or "walk" end
	function P.guard(m) rec("guard", m and m.id) return false end
	function P.disarm(m) rec("disarm", m and m.id) end
	function P.arm(m) rec("arm", m and m.id) end
	function P.gate(on) rec("gate", on) return true end
	function P.anim_slot(m)
		if m.anim_end and H.model_ms() >= m.anim_end and not H.anim_hold then m.anim_slot = nil end
		-- H.report_ms: the engine reports a new clip late (measured 2026-10-15: 0.19-0.31 s in a busy battle)
		if m.report_at and H.model_ms() < m.report_at then return m.reported end
		return m.anim_slot
	end
	function P.play(m, slot, mask)
		rec("play", m.id, slot, mask)
		m.reported, m.report_at = P.anim_slot(m), H.model_ms() + (H.report_ms or 0)
		m.mask = mask or 0
		m.anim_slot = slot ~= 42 and slot or nil -- WALK_1, mask 0, no event metadata: the engine reports no clip
		-- reload, raise to aim, the rest; o.clip_ms: a clip's own length
		m.anim_end = H.model_ms() + ((m.clip_ms or {})[slot] or slot == 1564 and 7000 or slot == 1554 and 1000 or 4000)
		return true
	end
	function P.face(m, yaw) rec("face", m.id, yaw) end
	function P.alive(unit, m) return m.alive ~= false and m.hp > 0 end
	function P.same(a, b) return a == b end
	function P.check_men(unit) if unit._men_ok == false then return false, "test: men off" end return true end
	return P
end

-- clock and timers: 60 frames a second; a one-shot's id is freed before it runs, as CA's is
os.clock = function() return H.T end
-- the model clock: the game steps it, and its clip reports, in 100 ms ticks (measured 2026-10-15: every
-- bm:time_elapsed_ms() a whole tenth, sampled each frame); H.tick_ms steps it here, smooth without
function H.model_ms() return H.tick_ms and math.floor(H.game_ms / H.tick_ms + 1e-9) * H.tick_ms or H.game_ms end

function H.step(seconds)
	for _ = 1, math.max(1, math.floor(seconds * 60 + 0.5)) do
		H.T = H.T + 1 / 60
		if not H.paused then H.game_ms = H.game_ms + 1000 / 60 end
		if not H.paused then for _, u in ipairs(H.units) do if u._prior_walk then
			u._z = u._z + 1 / 60
			for _, m in ipairs(u._models) do m.z = m.z + 1 / 60 end
		end end end
		local due = {}
		for id, t in pairs(H.timers) do if H.T >= t.at - 1e-9 then due[#due + 1] = id end end
		table.sort(due)
		for _, id in ipairs(due) do
			local t = H.timers[id]
			if t then
				if t.every then t.at = H.T + t.every else H.timers[id] = nil end
				H.in_oneshot = not t.every
				local ok, err = pcall(t.fn)
				H.in_oneshot = false
				if not ok then error(err, 0) end
			end
		end
	end
end

-- keys by MCT name
local function code(name) local c = H.K.vk[name] if type(c) == "table" then return c[1] end return c end
function H.down(name) H.keys[code(name)] = true end
function H.up(name) H.keys[code(name)] = nil end
function H.tap(name) H.down(name) H.step(1 / 60) H.up(name) H.step(1 / 60) end

-- a fresh battle with the mod loaded. opts: units, enemies, mct, memreader, mp, replay, features
function H.fresh(opts)
	opts = opts or {}
	H.K = assert(real_loadfile(file("script/derpy_tp/keys")))()
	H.T, H.calls, H.timers, H.keys, H.focus, H.mouse, H.wheel_notches = 100, {}, {}, {}, true, {0, 0}, 0
	H.log, H.phase, H.selection_cbs, H.selected, H.sel = {}, {}, {}, nil, {}
	H.units, H.enemies, next_id = {}, {}, 0 -- ids restart, so the second unit's men are 2001, 2002...
	H.mp, H.replay = opts.mp or false, opts.replay or false
	H.screen, H.tick_ms = opts.screen or {1920, 1080}, opts.tick_ms
	H.game_ms, H.paused, H.block_loads, H.in_oneshot, H.anim_hold, H.report_ms = 0, false, false, false, false, 0
	H.features = opts.features or {input = true, anim = true, wheel = true}
	H.root = comp("root")
	H.cco, H.cco_ids, H.w2s = H.default_cco(), nil, nil
	H.eye, H.look, H.ground, H.roof = nil, nil, nil, nil
	-- H.cam_lag: frames the engine's reported position trails the asked eye (measured 2026-10-15: two)
	H.cam_lag, H.eyes = opts.cam_lag or 0, {}
	H.cam = {
		move_to = function(_, eye, look) H.eye, H.look = eye, look H.eyes[#H.eyes + 1] = eye end,
		enable_functionality = function(_, name, on) rec("camera_functions", name, on) end,
		-- the engine's floor: an eye over a roof (H.roof(x, z), a building's top) is put 1.55 m above it
		position = function()
			local e = H.eyes[math.max(1, #H.eyes - H.cam_lag)] or v(0, 0, 0)
			local r = H.roof and H.roof(e.x, e.z)
			return r and e.y < r + 1.55 and v(e.x, r + 1.55, e.z) or e
		end,
		change_height_range = function(_, lo, hi) rec("camera_height_range", lo, hi) end,
	}
	math.randomseed(1)
	get_mct = opts.mct and function() return H.mct_stub(opts.mct) end or nil
	_G.memreader_plus = opts.memreader ~= false and {} or nil
	_G.DERPY_TP, _G.DERPY_TP_SELECTED = nil, nil
	bm = make_bm()
	for _, o in ipairs(opts.units or {{general = true}}) do H.unit(o) end
	for _, o in ipairs(opts.enemies or {}) do o.enemy = true H.unit(o) end
	local cards = comp("cards_panel", comp("hud_battle", H.root))
	for _, u in ipairs(H.units) do comp(tostring(u._id), cards).cco = "cco_" .. u._id end
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
