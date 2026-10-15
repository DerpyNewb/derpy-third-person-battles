local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then u = units:item(i) end
	end
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local r = {size_a4 = mr.read_int32(obj, 0xa4), size_184 = mr.read_int32(obj, 0x184)}
	local e = mr.read_pointer(mr.read_pointer(obj, 0xa8), 0)
	r.entity = mr.tostring(e)
	r.vtable = mr.tostring(mr.read_pointer(e, 0))
	r.e2 = mr.tostring(mr.read_pointer(mr.read_pointer(obj, 0x188), 0))
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
