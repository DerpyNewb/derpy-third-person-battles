-- Select the General. No string library calls.
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
for i = 1, units:count() do if units:item(i):type() == GENERAL then units:item(i):select_in_ui() return "selected" end end
return "ERR none"
