-- RE step 2: the general's model list (unit object +0x118, count +0x114), each model's vtable+0x630
-- (the captain predicate play_anim_for_captain asks), and the command-queue gate bytes.
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then u = units:item(i) end
	end
	local iface = mr.ud_topointer(u)
	local obj = mr.read_pointer(iface, 8)
	local n = mr.read_uint32(obj, 0x114)
	local arr = mr.read_pointer(obj, 0x118)
	local r = {iface = mr.tostring(iface), obj = mr.tostring(obj), count = n, ents = {}}
	for k = 0, math.min(n, 4) - 1 do
		local e = mr.read_pointer(arr, k * 8)
		local vt = mr.read_pointer(e, 0)
		r.ents[k + 1] = {mr.tostring(e), mr.tostring(vt), mr.tostring(mr.read_pointer(vt, 0x630))}
	end
	local g = mr.read_pointer(mr.add(mr.add(mr.base, 0x4400000), 0x79ee0))
	local b = mr.read_pointer(g, 0x468)
	r.gate = {mr.read_uint8(b, 0x3b0), mr.read_uint8(b, 0x3b1)}
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
