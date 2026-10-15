-- the address of the model zz_tp_f2_drift.lua will control (same unit choice, same front_man), for tp_cmd_trace.py
local E = _G.DERPY_TP
if not (E and E.move) then return "ERR load the bridge first" end
local u
for i = 1, bm:get_player_army():units():count() do
	local x = bm:get_player_army():units():item(i)
	if not u and x:number_of_men_alive() >= 10 and not x:is_artillery() then u = x end
end
if not u then return "ERR no regiment of 10 or more men" end
local m = E.move.front_man(u)
return {model = m and memreader_plus.tostring(m), steer_wrapped = _G.TP_STEER_ORIG ~= nil}
