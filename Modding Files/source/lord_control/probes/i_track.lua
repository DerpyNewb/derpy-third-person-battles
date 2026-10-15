-- Built-in tracking camera, measured. Arms on F2: lowers the camera's floor to 1.5m above ground,
-- then for 10 seconds records per frame how far the camera moved, its height above the general's
-- reported position and its ground distance from him, and how often that reported position changed.
-- If the camera moves a little every frame while his position only steps, the game's follow camera
-- is tracking his DRAWN position, which scripts cannot read.
local SECONDS = 10
local ok, res = pcall(function()
	core:remove_listener("derpy_cam_track_key")
	bm:remove_real_callback("derpy_cam_track")
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	if not lord then return "no general" end
	local cam = bm:camera()
	local T = {}
	_G.DERPY_CAM_TRACK = T

	local function tick()
		local good, problem = pcall(function()
			local now = os.clock()
			local p, q = cam:position(), lord:position()
			local px, py, pz, qx, qy, qz = p:get_x(), p:get_y(), p:get_z(), q:get_x(), q:get_y(), q:get_z()
			T.frames = T.frames + 1
			if T.px then
				local step = math.sqrt((px - T.px) ^ 2 + (py - T.py) ^ 2 + (pz - T.pz) ^ 2)
				if step > 0.0001 then T.cam_moving_frames = T.cam_moving_frames + 1 end
				if step > T.cam_step_max then T.cam_step_max = step end
				T.cam_step_sum = T.cam_step_sum + step
			end
			if T.qx and (qx ~= T.qx or qz ~= T.qz) then T.lord_steps = T.lord_steps + 1 end
			T.px, T.py, T.pz, T.qx, T.qz = px, py, pz, qx, qz
			local h = py - qy
			local g = math.sqrt((px - qx) ^ 2 + (pz - qz) ^ 2)
			if h < T.h_min then T.h_min = h end
			if h > T.h_max then T.h_max = h end
			if g < T.g_min then T.g_min = g end
			if g > T.g_max then T.g_max = g end
			if now - T.t0 >= SECONDS then
				T.done = true
				T.elapsed = now - T.t0
				bm:remove_real_callback("derpy_cam_track")
			end
		end)
		if not good then
			T.err = tostring(problem)
			T.done = true
			bm:remove_real_callback("derpy_cam_track")
		end
	end

	core:add_listener(
		"derpy_cam_track_key",
		"ShortcutPressed",
		function(context) return context.string == "script_F2" end,
		function()
			bm:remove_real_callback("derpy_cam_track")
			cam:change_height_range(1.5, 1000)
			T.done, T.err, T.px, T.qx = false, nil, nil, nil
			T.frames, T.cam_moving_frames, T.cam_step_max, T.cam_step_sum, T.lord_steps = 0, 0, 0, 0, 0
			T.h_min, T.h_max, T.g_min, T.g_max = 1e9, -1e9, 1e9, -1e9
			T.t0 = os.clock()
			T.runs = (T.runs or 0) + 1
			bm:repeat_real_callback(tick, 1, "derpy_cam_track")
		end,
		true
	)
	return "armed: press F2 in game"
end)
if ok then return res end
return "ERR " .. tostring(res)
