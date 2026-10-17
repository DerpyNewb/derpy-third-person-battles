-- Test scaffolding: one man of _G.TP_RH_TYPE played alone with fire held for _G.TP_RH_DURATION s of battle time
-- (default 25); the battle time of each shot (F.shot_n going up) and each F.ready_at the pack sets, from the start.
-- Read back with zz_tp_reload_hold_read.lua. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local want, DURATION = _G.TP_RH_TYPE, _G.TP_RH_DURATION or 25
	local army = bm:get_player_army()
	local u
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 1 then u = x end
	end
	if not u then return "no " .. tostring(want) end
	if F.on then E.main.stop("reload test") end
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
	local attack = E.S.keys.attack
	local id = type(attack) == "table" and attack[1] or attack
	local function ours(k) return (type(k) == "table" and k[1] or k) == id end
	local down = false
	P.held = function(k) return down and ours(k) end
	P.pressed = function() return false end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
	local T = {type = want, shots = {}, readys = {}, reload = E.D.shots[want] and E.D.shots[want][2], factor = E.S.reload_factor}
	_G.TP_RH = T
	local function finish()
		down = false
		if F.on then pcall(E.main.stop, "reload test") end
		for k, f in pairs(saved) do P[k] = f end
		T.done = true
		pcall(function() bm:remove_real_callback("tp_reload_hold") end)
	end
	E.main.start(u)
	if not F.on or not F.solo then T.err = "not shooting alone: on " .. tostring(F.on) .. ", solo " .. tostring(F.solo) finish() return T.err end
	T.reload_slot = tostring(F.reload_slot)
	local t0, n, ready = now(), F.shot_n or 0, F.ready_at
	down = true
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = now() - t0
			if (F.shot_n or 0) ~= n then n = F.shot_n or 0 T.shots[#T.shots + 1] = r1(t) end
			if F.ready_at ~= ready then ready = F.ready_at T.readys[#T.readys + 1] = r1(t) .. " -> " .. r1((ready or 0) - t0) end
			if not F.on or t > DURATION then finish() end
		end)
		if not worked then T.err = tostring(err) finish() end
	end, 1, "tp_reload_hold")
	return "holding fire on " .. want
end)
return ok and res or "ERR " .. tostring(res)
