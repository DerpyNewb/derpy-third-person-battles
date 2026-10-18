-- The follow camera (spec section 5, handoff 9): plays the unit back S.lag s late between its position
-- samples (unit:position() steps about every 0.2 s), with a light spring on top, then sits behind at the
-- mouse's yaw and pitch; ranged mode blends to an over-the-shoulder rig. Maths and the terrain height, built per battle:
-- return function(E) -> R. Reads E.S at every call, since settings are re-read at each toggle.
local K_POS, LOOK_H, AHEAD = 20, 1.8, 6 -- the lag, height and aiming distance are settings (S.lag, S.height, S.aim_back)
local OTS_SIDE, OTS_HEIGHT, OTS_AHEAD, OTS_RATE = 1.0, 2.0, 30, 4 -- OTS_RATE also eases the melee distance in and out
-- the shoulder set to top (the author, 2026-10-17: "shoulder either left right or top on options"): over his head, his
-- head just under the crosshair. The view is about 16 degrees each way up and down (measured 2026-10-18 off a shoulder
-- screenshot); at 3.0 a rider (zoom 2) was out of the bottom of it, at 2.3 a man's head sits ~9 degrees under the centre
local OTS_TOP = 2.3
local PITCH_MIN, PITCH_MAX, ZOOM_MIN, ZOOM_MAX = -0.25, 1.1, 0.6, 6
-- m the eye keeps over the ground: the engine's own floor even at change_height_range(0, 100) (measured 2026-10-15:
-- asked 0.53 and 1.09, it put the eye at 1.58 and 1.52, lifting the whole view)
local CLEAR = 1.6
-- the engine's floor also counts a roof, which bm:get_terrain_height does not (the author, 2026-10-15: "when near the
-- buidling, it should ignore terrain and buildings", the view on a roof) and nothing turns it off: lifted more than
-- LIFT_TOL m, the eye comes in along its boom at BOOM_IN of it a second, down to BOOM_MIN. It goes back out, at BOOM_OUT a
-- second, only once he has moved MOVED m or the camera turned TURNED rad since the last lift: trying the roof again
-- from the same place would pop the view over it every time
local LIFT_TOL, BOOM_MIN, BOOM_IN, BOOM_OUT, MOVED, TURNED = 0.3, 0.1, 3, 0.5, 1, 0.17
-- first person (the author, 2026-10-17: "first person camera"): the eye at FP_EYE of his height and FP_AHEAD m ahead of
-- his face, so it is not inside his head; FP_LAG s behind his position samples, one of their steps (a man's position
-- changed every 0.14-0.24 s, measured 2026-10-17, probes/zz_tp_fp.lua: any less and the eye stops between steps), where
-- third person's lag would leave the eye trailing his head; it looks up as far as FP_PITCH_MIN
local FP_EYE, FP_AHEAD, FP_LAG, FP_PITCH_MIN = 0.92, 0.35, 0.25, -1.2

