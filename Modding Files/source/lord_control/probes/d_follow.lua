-- Follow test, armed on F2: every frame, move the camera AND its target by however far a predicted
-- copy of the general's position moved, so the player's angle and zoom are untouched. (The camera's
-- target is a far look-direction point, not the ground under it, so it cannot be put on him.)
-- His reported position only changes every few hundred ms, so between reports the probe walks him
-- on at his last measured speed, never more than one report interval ahead.
-- Records frames, model steps, and how often the camera was NOT where this callback left it on the
-- previous frame (the player's input, or move_to not taking).
local SECONDS = 45
local SMOOTH = 12		-- per second
local ok, res = pcall(function()
	core:remove_listener("derpy_cam_follow_key")
	bm:remove_real_callback("derpy_cam_follow")
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	if not lord then return "no general" end
	local cam = bm:camera()
	local F = {armed = true}
	_G.DERPY_CAM_FOLLOW = F
	local lx, ly, lz, lt, span
	local vx, vy, vz = 0, 0, 0
	local sx, sy, sz

	local function stop()
		F.running = false
		F.done = true
		F.elapsed = os.clock() - F.t0
		bm:remove_real_callback("derpy_cam_follow")
	end

	local function tick()
		local good, problem = pcall(function()
			local now = os.clock()
			local dt = now - F.prev
			F.prev = now
			F.frames = F.frames + 1
			local p, t = cam:position(), cam:target()
			local px, py, pz = p:get_x(), p:get_y(), p:get_z()
			if F.setx then
				local off = math.abs(px - F.setx) + math.abs(py - F.sety) + math.abs(pz - F.setz)
				if off > 0.05 then F.moved_off = F.moved_off + 1 end
				if off > F.max_off then F.max_off = off end
			end
			local q = lord:position()
			local qx, qy, qz = q:get_x(), q:get_y(), q:get_z()
			if qx ~= lx or qy ~= ly or qz ~= lz then
				if lt then
					span = now - lt
					vx, vy, vz = (qx - lx) / span, (qy - ly) / span, (qz - lz) / span
					F.steps = F.steps + 1
					F.span_sum = F.span_sum + span
				end
				lx, ly, lz, lt = qx, qy, qz, now
			end
			local ahead = now - lt
			if not span or ahead > span * 1.5 then
				vx, vy, vz = 0, 0, 0		-- no report for too long: he has stopped
			elseif ahead > span then
				ahead = span
			end
			local ex, ey, ez = lx + vx * ahead, ly + vy * ahead, lz + vz * ahead
			if not sx then sx, sy, sz = ex, ey, ez end
			local k = math.min(1, dt * SMOOTH)
			local dx, dy, dz = (ex - sx) * k, (ey - sy) * k, (ez - sz) * k
			sx, sy, sz = sx + dx, sy + dy, sz + dz
			F.setx, F.sety, F.setz = px + dx, py + dy, pz + dz
			cam:move_to(battle_vector:new(F.setx, F.sety, F.setz), battle_vector:new(t:get_x() + dx, t:get_y() + dy, t:get_z() + dz), 0, false, -1)
			if now - F.t0 >= SECONDS then stop() end
		end)
		if not good then
			F.err = tostring(problem)
			stop()
		end
	end

	core:add_listener(
		"derpy_cam_follow_key",
		"ShortcutPressed",
		function(context) return context.string == "script_F2" end,
		function()
			if F.running then return stop() end
			F.running, F.done, F.err = true, false, nil
			F.frames, F.moved_off, F.max_off, F.steps, F.span_sum = 0, 0, 0, 0, 0
			F.setx, lx, lt, span, sx = nil, nil, nil, nil, nil
			F.t0 = os.clock()
			F.prev = F.t0
			F.runs = (F.runs or 0) + 1
			bm:repeat_real_callback(tick, 1, "derpy_cam_follow")
		end,
		true
	)
	return "armed: press F2 in game"
end)
if ok then return res end
return "ERR " .. tostring(res)
