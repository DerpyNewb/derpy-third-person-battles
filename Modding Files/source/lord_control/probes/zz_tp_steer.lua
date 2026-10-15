-- what do the three steering copies hold on a unit that has never been ordered? Per unit: the first and
-- the last model's position and the three (x, z) copies. Read-only.
local STEER = {{0x1e0, 0x1e8}, {0x194, 0x198}, {0x368, 0x370}}
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	local P = E.P
	local t = {}
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		local u = units:item(i)
		local ms = P.models(u)
		local row = {key = u:type(), moving = u:is_moving()}
		for _, k in ipairs({1, #ms}) do
			local m = ms[k]
			local x, y, z = P.model_pos(m)
			local s = string.format("m%d pos %.1f,%.1f,%.1f", k, x, y, z)
			for _, f in ipairs(STEER) do s = s .. string.format(" | %.1f,%.1f", mr.read_float(m, f[1]), mr.read_float(m, f[2])) end
			row[#row + 1] = s
		end
		t[#t + 1] = row
	end
	return t
end)
if ok then return res end
return "ERR " .. tostring(res)
