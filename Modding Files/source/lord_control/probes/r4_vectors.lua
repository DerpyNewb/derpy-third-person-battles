-- RE step 4: in a big enemy regiment's unit object, find CA vectors {u32 cap, i32 size, T* data}
-- whose size is near the living model count. Reports offset of size, size and the data pointer.
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local function plausible(p) local s = mr.tostring(p) return s >= "0000000010000000" and s < "0000080000000000" end
	local reg
	local armies = bm:get_non_player_alliance():armies()
	for a = 1, armies:count() do
		local list = armies:item(a):units()
		for i = 1, list:count() do
			local e = list:item(i)
			if not reg and e:number_of_men_alive() > 100 then reg = e end
		end
	end
	local alive = reg:number_of_men_alive()
	local obj = mr.read_pointer(mr.ud_topointer(reg), 8)
	local r = {alive = alive, initial = reg:initial_number_of_men(), hits = {}}
	for off = 4, 0x3000, 8 do
		local good, n = pcall(mr.read_int32, obj, off)
		if not good then break end
		if n >= alive - 2 and n <= r.initial + 2 then
			local g2, p = pcall(mr.read_pointer, obj, off + 4)
			if g2 and plausible(p) then
				local g3, v = pcall(mr.read_pointer, mr.read_pointer(p, 0), 0)
				r.hits[#r.hits + 1] = off .. ":" .. n .. ":" .. mr.tostring(p) .. ":" .. (g3 and mr.tostring(v) or "?")
			end
		end
	end
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
