-- Leaving a melee (2026-11-08): the open "Shift drift in melee" (THIRD_PERSON_PLAYER_REPORTS_20261023.md report 3: in melee
-- he moved about 2 m/s with no order of ours on him) and "sprinting from inside a melee is slow" (WORKSHOP_REPORTS_20261103).
-- The unit _G.TP_ME_TYPE (default the first unit of one) is placed START m in front of the nearest held enemy regiment,
-- played, walked in with W until is_in_melee (or WALK_MAX s), then: IDLE s with no key (the drift), turned 180 degrees,
-- and W (pass "run") or W+Shift (pass "sprint") held GO s. Each pass runs twice: with the sprint's charge order, and
-- with C.charge stubbed (_nocharge). A sample every 0.2 model s: time, phase, distance from the enemy's centre, speed,
-- melee, F.sprinting, F.charge_order, his command, his clip. Read with TP_ME_READ(); _G.TP_ME_STOP = true cancels.
-- Everyone invincible, the enemy held. No string library calls.
local START, WALK_MAX, IDLE, GO, SAMPLE = _G.TP_ME_START or 12, 6, 3, 3, 0.2
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.main and E.P) then return "no pack" end
	if _G.TP_ME and not _G.TP_ME.done then return "already running" end
	local P, F = E.P, E.F
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
	local charge_was = E.combat.charge
	local keys, edges = {}, {}
	local T = {runs = {}, done = false}
	_G.TP_ME, _G.TP_ME_STOP = T, false
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
	local function set(action, down)
		local k = E.S.keys[action]
		keys[type(k) == "table" and k[1] or k] = down or nil
	end
	local function clear() for k in pairs(keys) do keys[k] = nil end end
	local function now() return bm:time_elapsed_ms() / 1000 end
	local army = bm:get_player_army()
	local u
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if not u and ((_G.TP_ME_TYPE and x:type() == _G.TP_ME_TYPE) or (not _G.TP_ME_TYPE and x:number_of_men_alive() == 1)) then u = x end
	end
	if not u then return "no unit" end
	local target, td
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local e = ar:units():item(i)
			if e:number_of_men_alive() >= 20 then
				local d = e:position():distance_xz(u:position())
				if not td or d < td then target, td = e, d end
			end
		end
	end
	if not target then return "no enemy regiment" end
	local tq = target:position()
	local tx, tz = tq:get_x(), tq:get_z()
	local tb = math.rad(target:bearing())
	-- in front of the regiment: along its own facing
	local fx, fz = math.sin(tb), math.cos(tb)
	local sx, sz = tx + fx * START, tz + fz * START
	local yaw_in = math.atan2(tx - sx, tz - sz)
	T.unit, T.target = u:type(), target:type()
	local plan = _G.TP_ME_PLAN or {{"run", false}, {"sprint", false}, {"run", true}, {"sprint", true}}
	local pi, rec, t0, step, last, lx, lz, tphase = 0, nil, nil, nil, nil, nil, nil, nil
	local function body()
		local man = F.model or F.single
		return man and (P.mount(man) or man)
	end
	local function pos()
		local b = body()
		if b then local x, _, z = P.model_pos(b) return x, z end
		local q = u:position() return q:get_x(), q:get_z()
	end
	local function finish(why)
		T.done, T.why = true, why
		clear()
		if F.on then pcall(E.main.stop, "escape test") end
		for k, f in pairs(saved) do P[k] = f end
		E.combat.charge = charge_was
		pcall(function() bm:remove_real_callback("tp_escape") end)
	end
	local function place()
		local c = army:create_unit_controller()
		c:add_units(u)
		c:halt()
		c:teleport_to_location(v(sx, bm:get_terrain_height(sx, sz), sz), math.deg(yaw_in) % 360, 30)
		c:release_control()
		bm:clear_selection()
		u:select_in_ui()
	end
	local function next_pass()
		pi = pi + 1
		local p = plan[pi]
		if not p then finish("all done") return end
		rec = {pass = p[1] .. (p[2] and "_nocharge" or ""), s = {}}
		T.runs[#T.runs + 1] = rec
		E.combat.charge = p[2] and function() end or charge_was
		place()
		t0, step = now(), "on"
	end
	next_pass()
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if _G.TP_ME_STOP then finish("stopped") return end
			local t = now() - t0
			local function sample(phase)
				if t - last < SAMPLE then return end
				local x, z = pos()
				local b = body()
				local sp = lx and math.sqrt((x - lx) ^ 2 + (z - lz) ^ 2) / math.max(t - last, 0.01) or 0
				lx, lz, last = x, z, t
				rec.s[#rec.s + 1] = {t = t, ph = phase, d = math.sqrt((x - tx) ^ 2 + (z - tz) ^ 2), v = sp, m = u:is_in_melee(),
					sp = F.sprinting, co = F.charge_order ~= nil, cmd = b and P.command(b), slot = b and P.anim_slot(b),
					na = F.native_attack ~= nil}
			end
			if step == "on" and t >= 1.2 then
				local s_ok, s_err = pcall(E.main.start, u)
				if not s_ok then rec.start_err = tostring(s_err) end
				step = "check"
			elseif step == "check" and t >= 2 then
				if not (F.on and F.single) then rec.skipped = "on " .. tostring(F.on) .. ", single " .. tostring(F.single ~= nil) step = "off" return end
				E.rig.yaw, E.rig.want_yaw = yaw_in, yaw_in
				set("forward", true)
				step, tphase, last, lx = "walk", t, -1, nil
				if _G.TP_ME_ON_WALK then pcall(_G.TP_ME_ON_WALK, u, target) end
			elseif step == "walk" then
				sample("walk")
				local x, z = pos()
				local near = _G.TP_ME_EDGE and math.sqrt((x - tx) ^ 2 + (z - tz) ^ 2) <= _G.TP_ME_EDGE
				if u:is_in_melee() or near or t - tphase >= WALK_MAX then
					rec.in_melee_at = u:is_in_melee() and (t - tphase) or nil
					clear()
					step, tphase = "idle", t
				end
			elseif step == "idle" then
				sample("idle")
				if _G.TP_ME_FIGHT and not rec.melee_seen then
					if u:is_in_melee() then rec.melee_seen, tphase = t, t elseif t - tphase < 8 then return end
				end
				if t - tphase >= IDLE then
					local away = yaw_in + math.pi
					E.rig.yaw, E.rig.want_yaw = away, away
					set("forward", true)
					if rec.pass == "sprint" or rec.pass == "sprint_nocharge" then set("sprint", true) end
					step, tphase = "go", t
				end
			elseif step == "go" then
				sample("go")
				if t - tphase >= GO then clear() step = "off" end
			elseif step == "off" then pcall(E.main.stop, "escape test") step, rec.t_off = "off_wait", t
			elseif step == "off_wait" and t >= rec.t_off + 1 then
				if E.disabled then finish("pack disabled") return end
				next_pass()
			end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_escape")
	return "escape test: " .. T.unit .. " at " .. T.target .. ", " .. #plan .. " passes"
end)
_G.TP_ME_READ = function()
	local T = _G.TP_ME
	if not T then return "not run" end
	local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
	local out = {(T.done and "done" or "running") .. " (" .. tostring(T.why) .. ") " .. tostring(T.unit) .. " at " .. tostring(T.target) .. (T.err and (" ERR " .. T.err) or "")}
	for _, r in ipairs(T.runs) do
		out[#out + 1] = r.pass .. (r.skipped and (" SKIPPED " .. r.skipped) or "") .. (r.start_err and (" START ERR " .. r.start_err) or "") .. " melee at " .. tostring(r.in_melee_at and r1(r.in_melee_at))
		local by = {}
		for _, p in ipairs(r.s) do
			by[p.ph] = by[p.ph] or {}
			local l = by[p.ph]
			l[#l + 1] = r1(p.t) .. "s " .. r1(p.d) .. "m " .. r1(p.v) .. (p.m and " M" or "") .. (p.sp and " S" or "") .. (p.co and " CO" or "") .. (p.na and " NA" or "") .. " " .. tostring(p.cmd) .. " c" .. tostring(p.slot)
		end
		for _, ph in ipairs({"walk", "idle", "go"}) do
			if by[ph] then out[#out + 1] = "  " .. ph .. ": " .. table.concat(by[ph], " | ") end
		end
	end
	return out
end
return ok and res or "ERR " .. tostring(res)
