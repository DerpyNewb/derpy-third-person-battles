-- A melee that lasts, for the regiment tests (2026-10-16): the first regiment of TYPE and the enemy regiment nearest it
-- are both made invincible (test scaffolding through script unit controllers, never the pack) and sent at each other.
-- Re-run to read whether they are in melee. No string library calls.
local TYPE = "wh3_main_ksl_inf_armoured_kossars_1"
local E = _G.DERPY_TP
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == TYPE and x:number_of_men_alive() > 0 then u = x end
end
if not u then return "no " .. TYPE end
if E and E.F and E.F.on then pcall(E.main.stop, "test wait") end
local S = _G.TP_MELEE
if S then
	return "melee " .. tostring(u:is_in_melee()) .. " men " .. u:number_of_men_alive() .. " vs " .. S.enemy:number_of_men_alive()
		.. " moving " .. tostring(u:is_moving()) .. " apart " .. math.floor(u:position():distance_xz(S.enemy:position())) .. " m"
end
local q, best, bd, barmy = u:position(), nil, nil, nil
local enemies = bm:get_non_player_alliance():armies()
for a = 1, enemies:count() do
	local l = enemies:item(a):units()
	for i = 1, l:count() do
		local e = l:item(i)
		if e:number_of_men_alive() >= 20 and not e:is_routing() then
			local d = e:position():distance_xz(q)
			if not bd or d < bd then best, bd, barmy = e, d, enemies:item(a) end
		end
	end
end
if not best then return "no enemy regiment of 20 or more" end
local mine, theirs = army:create_unit_controller(), barmy:create_unit_controller()
mine:add_units(u)
theirs:add_units(best)
mine:set_invincible(true)
theirs:set_invincible(true)
mine:attack_unit(best, true, true)
theirs:attack_unit(u, true, true)
_G.TP_MELEE = {mine = mine, theirs = theirs, enemy = best}
return "set: " .. best:type() .. " (" .. best:number_of_men_alive() .. " men) " .. math.floor(bd) .. " m away"
