-- does unitcontroller:attack_location make a missile unit shoot at a ground point? measured by ammo
local IDX, AHEAD_M = 4, 80
local ok, res = pcall(function()
	local u = bm:get_player_army():units():item(IDX)
	local p = u:position()
	local b = math.rad(u:bearing())
	local tx, tz = p:get_x() + math.sin(b) * AHEAD_M, p:get_z() + math.cos(b) * AHEAD_M
	local T = {name = u:type(), ammo0 = u:ammo_left(), target = {tx, tz}}
	_G.DERPY_FIRE = T
	local uc = create_unitcontroller(u)
	uc:attack_location(v(tx, p:get_y(), tz), false)
	uc:release_control()
	for _, ms in ipairs({1500, 3000, 6000}) do
		bm:real_callback(function() T["ammo_" .. ms] = u:ammo_left() T["moved_" .. ms] = math.floor(u:position():distance_xz(p) * 10) / 10 end, ms, "derpy_fire_" .. ms)
	end
	return T
end)
if ok then return res end
return "ERR " .. tostring(res)
