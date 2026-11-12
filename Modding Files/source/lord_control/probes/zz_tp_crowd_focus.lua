-- Report 2 of THIRD_PERSON_PLAYER_REPORTS_20261023.md: "two lords fighting focus their attacks on one entity"; played,
-- the lord's blows spread over the crowd. Fixed in the harness 2026-11-01 (combat.lua victim: the locked enemy's man
-- first, where one is in reach); never checked live. The enemy lord (_G.TP_CF_LORD) is teleported into the middle of
-- the enemy regiment _G.TP_CF_GUARD, everyone invincible and the enemy held. The player's unit of one _G.TP_CF_ME stands
-- STAND m in front of the regiment, facing it, is played, and swings every SWING s for SWINGS swings: pass "plain"
-- with no lock-on, pass "lock" after C.target() (the lock-on key's click). Every P.strike is recorded: on the lord's
-- man or not, and the blow the cave armed. Read with TP_CF_READ(). No string library calls.
local STAND, SWING, SWINGS = _G.TP_CF_STAND or 3, 1.4, 10
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.main and E.P) then return "no pack" end
	if _G.TP_CF and not _G.TP_CF.done then return "already running" end
	local P, F = E.P, E.F
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel", "strike"}) do saved[k] = P[k] end
	local keys, edges = {}, {}
	local T = {passes = {}, done = false}
	_G.TP_CF = T
	function P.held(k)
		if type(k) == "table" then for _, x in ipairs(k) do if keys[x] then return true end end return false end
		return keys[k] == true
	end
	function P.pressed(k)
		local i = type(k) == "table" and k[1] or k
		if not i then return false end
		local d = P.held(k)
		local e = d and not edges[i]
		edges[i] = d
		return e
	end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	local function vk(action) local k = E.S.keys[action] return type(k) == "table" and k[1] or k end
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function find(alliance, ty)
		local armies = alliance:armies()
		for a = 1, armies:count() do
			local us = armies:item(a):units()
			for i = 1, us:count() do local u = us:item(i) if u:type() == ty then return u, armies:item(a) end end
		end
	end
	local me, my_army = find(bm:get_player_alliance(), _G.TP_CF_ME)
	local lord, lord_army = find(bm:get_non_player_alliance(), _G.TP_CF_LORD)
	local guard, guard_army = find(bm:get_non_player_alliance(), _G.TP_CF_GUARD)
	if not (me and lord and guard) then return "missing: me " .. tostring(me ~= nil) .. ", lord " .. tostring(lord ~= nil) .. ", guard " .. tostring(guard ~= nil) end
	local lord_men = {}
	for _, m in ipairs(P.models(lord)) do lord_men[m] = true local mt = P.mount(m) if mt then lord_men[mt] = true end end
	T.lord_men = 0
	for _ in pairs(lord_men) do T.lord_men = T.lord_men + 1 end
	-- the lord into the regiment's middle, both held and invincible
	local gq = guard:position()
	local gx, gz = gq:get_x(), gq:get_z()
	local gb = math.rad(guard:bearing())
	-- _G.TP_CF_NOMOVE: the lord already placed (a second controller cannot move a unit another one holds: the lord stayed
	-- 41 m off, 2026-11-08)
	if not _G.TP_CF_NOMOVE then
		local c = lord_army:create_unit_controller()
		c:add_units(lord)
		c:take_control()
		c:set_invincible(true)
		c:morale_behavior_fearless()
		c:teleport_to_location(v(gx, bm:get_terrain_height(gx, gz), gz), guard:bearing(), 2)
		c:halt()
		T.lord_c = c
	end
	T.lord_off = math.floor(lord:position():distance_xz(guard:position()) * 10 + 0.5) / 10
	local strikes
	P.strike = function(m, victim, slot)
		local r = saved.strike(m, victim, slot)
		if strikes then
			local vx, _, vz = P.model_pos(victim)
			strikes[#strikes + 1] = {lord = lord_men[victim] == true, slot = slot, sent = r == true,
				d_lord = math.floor(math.sqrt((vx - gx) ^ 2 + (vz - gz) ^ 2) * 10 + 0.5) / 10}
		end
		return r
	end
	-- in front of the regiment, along its facing
	local fx, fz = math.sin(gb), math.cos(gb)
	local plan = _G.TP_CF_PLAN or {"plain", "lock"}
	local pi, rec, t0, step, n = 0, nil, nil, nil, 0
	local function finish(why)
		T.done, T.why = true, why
		for k in pairs(keys) do keys[k] = nil end
		if F.on then pcall(E.main.stop, "crowd test") end
		for k, f in pairs(saved) do P[k] = f end
		pcall(function() bm:remove_real_callback("tp_crowd") end)
	end
	local function place()
		local depth = _G.TP_CF_DEPTH or 6
		local sx, sz = gx + fx * (depth + STAND), gz + fz * (depth + STAND)
		local mc = my_army:create_unit_controller()
		mc:add_units(me)
		mc:halt()
		mc:teleport_to_location(v(sx, bm:get_terrain_height(sx, sz), sz), (guard:bearing() + 180) % 360, 2)
		mc:release_control()
		bm:clear_selection()
		me:select_in_ui()
	end
	local function next_pass()
		pi = pi + 1
		if not plan[pi] then finish("all done") return end
		rec = {pass = plan[pi], strikes = {}, logs = {}}
		strikes = rec.strikes
		T.passes[#T.passes + 1] = rec
		place()
		t0, step, n = now(), "on", 0
	end
	local log_was = E.log
	next_pass()
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if _G.TP_CF_STOP then finish("stopped") return end
			local t = now() - t0
			if step == "on" and t >= 1.2 then
				local s_ok, s_err = pcall(E.main.start, me)
				if not s_ok then rec.start_err = tostring(s_err) end
				step = "aim"
			elseif step == "aim" and t >= 2 then
				if not F.on then rec.skipped = "not on" step = "off" return end
				local mx, mz
				local b = F.model or F.single
				if b then local x, _, z = P.model_pos(P.mount(b) or b) mx, mz = x, z else local q = me:position() mx, mz = q:get_x(), q:get_z() end
				-- _G.TP_CF_AT_LORD: aim and walk at the lord where he stands, not the regiment's centre (2026-11-11: the lord
				-- ended 7 m from it, and the walk passed him by)
				if _G.TP_CF_AT_LORD then local lq = lord:position() gx, gz = lq:get_x(), lq:get_z() end
				local yaw = math.atan2(gx - mx, gz - mz)
				E.rig.yaw, E.rig.want_yaw = yaw, yaw
				rec.d_start = math.floor(math.sqrt((gx - mx) ^ 2 + (gz - mz) ^ 2) * 10 + 0.5) / 10
				-- the log, for the blow lines
				E.log = function(s) if rec then rec.logs[#rec.logs + 1] = s end return log_was(s) end
				if rec.pass == "lock" then
					E.combat.target()
					rec.locked = F.target and F.target:type() or "nothing"
				end
				if _G.TP_CF_WALK then keys[vk("forward")] = true end
				step, rec.t_swing = "swing", t
			elseif step == "swing" then
				if _G.TP_CF_WALK then
					local b = F.model or F.single
					if b then local x, _, z = P.model_pos(P.mount(b) or b) local y = math.atan2(gx - x, gz - z) E.rig.yaw, E.rig.want_yaw = y, y
						rec.d_min = math.min(rec.d_min or 99, math.floor(math.sqrt((gx - x) ^ 2 + (gz - z) ^ 2) * 10 + 0.5) / 10) end
				end
				if t >= rec.t_swing + n * SWING then
					keys[vk("attack")] = true
					n = n + 1
				elseif keys[vk("attack")] and t >= rec.t_swing + (n - 1) * SWING + 0.15 then
					keys[vk("attack")] = nil
				end
				if n > SWINGS then
					keys[vk("attack")] = nil
					keys[vk("forward")] = nil
					rec.still_locked = F.target and F.target:type() or "nothing"
					step = "off"
				end
			elseif step == "off" then
				E.log = log_was
				pcall(E.main.stop, "crowd test") step, rec.t_off = "off_wait", t
			elseif step == "off_wait" and t >= rec.t_off + 1 then
				if E.disabled then finish("pack disabled") return end
				next_pass()
			end
		end)
		if not worked then T.err = tostring(err) E.log = log_was finish("probe error") end
	end, 1, "tp_crowd")
	return "crowd test: " .. me:type() .. " at " .. lord:type() .. " in " .. guard:type() .. " (" .. T.lord_men .. " lord models)"
