-- Test scaffolding (2026-10-17, "the first person mode should work if the player scrolled to the lowest"): one man of
-- _G.TP_ZF_TYPE (default the Hessmarine Bayonets) through the shipped frame loop with synthetic keys and wheel, starting
-- in third person at the unit's default zoom. 1 s: 2 notches in; 3 s: 20 in; 5 s: 1 out; 6.2 s: 3 more out; 7.6-9.6 s: the zoom-in key
-- held. A second after each: the zoom, first person, and where the eye is from his feet (ahead along the view, up).
-- Screenshots tp_zoom_close.tga (2.5 s), tp_zoom_fp.tga (4.5 s) and tp_zoom_out.tga (7.4 s). Read with zz_tp_zoomfp_read.lua. No string library
-- calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local want = _G.TP_ZF_TYPE or "emp_hessmarines_bayonets"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 1 then u = x end
	end
	if not u then return "no " .. tostring(want) end
	if F.on then E.main.stop("zoom test") end
	E.first_person = false
	E.zoom_by_type[want] = nil
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
	local keys, edges, notches = {}, {}, 0
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
	local function set(action, down) local k = E.S.keys[action] keys[type(k) == "table" and k[1] or k] = down or nil end
	local T = {type = want, at = {}, log = {}, done = false}
	_G.TP_ZF = T
	local log_was, once_was = E.log, E.once
	local t0 = os.clock()
	local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
	E.log = function(msg) if #T.log < 40 then T.log[#T.log + 1] = r2(os.clock() - t0) .. " " .. tostring(msg) end return log_was(msg) end
	E.once = function(tag, msg) T.log[#T.log + 1] = r2(os.clock() - t0) .. " ONCE " .. tostring(msg) return once_was(tag, msg) end
	local function finish(why)
		T.done, T.why = true, why
		for k in pairs(keys) do keys[k] = nil end
		E.first_person = false
		if F.on then pcall(E.main.stop, "zoom test") end
		for k, f in pairs(saved) do P[k] = f end
		E.log, E.once = log_was, once_was
		pcall(function() bm:remove_real_callback("tp_zoomfp") end)
	end
	local function record(label)
		local R = E.rig
		local mx, my, mz = P.model_pos(F.model)
		local fx, fz = math.sin(R.yaw), math.cos(R.yaw)
		local ahead = (R.ex - mx) * fx + (R.ez - mz) * fz
		T.at[#T.at + 1] = label .. ": zoom " .. r2(R.zoom) .. " first " .. tostring(E.first_person) .. " eye ahead " .. r2(ahead)
			.. " up " .. r2(R.ey - my)
	end
	E.main.start(u)
	if not F.on then finish("could not start") return T.why end
	-- after the start: the battle's first start opens the wheel's device, and that defines P.wheel afresh
	P.wheel = function() local n = notches notches = 0 return n end
	T.strikes0 = E.strikes
	local plan = {
		{0.5, function() record("start") end},
		{1, function() notches = 2 end},
		{2, function() record("2 in") end},
		{2.5, function() pcall(function() common.take_screenshot("tp_zoom_close.tga") end) end},
		{3, function() notches = 20 end},
		{4, function() record("20 in") end},
		{4.5, function() pcall(function() common.take_screenshot("tp_zoom_fp.tga") end) end},
		{5, function() notches = -1 end},
		{6, function() record("1 out") end},
		{6.2, function() notches = -3 end},
		{7.2, function() record("3 more out") end},
		{7.4, function() pcall(function() common.take_screenshot("tp_zoom_out.tga") end) end},
		{7.6, function() set("zoom_in", true) end},
		{9.6, function() set("zoom_in", false) end},
		{10, function() record("key held 2 s") end},
		{10.5, function() T.strikes = E.strikes - T.strikes0 finish("ran") end},
	}
	local n = 1
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if not F.on then finish("third person went off") return end
			local t = os.clock() - t0
			while plan[n] and t >= plan[n][1] do local p = plan[n] n = n + 1 p[2]() if T.done then return end end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_zoomfp")
	return "running on " .. want
end)
return ok and res or "ERR " .. tostring(res)
