-- Is our unit of _G.TP_MS_TYPE in melee. No string library calls.
local want = _G.TP_MS_TYPE or "wh3_dlc29_emp_inf_teutogen_guard_ror"
local army = bm:get_player_army()
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if x:type() == want and x:number_of_men_alive() > 1 then return want .. " in melee " .. tostring(x:is_in_melee()) end
end
return "no " .. want
