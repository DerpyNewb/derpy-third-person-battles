-- Test scaffolding (2026-10-17, the author: "check artillery still bugging"): how often _G.TP_TF_TYPE (default the
-- Tilean tank, teb_tank_ror) fires in 30 s at the nearest enemy. _G.TP_TF_MODE "vanilla": third person off, one
-- attack_location from a fresh controller, "unit" one attack_unit on the enemy; "steady": third person on, the fire key held, the crosshair's point held on the
-- enemy (E.combat.aim_point stubbed); "sweep": the same with the point moved 6 m every 0.6 s, as a hand on the mouse
-- moves it. _G.TP_TF_AHEAD: a ground point that many m ahead of him instead of the enemy, _G.TP_TF_TURN degrees
-- off his facing. Every ammo change and every order the pack logs. Read with zz_tp_tank_fire_read.lua. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F, C = E.P, E.F, E.combat
	local want, mode = _G.TP_TF_TYPE or "teb_tank_ror", _G.TP_TF_MODE or "vanilla"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do if army:units():item(i):type() == want then u = army:units():item(i) end end
	if not u then return "no " .. tostring(want) end
	if F.on then E.main.stop("tank fire test") end
	local q = u:position()
	local best, bd
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local e = ar:units():item(i)
			if e:number_of_men_alive() > 0 then
				local p = e:position()
				local d = math.sqrt((p:get_x() - q:get_x()) ^ 2 + (p:get_z() - q:get_z()) ^ 2)
				if not bd or d < bd then best, bd = e, d end
			end
		end
	end
	if not best then return "no enemy" end
	local p = best:position()
	local tx, ty, tz = p:get_x(), p:get_y(), p:get_z()
	if _G.TP_TF_AHEAD then -- a ground point that many m ahead along his facing instead of the enemy
		local b = math.rad(u:bearing() + (_G.TP_TF_TURN or 0))
		tx, tz = q:get_x() + math.sin(b) * _G.TP_TF_AHEAD, q:get_z() + math.cos(b) * _G.TP_TF_AHEAD
		ty = bm:get_terrain_height(tx, tz)
	end
	local T = {type = want, mode = mode, enemy = best:type(), enemy_d = math.floor(bd), ammo = {}, log = {}, done = false,
		range = u:missile_range()}
	_G.TP_TF = T
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
	local saved, aim_was, log_was = {}, C.aim_point, E.log
	local t0, last = now(), u:ammo_left()
	T.ammo0 = last
	local function finish(why)
		T.done, T.why = true, why
		if F.on then pcall(E.main.stop, "tank fire test") end
		for k, f in pairs(saved) do P[k] = f end
		C.aim_point, E.log = aim_was, log_was
		pcall(function() bm:remove_real_callback("tp_tank_fire") end)
	end
	if mode == "vanilla" or mode == "unit" then
		local uc = army:create_unit_controller()
		uc:add_units(u)
		if mode == "unit" then uc:attack_unit(best, true, false) else uc:attack_location(v(tx, ty, tz), false) end
		uc:release_control()
		T.facing = {}
	else
		for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
		local fire = E.S.keys.attack
		local id = type(fire) == "table" and fire[1] or fire
		local down = false
		P.held = function(k) return down and (type(k) == "table" and k[1] or k) == id end
		local was = false
		P.pressed = function(k) -- an edge of the fire key only
			if (type(k) == "table" and k[1] or k) ~= id then return false end
			local e = down and not was
			was = down
			return e
		end
		P.focused = function() return true end
		P.look_begin = function() end
		P.look_delta = function() return 0, 0 end
		E.log = function(msg) if #T.log < 40 then T.log[#T.log + 1] = r1(now() - t0) .. " " .. tostring(msg) end return log_was(msg) end
		bm:clear_selection()
		u:select_in_ui()
		E.main.start(u)
		if not F.on then finish("could not start") return T.why end
		P.wheel = function() return 0 end
		-- every order the pack gives, logged: its controller behind a proxy for the run
		local real = F.uc
		F.uc = setmetatable({}, {__index = function(_, name)
			local f = real[name]
			if type(f) ~= "function" then return f end
			return function(_, ...)
				if name ~= "release_control" and #T.log < 40 then T.log[#T.log + 1] = r1(now() - t0) .. " uc:" .. name end
				return f(real, ...)
			end
		end})
		T.facing = {}
		T.whole = F.model == nil
		E.rig.yaw = math.atan2(tx - q:get_x(), tz - q:get_z())
		E.rig.want_yaw = E.rig.yaw
		local k = 0
		C.aim_point = function()
			if mode == "sweep" then k = math.floor((now() - t0) / 0.6) % 2 return tx + k * 6, ty, tz end
			return tx, ty, tz
		end
		T.press = function() down = true end -- 0.5 s in: on the first tick he has not the mouse yet
	end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = now() - t0
			local a = u:ammo_left()
			if a ~= last then T.ammo[#T.ammo + 1] = r1(t) .. ":" .. a last = a end
			if mode ~= "vanilla" and mode ~= "unit" and not F.on then finish("third person went off") return end
			if T.press and t >= 0.5 then T.press() T.press = nil end
			if T.facing and t >= #T.facing + 1 and #T.facing < 30 then
				local ax, az = tx, tz
				if mode ~= "vanilla" and mode ~= "unit" then local x, _, z = C.aim_point(u:missile_range()) ax, az = x, z end
				local w = math.deg(math.atan2(ax - u:position():get_x(), az - u:position():get_z())) % 360
				local up = u:position()
				T.facing[#T.facing + 1] = math.floor(t) .. ": facing " .. math.floor(u:bearing()) .. " aim " .. math.floor(w) .. " at " .. math.floor(up:get_x()) .. "," .. math.floor(up:get_z()) .. ", "
					.. math.floor(math.sqrt((tx - up:get_x()) ^ 2 + (tz - up:get_z()) ^ 2)) .. " m to the target"
					.. (u:is_moving() and " moving" or "") .. (F.firing and " firing" or "")
			end
			if t >= 30 then T.fired = T.ammo0 - a finish("ran") end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_tank_fire")
	return "watching " .. want .. " " .. mode .. " at " .. best:type() .. " " .. math.floor(bd) .. " m"
end)
return ok and res or "ERR " .. tostring(res)
