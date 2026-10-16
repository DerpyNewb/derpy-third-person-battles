-- Two Streltsi shots through the pack's own code, seen from his side, 2026-10-16 (the author: "strteltzi sitll suffering
-- from the same ranged animation issue, aim high -> shoot level"). Third person on the first Streltsi regiment; main
-- gets a camera 10 m off his right, 6 m up, at his chest (lower, the engine lifts eye and target alike and he leaves the
-- frame, measured); the rig still runs, so the aim is its own. Shot 1 at 2 s with the view as it is; shot 2 at 8 s with
-- the view tipped fully up (the rig's PITCH_MIN, 14 deg), its reload waived (test only). The game's screenshot (3D only)
-- every 0.2 s for 3 s from each click as tp_s<shot>_NN.tga, each with his clip. No projectile changes. No string
-- library calls. Read back: zz_tp_shot_side2_read.lua.
local TYPE = "wh3_main_ksl_inf_streltsi_0"
local E = _G.DERPY_TP
if not (E and E.main and E.combat) then return "the pack first" end
local P, F = E.P, E.F
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == TYPE and x:number_of_men_alive() > 0 then u = x end
end
if not u then return "no " .. TYPE end
local T = {frames = {}, shots = {}, done = false}
_G.TP_SHOT_SIDE2 = T
local ok, err = pcall(function()
	if F.on then E.main.stop("test") end
	E.main.start(u)
end)
if not (ok and F.on and F.model and F.ranged) then return "third person did not go on a shooting man: " .. tostring(err) end
local orig = E.rig.update
E.rig.update = function(...)
	orig(...)
	local x, y, z = P.model_pos(F.model)
	local yaw = E.rig.yaw
	local rx, rz = math.cos(yaw), -math.sin(yaw)
	return x + rx * 10, y + 6, z + rz * 10, x, y + 1.3, z
end
local t0, n, shot, at = os.clock(), 0, 0, nil
bm:repeat_real_callback(function()
	local ok2, e2 = pcall(function()
		local t = os.clock() - t0
		local now = bm:time_elapsed_ms() / 1000
		if shot == 0 and t >= 2 then
			shot, at, n = 1, t, 0
			E.combat.attack(now, true, false)
			T.shots[1] = {pair = F.shot and F.shot.pair, pitch = E.rig.pitch}
		elseif shot == 1 and t >= 7 and t < 8 then
			E.rig.pitch = -0.25
		elseif shot == 1 and t >= 8 then
			E.rig.pitch = -0.25
			F.ready_at = 0
			shot, at, n = 2, t, 0
			E.combat.attack(now, true, false)
			T.shots[2] = {pair = F.shot and F.shot.pair, pitch = E.rig.pitch}
		end
		if shot == 2 then E.rig.pitch = -0.25 end
		if at and n <= 15 and t >= at + n * 0.2 then
			local name = "tp_s" .. shot .. "_" .. (n < 10 and "0" or "") .. n .. ".tga"
			common.take_screenshot(name)
			T.frames[#T.frames + 1] = name .. " " .. math.floor((t - at) * 100) / 100 .. "s clip "
				.. tostring(F.model and P.anim_slot(F.model)) .. " phase " .. tostring(F.shot and F.shot.phase)
			n = n + 1
		end
		if shot == 2 and n > 15 then T.done = true end
	end)
	if not ok2 then T.err = tostring(e2) T.done = true end
	if T.done then E.rig.update = orig bm:remove_real_callback("tp_shot_side2") end
end, 30, "tp_shot_side2")
return "started"
