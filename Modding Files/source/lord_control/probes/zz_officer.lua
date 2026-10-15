-- where is a regiment's officer: position_of_officer() vs position(), and which model object holds
-- floats matching the officer's x/z (first 0x600 bytes of each model, float32 at every 4 bytes)
local IDX, SPAN, TOL = 4, 0x600, 0.6
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = bm:get_player_army():units():item(IDX)
	local o, c = u:position_of_officer(), u:position()
	local ox, oz = o:get_x(), o:get_z()
	local T = {officer = {ox, o:get_y(), oz}, centre = {c:get_x(), c:get_y(), c:get_z()}, hits = {}}
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local n = mr.read_int32(obj, 0xa4)
	local models = mr.read_pointer(obj, 0xa8)
	T.models = n
	for k = 0, n - 1 do
		local m = mr.read_pointer(models, k * 8)
		for off = 0, SPAN - 12, 4 do
			local x = mr.read_float(m, off)
			if x == x and math.abs(x - ox) < TOL then
				local z = mr.read_float(m, off + 8)
				if z == z and math.abs(z - oz) < TOL then
					if #T.hits < 30 then T.hits[#T.hits + 1] = k .. "@" .. off .. ":" .. math.floor(x * 100) / 100 .. "," .. math.floor(z * 100) / 100 end
				end
			end
		end
	end
	T.hits = table.concat(T.hits, " ")
	return T
end)
if ok then return res end
return "ERR " .. tostring(res)
