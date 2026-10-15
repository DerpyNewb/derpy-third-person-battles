-- play_anim_for_captain on a regiment (the first non-general unit with more than 10 men): frame its
-- centre from the front at 14 m, screenshot before and after CELEBRATE_1.
local ok, res = pcall(function()
	local u
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		local x = units:item(i)
		if not u and not x:is_commanding_unit() and x:number_of_men_alive() > 10 then u = x end
	end
	if not u then return "no regiment" end
	local q = u:position()
	local b = math.rad(u:bearing())
	local fx, fz = math.sin(b), math.cos(b)
	bm:camera():move_to(v(q:get_x() + fx * 14, q:get_y() + 2.5, q:get_z() + fz * 14), v(q:get_x(), q:get_y() + 1, q:get_z()), 0, false, -1, false)
	bm:real_callback(function() common.take_screenshot("derpy_reg_0.tga") end, 300, "derpy_rg_0")
	bm:real_callback(function() u:play_anim_for_captain("CELEBRATE_1", false) end, 450, "derpy_rg_go")
	local shots = {800, 1200, 1700}
	for k = 1, #shots do
		bm:real_callback(function() common.take_screenshot("derpy_reg_" .. k .. ".tga") end, shots[k], "derpy_rg_" .. k)
	end
	return {unit = u:name(), men = u:number_of_men_alive()}
end)
if ok then return res end
return "ERR " .. tostring(res)
