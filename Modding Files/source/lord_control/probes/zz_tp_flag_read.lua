-- Read the two selection-following bytes found by tp_sel_diff (2026-10-14), reached from the General's model
-- in float32-exact steps. Read only. No string library calls.
local E = _G.DERPY_TP
if not (E and E.P) then return "ERR load the bridge first" end
local mr = memreader_plus
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GENERAL then u = units:item(i) end end
local m = E.P.models(u)[1]
local hidden = mr.add(mr.add(m, -0x8e60000), -0x2fd4)
local selected = mr.add(mr.add(m, 0x84a0000), 0x4c48)
return {model = mr.tostring(m), hidden_at = mr.tostring(hidden), hidden = mr.read_uint8(hidden, 0),
	selected_at = mr.tostring(selected), selected = mr.read_uint8(selected, 0), any = tostring(bm:is_any_unit_selected())}
