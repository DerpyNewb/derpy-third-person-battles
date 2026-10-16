-- 2026-10-16, "aim high -then shoot level": one shot, the camera 34 deg up; every P.play the pack sends and every clip
-- the engine reports on his model (+0x278) at 20 ms, with the shot's pair. Read with zz_tp_shot_pair_read.lua. No
-- string library; every callback under pcall.
local E = _G.DERPY_TP
if not E or not E.P then return "no DERPY_TP" end
local F, P = E.F, E.P
if not F.on then E.main.start() end
if not F.on then return "did not start" end
if not F.solo or not F.model then return "not one man shooting alone: " .. tostring(F.utype) end
local T = {rows = {}, plays = {}, err = nil, t0 = os.clock(), g0 = bm:time_elapsed_ms()}
_G.TPSHOT = T
P._play0 = P._play0 or P.play
local play0 = P._play0
P.play = function(m, slot, mask)
	local ok = play0(m, slot, mask)
	if #T.plays < 60 then
		T.plays[#T.plays + 1] = (os.clock() - T.t0) .. " play " .. tostring(slot) .. " mask " .. tostring(mask) .. " ok " .. tostring(ok)
			.. " his " .. tostring(m == F.model)
	end
	return ok
end
E.rig.pitch = -0.6
local last = ""
bm:remove_real_callback("derpy_tp_shotpair")
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		local dt = os.clock() - T.t0
		local s = F.shot
		local row = "slot " .. tostring(F.model and P.anim_slot(F.model)) .. " shot " .. tostring(s and s.phase) .. " pair "
			.. tostring(s and s.pair) .. " aim " .. tostring(s and s.aim_slot) .. " fire " .. tostring(s and s.fire_slot)
			.. " started " .. tostring(s and s.started) .. " launched " .. tostring(s and s.launched)
		if row ~= last and #T.rows < 200 then T.rows[#T.rows + 1] = dt .. " g " .. (bm:time_elapsed_ms() - T.g0) .. " " .. row end
		last = row
		if dt > 9 then
			bm:remove_real_callback("derpy_tp_shotpair")
			P.play = play0
			if F.on then E.main.stop("probe") end
			T.done = true
		end
	end)
	if not ok then T.err = tostring(err) bm:remove_real_callback("derpy_tp_shotpair") P.play = play0 end
end, 20, "derpy_tp_shotpair")
local ax, ay, az = E.combat.aim_point(F.unit:missile_range())
local x, y, z = P.model_pos(F.model)
E.combat.attack(bm:time_elapsed_ms() / 1000, true, false)
return "fired: unit " .. F.utype .. " aim dy " .. tostring(ay and ay - y) .. " dist " .. tostring(ax and math.sqrt((ax - x) ^ 2 + (az - z) ^ 2))
	.. " has 1555 " .. tostring(P.has_slot(F.model, 1555)) .. " 1558 " .. tostring(P.has_slot(F.model, 1558))
	.. " shot " .. tostring(F.shot and F.shot.pair)
