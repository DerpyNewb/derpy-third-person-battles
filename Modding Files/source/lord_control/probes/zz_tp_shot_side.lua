-- Frames of one Streltsi shot, side on, 2026-10-16 (the first try, zz_tp_shot_frames.lua, drew the rig's head-cam) (the author: "strteltzi sitll suffering from the same ranged animation issue,
-- aim high -> shoot level"; the shot log has a level raise and a level fire). Third person on the first Streltsi
-- regiment, the camera left 2 s to settle behind him, then one shot through the pack's own code as a left click, and
-- the game's own screenshot (3D only, no UI) every 0.2 s for 4.6 s into the game folder as tp_shot_NN.tga, each with
-- the clip he was in. The battle running. No string library calls. Read back: _G.TP_SHOT_FRAMES.
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
local T = {frames = {}, done = false}
_G.TP_SHOT_FRAMES = T
local ok, err = pcall(function()
	if F.on then E.main.stop("test") end
	E.main.start(u)
end)
if not (ok and F.on and F.model and F.ranged) then return "third person did not go on a shooting man: " .. tostring(err) end
-- the camera 4 m off his right, 1.6 m up, at his chest, for the capture only: the rig still runs (the aim ray is its
-- eye and look), main gets the side view; put back when done
local orig = E.rig.update
E.rig.update = function(...)
	orig(...)
	local x, y, z = P.model_pos(F.model)
	local yaw = E.rig.yaw
	local rx, rz = math.cos(yaw), -math.sin(yaw)
	return x + rx * 4, y + 1.6, z + rz * 4, x, y + 1.2, z
end
local t0, shot_at, n = os.clock(), nil, 0
bm:repeat_real_callback(function()
	local ok2, e2 = pcall(function()
		local t = os.clock() - t0
		if not shot_at and t >= 2 then
			shot_at = t
			E.combat.attack(bm:time_elapsed_ms() / 1000, true, false)
			T.pair = F.shot and F.shot.pair
		end
		if shot_at and t >= shot_at + n * 0.2 then
			local name = "tp_side_" .. (n < 10 and "0" or "") .. n .. ".tga"
			common.take_screenshot(name)
			T.frames[#T.frames + 1] = name .. " " .. math.floor((t - shot_at) * 100) / 100 .. "s clip "
				.. tostring(F.model and P.anim_slot(F.model)) .. " phase " .. tostring(F.shot and F.shot.phase)
			n = n + 1
		end
		if n > 23 then T.done = true end
	end)
	if not ok2 then T.err = tostring(e2) T.done = true end
	if T.done then E.rig.update = orig bm:remove_real_callback("tp_shot_frames") end
end, 30, "tp_shot_frames")
return "started"
