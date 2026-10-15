-- find a model's position offset: the general is one model, so floats matching his x and z are it
local SPAN, TOL = 0x800, 0.3
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = bm:get_player_army():units():item(1)
	local c = u:position()
	local cx, cy, cz = c:get_x(), c:get_y(), c:get_z()
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local m = mr.read_pointer(mr.read_pointer(obj, 0xa8), 0)
	local hits = {}
	for off = 0, SPAN - 12, 4 do
		local x = mr.read_float(m, off)
		if x == x and math.abs(x - cx) < TOL then
			local y, z = mr.read_float(m, off + 4), mr.read_float(m, off + 8)
			hits[#hits + 1] = off .. ":" .. math.floor(x * 100) / 100 .. "," .. math.floor(y * 100) / 100 .. "," .. math.floor(z * 100) / 100
		end
	end
	return {centre = cx .. "," .. cy .. "," .. cz, hits = table.concat(hits, " ")}
end)
if ok then return res end
return "ERR " .. tostring(res)
