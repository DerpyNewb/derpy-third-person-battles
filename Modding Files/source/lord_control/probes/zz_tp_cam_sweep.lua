-- Test scaffolding (2026-10-18, the author: "if its around a building, it would go way up"). The camera's floor
-- (exe+2ebf734) clamps the eye to A + min, A the collision height at the eye (exe+2ee841c, buildings included) and B
-- the terrain (exe+2ec2710). Asks for an eye 2 m over the terrain at each point of a line (_G.TP_CS_X, _G.TP_CS_Z0 to
-- _G.TP_CS_Z1, step _G.TP_CS_STEP), one every 300 ms, and records the height it got. "read" returns them.
-- Third person must be off. No string library calls.
local ok, res = pcall(function()
	if _G.TP_CS_MODE == "read" then
		local s = ""
		for _, l in ipairs(_G.TP_CS or {}) do s = s .. l .. " | " end
		return s
	end
	local x, z0, z1, step = _G.TP_CS_X or -60, _G.TP_CS_Z0 or -370, _G.TP_CS_Z1 or -420, _G.TP_CS_STEP or 5
	cam:change_height_range(0, 100)
	_G.TP_CS = {}
	local z, asked = z0, nil
	bm:remove_real_callback("tp_cam_sweep")
	bm:repeat_real_callback(function()
		if asked then
			local c = cam:position()
			_G.TP_CS[#_G.TP_CS + 1] = "z " .. asked .. " ground " .. math.floor(bm:get_terrain_height(x, asked) * 10) / 10
				.. " got +" .. math.floor((c:get_y() - bm:get_terrain_height(x, asked)) * 10) / 10
			z = asked + (z1 < z0 and -step or step)
			if (z1 < z0 and z < z1) or (z1 > z0 and z > z1) then bm:remove_real_callback("tp_cam_sweep") return end
		end
		local g = bm:get_terrain_height(x, z)
		cam:move_to(v(x, g + 2, z), v(x, g + 2, z + (z1 < z0 and -10 or 10)), 0, false, -1, false)
		asked = z
	end, 300, "tp_cam_sweep")
	return "sweeping x " .. x .. " z " .. z0 .. " to " .. z1
end)
return ok and res or "ERR " .. tostring(res)
