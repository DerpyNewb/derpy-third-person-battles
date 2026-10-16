-- CA's own shot, seen from the side, 2026-10-16: the pack's level raise ends ~20 deg up and its fire snaps level (seen:
-- probes/zz_tp_aim_seq.lua); CA's sequence is the same raise, a 0.1-0.2 s gap, then the fire (zz_tp_vanilla_fire.lua).
-- Third person off; the regiment of TYPE fires at the ground AHEAD m in front by test scaffolding (a script unit
-- controller); the camera is held 10 m off the right of its man K, 6 m up, at his chest; once his clip is a raise
-- (1553-1555), the game's screenshot (3D only) every 0.2 s for 4.6 s as tp_v_NN.tga, each with his clip. No string
-- library calls. Read back: zz_tp_vanilla_shot_frames_read.lua.
local TYPE, AHEAD, K, WAIT = "wh3_dlc24_ksl_inf_streltsi_ror", 140, 5, 30
local E = _G.DERPY_TP
local P, F = E.P, E.F
if F.on then E.main.stop("test") end
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == TYPE and x:number_of_men_alive() > 0 then u = x end
end
if not u then return "no " .. TYPE end
local q = u:position()
local b = math.rad(u:bearing())
local gx, gz = q:get_x() + math.sin(b) * AHEAD, q:get_z() + math.cos(b) * AHEAD
local uc = army:create_unit_controller()
uc:add_units(u)
uc:fire_at_will(true)
uc:attack_location(v(gx, bm:get_terrain_height(gx, gz), gz), false)
uc:release_control()
local m = P.models(u)[K]
local T = {frames = {}, done = false}
_G.TP_VANILLA_FRAMES = T
local cam = bm:camera()
local rx, rz = math.cos(b), -math.sin(b)
local t0, at, n = os.clock(), nil, 0
bm:repeat_real_callback(function()
	local ok, e = pcall(function()
		local t = os.clock() - t0
		local x, y, z = P.model_pos(m)
		cam:move_to(v(x + rx * 10, y + 6, z + rz * 10), v(x, y + 1.3, z), 0, false, -1, false)
		local s = P.anim_slot(m)
		if not at and s and s >= 1553 and s <= 1555 then at = t end
		if at and t >= at + n * 0.2 then
			local name = "tp_v_" .. (n < 10 and "0" or "") .. n .. ".tga"
			common.take_screenshot(name)
			T.frames[#T.frames + 1] = n .. ":" .. tostring(s)
			n = n + 1
		end
		if n > 23 or t > WAIT then T.done = true end
	end)
	if not ok then T.err = tostring(e) T.done = true end
	if T.done then bm:remove_real_callback("tp_vanilla_frames") end
end, 30, "tp_vanilla_frames")
return "waiting for man " .. K .. "'s raise"
