-- Test setup (the author, 2026-10-16: "you can stop the enemies from moving and disable ranged attacks to all armies to
-- extend testing"): every unit of both sides invincible, fearless and holding its fire; every enemy unit halted and kept
-- under a script controller, so its AI cannot move it. zz_tp_engage.lua's two attackers are taken over after this by
-- their own controllers. The player's side is released again: the pack and the player order it. Controllers kept in
-- _G.TP_FREEZE. Not shipped. No string library calls.
local ok, res = pcall(function()
	local G = _G.TP_FREEZE or {cs = {}}
	_G.TP_FREEZE = G
	local men, halted = 0, 0
	local function each(alliance, enemy)
		local armies = alliance:armies()
		for a = 1, armies:count() do
			local ar = armies:item(a)
			local c = ar:create_unit_controller()
			for i = 1, ar:units():count() do
				c:add_units(ar:units():item(i))
				men = men + 1
				if enemy then halted = halted + 1 end
			end
			c:take_control()
			c:set_invincible(true)
			c:morale_behavior_fearless()
			c:fire_at_will(false)
			if enemy then c:halt() else c:release_control() end
			G.cs[#G.cs + 1] = c
		end
	end
	each(bm:get_player_alliance(), false)
	each(bm:get_non_player_alliance(), true)
	return "frozen: " .. men .. " units invincible, fearless, holding fire; " .. halted .. " enemy units halted"
end)
return ok and res or "ERR " .. tostring(res)
