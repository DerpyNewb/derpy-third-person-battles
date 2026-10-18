-- Test scaffolding (2026-10-18): every enemy unit halted and invincible, and every one of ours invincible, under
-- controllers kept in _G.TP_HELD_ENEMY so they live as long as the battle: a probe's local controllers went with it, the
-- AI took its units back and ended two battles. _G.TP_HOLD_OFF = true then sending it again lets them go.
-- No string library calls.
local ok, res = pcall(function()
	if _G.TP_HOLD_OFF then
		for _, c in ipairs(_G.TP_HELD_ENEMY or {}) do pcall(function() c:set_invincible(false) c:release_control() end) end
		_G.TP_HELD_ENEMY, _G.TP_HOLD_OFF = nil, nil
		return "released"
	end
	local held, n = {}, 0
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local u = ar:units():item(i)
			local c = ar:create_unit_controller()
			c:add_units(u)
			c:set_invincible(true)
			c:halt()
			held[#held + 1] = c
			n = n + 1
		end
	end
	local army = bm:get_player_army()
	for i = 1, army:units():count() do
		local c = army:create_unit_controller()
		c:add_units(army:units():item(i))
		c:set_invincible(true)
		c:release_control()
		held[#held + 1] = c
	end
	_G.TP_HELD_ENEMY = held
	return "holding " .. n .. " enemy units"
end)
return ok and res or "ERR " .. tostring(res)
