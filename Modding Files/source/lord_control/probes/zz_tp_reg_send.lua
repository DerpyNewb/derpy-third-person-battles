-- The test's scaffold (2026-10-16): the first regiment of TYPE attacks the enemy unit nearest it, invincible, third person
-- off. Re-run to read whether it is in melee. _G.TP_REG_UC keeps the controller (set_invincible(false) when done).
-- No string library calls.
local TYPE = "wh3_main_ksl_inf_armoured_kossars_1"
local E = _G.DERPY_TP
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == TYPE and x:number_of_men_alive() > 0 then u = x end
end
if not u then return "no " .. TYPE end
if E and E.F and E.F.on then pcall(E.main.stop, "test wait") end
if u:is_in_melee() then return "melee true men " .. u:number_of_men_alive() end
if not _G.TP_REG_UC or (_G.TP_REG_RESEND and not u:is_moving()) then
	_G.TP_REG_RESEND = nil
	local q, best, bd = u:position(), nil, nil
	local enemies = bm:get_non_player_alliance():armies()
	for a = 1, enemies:count() do
		local l = enemies:item(a):units()
		for i = 1, l:count() do
			local e = l:item(i)
			if e:number_of_men_alive() > 0 and not e:is_routing() then
				local d = e:position():distance_xz(q)
				if not bd or d < bd then best, bd = e, d end
			end
		end
	end
	if not best then return "no enemy" end
	local uc = army:create_unit_controller()
	uc:add_units(u)
	uc:set_invincible(true)
	uc:attack_unit(best, true, true)
	_G.TP_REG_UC = uc
	return "sent at " .. best:type() .. " " .. math.floor(bd) .. " m"
end
return "melee false men " .. u:number_of_men_alive() .. " moving " .. tostring(u:is_moving())
