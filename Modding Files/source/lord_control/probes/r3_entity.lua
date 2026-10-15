-- RE step 3: officer models of an enemy regiment give the model vtable V. Then search the general's
-- unit object (0x1000 bytes) for a pointer to a V object, directly or as the first element of an array.
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local function plausible(p) local s = mr.tostring(p) return s >= "0000000010000000" and s < "0000080000000000" end
	local reg, robj, n
	local counts = {}
	local armies = bm:get_non_player_alliance():armies()
	for a = 1, armies:count() do
		local list = armies:item(a):units()
		for i = 1, list:count() do
			local e = list:item(i)
			local o = mr.read_pointer(mr.ud_topointer(e), 8)
			local c = mr.read_uint32(o, 0x114)
			counts[#counts + 1] = e:number_of_men_alive() .. ":" .. c
			if not reg and c > 0 then reg, robj, n = e, o, c end
		end
	end
	if not reg then return {no_officers_anywhere = counts} end
	local officer = mr.read_pointer(mr.read_pointer(robj, 0x118), 0)
	local V = mr.read_pointer(officer, 0)
	local r = {counts = counts, regiment = reg:name(), men = reg:number_of_men_alive(), officers = n, vtable = mr.tostring(V), hits = {}}
	local general
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then general = units:item(i) end
	end
	local gobj = mr.read_pointer(mr.ud_topointer(general), 8)
	for off = 0, 0xff8, 8 do
		local good, p = pcall(mr.read_pointer, gobj, off)
		if good and plausible(p) then
			local g1, q = pcall(mr.read_pointer, p, 0)
			if g1 and mr.eq(q, V) then r.hits[#r.hits + 1] = "obj+" .. off .. " direct" end
			if g1 and plausible(q) then
				local g2, w = pcall(mr.read_pointer, q, 0)
				if g2 and mr.eq(w, V) then r.hits[#r.hits + 1] = "obj+" .. off .. " [0]" end
			end
		end
	end
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
