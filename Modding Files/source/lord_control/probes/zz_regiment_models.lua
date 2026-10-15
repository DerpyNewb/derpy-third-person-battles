-- the regiment's models at +0x88 (x, y, z): their mean against position(), and the front-centre model
local IDX, POS = 4, 0x88
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = bm:get_player_army():units():item(IDX)
	local c = u:position()
	local cx, cz = c:get_x(), c:get_z()
	local b = math.rad(u:bearing())
	local fx, fz = math.sin(b), math.cos(b)
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local n = mr.read_int32(obj, 0xa4)
	local models = mr.read_pointer(obj, 0xa8)
	local sx, sz, best, best_score, minf, maxf, mins, maxs = 0, 0, nil, nil, 1e9, -1e9, 1e9, -1e9
	local first = {}
	for k = 0, n - 1 do
		local m = mr.read_pointer(models, k * 8)
		local x, z = mr.read_float(m, POS), mr.read_float(m, POS + 8)
		sx, sz = sx + x, sz + z
		local ahead, side = (x - cx) * fx + (z - cz) * fz, (x - cx) * fz - (z - cz) * fx
		minf, maxf, mins, maxs = math.min(minf, ahead), math.max(maxf, ahead), math.min(mins, side), math.max(maxs, side)
		local score = -ahead + math.abs(side) * 0.5
		if not best_score or score < best_score then best, best_score = k, score end
		if k < 6 then first[#first + 1] = k .. ":" .. math.floor(ahead * 10) / 10 .. "/" .. math.floor(side * 10) / 10 end
	end
	return {n = n, mean_off = math.floor(math.sqrt((sx / n - cx) ^ 2 + (sz / n - cz) ^ 2) * 100) / 100, depth = {minf, maxf}, width = {mins, maxs}, front_centre = best, first = table.concat(first, " ")}
end)
if ok then return res end
return "ERR " .. tostring(res)
