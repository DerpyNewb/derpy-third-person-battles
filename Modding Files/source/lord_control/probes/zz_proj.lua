-- spike: does bm:trigger_projectile_launch fly and do damage? N crossbow bolts from a point GAP m in
-- front of the nearest enemy, aimed at its centre; its men are counted before and WAIT ms after.
local KEY, N, GAP, WAIT = "wh3_cth_crossbow_bolt", 20, 40, 4000
local ok, res = pcall(function()
	local me
	local units = bm:get_player_army():units()
	for i = 1, units:count() do if units:item(i):type() == "wh3_main_cth_inf_jade_warrior_crossbowmen_1" then me = units:item(i) end end
	local q = me:position()
	local best, bd
	local armies = bm:get_non_player_alliance():armies()
	for a = 1, armies:count() do
		local list = armies:item(a):units()
		for i = 1, list:count() do
			local e = list:item(i)
			local d = q:distance_xz(e:position())
			if e:number_of_men_alive() > 0 and (not bd or d < bd) then best, bd = e, d end
		end
	end
	local p = best:position()
	local dx, dz = q:get_x() - p:get_x(), q:get_z() - p:get_z()
	local l = math.sqrt(dx * dx + dz * dz)
	local from = v(p:get_x() + dx / l * GAP, p:get_y() + 2, p:get_z() + dz / l * GAP)
	local to = v(p:get_x(), p:get_y() + 1, p:get_z())
	local P = {target = best:type(), dist = math.floor(bd), men0 = best:number_of_men_alive(), ammo0 = me:ammo_left(), errs = {}}
	_G.DERPY_PROJ = P
	for k = 1, N do
		local fine, err = pcall(function() bm:trigger_projectile_launch(KEY, from, to) end)
		if not fine then P.errs[#P.errs + 1] = tostring(err) end
	end
	bm:remove_real_callback("derpy_proj")
	bm:real_callback(function() P.men1 = best:number_of_men_alive() P.ammo1 = me:ammo_left() end, WAIT, "derpy_proj")
	return P
end)
if ok then return res end
return "ERR " .. tostring(res)
