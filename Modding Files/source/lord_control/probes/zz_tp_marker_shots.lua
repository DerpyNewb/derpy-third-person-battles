-- Selection-marker experiment, 2026-10-14, paired with screenshots: markers pref 0 on the current selection
-- (shot A ~1.5 s), then clear and reselect the General under pref 0 (shot B ~3.5 s), then the player's value
-- back (shot C ~6 s). NO string library calls.
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GENERAL then u = units:item(i) end end
if not u then return "no " .. GENERAL end
local T = {n = 0, was = core:get_integer_preference("ui_selection_markers")}
_G.TP_MSHOT = T
bm:repeat_real_callback(function()
	T.n = T.n + 1
	local ok, err = pcall(function()
		if T.n == 1 then core:set_integer_preference("ui_selection_markers", 0)
		elseif T.n == 20 then bm:clear_selection()
		elseif T.n == 25 then u:select_in_ui()
		elseif T.n == 50 then core:set_integer_preference("ui_selection_markers", T.was) end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= 50 or not ok then
		bm:remove_real_callback("tp_mshot")
		if not ok then pcall(function() core:set_integer_preference("ui_selection_markers", T.was) end) end
		T.ended = true
	end
end, 100, "tp_mshot")
return "started, was " .. tostring(T.was)
