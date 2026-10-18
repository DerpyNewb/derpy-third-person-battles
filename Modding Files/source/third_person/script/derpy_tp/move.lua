-- Walking (spec section 5; handoff 9b and 9i): a single entity or a whole regiment gets move orders,
-- and one man of a regiment is steered alone. Directions are relative to the camera's yaw.
-- return function(E) -> M.
local LEAD, REFRESH, STEER_DEG, STEER_GAP = 15, 6, 12, 0.5 -- m ahead; re-order within m; deg of turn; s between orders
-- his steering point, m ahead: a body runs no faster than it can stop in the distance to it. At 3 m a horse made 1.25
-- m/s of 7.8, 7.35 at 15 (measured 2026-10-16, probes/zz_tp_run_speed.lua), the Mutalith half his speed (2026-10-18),
-- and a monster played as one man sprinted no faster than he ran: Spawn of Tzeentch 3.4 m/s of 6.3, 6.7 at 15 m;
-- Champions of Slaanesh 2.0, 10.4 (2026-10-18, real keys, probes/zz_tp_watch_sprint.lua). Infantry the same either way
local STEER_LEAD = 15
-- a point the engine finds no path to ends his walk (P.walk_ended): the next is nearer, halved down to LEAD_MIN m, tried
-- again there every LEAD_RETRY s; LEAD_BACK s with none ended, and it is STEER_LEAD again
local LEAD_MIN, LEAD_RETRY, LEAD_BACK = 1.5, 0.5, 2
local TOOK = 2 -- m between the engine's ordered position and ours: further, the order was dropped
local WALK_1, UNLATCH_GAP = 42, 0.3 -- 9.0 slot id; s between two walking clips

