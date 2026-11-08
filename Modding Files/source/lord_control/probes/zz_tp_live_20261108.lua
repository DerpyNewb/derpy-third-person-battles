-- Live probes for the third-person test run of 2026-11-08. Loaded once per battle over the bridge:
--   local f = assert(loadfile('<scratchpad>/tptest.lua')) setfenv(f, getfenv(1)) return f()
-- No string library calls and no s:method() anywhere (memory: wh3-mcp-bridge-wedges-on-interface-walks). Work that
-- walks the interface runs in a real callback, never in the eval; evals only call these and read _G.TPT back.
local T = _G.TPT or {}
_G.TPT = T
local E = _G.DERPY_TP
if not (E and E.main and E.P) then return "no pack" end
T.E = E
local P, F = E.P, E.F

-- keys: the pack reads these instead of the keyboard, and never moves the real cursor ------------------------------
function T.stub()
	if T.saved then return "already stubbed" end
	T.saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "hide_cursor"}) do T.saved[k] = P[k] end
	local keys, edges = {}, {}
	T.keys = keys
	P.held = function(k)
		if k == nil then return false end
		if type(k) == "table" then for _, x in ipairs(k) do if keys[x] then return true end end return false end
		return keys[k] == true
	end
	P.pressed = function(k)
		if k == nil then return false end
		local i = type(k) == "table" and k[1] or k
		local d = P.held(k)
		local e = d and not edges[i]
		edges[i] = d
		return e
	end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.hide_cursor = function() end
	return "stubbed"
end
function T.unstub()
	if not T.saved then return "not stubbed" end
	for k, f in pairs(T.saved) do P[k] = f end
	T.saved = nil
	return "restored"
end
-- the wheel exists only after a start (P.open_wheel); its DirectInput device reads the real wheel in the background
function T.nowheel() P.wheel = function() return 0 end return "no wheel" end
function T.vk(action) local k = E.S.keys[action] if type(k) == "table" then k = k[1] end return k end
function T.key(action, down) local k = T.vk(action) if k then T.keys[k] = down and true or nil end return k end
local taps = 0
function T.tap(action, ms)
	local k = T.key(action, true)
	taps = taps + 1
	bm:real_callback(function() T.keys[k] = nil end, ms or 150, "tpt_tap" .. taps)
	return k
end

