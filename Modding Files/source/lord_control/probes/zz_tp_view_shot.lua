-- Third person on the General for 3 s, for a screenshot of what shows. NO string library calls.
local E = _G.DERPY_TP
if not (E and E.main) then return "load the bridge first" end
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GENERAL then u = units:item(i) end end
if not u then return "no " .. GENERAL end
local T = {n = 0}
_G.TP_VIEW = T
bm:repeat_real_callback(function()
	T.n = T.n + 1
	if T.n == 1 then pcall(E.main.start, u) end
	if T.n >= 30 then bm:remove_real_callback("tp_view") pcall(E.main.stop, "view probe") T.ended = true end
end, 100, "tp_view")
return "started"
