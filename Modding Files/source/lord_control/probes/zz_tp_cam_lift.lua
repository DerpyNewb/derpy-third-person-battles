-- 2026-10-15, "near a building the camera follows the terrain or building": over 2 s at 10 Hz, the eye the rig asked
-- for against where the engine says the camera is, and the terrain under each. Read with zz_tp_cam_lift_read.lua.
-- Read-only; no string library calls.
local E = _G.DERPY_TP
if not E or not E.rig then return "no DERPY_TP" end
local R, F = E.rig, E.F
if not F.on then return "third person is off" end
local L = {rows = {}}
_G.TP_CAMLIFT = L
local n = 0
local function f1(x) return math.floor(x * 100 + 0.5) / 100 end
bm:remove_real_callback("derpy_tp_camlift")
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		n = n + 1
		local p = bm:camera():position()
		L.rows[#L.rows + 1] = "asked " .. f1(R.ex) .. "," .. f1(R.ey) .. "," .. f1(R.ez) .. " got " .. f1(p:get_x()) .. ","
			.. f1(p:get_y()) .. "," .. f1(p:get_z()) .. " lift " .. f1(p:get_y() - R.ey) .. " terrain under eye "
			.. f1(bm:get_terrain_height(R.ex, R.ez)) .. " head " .. f1(R.sy) .. " boom " .. tostring(R.boom)
	end)
	if not ok then L.err = tostring(err) end
	if n >= 20 or not ok then bm:remove_real_callback("derpy_tp_camlift") end
end, 100, "derpy_tp_camlift")
return "sampling"
