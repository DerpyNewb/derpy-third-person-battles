-- Is the first Tzar Guard regiment in melee yet, and how far from its target? Third person off first (the next test turns
-- it on), so the pack's hold is not on a man while waiting. Read only otherwise. No string library calls.
local E = _G.DERPY_TP
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == "wh3_main_ksl_inf_tzar_guard_1" and x:number_of_men_alive() > 0 then u = x end
end
if not u then return "no tzar guard" end
if E and E.F and E.F.on then pcall(E.main.stop, "test wait") end
return "melee " .. tostring(u:is_in_melee()) .. " men " .. u:number_of_men_alive() .. " moving " .. tostring(u:is_moving())
	.. " ms " .. bm:time_elapsed_ms()
