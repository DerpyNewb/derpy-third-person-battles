-- The melee scaffold's two regiments: melee, routing, moving, men. Read only. No string library calls.
local S = _G.TP_MELEE
if not S then return "no scaffold" end
local e = S.enemy
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == "wh3_main_ksl_inf_armoured_kossars_1" then u = x end
end
return "kossars melee " .. tostring(u:is_in_melee()) .. " routing " .. tostring(u:is_routing()) .. " moving " .. tostring(u:is_moving())
	.. " | enemy melee " .. tostring(e:is_in_melee()) .. " routing " .. tostring(e:is_routing()) .. " moving " .. tostring(e:is_moving())
	.. " men " .. e:number_of_men_alive() .. " | apart " .. math.floor(u:position():distance_xz(e:position()))
