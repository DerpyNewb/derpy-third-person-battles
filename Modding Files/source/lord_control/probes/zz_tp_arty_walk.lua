-- Test scaffolding (2026-10-17): how far _G.TP_AW_TYPE gets in 6 s straight ahead along its own facing.
-- _G.TP_AW_MODE "run" / "walk": third person off, one goto_location 15 m ahead from a fresh controller, as the pack's walk
-- sends it; "pack": third person on and the forward key held (synthetic keys, the camera turned to its facing).
-- Position every 0.5 s. Read with zz_tp_arty_walk_read.lua. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local want, mode = _G.TP_AW_TYPE, _G.TP_AW_MODE or "run"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do if army:units():item(i):type() == want then u = army:units():item(i) end end
	if not u then return "no " .. tostring(want) end
	if F.on then E.main.stop("walk test") end
	local T = {type = want, mode = mode, at = {}, log = {}, done = false}
	_G.TP_AW = T
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
	local q0 = u:position()
	local x0, z0 = q0:get_x(), q0:get_z()
	local b = math.rad(u:bearing())
	T.bearing = r1(u:bearing())
	local saved, log_was = {}, E.log
	T.t0 = now()
	local function put_back()
		for k, f in pairs(saved) do P[k] = f end
		E.log = log_was
		if F.on then pcall(E.main.stop, "walk test") end
	end
	if mode == "pack" then
		for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
		local fwd = E.S.keys.forward
		local id = type(fwd) == "table" and fwd[1] or fwd
		P.held = function(k) return (type(k) == "table" and k[1] or k) == id end
		P.pressed = function() return false end
		P.focused = function() return true end
		P.look_begin = function() end
		P.look_delta = function() return 0, 0 end
		P.wheel = function() return 0 end
		E.log = function(msg) if #T.log < 30 then T.log[#T.log + 1] = r1(now() - T.t0) .. " " .. tostring(msg) end return log_was(msg) end
		E.main.start(u)
		E.rig.yaw = b
	else
		local uc = army:create_unit_controller()
		uc:add_units(u)
		uc:goto_location(v(x0 + math.sin(b) * 15, q0:get_y(), z0 + math.cos(b) * 15), mode == "run")
		uc:release_control()
	end
	local next_at = 0
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = now() - T.t0
			if t >= next_at then
				next_at = next_at + 0.5
				local q = u:position()
				T.at[#T.at + 1] = r1(t) .. ":" .. r1(math.sqrt((q:get_x() - x0) ^ 2 + (q:get_z() - z0) ^ 2)) .. (u:is_moving() and "m" or "")
					.. " b" .. r1(u:bearing())
			end
			if t > 6 then T.done = true put_back() bm:remove_real_callback("tp_arty_walk") end
		end)
		if not worked then T.err = tostring(err) T.done = true put_back() pcall(function() bm:remove_real_callback("tp_arty_walk") end) end
	end, 1, "tp_arty_walk")
	return "watching " .. want .. " " .. mode
end)
return ok and res or "ERR " .. tostring(res)
