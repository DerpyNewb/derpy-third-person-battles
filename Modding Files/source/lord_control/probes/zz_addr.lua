-- addresses (as numbers) of the shooter's unit object and its front-centre man and two others
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = _G.DERPY_TGT.shooter
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local q = u:position()
	local b = math.rad(u:bearing())
	local fx, fz = math.sin(b), math.cos(b)
	local n, models = mr.read_int32(obj, 0xa4), mr.read_pointer(obj, 0xa8)
	local best, bs, bk
	for k = 0, n - 1 do
		local m = mr.read_pointer(models, k * 8)
		local dx, dz = mr.read_float(m, 0x88) - q:get_x(), mr.read_float(m, 0x90) - q:get_z()
		local s = -(dx * fx + dz * fz) + math.abs(dx * fz - dz * fx) * 0.5
		if not bs or s < bs then best, bs, bk = m, s, k end
	end
	return {obj = mr.tostring(obj), best = mr.tostring(best), k = bk, m0 = mr.tostring(mr.read_pointer(models, 0)), m1 = mr.tostring(mr.read_pointer(models, 8)), n = n, base = mr.tostring(mr.base)}
end)
if ok then return res end
return "ERR " .. tostring(res)
