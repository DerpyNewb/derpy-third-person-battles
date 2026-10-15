-- Deselect experiment, 2026-10-14: clear the selection for ~2.5 s (screenshot meanwhile), then reselect the
-- General. NO string library calls.
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GENERAL then u = units:item(i) end end
if not u then return "no " .. GENERAL end
local T = {n = 0}
_G.TP_DSHOT = T
bm:clear_selection()
bm:repeat_real_callback(function()
	T.n = T.n + 1
	if T.n >= 25 then bm:remove_real_callback("tp_dshot") pcall(function() u:select_in_ui() end) T.ended = true end
end, 100, "tp_dshot")
return "cleared, any selected " .. tostring(bm:is_any_unit_selected())
