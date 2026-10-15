-- spike: which fields of one regiment model hold where he is GOING (vs +0x88, where he is)?
-- snapshot model memory idle, then while the regiment walks 30 m; read back with zz_snap_read.lua
local IDX, SPAN, WALK = 4, 0x800, 30
local ok, res = pcall(function()
	local mr = _G.memreader_plus
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
	local P = {model = best, snaps = {}, goal = {q:get_x() + fx * WALK, q:get_z() + fz * WALK}}
	_G.DERPY_SNAP = P
	local function snap(tag)
		local f = {}
		for off = 0, SPAN - 4, 4 do
			local x = mr.read_float(best, off)
			if x ~= x or x > 1e7 or x < -1e7 then x = -99999 end
			f[#f + 1] = math.floor(x * 1000 + 0.5) / 1000
		end
		local p = u:position()
		P.snaps[#P.snaps + 1] = {tag = tag, f = f, unit = {p:get_x(), p:get_z()}}
	end
	snap("idle")
	local uc = create_unitcontroller(u)
	uc:goto_location(v(P.goal[1], q:get_y(), P.goal[2]), false)
	uc:release_control()
	for _, ms in ipairs({600, 1500, 3000, 6000}) do
		bm:real_callback(function() snap("t" .. ms) end, ms, "derpy_snap_" .. ms)
	end
	return {n = n, goal = P.goal}
end)
if ok then return res end
return "ERR " .. tostring(res)
