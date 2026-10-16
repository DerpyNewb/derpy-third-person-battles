-- Where the camera is against the man third person plays, and one screenshot of it (tp_cam_check.tga), 2026-10-16: the
-- shot frames showed a still, ground-level view with no Streltsi in it. Third person on the first Streltsi regiment if
-- it is off. No string library calls.
local E = _G.DERPY_TP
local P, F = E.P, E.F
if not F.on then
	local army = bm:get_player_army()
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if not F.on and x:type() == "wh3_main_ksl_inf_streltsi_0" then E.main.start(x) end
	end
end
if not (F.on and F.model) then return "not on" end
local function r1(n) return math.floor(n * 10) / 10 end
local mx, my, mz = P.model_pos(F.model)
local cam = bm:camera()
local p, t = cam:position(), cam:target()
local q = F.unit:position()
common.take_screenshot("tp_cam_check.tga")
return "man " .. r1(mx) .. "," .. r1(my) .. "," .. r1(mz) .. " | regiment centre " .. r1(q:get_x()) .. "," .. r1(q:get_z())
	.. " | camera " .. r1(p:get_x()) .. "," .. r1(p:get_y()) .. "," .. r1(p:get_z()) .. " looking at " .. r1(t:get_x()) .. ","
	.. r1(t:get_y()) .. "," .. r1(t:get_z()) .. " | rig eye " .. r1(E.rig.ex or 0) .. "," .. r1(E.rig.ey or 0) .. ","
	.. r1(E.rig.ez or 0) .. " frames " .. tostring(F.frames)
