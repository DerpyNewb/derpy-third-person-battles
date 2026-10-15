-- spike: the shooter ground-fires at a point AHEAD m in front for DUR s, then halts and is released
local AHEAD, DUR = 60, 25
local ok, res = pcall(function()
	local u = _G.DERPY_TGT.shooter
	local q = u:position()
	local b = math.rad(u:bearing())
	local uc = create_unitcontroller(u)
	uc:fire_at_will(true)
	uc:attack_location(v(q:get_x() + math.sin(b) * AHEAD, q:get_y(), q:get_z() + math.cos(b) * AHEAD), false)
	uc:release_control()
	bm:remove_real_callback("derpy_gfire_end")
	bm:real_callback(function() uc:halt() uc:release_control() end, DUR * 1000, "derpy_gfire_end")
	return {ammo = u:ammo_left()}
end)
if ok then return res end
return "ERR " .. tostring(res)
