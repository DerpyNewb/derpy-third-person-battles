-- spike: hold one idle model's steering point (+0x1e0 x, +0x1e8 z) 8 m to the side every frame for 6 s;
-- does he walk there alone and stay?
local IDX, DX, FIELDS = 2, 8, {{0x1e0, 0x1e8}}
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = bm:get_player_army():units():item(IDX)
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local m = mr.read_pointer(mr.read_pointer(obj, 0xa8), 0)
	local m2 = mr.read_pointer(mr.read_pointer(obj, 0xa8), 8) -- a neighbour, as the control
	local x0, z0 = mr.read_float(m, 0x88), mr.read_float(m, 0x90)
	local tx, tz = x0 + DX, z0
	local function rd(p) return math.floor(mr.read_float(p, 0x88) * 10) / 10 .. "," .. math.floor(mr.read_float(p, 0x90) * 10) / 10 end
	local T = {start = rd(m), target = tx .. "," .. tz, trace = {}, writes = 0}
	_G.DERPY_STEER = T
	local t0 = os.clock()
	bm:remove_real_callback("derpy_steer")
	bm:repeat_real_callback(function()
		local t = os.clock() - t0
		if t < 6 then
			for _, f in ipairs(FIELDS) do mr.write(m, f[1], tx) mr.write(m, f[2], tz) end
			T.writes = T.writes + 1
		end
		local k = math.floor(t * 2)
		if k ~= T.k then T.k = k T.trace[#T.trace + 1] = math.floor(t * 10) / 10 .. "s " .. rd(m) .. " nb " .. rd(m2) end
		if t > 10 then bm:remove_real_callback("derpy_steer") end
	end, 1, "derpy_steer")
	return T
end)
if ok then return res end
return "ERR " .. tostring(res)
