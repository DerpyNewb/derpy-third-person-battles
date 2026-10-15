-- GENERATED from maintained move.lua for this live reload.
local src = [==[
-- Walking (spec section 5; handoff 9b and 9i): a single entity or a whole regiment gets move orders,
-- and one man of a regiment is steered alone. Directions are relative to the camera's yaw.
-- return function(E) -> M.
local LEAD, REFRESH, STEER_DEG, STEER_GAP = 15, 6, 12, 0.5 -- m ahead; re-order within m; deg of turn; s between orders
local MAN_LEAD, MAN_NUDGE, MAN_STUCK = 3, 0.5, 0.05 -- one man: steering point m ahead; nudge m; stuck below m per 0.5 s
local MAN_WINDOW = 1 -- s after a key press during which a stuck man may be nudged: later, stuck means a wall or a unit

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
		if F.driving then
			F.uc:halt()
			F.uc:release_control()
			F.driving = false
			E.log("halt")
		end
	end

	-- one man chases his own steering point, held every frame: MAN_LEAD ahead while a key is held, on his
	-- own spot when none is (so he does not walk back to his slot). An idle man ignores the point, so a
	-- held key that has not moved him MAN_STUCK in half a second gets a MAN_NUDGE shove of his position -
	-- only within MAN_WINDOW of the keys changing, so a man against a wall is not pushed through it.
	-- keys: the held keys as one number, to tell a new press from a held one.
	local function man_drive(now, dx, dz, keys)
		local m = F.model
		local x, _, z = P.model_pos(m)
		local tx, tz
		if dx == 0 and dz == 0 then
			F.man_hold = F.man_hold or {x, z}
			tx, tz, F.man_check, F.man_keys = F.man_hold[1], F.man_hold[2], nil, nil
		else
			F.man_hold = nil
			if keys ~= F.man_keys then F.man_keys, F.man_walk = keys, now end
			local c = F.man_check
			if not c or now - c[1] > 0.5 then
				local stuck = not c or (x - c[2]) ^ 2 + (z - c[3]) ^ 2 < MAN_STUCK * MAN_STUCK
				if stuck and now - F.man_walk < MAN_WINDOW then
					x, z = x + dx * MAN_NUDGE, z + dz * MAN_NUDGE
					P.place(m, x, z)
				end
				F.man_check = {now, x, z}
			end
			tx, tz = x + dx * MAN_LEAD, z + dz * MAN_LEAD
		end
		P.steer(m, tx, tz)
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
		if F.model then man_drive(now, dx, dz, kf * 3 + kr) return end
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
]==]
local E=_G.DERPY_TP E.main.stop("movement reloaded") _G.DERPY_TP_SRC["/script/derpy_tp/move"]=src local f=assert(loadstring(src,"move_reload")) setfenv(f,core:get_env()) E.move=f()(E) return "move reloaded"
