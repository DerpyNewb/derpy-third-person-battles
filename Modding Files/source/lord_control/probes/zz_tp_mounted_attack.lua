local E = assert(DERPY_TP)
local u = bm:get_player_army():units():item(1)
if E.F.on then E.main.stop("mounted attack test") end
E.main.start(u)
local m = E.P.models(u)[1]
local mount = E.P.mount(m)
local T = {at = bm:time_elapsed_ms(), flying = u:is_currently_flying(), unit = u:type(), samples = {}}
_G.TP_MOUNTED_ATTACK_TEST = T
E.combat.melee(bm:time_elapsed_ms() / 1000, true)
bm:repeat_real_callback(function()
	local slot = E.P.anim_slot(m) or 0
	local mount_slot = mount and E.P.anim_slot(mount) or 0
	local key = slot .. ":" .. mount_slot
	if key ~= T.last then T.samples[#T.samples + 1] = {t = bm:time_elapsed_ms() - T.at, slot = slot, mount_slot = mount_slot} T.last = key end
	if bm:time_elapsed_ms() - T.at >= 4500 then
		bm:remove_real_callback("tp_mounted_attack_test")
		T.ended, T.strikes = true, E.strikes
	end
end, 20, "tp_mounted_attack_test")
return {started = true, flying = T.flying}
