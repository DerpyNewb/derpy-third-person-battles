-- unitcontroller:attack_location on a melee general: a point 6 m ahead. Frame side-on, screenshot
-- before and at 0.6/1.2/2.0 s, and record how far he moved.
local ok, res = pcall(function()
	local u
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then u = units:item(i) end
	end
	local q = u:position()
	local b = math.rad(u:bearing())
	local fx, fz = math.sin(b), math.cos(b)
	local rx, rz = fz, -fx
	_G.DERPY_A4 = {q:get_x(), q:get_z()}
	bm:camera():move_to(v(q:get_x() + rx * 7 + fx * 3, q:get_y() + 1.8, q:get_z() + rz * 7 + fz * 3), v(q:get_x() + fx * 3, q:get_y() + 1.2, q:get_z() + fz * 3), 0, false, -1, false)
	local uc = create_unitcontroller(u)
	bm:real_callback(function() common.take_screenshot("derpy_aloc_0.tga") end, 250, "derpy_al_0")
	bm:real_callback(function() uc:attack_location(v(q:get_x() + fx * 6, q:get_y(), q:get_z() + fz * 6), false) uc:release_control() end, 400, "derpy_al_go")
	local shots = {1000, 1600, 2400}
	for k = 1, #shots do
		bm:real_callback(function() common.take_screenshot("derpy_aloc_" .. k .. ".tga") end, shots[k], "derpy_al_" .. k)
	end
	return "attack_location 6 m ahead"
end)
if ok then return res end
return "ERR " .. tostring(res)
