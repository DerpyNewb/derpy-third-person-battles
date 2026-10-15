-- Rates, camera untouched: walk the general 40m, and for 6 seconds count real-timer calls
-- (frames), the longest gap between two, and how often his reported position changes.
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
	uc:goto_location(battle_vector:new(q:get_x() + 28, q:get_y(), q:get_z() + 28), false)
	uc:release_control()

	local P = {frames = 0, pos_changes = 0, max_gap = 0, t0 = os.clock()}
	P.prev = P.t0
	_G.DERPY_CAM_RATES = P
	bm:repeat_real_callback(function()
		local now = os.clock()
		P.frames = P.frames + 1
		if now - P.prev > P.max_gap then P.max_gap = now - P.prev end
		P.prev = now
		local p = lord:position()
		local x, z = p:get_x(), p:get_z()
		if P.lx and (x ~= P.lx or z ~= P.lz) then P.pos_changes = P.pos_changes + 1 end
		P.lx, P.lz = x, z
		if now - P.t0 >= 6 then
			P.elapsed = now - P.t0
			P.done = true
			bm:remove_real_callback("derpy_cam_rates")
		end
	end, 1, "derpy_cam_rates")
	return "started"
end)
if ok then return res end
return "ERR " .. tostring(res)
