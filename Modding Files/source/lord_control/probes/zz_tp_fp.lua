-- Test scaffolding (2026-10-17, "first person camera", "smoothness of the camera turning"): one man of _G.TP_FP_TYPE
-- (default the Hessmarine Bayonets) through the shipped frame loop with synthetic keys, walking throughout. 0-3 s third
-- person, 3-8 s first person (V at 3 s, V and F2 at 8 s). The mouse is bursty, 8 px one frame and 0 the next, from 1.5 to
-- 3 s and from 5.5 to 8 s: frames the view did not turn ("still") show steps. 3.5-5.5 s, no mouse: frames the
-- first-person eye did not move while he walked show its lag stopping between his position's steps. _G.TP_FP_SMOOTH:
-- E.S.smooth for the run (nil, the setting). Screenshot tp_fp_shot.tga at 6 s. Read with zz_tp_fp_read.lua. No string
-- library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local want = _G.TP_FP_TYPE or "emp_hessmarines_bayonets"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 1 then u = x end
	end
	if not u then return "no " .. tostring(want) end
	if F.on then E.main.stop("fp test") end
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
	local keys, edges, mouse = {}, {}, 0
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
	P.look_delta = function() return mouse, 0 end
	P.wheel = function() return 0 end
	local function set(action, down) local k = E.S.keys[action] keys[type(k) == "table" and k[1] or k] = down or nil end
	local T = {type = want, log = {}, done = false, tp = {}, fp = {}}
	_G.TP_FP = T
	local log_was, once_was = E.log, E.once
	local t0 = os.clock()
	local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
	E.log = function(msg) if #T.log < 40 then T.log[#T.log + 1] = r2(os.clock() - t0) .. " " .. tostring(msg) end return log_was(msg) end
	E.once = function(tag, msg) T.log[#T.log + 1] = r2(os.clock() - t0) .. " ONCE " .. tostring(msg) return once_was(tag, msg) end
	local function finish(why)
		T.done, T.why = true, why
		for k in pairs(keys) do keys[k] = nil end
		mouse = 0
		E.first_person = false
		if F.on then pcall(E.main.stop, "fp test") end
		for k, f in pairs(saved) do P[k] = f end
		E.log, E.once = log_was, once_was
		pcall(function() bm:remove_real_callback("tp_fp") end)
	end
	E.main.start(u)
	if not F.on then finish("could not start") return T.why end
	if _G.TP_FP_SMOOTH then E.S.smooth = _G.TP_FP_SMOOTH end
	T.smooth = E.S.smooth
	T.strikes0 = E.strikes
	set("forward", true)
	local last_pos, last_change, last_eye, last_yaw
	local step, frame = "tp", 0
	-- per window: frames, his position's changes and the gaps between them (ms), and frames the view did not turn
	-- (bursty mouse) or the eye did not move (no mouse)
	local function watch(W, t, x, z, what)
		W.frames = (W.frames or 0) + 1
		if last_pos and (x ~= last_pos[1] or z ~= last_pos[2]) then
			W.changes = (W.changes or 0) + 1
			if last_change then
				local gap = math.floor((t - last_change) * 1000)
				W.gap_min, W.gap_max = math.min(W.gap_min or gap, gap), math.max(W.gap_max or gap, gap)
			end
			last_change = t
		end
		last_pos = {x, z}
		local R = E.rig
		if what == "turn" and last_yaw then
			local d = math.abs(R.yaw - last_yaw)
			if d < 1e-5 then W.still = (W.still or 0) + 1 end
			W.step_max = math.max(W.step_max or 0, d)
			W.step_sum = (W.step_sum or 0) + d
		elseif what == "eye" and last_eye then
			local d = math.sqrt((R.ex - last_eye[1]) ^ 2 + (R.ez - last_eye[2]) ^ 2)
			if d < 1e-4 then W.still = (W.still or 0) + 1 end
			if d > 0.5 then
				W.jumps = W.jumps or {}
				local mx, my, mz = P.model_pos(F.model)
				if #W.jumps < 6 then W.jumps[#W.jumps + 1] = r2(t) .. " d " .. r2(d) .. " first " .. tostring(R.first) .. " model "
					.. tostring(F.model) .. " man " .. r2(mx) .. "," .. r2(mz) .. " s " .. r2(R.sx) .. "," .. r2(R.sz)
					.. " eye " .. r2(R.ex) .. "," .. r2(R.ez) .. " fp " .. tostring(E.first_person) end
			end
			W.move_max = math.max(W.move_max or 0, d)
			W.move_sum = (W.move_sum or 0) + d
		end
		last_yaw = R.yaw
		if R.ex then last_eye = {R.ex, R.ez} end
	end
	local W = {tp_walk = {}, tp_turn = {}, fp_walk = {}, fp_turn = {}}
	T.w = W
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = os.clock() - t0
			frame = frame + 1
			if not F.on then finish("third person went off at " .. r2(t)) return end
			local x, _, z = P.model_pos(F.model)
			local bursty = (t >= 1.5 and t < 3) or (t >= 5.5 and t < 8)
			mouse = bursty and (frame % 2 == 0 and 8 or 0) or 0
			if step == "tp" then
				if t < 1.5 then watch(W.tp_walk, t, x, z) else watch(W.tp_turn, t, x, z, "turn") end
				if t >= 3 then set("view", true) step = "v_down" end
			elseif step == "v_down" then
				set("view", false) step = "fp" last_change = nil
				T.first_on = E.first_person
			elseif step == "fp" then
				if t >= 3.5 and t < 5.5 then watch(W.fp_walk, t, x, z, "eye")
				elseif t >= 5.7 then watch(W.fp_turn, t, x, z, "turn") end
				if t >= 6 and not T.shot then T.shot = true pcall(function() common.take_screenshot("tp_fp_shot.tga") end) end
				if t >= 8 then
					T.eye_y_above_man = r2(E.rig.ey - select(2, P.model_pos(F.model)))
					set("forward", false) set("view", true) step = "v2"
				end
			elseif step == "v2" then
				set("view", false) T.first_after = E.first_person step = "end" T.t_end = t
			elseif step == "end" and t >= T.t_end + 0.5 then
				T.strikes = E.strikes - T.strikes0
				finish("ran")
			end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_fp")
	return "running on " .. want
end)
return ok and res or "ERR " .. tostring(res)
