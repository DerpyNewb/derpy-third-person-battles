-- Marker experiment, 2026-10-14: with the General selected, write 0 every 10 ms for 3 s to the byte that
-- follows his selection (tp_sel_diff: 1 selected, 0 not), counting how often the engine set it back to 1.
-- Paired with a screenshot. Afterwards the engine owns it again. No string library calls.
local E = _G.DERPY_TP
if not (E and E.P) then return "ERR load the bridge first" end
local mr = memreader_plus
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GENERAL then u = units:item(i) end end
local m = E.P.models(u)[1]
local flag = mr.add(mr.add(m, 0x84a0000), 0x4c48)
u:select_in_ui()
local T = {n = 0, back = 0, first = mr.read_uint8(flag, 0)}
_G.TP_FLAGW = T
local t0 = os.clock()
bm:repeat_real_callback(function()
	T.n = T.n + 1
	if mr.read_uint8(flag, 0) ~= 0 then T.back = T.back + 1 end
	mr.write(flag, 0, mr.uint8(0))
	if os.clock() - t0 > 3 then bm:remove_real_callback("tp_flagw") T.ended = true T.after = mr.read_uint8(flag, 0) end
end, 10, "tp_flagw")
return "writing, first " .. tostring(T.first)