return function(E)
	local R = {}

	function R.start(now, x, y, z, yaw, zoom, ranged)
		R.samples, R.sx, R.sy, R.sz = {{now, x, y, z}}, x, y, z
		R.yaw, R.pitch, R.zoom, R.ots, R.close, R.centre = yaw, 0, zoom, ranged and 1 or 0, 0, ranged and 0 or 1
		R.want_yaw, R.want_pitch = yaw, 0
		R.ey, R.ey1, R.ey2, R.boom, R.cap = nil, nil, nil, 1, nil
		-- no eye until this session's first frame: the aim's "no eye yet" reads R.ex, and the last session's x with this
		-- one's cleared height threw on fire held as F2 went on (2026-10-17)
		R.ex, R.ez, R.lx, R.ly, R.lz = nil, nil, nil, nil, nil
	end

	-- the mouse sets where the view goes; R.update eases it there
	function R.look(dx, dy) -- mouse pixels
		local S = E.S
		R.want_yaw = R.want_yaw + dx * S.sensitivity
		if S.invert_y then dy = -dy end
		R.want_pitch = math.max(R.first and FP_PITCH_MIN or PITCH_MIN, math.min(PITCH_MAX, R.want_pitch + dy * S.sensitivity))
	end

	function R.zoom_by(steps) -- natural-log steps: positive zooms out; true at the closest zoom
		R.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, R.zoom * math.exp(steps)))
		return R.zoom <= ZOOM_MIN
	end

	-- the eye and the point it looks at, behind him at zoom zm and over his shoulder as far as R.ots, before the ground
	local function behind(zm)
		local S = E.S
		local fx, fz = math.sin(R.yaw), math.cos(R.yaw)
		local dist = S.distance + (math.min(S.melee_distance, S.distance) - S.distance) * R.close
		local back, lift = dist * zm * math.cos(R.pitch), dist * zm * math.sin(R.pitch)
		local ex, ey, ez = R.sx - fx * back, R.sy + S.height * zm + lift, R.sz - fz * back
		-- centred as far as R.centre, it looks at him (the author, 2026-10-17: "center when melee")
		local ahead = AHEAD * zm * (1 - R.centre)
		local lx, ly, lz = R.sx + fx * ahead, R.sy + LOOK_H * zm, R.sz + fz * ahead
		if R.ots > 0.001 then
			local rx, rz = fz * S.shoulder, -fx * S.shoulder
			local up = S.shoulder == 0 and OTS_TOP or OTS_HEIGHT
			local ox, oy, oz = R.sx + (rx * OTS_SIDE - fx * S.aim_back) * zm, R.sy + up * zm, R.sz + (rz * OTS_SIDE - fz * S.aim_back) * zm
			local c, sn = math.cos(R.pitch), math.sin(R.pitch)
			local ax, ay, az = ox + fx * c * OTS_AHEAD, oy - sn * OTS_AHEAD, oz + fz * c * OTS_AHEAD
			local k = R.ots
			ex, ey, ez = ex + (ox - ex) * k, ey + (oy - ey) * k, ez + (oz - ez) * k
			lx, ly, lz = lx + (ax - lx) * k, ly + (ay - ly) * k, lz + (az - lz) * k
		end
		return ex, ey, ez, lx, ly, lz
	end

	-- the engine's altitude floor is lowered while on (main.lua: it lifted the eye with the terrain, measured
	-- 2026-10-15), so the eye keeps out of the ground here: it comes in along the boom from his head, not up. The fourth
	-- return is the tenth of the boom it stopped at: 1, nothing behind his head cleared
	local function clear(zm, ex, ey, ez)
		local px, py, pz = R.sx, R.sy + LOOK_H * zm, R.sz
		for i = 10, 1, -1 do
			local t = i / 10 * R.boom
			local x, y, z = px + (ex - px) * t, py + (ey - py) * t, pz + (ez - pz) * t
			local g = bm:get_terrain_height(x, z) + CLEAR
			if y >= g or i == 1 then return x, math.max(y, g), z, i end
		end
	end

	-- the eye can stay behind him at this zoom, where he stands now: false where the ground brings it in to his head
	-- (measured 2026-10-17, probes/zz_tp_zoomsweep.lua: 0.2-0.3 m behind a Hessmarine's head at every zoom under 0.9, the
	-- ground 0.4-0.7 m up behind him)
	function R.fits(zoom)
		local ex, ey, ez = behind(zoom)
		local _, _, _, i = clear(zoom, ex, ey, ez)
		return i > 1
	end

	-- melee: his unit fights hand to hand, and the camera comes in to S.melee_distance (the author, 2026-10-15)
	-- height: first person, out of a man that tall; nil, behind him. centre: it looks at him, not ahead
	function R.update(now, dt, x, y, z, ranged, melee, got_y, height, centre)
		local S, Q = E.S, R.samples
		R.first = height ~= nil
		if not R.first and R.want_pitch < PITCH_MIN then R.want_pitch = PITCH_MIN end
		-- the view eases to where the mouse put it over S.smooth s, in real time (the author, 2026-10-17: "smoothness of the
		-- camera turning"): a frame's mouse step is whole pixels, in the bursts the mouse's own rate sets, and applied raw
		-- the view turned in steps
		local k = S.smooth > 0 and 1 - math.exp(-dt / S.smooth) or 1
		R.yaw, R.pitch = R.yaw + (R.want_yaw - R.yaw) * k, R.pitch + (R.want_pitch - R.pitch) * k
		local last = Q[#Q]
		if x ~= last[2] or z ~= last[4] then
			Q[#Q + 1] = {now, x, y, z}
			if #Q > 16 then table.remove(Q, 1) end
		end
		local tp = now - (R.first and FP_LAG or S.lag)
		local i = #Q
		while i > 1 and Q[i][1] > tp do i = i - 1 end
		local tx, ty, tz = Q[i][2], Q[i][3], Q[i][4]
		if Q[i][1] <= tp and i < #Q then
			local b = Q[i + 1]
			local f = (tp - Q[i][1]) / (b[1] - Q[i][1])
			tx, ty, tz = tx + (b[2] - tx) * f, ty + (b[3] - ty) * f, tz + (b[4] - tz) * f
		end
		local a = R.first and 1 or 1 - math.exp(-K_POS * dt) -- in his head, no spring behind him
		R.sx, R.sy, R.sz = R.sx + (tx - R.sx) * a, R.sy + (ty - R.sy) * a, R.sz + (tz - R.sz) * a
		local fx, fz = math.sin(R.yaw), math.cos(R.yaw)
		if R.first then
			local ex, ez = R.sx + fx * FP_AHEAD, R.sz + fz * FP_AHEAD
			local ey = math.max(R.sy + height * FP_EYE, bm:get_terrain_height(ex, ez) + 0.2)
			local c = math.cos(R.pitch)
			local lx, ly, lz = ex + fx * c * AHEAD, ey - math.sin(R.pitch) * AHEAD, ez + fz * c * AHEAD
			R.ey2, R.ey1 = R.ey1, R.ey
			R.ex, R.ey, R.ez, R.lx, R.ly, R.lz = ex, ey, ez, lx, ly, lz
			return ex, ey, ez, lx, ly, lz
		end
		R.close = R.close + ((melee and 1 or 0) - R.close) * math.min(1, OTS_RATE * dt)
		R.ots = R.ots + ((ranged and 1 or 0) - R.ots) * math.min(1, OTS_RATE * dt)
		R.centre = R.centre + ((centre and 1 or 0) - R.centre) * math.min(1, OTS_RATE * dt)
		local ex, ey, ez, lx, ly, lz = behind(R.zoom)
		-- got_y: where the engine put an eye of the last frames, against where they were asked. It reports two frames
		-- late (measured 2026-10-15, probes/zz_tp_recorder.lua: on open ground it gave the y asked two frames before), so
		-- every quick drop of the eye read as a roof's lift and pulled the boom into a head-cam ("the camera issue is still
		-- happening"): a roof's lift is above all three
		if R.ey and got_y then
			local c = R.cap
			if got_y - math.max(R.ey, R.ey1 or R.ey, R.ey2 or R.ey) > LIFT_TOL then
				R.boom = math.max(BOOM_MIN, R.boom - BOOM_IN * dt)
				R.cap = {R.boom, R.sx, R.sz, R.yaw} -- as far out as the engine let it, from here, facing so
			else
				if c and ((R.sx - c[2]) ^ 2 + (R.sz - c[3]) ^ 2 > MOVED * MOVED or math.abs(R.yaw - c[4]) > TURNED) then
					R.cap = nil
				end
				R.boom = math.min(R.cap and R.cap[1] or 1, R.boom + BOOM_OUT * dt)
			end
		end
		ex, ey, ez = clear(R.zoom, ex, ey, ez)
		R.ey2, R.ey1 = R.ey1, R.ey
		R.ex, R.ey, R.ez, R.lx, R.ly, R.lz = ex, ey, ez, lx, ly, lz
		return ex, ey, ez, lx, ly, lz
	end

	return R
end
