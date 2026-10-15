-- Porthole cup probe, 2026-10-14: third person on for the General, read porthole_mask's state image opacity
-- 1-3 (frame, side strip, button cup), third person off, read again. Expect "255 0 0" then "255 255 255".
-- NO string.* or s:method() (memory wh3-mcp-bridge-wedges-on-interface-walks). Read back: TP_CUP via zz_tp_cup_read.lua.
local E = _G.DERPY_TP
if not (E and E.main) then return "load the bridge first" end
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GENERAL then u = units:item(i) end end
if not u then return "no " .. GENERAL end
local T = {n = 0, log = ""}
_G.TP_CUP = T
local function read(label)
	local mask = find_uicomponent(core:get_ui_root(), "porthole_parent", "porthole_mask")
	if not mask then T.log = T.log .. label .. " no mask | " return end
	T.log = T.log .. label .. " " .. mask:GetCurrentStateImageOpacity(1) .. " " .. mask:GetCurrentStateImageOpacity(2) .. " " .. mask:GetCurrentStateImageOpacity(3) .. " | "
end
bm:repeat_real_callback(function()
	T.n = T.n + 1
	local ok, err = pcall(function()
		if T.n == 1 then read("before") if not E.F.on then E.main.start(u) end
		elseif T.n == 5 then read("on " .. tostring(E.F.on)) E.main.stop("cup probe")
		elseif T.n == 7 then read("off " .. tostring(E.F.on)) end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= 7 or not ok then
		bm:remove_real_callback("tp_cup")
		T.ended = true
		if E.F.on then pcall(E.main.stop, "cup probe") end
	end
end, 100, "tp_cup")
return "started"
