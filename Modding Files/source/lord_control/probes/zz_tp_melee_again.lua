-- The melee scaffold's orders again, the enemy taken off its AI first (take_control) so its own planner cannot move it
-- away. No string library calls.
local S = _G.TP_MELEE
if not S then return "no scaffold" end
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == "wh3_main_ksl_inf_armoured_kossars_1" then u = x end
end
S.theirs:take_control()
S.theirs:attack_unit(u, true, true)
S.mine:attack_unit(S.enemy, true, true)
return "ordered again, " .. math.floor(u:position():distance_xz(S.enemy:position())) .. " m apart"
