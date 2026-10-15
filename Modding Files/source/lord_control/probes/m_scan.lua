-- memreader pass 3: behind every heap pointer in the two interface objects, look for the floats
-- the script API reports - the general's x and z, the camera's x, y and z. Offsets of each hit.
local LIMIT, TOL = 0x1000, 0.01
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	local cam = bm:camera()
	local q, p = lord:position(), cam:position()
	local want = {lx = q:get_x(), lz = q:get_z(), cx = p:get_x(), cy = p:get_y(), cz = p:get_z()}
	local a, c = mr.ud_topointer(lord), mr.ud_topointer(cam)
	local bases = {
		{"L0", a}, {"L8", mr.read_pointer(a, 8)}, {"L20", mr.read_pointer(a, 0x20)}, {"L30", mr.read_pointer(a, 0x30)},
		{"C0", mr.read_pointer(c, 0)}, {"C8", c}, {"C20", mr.read_pointer(c, 0x20)}, {"C28", mr.read_pointer(c, 0x28)}, {"C30", mr.read_pointer(c, 0x30)},
	}
	local hits, ends, n = {}, {}, 0
	for _, b in ipairs(bases) do
		local off = 0
		while off < LIMIT do
			local good, v = pcall(mr.read_float, b[2], off)
			if not good then break end
			for name, w in pairs(want) do
				if math.abs(v - w) < TOL and n < 120 then
					n = n + 1
					hits[n] = b[1] .. "+" .. off .. "=" .. name
				end
			end
			off = off + 4
		end
		ends[b[1]] = off
	end
	return {want = want, hits = hits, scanned = ends}
end)
if ok then return res end
return "ERR " .. tostring(res)
