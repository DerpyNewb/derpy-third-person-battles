-- The General's model and unit addresses, for tp_sel_diff.py. No string library calls.
local E = _G.DERPY_TP
if not (E and E.move) then return "ERR load the bridge first" end
local mr = memreader_plus
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GENERAL then u = units:item(i) end end
if not u then return "ERR no " .. GENERAL end
local m = E.P.models(u)[1]
if not m then return "ERR no model" end
return {model = mr.tostring(m), unit = mr.tostring(mr.read_pointer(m, 0x2e8))}
