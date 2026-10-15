-- F2 drift, 2026-10-14: does the controlled man stay put with no keys, walk on W and stop on release,
-- from idle (scenario A) and during a prior regiment move order (scenario B)? Scripted input only; the
-- original input functions come back at the end or on any error. Result in TP_F2_DRIFT, read it back with
-- zz_tp_f2_drift_read.lua. Samples the man, a neighbour, the unit centre, his command type and point.
-- top level never throws: an error inside wh3_eval wedges the bridge for the rest of the session
local E = _G.DERPY_TP
if not (E and E.main) then return "ERR load the bridge first" end
local P, mr = E.P, memreader_plus
local u
for i = 1, bm:get_player_army():units():count() do -- battle lists are 1-based
	local x = bm:get_player_army():units():item(i)
	if not u and x:number_of_men_alive() >= 10 and not x:is_artillery() then u = x end
end
if not u then return "ERR no regiment of 10 or more men" end
if E.F.on then E.main.stop("f2 drift test") end
local focus, held, pressed, delta = P.focused, P.held, P.pressed, P.look_delta
-- {from ms, stage name, action at entry}
local PLAN = {
	{500, "A on idle", "on"}, {2500, "A W", nil}, {4500, "A release", nil}, {6500, "A off", "off"},
	{8500, "A on again", "on"}, {10500, "B order", "order"}, {11000, "B on idle", "on"}, {13000, "B W", nil},
	{15000, "B release", nil}, {17000, "B off", "off"}, {19000, "end", "end"},
}
local W = {["A W"] = true, ["B W"] = true}
local T = {at = bm:time_elapsed_ms(), unit = u:type(), samples = {}, stage = "setup", log = {}}
_G.TP_F2_DRIFT = T
local function restore()
	P.focused, P.held, P.pressed, P.look_delta = focus, held, pressed, delta
	bm:remove_real_callback("tp_f2_drift")
end
local function other(m)
	for _, x in ipairs(P.models(u)) do if not P.same(x, m) then return x end end
end
P.focused = function() return true end
P.pressed = function() return false end
P.look_delta = function() return 0, 0 end
P.held = function(k) return k == E.S.keys.forward and W[T.stage] == true end
local nb
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		local t = bm:time_elapsed_ms() - T.at
		local stage, act = T.stage, nil
		for _, p in ipairs(PLAN) do if t >= p[1] then stage, act = p[2], p[3] end end
		if stage ~= T.stage then
			T.stage = stage
			T.log[#T.log + 1] = t .. " " .. stage
			if act == "on" then E.main.start(u) nb = E.F.model and other(E.F.model)
			elseif act == "off" then E.main.stop("drift test")
			elseif act == "order" then
				if E.F.on then E.main.stop("drift test") end
				local q = u:position()
				local uc = create_unitcontroller(u)
				uc:goto_location(v(q:get_x(), q:get_y(), q:get_z() - 10), false)
				uc:release_control()
			elseif act == "end" then
				if E.F.on then E.main.stop("drift test") end
				restore()
				T.ended, T.strikes = true, E.strikes
				return
			end
		end
		local m = E.F.model or T.m
		T.m = m
		if not m then return end
		local q = u:position()
		local x, _, z = P.model_pos(m)
		local s = {t = t, s = stage, x = x, z = z, ux = q:get_x(), uz = q:get_z(), on = E.F.on == true,
			cmd = mr.tostring(mr.read_pointer(m, 0x330)), px = mr.read_float(m, 0x368), pz = mr.read_float(m, 0x370),
			hold = E.F.man_hold and (E.F.man_hold[1] .. "," .. E.F.man_hold[2]) or nil, yaw = E.rig.yaw}
		if nb then s.nx, _, s.nz = P.model_pos(nb) end
		T.samples[#T.samples + 1] = s
	end)
	if not ok then T.error = tostring(err) restore() if E.F.on then pcall(E.main.stop, "drift test error") end end
end, 100, "tp_f2_drift")
return {started = true, unit = T.unit}
