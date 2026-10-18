-- Test scaffolding (2026-10-18): does an artillery piece fire on attack_unit with fire at will OFF? _G.TP_AA_IDX (player
-- army index) attacks the nearest enemy unit; ammo sampled every 0.5 s for _G.TP_AA_SECONDS (20). Read: _G.TP_AA.
-- No string library calls.
local ok, res = pcall(function()
	local army = bm:get_player_army()
	local u = army:units():item(_G.TP_AA_IDX or 20)
	local q = u:position()
	local best, target
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local e = ar:units():item(i)
			local p = e:position()
			local d = (p:get_x() - q:get_x()) ^ 2 + (p:get_z() - q:get_z()) ^ 2
			if not best or d < best then best, target = d, e end
		end
	end
	local c = army:create_unit_controller()
	c:add_units(u)
	c:fire_at_will(false)
	c:attack_unit(target, true, false)
	c:release_control()
	local T = {rows = {}, done = false, c = c}
	_G.TP_AA = T
	T.rows[1] = u:type() .. " -> " .. target:type() .. " " .. math.floor(math.sqrt(best)) .. " m, ammo " .. u:ammo_left()
	local t0 = os.clock()
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			local t = os.clock() - t0
			local p = u:position()
			T.rows[#T.rows + 1] = math.floor(t * 10) / 10 .. " ammo " .. u:ammo_left() .. " at " .. math.floor(p:get_x()) .. "," .. math.floor(p:get_z())
			if t > (_G.TP_AA_SECONDS or 20) then T.done = true bm:remove_real_callback("tp_arty_attack") end
		end)
		if not worked then T.err = tostring(err) T.done = true bm:remove_real_callback("tp_arty_attack") end
	end, 500, "tp_arty_attack")
	return T.rows[1]
end)
return ok and res or "ERR " .. tostring(res)
