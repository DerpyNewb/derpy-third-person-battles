-- Does camera:move_to take in this battle, 2026-10-16? Moves the camera 30 m above the first Streltsi's front man,
-- looking down at him, and reads the camera back now; zz_tp_cam_move_read.lua reads it again. No string library calls.
local E = _G.DERPY_TP
local P, F = E.P, E.F
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == "wh3_main_ksl_inf_streltsi_0" and x:number_of_men_alive() > 0 then u = x end
end
local m = E.move.front_man(u)
local x, y, z = P.model_pos(m)
local cam = bm:camera()
local b = math.rad(u:bearing())
local ox, oz = (_G.TP_CAM_SIDE or 5) * math.cos(b), -(_G.TP_CAM_SIDE or 5) * math.sin(b)
cam:move_to(v(x + ox, y + (_G.TP_CAM_UP or 1.5), z + oz), v(x, y + 1.3, z), 0, false, -1, false)
local p = cam:position()
_G.TP_CAM_MOVE = {x = x - 5 + ox, y = y - 30 + (_G.TP_CAM_UP or 1.5), z = z - 5 + oz}
local function r(n) return math.floor(n * 10) / 10 end
return "on " .. tostring(F.on) .. " | man " .. r(x) .. "," .. r(y) .. "," .. r(z) .. " | camera now " .. r(p:get_x()) .. "," .. r(p:get_y()) .. "," .. r(p:get_z())
	.. " | anim " .. tostring(P.features.anim) .. " slot " .. tostring(P.anim_slot(m))
