-- Test setup (2026-10-19), never shipped. Every enemy unit halted and invincible under controllers kept in _G.TP_FS (a
-- probe's local controllers die with it - zz_hold_enemy.lua); OUR units are left alone, unlike zz_hold_enemy.lua, so the
-- pack's invincibility (C.invincible) is not pre-empted by one already on. Our unit _G.TP_FS_OURS (player army index,
-- default 9) is placed at _G.TP_FS_AT (default {0, 330}) facing _G.TP_FS_FACE (default 0), and the enemy unit nearest
-- _G.TP_FS_FROM (default {0, 638}) _G.TP_FS_GAP m (default 90) in front of it, facing it, halted.
-- _G.TP_FS_OFF = true then sending it again releases them all. No string library calls.
local ok, res = pcall(function()
	local G = _G.TP_FS
	if _G.TP_FS_OFF then
		for _, c in ipairs(G and G.cs or {}) do pcall(function() c:set_invincible(false) c:release_control() end) end
		_G.TP_FS, _G.TP_FS_OFF = nil, nil
		return "released"
	end
	if not G then
		G = {cs = {}, of = {}}
		_G.TP_FS = G
		local all = bm:get_non_player_alliance():armies()
		for a = 1, all:count() do
			local ar = all:item(a)
			for i = 1, ar:units():count() do
				local u = ar:units():item(i)
				local c = ar:create_unit_controller()
				c:add_units(u)
				-- an order alone leaves the AI in charge: it ordered them on again at once (2026-10-19, every unit in the fort
				-- within a minute); CA's intro battles take control first
				c:take_control()
				c:set_invincible(true)
				-- a halt does not end a melee: out of it, on a line 500 m south
				local px = -400 + #G.cs * 40
				c:teleport_to_location(v(px, bm:get_terrain_height(px, -500), -500), 0, 30)
				c:halt()
				G.cs[#G.cs + 1] = c
				G.of[#G.cs] = u
			end
		end
	end
	local at, face, gap = _G.TP_FS_AT or {0, 330}, _G.TP_FS_FACE or 0, _G.TP_FS_GAP or 90
	local from = _G.TP_FS_FROM or {0, 638}
	local army = bm:get_player_army()
	local ours = army:units():item(_G.TP_FS_OURS or 9)
	local oc = army:create_unit_controller()
	oc:add_units(ours)
	oc:teleport_to_location(v(at[1], bm:get_terrain_height(at[1], at[2]), at[2]), face, 40)
	oc:release_control()
	local best, bd
	for k, u in ipairs(G.of) do
		if u:number_of_men_alive() >= 50 then
			local p = u:position()
			local d = (p:get_x() - from[1]) ^ 2 + (p:get_z() - from[2]) ^ 2
			if not bd or d < bd then best, bd = k, d end
		end
	end
	local r = math.rad(face)
	local tx, tz = at[1] + math.sin(r) * gap, at[2] + math.cos(r) * gap
	local c = G.cs[best]
	c:teleport_to_location(v(tx, bm:get_terrain_height(tx, tz), tz), (face + 180) % 360, 40)
	c:halt()
	return "holding " .. #G.cs .. "; " .. ours:type() .. " at " .. at[1] .. "," .. at[2] .. "; target " .. G.of[best]:type()
		.. " at " .. math.floor(tx) .. "," .. math.floor(tz)
end)
return ok and res or "ERR " .. tostring(res)
