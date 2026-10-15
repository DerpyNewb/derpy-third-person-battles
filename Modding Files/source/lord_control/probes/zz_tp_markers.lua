-- Selection-marker probe, 2026-10-14: read ui_selection_markers before, during and after third person on the
-- General. Expect "1 0 1" for this player. NO string library calls. Read back: zz_tp_markers_read.lua.
local E = _G.DERPY_TP
if not (E and E.main) then return "load the bridge first" end
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GENERAL then u = units:item(i) end end
if not u then return "no " .. GENERAL end
local T = {n = 0, log = ""}
_G.TP_MARKERS = T
local function read(label) T.log = T.log .. label .. " " .. tostring(core:get_integer_preference("ui_selection_markers")) .. " | " end
bm:repeat_real_callback(function()
	T.n = T.n + 1
	local ok, err = pcall(function()
		if T.n == 1 then read("before") if not E.F.on then E.main.start(u) end
		elseif T.n == 5 then read("on " .. tostring(E.F.on)) E.main.stop("markers probe")
		elseif T.n == 7 then read("off " .. tostring(E.F.on)) end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= 7 or not ok then
		bm:remove_real_callback("tp_markers")
		T.ended = true
		if E.F.on then pcall(E.main.stop, "markers probe") end
	end
end, 100, "tp_markers")
return "started"
