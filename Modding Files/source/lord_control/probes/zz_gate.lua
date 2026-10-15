-- spike: does clearing one per-man flag on every man but one stop them shooting? attack_unit on the
-- pinned target (zz_target_setup): WIN s baseline, then WIN s with FIELD held at 0 on all men but one.
-- FIELD = 0 runs a control with no gating.
local IDX, WIN, FIELD = 2, 12, 0
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = _G.DERPY_TGT.shooter
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local q = u:position()
	local b = math.rad(u:bearing())
	local fx, fz = math.sin(b), math.cos(b)
	local n, models = mr.read_int32(obj, 0xa4), mr.read_pointer(obj, 0xa8)
	local best, bs
	for k = 0, n - 1 do
		local m = mr.read_pointer(models, k * 8)
		local dx, dz = mr.read_float(m, 0x88) - q:get_x(), mr.read_float(m, 0x90) - q:get_z()
		local s = -(dx * fx + dz * fz) + math.abs(dx * fz - dz * fx) * 0.5
		if not bs or s < bs then best, bs = m, s end
	end
	local others = {}
	for k = 0, n - 1 do local m = mr.read_pointer(models, k * 8) if not mr.eq(m, best) then others[#others + 1] = m end end
	local T = {field = FIELD, trace = {}}
	_G.DERPY_GATE = T
	local uc = create_unitcontroller(u)
	uc:fire_at_will(true)
	uc:halt() -- shoot what is in range: fire at will, no move order (attack_unit sent them into melee)
	uc:release_control()
	local t0 = os.clock()
	T.a0 = u:ammo_left()
	bm:remove_real_callback("derpy_gate")
	bm:repeat_real_callback(function()
		local t = os.clock() - t0
		if t >= WIN and t < 2 * WIN and FIELD > 0 then for _, m in ipairs(others) do mr.write(m, FIELD, mr.int32(0)) end end
		if t >= WIN and not T.a6 then T.a6 = u:ammo_left() end
		if t >= 2 * WIN and not T.a12 then
			T.a12 = u:ammo_left()
			T.mine = mr.read_int32(best, FIELD)
			uc:halt() uc:release_control()
			bm:remove_real_callback("derpy_gate")
		end
	end, 1, "derpy_gate")
	return {men = n, others = #others}
end)
if ok then return res end
return "ERR " .. tostring(res)
