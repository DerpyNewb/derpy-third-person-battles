-- spike: does writing one idle model's position (+0x88 x) stick, snap back, or does he walk back?
local IDX, DX = 2, 5
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = bm:get_player_army():units():item(IDX)
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local m = mr.read_pointer(mr.read_pointer(obj, 0xa8), 0)
	local function rd() return math.floor(mr.read_float(m, 0x88) * 100) / 100 .. "," .. math.floor(mr.read_float(m, 0x90) * 100) / 100 .. " v=" .. math.floor(mr.read_float(m, 0xe0) * 100) / 100 .. "," .. math.floor(mr.read_float(m, 0xe8) * 100) / 100 .. " c=" .. math.floor(mr.read_float(m, 0x1e0) * 100) / 100 end
	local T = {before = rd(), trace = {}}
	_G.DERPY_NUDGE = T
	local x0 = mr.read_float(m, 0x88)
	mr.write(m, 0x88, x0 + DX)
	T.right_after = rd()
	for _, ms in ipairs({100, 300, 700, 1500, 3000, 5000}) do
		bm:real_callback(function() T.trace[#T.trace + 1] = ms .. ": " .. rd() end, ms, "derpy_nudge_" .. ms)
	end
	return T
end)
if ok then return res end
return "ERR " .. tostring(res)
