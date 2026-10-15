-- Start while a previous walk is active, then idle/W/release/off/on without physical key input.
local E = assert(DERPY_TP)
local u = bm:get_player_army():units():item(3)
if E.F.on then E.main.stop("idle handover test") end
local P = E.P
local focus, held, pressed, delta = P.focused, P.held, P.pressed, P.look_delta
local q = u:position()
local uc = create_unitcontroller(u)
uc:goto_location(v(q:get_x(), q:get_y(), q:get_z() - 10), false)
uc:release_control()
local T = {at = bm:time_elapsed_ms(), samples = {}, stage = 0}
_G.TP_IDLE_HANDOVER_TEST = T
P.focused = function() return true end
P.pressed = function() return false end
P.look_delta = function() return 0, 0 end
P.held = function(k)
	local t = bm:time_elapsed_ms() - T.at
	return k == E.S.keys.forward and t >= 2500 and t < 4500
end
bm:repeat_real_callback(function()
	local t = bm:time_elapsed_ms() - T.at
	local stage = t < 500 and 0 or t < 2500 and 1 or t < 4500 and 2 or t < 6500 and 3 or t < 8500 and 4 or 5
	if stage ~= T.stage then
		if stage == 1 or stage == 5 then E.main.start(u) end
		if stage == 4 then E.main.stop("handover") end
		T.stage = stage
	end
	if E.F.model then
		local x, _, z = P.model_pos(E.F.model)
		T.samples[#T.samples + 1] = {t = t, stage = stage, x = x, z = z}
	end
	if t >= 10500 then
		P.focused, P.held, P.pressed, P.look_delta = focus, held, pressed, delta
		T.ended, T.strikes = true, E.strikes
		bm:remove_real_callback("tp_idle_handover_test")
	end
end, 100, "tp_idle_handover_test")
return {started = true}
