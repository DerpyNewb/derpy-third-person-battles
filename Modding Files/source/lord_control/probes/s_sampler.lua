-- Records, every 0.5 s for 12 s, where the camera is and how far it sits from the general.
-- Read back with t_sampler_read.lua. Installed right after a battle loads, with nobody touching input.
local ok, res = pcall(function()
	bm:remove_real_callback("derpy_cam_sampler")
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	local cam = bm:camera()
	local T = {rows = {}, pref = core:get_integer_preference("default_battle_camera_type"), t0 = os.clock()}
	_G.DERPY_CAM_SAMPLER = T
	bm:repeat_real_callback(function()
		local good, err = pcall(function()
			local p, q = cam:position(), lord:position()
			local dx, dz = p:get_x() - q:get_x(), p:get_z() - q:get_z()
			T.rows[#T.rows + 1] = {math.floor((os.clock() - T.t0) * 10) / 10, p:get_x(), p:get_y(), p:get_z(), math.sqrt(dx * dx + dz * dz), p:get_y() - q:get_y()}
			if os.clock() - T.t0 > 12 then bm:remove_real_callback("derpy_cam_sampler") T.done = true end
		end)
		if not good then T.err = tostring(err) bm:remove_real_callback("derpy_cam_sampler") end
	end, 500, "derpy_cam_sampler")
	local q = lord:position()
	return {lord = {q:get_x(), q:get_y(), q:get_z(), lord:bearing()}, pref = T.pref}
end)
if ok then return res end
return "ERR " .. tostring(res)
