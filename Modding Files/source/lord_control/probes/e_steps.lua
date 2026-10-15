-- Position steps: walk the general 60m, then for 5 seconds log the time and size of every change
-- in his reported position (first 40 changes), so the update interval can be read directly.
local ok, res = pcall(function()
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	if not lord then return "no general" end
	local q = lord:position()
	local uc = bm:get_player_army():create_unit_controller()
	uc:add_units(lord)
	uc:goto_location(battle_vector:new(q:get_x() - 42, q:get_y(), q:get_z() - 42), true)
	uc:release_control()

	local S = {t0 = os.clock(), steps = {}, start = {q:get_x(), q:get_z()}}
	_G.DERPY_CAM_STEPS = S
	bm:repeat_real_callback(function()
		local now = os.clock()
		local p = lord:position()
		local x, z = p:get_x(), p:get_z()
		if S.lx and (x ~= S.lx or z ~= S.lz) and #S.steps < 40 then
			S.steps[#S.steps + 1] = {math.floor((now - S.t0) * 1000), math.floor(math.sqrt((x - S.lx) ^ 2 + (z - S.lz) ^ 2) * 100) / 100}
		end
		S.lx, S.lz = x, z
		if now - S.t0 >= 5 then
			S.done = true
			S.finish = {x, z}
			S.moving = lord:is_moving()
			bm:remove_real_callback("derpy_cam_steps")
		end
	end, 1, "derpy_cam_steps")
	return "started"
end)
if ok then return res end
return "ERR " .. tostring(res)