end)
_G.TP_CF_READ = function()
	local T = _G.TP_CF
	if not T then return "not run" end
	local out = {(T.done and "done" or "running") .. " (" .. tostring(T.why) .. ") lord " .. tostring(T.lord_off) .. " m from the regiment's centre" .. (T.err and (" ERR " .. T.err) or "")}
	for _, r in ipairs(T.passes) do
		local on_lord, sent = 0, 0
		for _, s in ipairs(r.strikes) do if s.sent then sent = sent + 1 if s.lord then on_lord = on_lord + 1 end end end
		out[#out + 1] = r.pass .. ": start " .. tostring(r.d_start) .. " m from the lord (closest " .. tostring(r.d_min) .. "), locked " .. tostring(r.locked) .. ", still " .. tostring(r.still_locked)
			.. " | blows sent " .. sent .. ", on the lord " .. on_lord .. (r.skipped and (" SKIPPED " .. r.skipped) or "") .. (r.start_err and (" START ERR " .. r.start_err) or "")
		local ds = {}
		for _, s in ipairs(r.strikes) do ds[#ds + 1] = (s.lord and "L" or "x") .. s.d_lord end
		out[#out + 1] = "  victims (L = the lord, m from the lord's spot): " .. table.concat(ds, " ")
		local bl = {}
		for _, s in ipairs(r.logs) do if s and #s < 160 then bl[#bl + 1] = s end end
		out[#out + 1] = "  log: " .. table.concat(bl, " || ")
	end
	return out
end
return ok and res or "ERR " .. tostring(res)
