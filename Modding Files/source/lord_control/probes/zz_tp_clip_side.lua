-- The Streltsi's shot as the pack plays it, seen from his side, 2026-10-16 (the author: "strteltzi sitll suffering from
-- the same ranged animation issue, aim high -> shoot level"). Third person OFF, so neither the rig nor the pack moves
-- the camera: the front man of the first Streltsi regiment gets the raise (1554, mask 6) at 1 s and the fire (1557,
-- mask 0) when the raise's clip ends, as combat.lua sends them; the camera is held 5 m off his right, 1.5 m up, at his
-- chest, every frame; the game's own screenshot (3D only) every 0.15 s from 0.8 s as tp_clip_NN.tga, each with the
-- clip he was in. No projectile. No string library calls. Read back: _G.TP_CLIP_SIDE.
local TYPE, MASK_AIM, MASK_FIRE = "wh3_main_ksl_inf_streltsi_0", 6, 0
local E = _G.DERPY_TP
if not (E and E.P and E.main and E.move) then return "the pack first" end
local P, F = E.P, E.F
if not P.features.anim then return "no anim command" end
if F.on then E.main.stop("test") end
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == TYPE and x:number_of_men_alive() > 0 then u = x end
end
if not u then return "no " .. TYPE end
local m = E.move.front_man(u)
if not m then return "no front man" end
local T = {frames = {}, done = false}
_G.TP_CLIP_SIDE = T
local cam = bm:camera()
local b = math.rad(u:bearing())
local rx, rz = math.cos(b), -math.sin(b)
local t0, n, fired, raised = os.clock(), 0, nil, nil
bm:repeat_real_callback(function()
	local ok, e = pcall(function()
		local t = os.clock() - t0
		local x, y, z = P.model_pos(m)
		cam:move_to(v(x + rx * 5, y + 1.5, z + rz * 5), v(x, y + 1.3, z), 0, false, -1, false)
		local slot = P.anim_slot(m)
		if not raised and t >= 1 then raised = t P.play(m, 1554, MASK_AIM) end
		-- the raise reported, then gone or another clip: the fire, as C.locked's shot phase does
		if raised and not fired and t >= raised + 0.3 and slot ~= 1554 then fired = t P.play(m, 1557, MASK_FIRE) end
		if t >= 0.8 + n * 0.15 then
			local name = "tp_clip_" .. (n < 10 and "0" or "") .. n .. ".tga"
			common.take_screenshot(name)
			T.frames[#T.frames + 1] = name .. " " .. math.floor(t * 100) / 100 .. "s clip " .. tostring(slot)
			n = n + 1
		end
		if n > 26 then T.done = true end
	end)
	if not ok then T.err = tostring(e) T.done = true end
	if T.done then T.raised, T.fired = raised, fired bm:remove_real_callback("tp_clip_side") end
end, 30, "tp_clip_side")
return "started on a man at " .. math.floor(u:bearing()) .. " deg"
