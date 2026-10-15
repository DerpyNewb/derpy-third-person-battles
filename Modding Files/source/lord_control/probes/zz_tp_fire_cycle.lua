-- Bridge-loaded source: hold fire for 28 model seconds, release, and let the reload finish.
local E = assert(DERPY_TP)
local u = bm:get_player_army():units():item(TP_FIRE_UNIT_INDEX or 3)
if E.F.on then E.main.stop("fire cycle test") end
E.main.start(u)
assert(E.F.solo, "test needs a supported ranged regiment")
local P = E.P
local focus, held, pressed, delta = P.focused, P.held, P.pressed, P.look_delta
local T = {at = bm:time_elapsed_ms(), ammo = u:ammo_left(), samples = {}, unit = u:type()}
_G.TP_FIRE_CYCLE_TEST = T
P.focused = function() return true end
P.held = function(k) return k == E.S.keys.attack and bm:time_elapsed_ms() - T.at < 28000 end
P.pressed = function() return false end
P.look_delta = function() return 0, 0 end
bm:remove_real_callback("tp_fire_cycle_test")
bm:repeat_real_callback(function()
	local F = E.F
	local t = bm:time_elapsed_ms() - T.at
	local phase = F.shot and F.shot.phase or "ready"
	local slot = F.model and P.anim_slot(F.model) or 0
	local key = phase .. ":" .. slot .. ":" .. F.shot_n
	if key ~= T.last then
		T.samples[#T.samples + 1] = {t = t, phase = phase, slot = slot, n = F.shot_n, ammo = u:ammo_left()}
		T.last = key
	end
	if t >= 41000 then
		P.focused, P.held, P.pressed, P.look_delta = focus, held, pressed, delta
		T.ended, T.strikes, T.ammo_after = true, E.strikes, u:ammo_left()
		T.ready = F.shot == nil
		bm:remove_real_callback("tp_fire_cycle_test")
	end
end, 50, "tp_fire_cycle_test")
return {started = true, unit = u:type()}
