-- Horse speed (the author, 2026-10-16: "horse speed mismatch; running but still staying at walking speed"). The pack
-- plays one man of _G.TP_RS_TYPE (default the Knights of the White Wolf): W held 4 s (running is the default), then W
-- and Shift 4 s. Per phase, from its second second: his body's speed, the command on the body, the run flag and speed
-- its walk carries (+0x390, +0x394), his clip, and the engine's own walk and run speed for the unit (exe+303b744).
-- Then the regiment whole on a run order for 6 s: a man's speed, the engine's own gait. Test scaffolding, not shipped.
-- Read with zz_tp_run_speed_read.lua; _G.TP_RS_STOP = true cancels. No string library calls.
local ok, result = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.main and mr) then return "load the pack in a battle first" end
	if _G.TP_RS and not _G.TP_RS.done then return "already running" end
	local P, F = E.P, E.F
	local function now() return bm:time_elapsed_ms() / 1000 end
	local want = _G.TP_RS_TYPE or "wh3_dlc29_emp_cav_knights_of_the_white_wolf_ror"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 1 then u = x break end
	end
	if not u then return "no " .. want end
	if F.on then E.main.stop("run speed test") end
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel", "steer"}) do saved[k] = P[k] end
	-- _G.TP_RS_LEAD: the experiment - his steering point that many metres ahead instead of move.lua's MAN_LEAD
	local LEAD = _G.TP_RS_LEAD
	if LEAD then
		P.steer = function(m, x, z, run, yaw, scale)
			local bx, _, bz = P.model_pos(P.mount(m) or m)
			local dx, dz = x - bx, z - bz
			local d = math.sqrt(dx * dx + dz * dz)
			if d > 0.01 then x, z = bx + dx / d * LEAD, bz + dz / d * LEAD end
			return saved.steer(m, x, z, run, yaw, scale)
		end
	end
	local keys, edges = {}, {}
	function P.held(k)
		if type(k) == "table" then for _, v in ipairs(k) do if keys[v] then return true end end return false end
		return keys[k] == true
	end
	function P.pressed(k)
		local id = type(k) == "table" and k[1] or k
		if not id then return false end
		local d = P.held(k)
		local e = d and not edges[id]
		edges[id] = d
		return e
	end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	local function key(action, on) local k = E.S.keys[action] keys[type(k) == "table" and k[1] or k] = on or nil end
	local walk_speed = mr.add(mr.add(mr.base, 0x3030000), 0xb744)
	local T = {done = false, type = want, lead = LEAD, phases = {}}
	_G.TP_RS, _G.TP_RS_STOP = T, false
	local c = army:create_unit_controller()
	c:add_units(u)
	local function native(m)
		local up = mr.read_pointer(m, 0x2e8)
		if mr.is_null(up) then return "null unit" end
		return {walk = mr.call(walk_speed, "float(pointer, uint8)", up, 0), run = mr.call(walk_speed, "float(pointer, uint8)", up, 1)}
	end
	local function bump(t, k) t[k] = (t[k] or 0) + 1 end
	local function finish()
		for k in pairs(keys) do keys[k] = nil end
		if F.on then pcall(E.main.stop, "run speed test") end
		for k, f in pairs(saved) do P[k] = f end
		pcall(function() c:release_control() end)
		T.done = true
		bm:remove_real_callback("tp_run_speed")
	end
	T.finish = finish
	local plan = {{"run", 4, {"forward"}}, {"sprint", 4, {"forward", "sprint"}}, {"release", 3, {}}, {"whole", 6, {}}}
	local i, R = 0, nil
	local function next_phase()
		for k in pairs(keys) do keys[k] = nil end
		i = i + 1
		local p = plan[i]
		if not p then finish() return end
		R = {name = p[1], len = p[2], began = now(), cmds = {}, clips = {}, flags = {}, speeds = {}}
		T.phases[#T.phases + 1] = R
		if R.name == "whole" then
			if F.on then E.main.stop("run speed test whole") end
			local q = u:position()
			local b = math.rad(u:bearing())
			c:goto_location(v(q:get_x() + math.sin(b) * 80, q:get_y(), q:get_z() + math.cos(b) * 80), true)
		else
			if not F.on then E.main.start(u) end
			if not F.model then T.err = "not one man" finish() return end
			for _, a in ipairs(p[3]) do key(a, true) end
		end
	end
	E.main.start(u)
	if not F.on or not F.model then finish() return "could not play one man" end
	T.one_man = true
	local first = F.model
	T.native_horse = native(P.mount(first) or first)
	T.native_rider = native(first)
	T.settle = now() + 1
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = now()
			if _G.TP_RS_STOP or E.disabled then finish() return end
			if not R then if t >= T.settle then next_phase() end return end
			local m = R.name == "whole" and P.models(u)[1] or F.model
			if not m then return end
			local b = P.mount(m) or m
			local x, _, z = P.model_pos(b)
			local el = t - R.began
			if el >= (R.name == "release" and 0 or 1) and not R.x0 then R.x0, R.z0, R.t0 = x, z, t end
			if R.x0 then
				bump(R.cmds, mr.tostring(mr.read_pointer(b, 0x330)))
				bump(R.clips, tostring(P.anim_slot(b)))
				bump(R.flags, tostring(mr.read_int32(b, 0x390)))
				local sp = math.floor(mr.read_float(b, 0x394) * 100) / 100
				bump(R.speeds, tostring(sp))
				R.x1, R.z1, R.t1 = x, z, t
			end
			if el >= R.len then
				if R.x0 and R.t1 > R.t0 then
					R.mps = math.sqrt((R.x1 - R.x0) ^ 2 + (R.z1 - R.z0) ^ 2) / (R.t1 - R.t0)
					R.moved = math.sqrt((R.x1 - R.x0) ^ 2 + (R.z1 - R.z0) ^ 2)
				end
				R.sprinting, R.running = F.sprinting, F.running
				next_phase()
			end
		end)
		if not worked then T.err = tostring(err) pcall(finish) end
	end, 1, "tp_run_speed")
	return "run speed test on " .. want
end)
return ok and result or "ERR " .. tostring(result)
