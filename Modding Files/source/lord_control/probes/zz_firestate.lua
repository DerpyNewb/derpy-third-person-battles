-- spike: one crossbowman's memory, idle vs while his regiment ground-fires at a point AHEAD m out.
-- Looking for his own target (the point's x/z), his own ammo (counts down) and his firing stage.
local IDX, SPAN, AHEAD = 4, 0x1000, 60
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local F = _G.DERPY_FOLLOW
	if F and F.on then F.stop_fn("firestate") end
	local u = bm:get_player_army():units():item(IDX)
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local n, models = mr.read_int32(obj, 0xa4), mr.read_pointer(obj, 0xa8)
	local q = u:position()
	local b = math.rad(u:bearing())
	local fx, fz = math.sin(b), math.cos(b)
	local best, bs
	for k = 0, n - 1 do
		local m = mr.read_pointer(models, k * 8)
		local dx, dz = mr.read_float(m, 0x88) - q:get_x(), mr.read_float(m, 0x90) - q:get_z()
		local s = -(dx * fx + dz * fz) + math.abs(dx * fz - dz * fx) * 0.5
		if not bs or s < bs then best, bs = m, s end
	end
	local P = {snaps = {}, point = {q:get_x() + fx * AHEAD, q:get_z() + fz * AHEAD}}
	_G.DERPY_FS = P
	local uc = create_unitcontroller(u)
	P.uc = uc
	local function snap(tag)
		local fl, it = {}, {}
		for off = 0, SPAN - 4, 4 do
			local x = mr.read_float(best, off)
			if x ~= x or x > 1e7 or x < -1e7 then x = -99999 end
			fl[#fl + 1] = math.floor(x * 1000 + 0.5) / 1000
			it[#it + 1] = mr.read_int32(best, off)
		end
		P.snaps[#P.snaps + 1] = {tag = tag, fl = fl, it = it, ammo = u:ammo_left()}
	end
	uc:fire_at_will(false)
	uc:halt()
	bm:real_callback(function() snap("idle") uc:fire_at_will(true) uc:attack_location(v(P.point[1], q:get_y(), P.point[2]), false) uc:release_control() end, 1500, "derpy_fs_0")
	for i, ms in ipairs({3000, 4500, 6500, 9000}) do
		bm:real_callback(function() snap("t" .. ms) end, ms, "derpy_fs_" .. i)
	end
	bm:real_callback(function() uc:halt() uc:fire_at_will(true) uc:release_control() end, 9500, "derpy_fs_end")
	return {n = n, point = P.point, ammo = u:ammo_left()}
end)
if ok then return res end
return "ERR " .. tostring(res)
