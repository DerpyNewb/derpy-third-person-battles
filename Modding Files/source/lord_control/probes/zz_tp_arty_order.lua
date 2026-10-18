-- Test scaffolding (2026-10-18): does an artillery piece fire on attack_location with fire at will OFF, so a shot is the
-- order's and not fire at will's? _G.TP_AO_IDX (player army index) is ordered onto the ground under the nearest enemy
-- unit (_G.TP_AO_GROUND: a point that far straight ahead instead); ammo sampled every 0.5 s for 15 s. Read: _G.TP_AO.
-- No string library calls.
local ok, res = pcall(function()
	local army = bm:get_player_army()
	local u = army:units():item(_G.TP_AO_IDX or 18)
	local q = u:position()
	local tx, tz, best
	if _G.TP_AO_GROUND then
		local b = math.rad(u:bearing())
		tx, tz = q:get_x() + math.sin(b) * _G.TP_AO_GROUND, q:get_z() + math.cos(b) * _G.TP_AO_GROUND
	else
		local all = bm:get_non_player_alliance():armies()
		for a = 1, all:count() do
			local ar = all:item(a)
			for i = 1, ar:units():count() do
				local e = ar:units():item(i)
				local p = e:position()
				local d = (p:get_x() - q:get_x()) ^ 2 + (p:get_z() - q:get_z()) ^ 2
				if not best or d < best then best, tx, tz = d, p:get_x(), p:get_z() end
			end
		end
	end
	local c = army:create_unit_controller()
	c:add_units(u)
	c:fire_at_will(false)
	c:attack_location(v(tx, bm:get_terrain_height(tx, tz), tz), false)
	c:release_control()
	local T = {rows = {}, done = false, c = c}
	_G.TP_AO = T
	T.rows[1] = u:type() .. " at " .. math.floor(q:get_x()) .. "," .. math.floor(q:get_z()) .. " -> " .. math.floor(tx) .. "," .. math.floor(tz)
		.. " (" .. math.floor(math.sqrt((tx - q:get_x()) ^ 2 + (tz - q:get_z()) ^ 2)) .. " m) ammo " .. u:ammo_left()
	local t0 = os.clock()
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			local t = os.clock() - t0
			local p = u:position()
			T.rows[#T.rows + 1] = math.floor(t * 10) / 10 .. " ammo " .. u:ammo_left() .. " faw " .. tostring(u:is_behaviour_active("fire_at_will"))
				.. " at " .. math.floor(p:get_x()) .. "," .. math.floor(p:get_z())
			if t > 15 then T.done = true bm:remove_real_callback("tp_arty_order") end
		end)
		if not worked then T.err = tostring(err) T.done = true bm:remove_real_callback("tp_arty_order") end
	end, 500, "tp_arty_order")
	return T.rows[1]
end)
return ok and res or "ERR " .. tostring(res)
