-- Where the sprint's speed goes, 2026-10-16: zz_tp_charge_run.lua measured a man steered at 1.2 times walk_speed no
-- faster than at 1.0 (0.38-0.40 m a tenth both). Third person on one man, the battle running, nobody at the keys; the
-- pack's drive is a no-op while this runs. Three phases of 2 s, alternating direction: scale 1, 1.2, 0.6. At 1.7 s into
-- each, every float of the model from +0 to +0xb40 is kept; the read-back lists the offsets whose value follows the
-- scale, and the metres each phase covered from 1.0 to 1.9 s. No string library calls. Read back: zz_tp_speed_diff_read.lua.
local E = _G.DERPY_TP
if not (E and E.F and E.F.on and E.F.model) then return "third person on one man first" end
local P, F, m = E.P, E.F, E.F.model
local mr = _G.memreader_plus
if not mr then return "no memreader_plus" end
if F.shot or F.lock then return "a shot or an action is under way: let it end first" end
local SCALES = {1, 1, 1.2, 1.2, 1.5, 1.5} -- each both ways: the ground's slope cancels
local T = {snap = {}, dist = {}, done = false}
_G.TP_SPEED_DIFF = T
local drive = E.move.drive
E.move.drive = function() end
local g0 = bm:time_elapsed_ms()
local t0, yaw0 = os.clock(), E.rig.yaw
local ax, az
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		local t = os.clock() - t0
		if t > 1 and bm:time_elapsed_ms() == g0 then T.err = "the battle is paused: nothing measured" T.done = true return end
		local r = math.floor(t / 2) + 1
		local x, _, z = P.model_pos(m)
		if r > #SCALES then
			P.play(m, 42, 0)
			P.hold(m, x, z, yaw0)
			T.done = true
			return
		end
		local rt = t - (r - 1) * 2
		local yaw = yaw0 + (r % 2 == 0 and math.pi or 0)
		P.steer(m, x + math.sin(yaw) * 3, z + math.cos(yaw) * 3, true, yaw, SCALES[r] ~= 1 and SCALES[r] or nil)
		if rt >= 1 and not T.dist[r] then T.dist[r] = {x, z} ax, az = x, z end
		if rt >= 1.9 and type(T.dist[r]) == "table" and #T.dist[r] == 2 then
			T.dist[r] = math.floor(math.sqrt((x - ax) ^ 2 + (z - az) ^ 2) / 0.9 * 100) / 100
		end
		if rt >= 1.7 and not T.snap[r] then
			local s = {}
			for o = 0, 0xb40, 4 do s[o] = mr.read_float(m, o) end
			T.snap[r] = s
		end
	end)
	if not ok then T.err = tostring(err) T.done = true end
	if T.done then
		E.move.drive = drive
		bm:remove_real_callback("tp_speed_diff")
	end
end, 30, "tp_speed_diff")
return "started: 6 s"
