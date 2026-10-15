-- move the already-held target (zz_target_setup) to STOP_AT m in front of the shooter, found by TYPE
-- (army list indexes shift when a unit dies), then pin it there: own-spot goto + halt every 0.5 s
local TYPE, STOP_AT = "wh3_main_cth_inf_jade_warrior_crossbowmen_1", 100
local ok, res = pcall(function()
	local S = _G.DERPY_TGT
	local units = bm:get_player_army():units()
	local me
	for i = 1, units:count() do if units:item(i):type() == TYPE then me = units:item(i) end end
	S.shooter = me
	local q = me:position()
	local b = math.rad(me:bearing())
	local tx, tz = q:get_x() + math.sin(b) * STOP_AT, q:get_z() + math.cos(b) * STOP_AT
	local e = S.enemy
	S.pin, S.arrived = nil, false
	bm:remove_real_callback("derpy_tgt_watch")
	S.uce:goto_location(v(tx, q:get_y(), tz), true)
	bm:repeat_real_callback(function()
		local p = e:position()
		local m = me:position()
		S.dist = math.floor(math.sqrt((p:get_x() - m:get_x()) ^ 2 + (p:get_z() - m:get_z()) ^ 2))
		S.men = e:number_of_men_alive()
		if not S.arrived and S.dist <= STOP_AT + 5 then S.arrived, S.pin = true, {p:get_x(), p:get_y(), p:get_z()} end
		if S.pin then S.uce:goto_location(v(S.pin[1], S.pin[2], S.pin[3]), false) S.uce:halt()
		else S.uce:goto_location(v(tx, q:get_y(), tz), true) end
	end, 500, "derpy_tgt_watch")
	return {shooter = me:type(), men = me:number_of_men_alive(), ammo = me:ammo_left(), to = {tx, tz}}
end)
if ok then return res end
return "ERR " .. tostring(res)
