-- The charge attack on the run, 2026-10-16 (the author: "charge attack while sprinting comepletely stops the player and
-- stops its legs"). Measured 2026-10-15: MOVING_ATTACK_1 (484) at the default mask stops him for ~1.8 s; at mask 6 the
-- engine reports 474 and freezes him. Untried: masks 1-5, and steering on through the clip (combat.lua now throws it at 1,
-- TORSO_AND_ARMS). Third person on one man, the battle RUNNING (this never unpauses it), nobody at the keys: the pack's
-- drive is swapped for a no-op while this runs (it holds a man with no key down) and put back at the end. Seven rounds
-- of 3.2 s, each run forward 0.8 s (P.steer every frame, at the run), then the round's clip, steered on to 2.8 s, then
-- WALK_1 at mask 0 to end it; alternate rounds run back the other way so he stays put. Every 0.1 s: metres covered, his
-- clip, his command. The first round throws no attack (his run's own pace), the second neither, steered at 1.2 (the
-- sprint's scale on the walk command's speed). No string library calls. Read back: zz_tp_charge_run_read.lua.
local E = _G.DERPY_TP
if not (E and E.F and E.F.on and E.F.model) then return "third person on one man first" end
local P, F, m = E.P, E.F, E.F.model
if not P.has_slot(m, 484) then return "his men have no MOVING_ATTACK_1" end
if F.shot or F.lock then return "a shot or an action is under way: let it end first" end
-- the exe's enum: 0 NONE, 1 TORSO_AND_ARMS, 2 SPINE_AND_CHILDREN, 5 RIGHT_ARM, 6 FULL_BODY
local MASKS = {"none", "fast", 0, 1, 2, 5, 6}
local T = {rounds = {}, done = false}
_G.TP_CHARGE_RUN = T
local drive = E.move.drive
E.move.drive = function() end
local g0 = bm:time_elapsed_ms()
local t0, round, sent, sample_at, px, pz = os.clock(), 0, false, 0, nil, nil
local yaw0 = E.rig.yaw
local function cur() return T.rounds[round] end
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		local t = os.clock() - t0
		-- the battle must be running: model time not moving 1 s in, the probe stops (it never unpauses)
		if t > 1 and bm:time_elapsed_ms() == g0 then T.err = "the battle is paused: nothing measured" T.done = true return end
		local r = math.floor(t / 3.2) + 1
		if r > #MASKS then
			P.play(m, 42, 0)
			local x, _, z = P.model_pos(m)
			P.hold(m, x, z, yaw0)
			T.done = true
			return
		end
		if r ~= round then
			round, sent = r, false
			T.rounds[r] = {mask = MASKS[r], log = ""}
			px, pz = nil, nil
		end
		local rt = t - (r - 1) * 3.2
		local yaw = yaw0 + (r % 2 == 0 and math.pi or 0)
		local x, _, z = P.model_pos(m)
		if rt < 2.8 then
			P.steer(m, x + math.sin(yaw) * 3, z + math.cos(yaw) * 3, true, yaw, MASKS[r] == "fast" and 1.2 or nil)
		elseif rt < 2.9 then
			P.play(m, 42, 0)
			P.hold(m, x, z, yaw)
		end
		if rt >= 0.8 and not sent then
			sent = true
			local mask = MASKS[r]
			if type(mask) == "number" then cur().sent = tostring(P.play(m, 484, mask)) end
		end
		if rt >= sample_at or sample_at > rt + 1 then
			sample_at = rt + 0.1
			local d = px and math.sqrt((x - px) ^ 2 + (z - pz) ^ 2) or 0
			px, pz = x, z
			cur().log = cur().log .. " " .. math.floor(rt * 10) / 10 .. ":" .. math.floor(d * 100) / 100 .. "m,"
				.. tostring(P.anim_slot(m)) .. "," .. tostring(P.command(m))
		end
	end)
	if not ok then T.err = tostring(err) T.done = true end
	if T.done then
		E.move.drive = drive
		bm:remove_real_callback("tp_charge_run")
	end
end, 30, "tp_charge_run")
return "started: " .. #MASKS .. " rounds, " .. #MASKS * 3.2 .. " s"