-- the battle: the enemy held and immune, the player's units invincible and still under orders ----------------------
function T.static()
	T.enemy, T.mine = {}, {}
	local armies = bm:get_non_player_alliance():armies()
	for a = 1, armies:count() do
		local ar = armies:item(a)
		local us = ar:units()
		for i = 1, us:count() do
			local u = us:item(i)
			local uc = ar:create_unit_controller()
			uc:add_units(u)
			uc:take_control()
			uc:set_invincible(true)
			uc:morale_behavior_fearless()
			uc:halt()
			T.enemy[#T.enemy + 1] = {uc = uc, u = u}
		end
	end
	local ar = bm:get_player_army()
	local us = ar:units()
	for i = 1, us:count() do
		local u = us:item(i)
		local uc = ar:create_unit_controller()
		uc:add_units(u)
		uc:set_invincible(true)
		uc:morale_behavior_fearless()
		uc:release_control()
		T.mine[#T.mine + 1] = {uc = uc, u = u}
	end
	return #T.enemy .. " enemy held, " .. #T.mine .. " mine shielded"
end
function T.unit(i) return bm:get_player_army():units():item(i) end
function T.list()
	local out = {}
	local us = bm:get_player_army():units()
	for i = 1, us:count() do
		local u = us:item(i)
		out[#out + 1] = {i = i, type = u:type(), men = u:number_of_men_alive(), general = u:is_commanding_unit() == true}
	end
	return out
end
function T.enemies()
	local out = {}
	for k, e in ipairs(T.enemy or {}) do out[k] = {type = e.u:type(), men = e.u:number_of_men_alive()} end
	return out
end
local function at(u)
	local q = u:position()
	return q:get_x(), q:get_z()
end
-- my units lined up around unit i, and the held enemy in a line dist m ahead of it
function T.gather(i, dist)
	local c = T.unit(i)
	local cx, cz = at(c)
	local b = math.rad(c:bearing())
	local fx, fz = math.sin(b), math.cos(b)
	local function put(uc, k, n, ahead, face)
		local off = (k - (n + 1) / 2) * 28
		local x, z = cx + fx * ahead + fz * off, cz + fz * ahead - fx * off
		uc:teleport_to_location(v(x, bm:get_terrain_height(x, z), z), face % 360, 24)
	end
	local others = {}
	for k, m in ipairs(T.mine) do if k ~= i then others[#others + 1] = m end end
	for k, m in ipairs(others) do
		local uc = bm:get_player_army():create_unit_controller()
		uc:add_units(m.u)
		put(uc, k, #others, -15, c:bearing())
		uc:release_control()
	end
	for k, e in ipairs(T.enemy) do put(e.uc, k, #T.enemy, dist or 30, c:bearing() + 180) end
	return #others .. " mine, " .. #T.enemy .. " enemy placed"
end

-- third person on and off -------------------------------------------------------------------------------------------
function T.state()
	return {on = F.on == true, single = F.single ~= nil, model = F.model ~= nil, men_ok = F.men_ok, disabled = E.disabled == true,
		strikes = E.strikes, cmd = F.command ~= nil, free_cursor = F.free_cursor == true, dragging = F.dragging == true,
		ui_off = F.ui_off == true, banners = F.banners == true, unit = F.utype}
end
function T.start(i)
	local ok, err = pcall(E.main.start, T.unit(i))
	local s = T.state()
	s.ok, s.err = ok, err ~= nil and tostring(err) or nil
	return s
end
function T.stop(why)
	local ok, err = pcall(E.main.stop, why or "test")
	return {ok = ok, err = err ~= nil and tostring(err) or nil, on = F.on == true}
end

-- the interface: every part of the three groups the pack hides, and whether the cinematic UI is on ------------------
T.snaps = T.snaps or {}
local snaps = 0
function T.snap(tag)
	snaps = snaps + 1
	bm:real_callback(function()
		local ok, err = pcall(function()
			local root = core:get_ui_root()
			local out = {}
			local function kids(c, group)
				if not c then out[group .. "/(missing)"] = false return end
				for i = 0, c:ChildCount() - 1 do
					local ch = UIComponent(c:Find(i))
					out[group .. "/" .. ch:Id()] = ch:Visible() == true
				end
			end
			kids(root, "root")
			kids(find_uicomponent(root, "hud_battle"), "hud_battle")
			kids(find_uicomponent(root, "porthole_parent"), "porthole_parent")
			local cin = false
			pcall(function() cin = bm:is_cinematic_ui_enabled() == true end)
			out["cinematic_ui"] = cin
			T.snaps[tag] = out
		end)
		if not ok then T.snaps[tag] = {err = tostring(err)} end
	end, 10, "tpt_snap" .. snaps)
	return tag
end
-- parts shown in snap a and not in snap b, and the other way
function T.diff(a, b)
	local A, B = T.snaps[a], T.snaps[b]
	if not (A and B) then return "missing snap" end
	local lost, gained = {}, {}
	for p, vis in pairs(A) do if vis and not B[p] then lost[#lost + 1] = p end end
	for p, vis in pairs(B) do if vis and not A[p] then gained[#gained + 1] = p end end
	table.sort(lost) table.sort(gained)
	return {lost = lost, gained = gained}
end

-- the clip slots the played man and his mount play, every frame -----------------------------------------------------
function T.slots_start()
	T.slot = {man = {}, mount = {}, n = 0, hp = {}}
	bm:repeat_real_callback(function()
		pcall(function()
			local man = F.model or F.single
			if not man then return end
			local S = T.slot
			S.n = S.n + 1
			local s = P.anim_slot(man)
			if s then S.man[s] = (S.man[s] or 0) + 1 end
			local m = P.mount(man)
			if m then
				local s2 = P.anim_slot(m)
				if s2 then S.mount[s2] = (S.mount[s2] or 0) + 1 end
			end
		end)
	end, 1, "tpt_slots")
	return "sampling"
end
function T.slots_stop() bm:remove_real_callback("tpt_slots") return T.slot end

-- frame time and the pack's share of it ----------------------------------------------------------------------------
local function upvalue(f, name)
	local i = 1
	while true do
		local n, val = debug.getupvalue(f, i)
		if n == nil then return nil end
		if n == name then return val end
		i = i + 1
	end
end
function T.meter_start(count_reads)
	if T.m and T.m.running then return "running" end
	local m = {dts = {}, pack = 0, men = 0, frames = 0, models = 0, running = true}
	T.m = m
	local rt = upvalue(bm.tm.remove_real_callback, "real_timers")
	if rt then
		for _, entry in pairs(rt) do
			if entry.name == "derpy_tp" and not m.entry then
				local cb = entry.callback
				m.entry, m.cb = entry, cb
				entry.callback = function() local t = os.clock() cb() m.pack = m.pack + os.clock() - t end
			end
		end
	end
	local men = E.hud.men
	m.men_f = men
	E.hud.men = function() local t = os.clock() men() m.men = m.men + os.clock() - t end
	if count_reads then
		local models = P.models
		m.models_f = models
		P.models = function(u) m.models = m.models + 1 return models(u) end
	end
	local last = os.clock()
	m.t0 = last
	bm:repeat_real_callback(function()
		local t = os.clock()
		m.frames = m.frames + 1
		m.dts[#m.dts + 1] = t - last
		last = t
	end, 1, "tpt_meter")
	return m.entry ~= nil and "timing the pack's frame" or "pack frame not found"
end
function T.meter_stop()
	local m = T.m
	if not (m and m.running) then return "not running" end
	m.running = false
	bm:remove_real_callback("tpt_meter")
	if m.entry then m.entry.callback = m.cb end
	E.hud.men = m.men_f
	if m.models_f then P.models = m.models_f end
	local secs = os.clock() - m.t0
	local d = m.dts
	table.sort(d)
	local n = #d
	local sum = 0
	for _, x in ipairs(d) do sum = sum + x end
	if n == 0 then return "no frames" end
	return {secs = secs, frames = m.frames, fps = m.frames / secs, dt_mean_ms = 1000 * sum / n,
		dt_med_ms = 1000 * d[math.floor(n / 2) + 1], dt_p95_ms = 1000 * d[math.max(1, math.floor(n * 0.95))],
		dt_max_ms = 1000 * d[n], pack_ms = 1000 * m.pack / m.frames, men_ms = 1000 * m.men / m.frames,
		models_per_s = m.models / secs, pack_found = m.entry ~= nil, on = F.on == true, man_bars = E.S.man_bars == true}
end
-- a timed sequence in one repeating callback (a one-shot registered inside a one-shot can be lost):
-- steps {ms, what, arg}: "tap" an action, "down"/"up" a held action, "snap" a tag, "start" unit i, "stop", "call" a function
local seqs = 0
function T.seq(steps, name)
	seqs = seqs + 1
	local id = "tpt_seq" .. seqs
	local t0, k = os.clock(), 1
	T.seq_done = T.seq_done or {}
	T.seq_done[name or id] = false
	bm:repeat_real_callback(function()
		local el = (os.clock() - t0) * 1000
		while steps[k] and el >= steps[k][1] do
			local s = steps[k]
			pcall(function()
				if s[2] == "tap" then T.tap(s[3], s[4])
				elseif s[2] == "down" then T.key(s[3], true)
				elseif s[2] == "up" then T.key(s[3], false)
				elseif s[2] == "snap" then T.snap(s[3])
				elseif s[2] == "start" then T.start(s[3])
				elseif s[2] == "stop" then T.stop(s[3])
				elseif s[2] == "call" then s[3]() end
			end)
			k = k + 1
		end
		if not steps[k] then bm:remove_real_callback(id) T.seq_done[name or id] = true end
	end, 1, id)
	return id
end
return "TPT loaded"
