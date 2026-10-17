-- Test scaffolding (2026-10-17, the author: "flying units still controls the whole battalion as well when moving"): one
-- man of _G.TP_FO_TYPE (default teb_birdmen), selected (the game's Toggle flying acts on the selection), through the
-- shipped frame loop with synthetic keys. 1-4 s: W held, as he starts; 4.5 s: the fly key; 10.5-13.5 s: W held again;
-- 14 s: the fly key again. At the end of each, how far he moved and
-- how far the rest of his regiment's centre moved, his height over the ground, and whether the unit flies. Read with
-- zz_tp_fly_one_read.lua. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local want = _G.TP_FO_TYPE or "teb_birdmen"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 1 then u = x end
	end
	if not u then return "no " .. tostring(want) end
	if F.on then E.main.stop("fly test") end
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
	local keys, edges = {}, {}
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
	_G.TP_FO = T
	local log_was = E.log
	local t0 = os.clock()
	local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
	E.log = function(msg) if #T.log < 40 then T.log[#T.log + 1] = r2(os.clock() - t0) .. " " .. tostring(msg) end return log_was(msg) end
	local function finish(why)
		T.done, T.why = true, why
		for k in pairs(keys) do keys[k] = nil end
		if F.on then pcall(E.main.stop, "fly test") end
		for k, f in pairs(saved) do P[k] = f end
		E.log = log_was
		pcall(function() bm:remove_real_callback("tp_fly_one") end)
	end
	local man
	local function where()
		local mx, my, mz = P.model_pos(man)
		local cx, cz, n = 0, 0, 0
		for _, m in ipairs(P.models(u)) do
			if m ~= man then local x, _, z = P.model_pos(m) cx, cz, n = cx + x, cz + z, n + 1 end
		end
		return mx, my, mz, cx / math.max(n, 1), cz / math.max(n, 1)
	end
	local mark
	local function begin() mark = {where()} end
	local function record(label)
		local mx, my, mz, cx, cz = where()
		T.at[#T.at + 1] = label .. ": he moved " .. r2(math.sqrt((mx - mark[1]) ^ 2 + (mz - mark[3]) ^ 2)) .. " m, the rest "
			.. r2(math.sqrt((cx - mark[4]) ^ 2 + (cz - mark[5]) ^ 2)) .. " m; up " .. r2(my - bm:get_terrain_height(mx, mz))
			.. " m; flying " .. tostring(u:is_currently_flying()) .. "; one man " .. tostring(F.model ~= nil)
	end
	bm:clear_selection()
	u:select_in_ui()
	E.main.start(u)
	if not F.on then finish("could not start") return T.why end
	P.wheel = function() return 0 end -- after the start, which defines it afresh
	man = F.model or P.models(u)[1]
	T.one_man = F.model ~= nil
	E.rig.yaw, E.rig.want_yaw = math.rad(u:bearing()), math.rad(u:bearing())
	local plan = {
		{1, function() begin() set("forward", true) end},
		{4, function() set("forward", false) record("as he starts, W 3 s") end},
		{4.5, function() begin() set("fly", true) end},
		{4.7, function() set("fly", false) end},
		{10, function() record("the fly key, 5.5 s on") end},
		{10.5, function() begin() set("forward", true) end},
		{13.5, function() set("forward", false) record("then W 3 s") end},
		{14, function() begin() set("fly", true) end},
		{14.2, function() set("fly", false) end},
		{20, function() record("the fly key again, 6 s on") finish("ran") end},
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
	end, 1, "tp_fly_one")
	return "running on " .. want .. (T.one_man and ", one man" or ", whole")
end)
return ok and res or "ERR " .. tostring(res)
