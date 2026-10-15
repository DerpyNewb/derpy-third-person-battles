-- Pin the enemy for testing (the author asked, 2026-10-14): take every enemy unit from the AI, move any within
-- 350 m of the player army's centre out to 400 m along the same line, facing the player, and halt them all
-- again every second for the rest of the battle. Re-send after a battle reload. No string library calls.
local ok, res = pcall(function()
	local pu = bm:get_player_army():units()
	local cx, cz, n = 0, 0, 0
	for i = 1, pu:count() do local q = pu:item(i):position() cx, cz, n = cx + q:get_x(), cz + q:get_z(), n + 1 end
	cx, cz = cx / n, cz / n
	local ucs, moved = {}, 0
	local armies = bm:get_non_player_alliance():armies()
	for a = 1, armies:count() do
		local units = armies:item(a):units()
		for i = 1, units:count() do
			local u = units:item(i)
			local uc = create_unitcontroller(u)
			uc:take_control()
			local q = u:position()
			local dx, dz = q:get_x() - cx, q:get_z() - cz
			local d = math.sqrt(dx * dx + dz * dz)
			if d < 350 then
				if d < 1 then dx, dz, d = 0, 1, 1 end
				local x, z = cx + dx / d * 400, cz + dz / d * 400
				uc:teleport_to_location(v(x, q:get_y(), z), math.deg(math.atan2(-dx, -dz)) % 360, 40)
				moved = moved + 1
			end
			uc:halt()
			ucs[#ucs + 1] = uc
		end
	end
	_G.TP_PINNED = ucs
	bm:remove_real_callback("tp_pin_enemy")
	bm:repeat_real_callback(function() for _, c in ipairs(_G.TP_PINNED) do pcall(function() c:take_control() c:halt() end) end end, 1000, "tp_pin_enemy")
	return "pinned " .. #ucs .. ", moved " .. moved
end)
return ok and res or ("failed " .. tostring(res))
