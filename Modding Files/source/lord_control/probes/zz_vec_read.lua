-- spike: the shooter's unit object around its two model vectors (+0xa4/+0xa8 and the mirror +0x184/+0x188)
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = _G.DERPY_TGT.shooter
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local out = {men = u:number_of_men_alive(), ammo = u:ammo_left()}
	local rows = {}
	for off = 0x90, 0x1a0, 8 do
		rows[#rows + 1] = {off, mr.read_int32(obj, off), mr.read_int32(obj, off + 4), tostring(mr.read_pointer(obj, off))}
	end
	out.rows = rows
	local d1, d2 = mr.read_pointer(obj, 0xa8), mr.read_pointer(obj, 0x188)
	out.same = mr.eq(d1, d2)
	out.first = {tostring(mr.read_pointer(d1, 0)), tostring(mr.read_pointer(d2, 0)), tostring(mr.read_pointer(d1, 8)), tostring(mr.read_pointer(d2, 8))}
	return out
end)
if ok then return res end
return "ERR " .. tostring(res)