return function(E)
	local F, P = E.F, E.P
	local M = {}

	-- the regiment's front-centre man, where the captain stands (position_of_officer() returns nil);
	-- nil for a unit of fewer than two
	function M.front_man(unit)
		local ms = P.models(unit)
		if #ms < 2 then return nil end
		local q = unit:position()
		local b = math.rad(unit:bearing())
		local fx, fz = math.sin(b), math.cos(b)
		local best, best_score
		for _, m in ipairs(ms) do
			if P.model_hp(m) > 0 then
				local x, _, z = P.model_pos(m)
				local dx, dz = x - q:get_x(), z - q:get_z()
				local score = -(dx * fx + dz * fz) + math.abs(dx * fz - dz * fx) * 0.5
				if not best_score or score < best_score then best, best_score = m, score end
			end
		end
		return best
	end

	function M.halt()
		local man = F.model or F.single
		if man and P.alive(F.unit, man) then
			local x, _, z = P.model_pos(man)
			F.man_hold = {x, z}
			P.hold(man, x, z, F.face_yaw or E.rig.yaw)
		end
		if F.driving then
			F.uc:halt()
			F.uc:release_control()
			-- an order: the next waits STEER_GAP from it, or the engine drops it (round 25: a click just after it fired nothing)
			F.driving, F.last_order = false, bm:time_elapsed_ms() / 1000
			E.log("halt")
		end
	end

	-- P.steer starts the engine's walking command when needed and P.hold stops it natively. Holding his own
	-- point keeps him out of his formation slot; the engine moves him and handles collisions, with no
	-- position nudges.
	-- F.model, one man of a regiment; F.single, a unit of one (main.lua)
	local function man_drive(now, dx, dz, run, speed)
		local man = F.model or F.single
		local m = P.mount(man) or man
		local x, _, z = P.model_pos(m)
		-- he faces where he walks and keeps that facing when he stops, as a single entity does (the author, 2026-10-15:
		-- steered with the camera's facing, a man pressed left walked mostly forward, measured). A swing or a shot
		-- clears it and he faces the crosshair again
		-- the frame's real time (main.lua reads a stall over 0.25 s as one frame): the model clock steps in 100 ms ticks,
		-- which turned him at a quarter to half the rate, in steps; a 0.05 s cap halved it under 20 fps (round 25)
		local dt = F.dt or 0
		if dx == 0 and dz == 0 then
			F.man_hold, F.lead = F.man_hold or {x, z}, nil
			-- standing past a swing's hold, its clip still playing: no facing written over the clip's turn (the author,
			-- 2026-10-15: "still looking at the right ... at the last part of the animation")
			local sw = F.swung
			if sw and P.anim_slot(sw[1]) ~= sw[2] then F.swung, sw = nil, nil end
			P.hold(m, F.man_hold[1], F.man_hold[2], not sw and (F.face_yaw or E.rig.yaw) or nil)
		else
			-- he turns toward the keys' direction at S.turn_rate and walks along his facing (the author, 2026-10-15:
			-- "smoother animation or turning rate when pressing side buttons and back")
			local face, want = F.face_yaw or E.rig.yaw, math.atan2(dx, dz)
			local d, step = (want - face + math.pi) % (2 * math.pi) - math.pi, E.S.turn_rate * dt
			if math.abs(d) <= step then face = want elseif d > 0 then face = face + step else face = face - step end
			F.face_yaw = face
			dx, dz = math.sin(face), math.cos(face)
			F.man_hold = nil
			-- the author, 2026-10-18: in sieges "the unit cannot move normally forward, as if theres a barrier", "everywhere".
			-- Measured in a dwarf hold (probes/zz_tp_siege_walk.lua): his point 15 m ahead inside a building, the walk ended and
			-- stood there, still his (west 0.2 m in 4 s; 8.7 m with the point 3 m ahead). Stopped, the next steer builds anew
			local lead = F.lead or STEER_LEAD
			if P.walk_ended(m) then
				if lead > LEAD_MIN or now >= (F.lead_retry or 0) then
					P.hold(m, x, z, F.face_yaw)
					F.lead, F.lead_end, F.lead_retry = math.max(LEAD_MIN, lead / 2), now, now + LEAD_RETRY
				end
				return
			end
			if F.lead and now - F.lead_end >= LEAD_BACK then F.lead, lead = nil, STEER_LEAD end
			-- A clip whose shot was dropped (a step out of a reload, the mode key) stays latched when the walk replaces
			-- its command, and he slides in its pose; WALK_1 with mask 0 ends it, the same frame (measured 2026-10-14,
			-- probes/zz_tp_unclip.lua). Spaced so a clip the engine keeps reporting is not queued every frame.
			if P.anim_slot(m) and not F.charging and not F.lock and now >= (F.unlatch_at or 0) and P.has_slot(m, WALK_1) then
				P.play(m, WALK_1, 0)
				F.unlatch_at = now + UNLATCH_GAP
			end
			P.steer(m, x + dx * lead, z + dz * lead, run, F.face_yaw, speed)
		end
	end

	-- kf, kr: -1, 0 or 1 forward and right from the keys; run: at the run; speed: times his own (a sprint's 1.5)
	function M.drive(now, kf, kr, run, speed)
		speed = speed or 1
		if kf ~= 0 or kr ~= 0 then F.native_attack = nil end
		local dx, dz = 0, 0
		if kf ~= 0 or kr ~= 0 then
			local fx, fz = math.sin(E.rig.yaw), math.cos(E.rig.yaw)
			dx, dz = kf * fx + kr * fz, kf * fz - kr * fx
			local n = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / n, dz / n
		end
		if F.model or F.single then man_drive(now, dx, dz, run, speed) return end
		if kf == 0 and kr == 0 then M.halt() return end
		local q = F.unit:position()
		local px, py, pz = q:get_x(), q:get_y(), q:get_z()
		-- no two orders closer than STEER_GAP, whatever asks for the second: closer ones stall the unit. The engine's target
		-- not ours: it dropped the order, one too soon after a halt or an attack (the recorder, 2026-10-15: W again 0.4 s
		-- after letting go left him ordered to his own spot, idle, for as long as W was held)
		local o = F.unit:ordered_position()
		local need = now - (F.last_order or -1e9) >= STEER_GAP and (not F.driving or kf ~= F.kf or kr ~= F.kr
			or run ~= F.run or speed ~= F.speed or (px - F.gx) ^ 2 + (pz - F.gz) ^ 2 < REFRESH * REFRESH
			or dx * F.dx + dz * F.dz < math.cos(math.rad(STEER_DEG))
			or (o:get_x() - F.gx) ^ 2 + (o:get_z() - F.gz) ^ 2 > TOOK * TOOK)
		if need then
			F.gx, F.gz, F.dx, F.dz = px + dx * LEAD, pz + dz * LEAD, dx, dz
			F.uc:goto_location(v(F.gx, py, F.gz), run)
			-- CA's scalar on the speed of the order just given (every order resets it, CA's doc). Measured 2026-10-18
			-- (probes/zz_tp_walk_scalar.lua): Chaos Marauders at the run 2.41 m/s, x1.5 4.14; a single entity's speed it
			-- leaves alone, at any scale, run or walk (Harald 2.74, the Mutalith 5.7)
			if speed ~= 1 then F.uc:change_current_walk_speed(speed) end
			F.uc:release_control()
			F.kf, F.kr, F.run, F.speed, F.driving, F.last_order = kf, kr, run, speed, true, now
			E.log("walk to " .. math.floor(F.gx) .. "," .. math.floor(F.gz) .. (run and " running" or ""))
		end
	end

	return M
end
