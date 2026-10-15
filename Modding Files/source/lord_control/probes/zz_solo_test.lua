-- self-test: play the crossbowmen, fire one solo shot through the hook, read it back, then let go (F2 off)
local ok, res = pcall(function()
	local F = _G.DERPY_FOLLOW
	if F.on then F.stop_fn("solo test") end
	local u
	local units = bm:get_player_army():units()
	for i = 1, units:count() do if units:item(i):type() == "wh3_main_cth_inf_jade_warrior_crossbowmen_1" then u = units:item(i) end end
	F.start_fn(u)
	local T = {solo = F.solo, model = F.model ~= nil, ranged = F.ranged, ammo0 = u:ammo_left()}
	_G.DERPY_SOLO = T
	bm:real_callback(function() T.fired_at = os.clock() F.man_shoot_fn(os.clock()) end, 1000, "derpy_solo_a")
	bm:real_callback(function()
		T.ammo1, T.shots, T.err, T.shot_err, T.on = u:ammo_left(), F.shots, F.err, F.shot_err, F.on
		F.stop_fn("solo test done")
	end, 2500, "derpy_solo_b")
	return T
end)
if ok then return res end
return "ERR " .. tostring(res)
