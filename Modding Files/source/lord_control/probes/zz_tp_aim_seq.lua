-- The Streltsi's shoot clips in a given order, seen from his side, 2026-10-16: the pack plays the raise (1554) then the
-- fire (1557), and his bin also has AIM_LEVEL (1548, hu1c_streltsi_aim) - CA's hold between them, which the pack never
-- plays. Third person on the first Streltsi regiment, the camera 10 m off his right and 6 m up at his chest (main's,
-- through E.rig.update), and nothing fired: _G.TP_SEQ = {tag = "a", {t, slot, mask}, ...} is sent to his model at those
-- seconds, and the game's screenshot (3D only) every 0.2 s from the first step for TP_SEQ.secs as tp_q<tag>_NN.tga, each
-- with the clip he reports. No string library calls. Read back: zz_tp_aim_seq_read.lua.
local TYPE = (_G.TP_SEQ and _G.TP_SEQ.type) or "wh3_main_ksl_inf_streltsi_0"
local E = _G.DERPY_TP
local P, F = E.P, E.F
local S = _G.TP_SEQ
if not S then return "set _G.TP_SEQ first" end
local T = {frames = {}, sent = {}, done = false}
_G.TP_AIM_SEQ = T
if not (F.on and F.unit and F.unit:type() == TYPE) then
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if not u and x:type() == TYPE and x:number_of_men_alive() > 0 then u = x end
	end
	if F.on then E.main.stop("test") end
	E.main.start(u)
end
if not (F.on and F.model) then return "third person did not go on one Streltsi" end
local m = F.model
local orig = E.rig.update
E.rig.update = function(...)
	orig(...)
	local x, y, z = P.model_pos(m)
	local yaw = E.rig.yaw
	return x + math.cos(yaw) * 10, y + 6, z - math.sin(yaw) * 10, x, y + 1.3, z
end
local t0, step, n = os.clock(), 1, 0
local first = S[1][1]
bm:repeat_real_callback(function()
	local ok, e = pcall(function()
		local t = os.clock() - t0
		local s = S[step]
		if s and t >= s[1] then
			T.sent[#T.sent + 1] = s[2] .. "@" .. math.floor(t * 100) / 100 .. "=" .. tostring(P.play(m, s[2], s[3]))
			step = step + 1
		end
		if t >= first + n * 0.2 and n * 0.2 <= S.secs then
			local name = "tp_q" .. S.tag .. "_" .. (n < 10 and "0" or "") .. n .. ".tga"
			common.take_screenshot(name)
			T.frames[#T.frames + 1] = n .. ":" .. tostring(P.anim_slot(m))
			n = n + 1
		end
		if n * 0.2 > S.secs then T.done = true end
	end)
	if not ok then T.err = tostring(e) T.done = true end
	if T.done then E.rig.update = orig bm:remove_real_callback("tp_aim_seq") end
end, 30, "tp_aim_seq")
return "started " .. S.tag
