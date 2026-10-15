-- Walking (spec section 5; handoff 9b and 9i): a single entity or a whole regiment gets move orders,
-- and one man of a regiment is steered alone. Directions are relative to the camera's yaw.
-- return function(E) -> M.
local LEAD, REFRESH, STEER_DEG, STEER_GAP = 15, 6, 12, 0.5 -- m ahead; re-order within m; deg of turn; s between orders
local MAN_LEAD = 3 -- one man's steering point, m ahead
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
			local x, _, z = P.model_pos(m)
			local dx, dz = x - q:get_x(), z - q:get_z()
			local score = -(dx * fx + dz * fz) + math.abs(dx * fz - dz * fx) * 0.5
			if not best_score or score < best_score then best, best_score = m, score end
		end
		return best
	end

	function M.halt()
		if F.model and P.alive(F.unit, F.model) then
			local x, _, z = P.model_pos(F.model)
			F.man_hold = {x, z}
			P.hold(F.model, x, z, F.face_yaw or E.rig.yaw)
		end
		if F.driving then
			F.uc:halt()
			F.uc:release_control()
			F.driving = false
			E.log("halt")
		end
	end

	-- P.steer starts the engine's walking command when needed and P.hold stops it natively. Holding his own
	-- point keeps him out of his formation slot; the engine moves him and handles collisions, with no
	-- position nudges.
	local function man_drive(now, dx, dz, run)
		local m = F.model
		local x, _, z = P.model_pos(m)
		-- he faces where he walks and keeps that facing when he stops, as a single entity does (the author, 2026-10-15:
		-- steered with the camera's facing, a man pressed left walked mostly forward, measured). A swing or a shot
		-- clears it and he faces the crosshair again
		-- one frame at most: after an action held him, he turns from where he was, not by the whole time held
		local dt = math.min(0.05, now - (F.turn_t or now))
		F.turn_t = now
		if dx == 0 and dz == 0 then
			F.man_hold = F.man_hold or {x, z}
			P.hold(m, F.man_hold[1], F.man_hold[2], F.face_yaw or E.rig.yaw)
		else
			-- he turns toward the keys' direction at S.turn_rate and walks along his facing (the author, 2026-10-15:
			-- "smoother animation or turning rate when pressing side buttons and back")
			local face, want = F.face_yaw or E.rig.yaw, math.atan2(dx, dz)
			local d, step = (want - face + math.pi) % (2 * math.pi) - math.pi, E.S.turn_rate * dt
			if math.abs(d) <= step then face = want elseif d > 0 then face = face + step else face = face - step end
			F.face_yaw = face
			dx, dz = math.sin(face), math.cos(face)
			F.man_hold = nil
			-- A clip whose shot was dropped (a step out of a reload, the mode key) stays latched when the walk replaces
			-- its command, and he slides in its pose; WALK_1 with mask 0 ends it, the same frame (measured 2026-10-14,
			-- probes/zz_tp_unclip.lua). Spaced so a clip the engine keeps reporting is not queued every frame.
			if P.anim_slot(m) and not F.charging and now >= (F.unlatch_at or 0) and P.has_slot(m, WALK_1) then
				P.play(m, WALK_1, 0)
				F.unlatch_at = now + UNLATCH_GAP
			end
			P.steer(m, x + dx * MAN_LEAD, z + dz * MAN_LEAD, run, F.face_yaw)
		end
	end

	-- kf, kr: -1, 0 or 1 forward and right from the keys; run: the toggled run state
	function M.drive(now, kf, kr, run)
		local dx, dz = 0, 0
		if kf ~= 0 or kr ~= 0 then
			local fx, fz = math.sin(E.rig.yaw), math.cos(E.rig.yaw)
			dx, dz = kf * fx + kr * fz, kf * fz - kr * fx
			local n = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / n, dz / n
		end
		if F.model then man_drive(now, dx, dz, run) return end
		if kf == 0 and kr == 0 then M.halt() return end
		local q = F.unit:position()
		local px, py, pz = q:get_x(), q:get_y(), q:get_z()
		-- no two orders closer than STEER_GAP, whatever asks for the second: closer ones stall the unit
		local need = now - (F.last_order or -1e9) >= STEER_GAP and (not F.driving or kf ~= F.kf or kr ~= F.kr
			or run ~= F.run or (px - F.gx) ^ 2 + (pz - F.gz) ^ 2 < REFRESH * REFRESH
			or dx * F.dx + dz * F.dz < math.cos(math.rad(STEER_DEG)))
		if need then
			F.gx, F.gz, F.dx, F.dz = px + dx * LEAD, pz + dz * LEAD, dx, dz
			F.uc:goto_location(v(F.gx, py, F.gz), run)
			F.uc:release_control()
			F.kf, F.kr, F.run, F.driving, F.last_order = kf, kr, run, true, now
			E.log("walk to " .. math.floor(F.gx) .. "," .. math.floor(F.gz) .. (run and " running" or ""))
		end
	end

	return M
end
