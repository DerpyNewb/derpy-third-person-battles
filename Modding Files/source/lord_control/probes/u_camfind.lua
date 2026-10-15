-- memreader pass 4: breadth-first walk out from the camera wrapper, following heap-looking pointers
-- up to three levels, looking for the camera's x, y, z (and its target's) as three adjacent floats.
-- Run with the camera standing still. No string library: pointers are compared as fixed-width hex.
local SCAN, SLOTS, MAXD, MAXN, TOL = 0x800, 32, 3, 600, 0.001
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local cam = bm:camera()
	local p, t = cam:position(), cam:target()
	local want = {
		pos = {p:get_x(), p:get_y(), p:get_z()},
		tgt = {t:get_x(), t:get_y(), t:get_z()},
	}
	local function plausible(s)
		if s < "0000000010000000" or s >= "0000080000000000" then return false end
		return s < "0000000140000000" or s >= "0000000146000000"
	end
	local root = mr.ud_topointer(cam)
	local queue, seen, hits = {{root, "c", 0}}, {}, {}
	local head, nodes, nhits = 1, 0, 0
	while head <= #queue and nodes < MAXN do
		local node = queue[head]
		head = head + 1
		nodes = nodes + 1
		local base, path, depth = node[1], node[2], node[3]
		local a, b = nil, nil
		local off = 0
		while off < SCAN do
			local good, v = pcall(mr.read_float, base, off)
			if not good then break end
			if a and b then
				for name, w in pairs(want) do
					if math.abs(a - w[1]) < TOL and math.abs(b - w[2]) < TOL and math.abs(v - w[3]) < TOL and nhits < 60 then
						nhits = nhits + 1
						hits[nhits] = path .. "+" .. (off - 8) .. "=" .. name
					end
				end
			end
			a, b = b, v
			off = off + 4
		end
		if depth < MAXD then
			for k = 0, SLOTS - 1 do
				local good, q = pcall(mr.read_pointer, base, k * 8)
				if not good then break end
				local s = mr.tostring(q)
				if plausible(s) and not seen[s] then
					seen[s] = true
					queue[#queue + 1] = {q, path .. ">" .. (k * 8), depth + 1}
				end
			end
		end
	end
	return {want = want, nodes = nodes, queued = #queue, hits = hits}
end)
if ok then return res end
return "ERR " .. tostring(res)
