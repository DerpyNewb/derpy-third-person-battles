-- Reads the camera back after zz_tp_cam_move.lua. No string library calls.
local T = _G.TP_CAM_MOVE
local p = bm:camera():position()
local function r(n) return math.floor(n * 10) / 10 end
common.take_screenshot("tp_cam_move.tga")
local t = bm:camera():target()
return "target " .. r(t:get_x()) .. "," .. r(t:get_y()) .. "," .. r(t:get_z()) .. " | asked " .. r(T.x + 5) .. "," .. r(T.y + 30) .. "," .. r(T.z + 5) .. " | camera " .. r(p:get_x()) .. "," .. r(p:get_y()) .. "," .. r(p:get_z())
