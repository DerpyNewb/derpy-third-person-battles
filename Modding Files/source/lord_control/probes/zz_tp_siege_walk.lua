-- Test scaffolding (2026-10-18, the author: in sieges one man "cannot move normally forward, as if theres a barrier",
-- "everywhere in sieges", fine on field maps). Third person on _G.TP_SW_IDX (player army index) through the shipped start
-- and frame loop, the forward key read as held (synthetic: the question is the engine's walk, not the key), the view
-- turned to each of _G.TP_SW_YAWS (degrees, default his bearing and the other three quarters) for 4 s, 1 s let go between.
-- Run zz_tp_watch_siege.lua beside it for the rows. Read: _G.TP_SW. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local u = bm:get_player_army():units():item(_G.TP_SW_IDX or 15)
	if F.on then E.main.stop("siege walk test") end
	local b = u:bearing()
	local yaws = _G.TP_SW_YAWS or {b, b + 90, b + 180, b + 270}
	local T = {type = u:type(), phases = {}, done = false}
	_G.TP_SW = T
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel", "walk_ended"}) do saved[k] = P[k] end
	-- _G.TP_SW_NOFIX: the control - no walk is ever read as ended, as before the fix
	if _G.TP_SW_NOFIX then P.walk_ended = function() return false end end
	local fwd = E.S.keys.forward
	local id = type(fwd) == "table" and fwd[1] or fwd
	local hold = false
	P.held = function(k) return hold and (type(k) == "table" and k[1] or k) == id end
	P.pressed = function() return false end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	local function put_back()
		for k, f in pairs(saved) do P[k] = f end
		if F.on then pcall(E.main.stop, "siege walk test") end
	end
	E.main.start(u)
	local t0, k, mark = os.clock(), 0, nil
	local function man_pos()
		local m = F.model or F.single
		m = m and (P.mount(m) or m)
		if m then local x, _, z = P.model_pos(m) return x, z end
		local q = u:position() return q:get_x(), q:get_z()
	end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = os.clock() - t0
			local HOLD = _G.TP_SW_HOLD or 4
			local phase = math.floor(t / (HOLD + 1)) + 1
			local into = t - (phase - 1) * (HOLD + 1)
			if phase > #yaws then T.done = true put_back() bm:remove_real_callback("tp_siege_walk") return end
			if phase ~= k then
				k = phase
				local yaw = math.rad(yaws[phase])
				E.rig.yaw, E.rig.want_yaw = yaw, yaw
				local x, z = man_pos()
				mark = {x, z}
				hold = true
			end
			if hold and into >= HOLD then
				hold = false
				local x, z = man_pos()
				T.phases[#T.phases + 1] = math.floor(yaws[phase]) .. " deg: " .. math.floor(math.sqrt((x - mark[1]) ^ 2 + (z - mark[2]) ^ 2) * 100) / 100 .. " m in " .. HOLD .. " s, at " .. math.floor(x) .. "," .. math.floor(z)
			end
		end)
		if not worked then T.err = tostring(err) T.done = true put_back() pcall(function() bm:remove_real_callback("tp_siege_walk") end) end
	end, 1, "tp_siege_walk")
	return "walking " .. u:type() .. (F.model and " one man" or "")
end)
return ok and res or "ERR " .. tostring(res)
