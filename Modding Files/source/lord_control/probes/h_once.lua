-- One move_to with the camera's own position and target, then record position, target and the
-- target's distance for the next 30 frames. A true no-op leaves all three unchanged.
local ok, res = pcall(function()
	local cam = bm:camera()
	local function snap()
		local p, t = cam:position(), cam:target()
		local px, py, pz, tx, ty, tz = p:get_x(), p:get_y(), p:get_z(), t:get_x(), t:get_y(), t:get_z()
		local d = math.sqrt((tx - px) ^ 2 + (ty - py) ^ 2 + (tz - pz) ^ 2)
		return {math.floor(px * 10) / 10, math.floor(py * 10) / 10, math.floor(pz * 10) / 10,
			math.floor(tx * 10) / 10, math.floor(ty * 10) / 10, math.floor(tz * 10) / 10, math.floor(d * 10) / 10}
	end
	local O = {before = snap(), frames = {}}
	_G.DERPY_CAM_ONCE = O
	local p, t = cam:position(), cam:target()
	cam:move_to(battle_vector:new(p:get_x(), p:get_y(), p:get_z()), battle_vector:new(t:get_x(), t:get_y(), t:get_z()), 0, false, -1)
	O.right_after = snap()
	bm:repeat_real_callback(function()
		O.frames[#O.frames + 1] = snap()
		if #O.frames >= 30 then
			O.done = true
			bm:remove_real_callback("derpy_cam_once")
		end
	end, 1, "derpy_cam_once")
	return "moved once"
end)
if ok then return res end
return "ERR " .. tostring(res)
