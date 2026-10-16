-- Test setup: the two nearest enemy units of 50+ men are teleported 14 m from our unit of _G.TP_MS_TYPE and ordered to
-- attack it, invincible. _G.TP_ENGAGE_OFF = true then sending zz_tp_engage.lua again releases them. Not shipped.
-- No string library calls.
local ok, res = pcall(function()
	local G = _G.TP_ENGAGE or {cs = {}}
	_G.TP_ENGAGE = G
	if _G.TP_ENGAGE_OFF then
		for _, c in ipairs(G.cs) do pcall(function() c:set_invincible(false) c:release_control() end) end
		G.cs, _G.TP_ENGAGE_OFF = {}, nil
		return "released"
	end
	local want = _G.TP_MS_TYPE or "wh3_dlc29_emp_inf_teutogen_guard_ror"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 1 then u = x break end
	end
	if not u then return "no " .. want end
	local p = u:position()
	local x, z = p:get_x(), p:get_z()
	local cands = {}
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local e = ar:units():item(i)
			if e:number_of_men_alive() >= 50 and not e:is_artillery() then
				cands[#cands + 1] = {ar = ar, e = e, d = e:position():distance_xz(p)}
			end
		end
	end
	table.sort(cands, function(a, b) return a.d < b.d end)
	local offs = {{0, 14, 180}, {14, 0, 270}}
	local names = {}
	for k = 1, math.min(2, #cands) do
		local c = cands[k].ar:create_unit_controller()
		c:add_units(cands[k].e)
		c:set_invincible(true)
		local o = offs[k]
		c:teleport_to_location(v(x + o[1], bm:get_terrain_height(x + o[1], z + o[2]), z + o[2]), o[3], 20)
		c:attack_unit(u, true, true)
		G.cs[#G.cs + 1] = c
		names[#names + 1] = cands[k].e:type()
	end
	return "engaging " .. want .. " with " .. table.concat(names, ", ")
end)
return ok and res or "ERR " .. tostring(res)
