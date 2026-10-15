-- One-frame snapshot: walk out from the general's game object (interface +8) up to three pointer
-- hops, and keep every float triple within TOL of his script position. NaN/Inf slots are rejected
-- by their bits, since this Lua build compares NaN as near anything. Candidates are kept in
-- _G.DERPY_LORD_CANDS for z_lordwatch.lua.
local SCAN, SLOTS, MAXD, MAXN, TOL = 0x800, 48, 3, 800, 1.0
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	local q = lord:position()
	local w = {q:get_x(), q:get_y(), q:get_z()}
	local function finite(base, off)
		local u = mr.read_uint32(base, off)
		return not ((u >= 2139095040 and u < 2147483648) or u >= 4286578688)
	end
	local function plausible(s)
		if s < "0000000010000000" or s >= "0000080000000000" then return false end
		return s < "0000000140000000" or s >= "0000000146000000"
	end
	local root = mr.read_pointer(mr.ud_topointer(lord), 8)
	local queue, seen, hits, cands = {{root, "o", 0}}, {}, {}, {}
	local head, nodes = 1, 0
	while head <= #queue and nodes < MAXN do
		local node = queue[head]
		head = head + 1
		nodes = nodes + 1
		local base, path, depth = node[1], node[2], node[3]
		local a, b = nil, nil
		local off = 0
		while off < SCAN do
			local good, c = pcall(mr.read_float, base, off)
			if not good then break end
			if a and b and math.abs(a - w[1]) < TOL and math.abs(b - w[2]) < TOL and math.abs(c - w[3]) < TOL
				and finite(base, off - 8) and finite(base, off - 4) and finite(base, off) and #hits < 60 then
				hits[#hits + 1] = path .. "+" .. (off - 8) .. " " .. a .. " " .. b .. " " .. c
				cands[#cands + 1] = {base, off - 8, path .. "+" .. (off - 8)}
			end
			a, b = b, c
			off = off + 4
		end
		if depth < MAXD then
			for k = 0, SLOTS - 1 do
				local good, p = pcall(mr.read_pointer, base, k * 8)
				if not good then break end
				local s = mr.tostring(p)
				if plausible(s) and not seen[s] then
					seen[s] = true
					queue[#queue + 1] = {p, path .. ">" .. (k * 8), depth + 1}
				end
			end
		end
	end
	_G.DERPY_LORD_CANDS = cands
	return {want = w, nodes = nodes, queued = #queue, hits = hits}
end)
if ok then return res end
return "ERR " .. tostring(res)
