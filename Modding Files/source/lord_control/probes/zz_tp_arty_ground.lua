-- Test scaffolding (2026-10-18, the author: artillery in third person played only its crew, as melee men). Does the
-- engine fire an artillery piece on a ground-fire order (fire at will on, attack_location 80 m ahead), as it does a whole
-- ranged unit's? Each of _G.TP_AG_IDX (player army indices) gets the order under a controller kept in a global; ammo is
-- sampled every 0.5 s for 15 s. Read: _G.TP_AG.rows. No string library calls.
local ok, res = pcall(function()
	local T = {rows = {}, done = false, ctl = {}}
	_G.TP_AG = T
	local army = bm:get_player_army()
	local list = {}
	for _, i in ipairs(_G.TP_AG_IDX or {18, 19, 20}) do
		local u = army:units():item(i)
		local c = army:create_unit_controller()
		c:add_units(u)
		local q, b = u:position(), math.rad(u:bearing())
		local ax, az = q:get_x() + math.sin(b) * 80, q:get_z() + math.cos(b) * 80
		c:fire_at_will(true)
		c:attack_location(v(ax, bm:get_terrain_height(ax, az), az), false)
		c:release_control()
		T.ctl[#T.ctl + 1] = c
		list[#list + 1] = {u = u, ammo0 = u:ammo_left()}
		T.rows[#T.rows + 1] = u:type() .. " artillery " .. tostring(u:is_artillery()) .. " ammo " .. u:ammo_left() .. " range " .. u:missile_range()
	end
	local t0 = os.clock()
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			local t = os.clock() - t0
			local row = math.floor(t * 10) / 10 .. ""
			for _, e in ipairs(list) do row = row .. " | " .. e.u:type() .. " ammo " .. e.u:ammo_left() end
			T.rows[#T.rows + 1] = row
			if t > 15 then T.done = true bm:remove_real_callback("tp_arty_ground") end
		end)
		if not worked then T.err = tostring(err) T.done = true bm:remove_real_callback("tp_arty_ground") end
	end, 500, "tp_arty_ground")
	return "ordered " .. #list
end)
return ok and res or "ERR " .. tostring(res)
