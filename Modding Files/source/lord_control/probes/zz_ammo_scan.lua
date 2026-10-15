-- spike: which model field, summed over the regiment, equals unit:ammo_left()? (int32 or float)
local IDX, SPAN = 4, 0x1000
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = bm:get_player_army():units():item(IDX)
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local n, models = mr.read_int32(obj, 0xa4), mr.read_pointer(obj, 0xa8)
	local ms = {}
	for k = 0, n - 1 do ms[k] = mr.read_pointer(models, k * 8) end
	local ammo = u:ammo_left()
	local hits = {}
	for off = 0, SPAN - 4, 4 do
		local si, sf, okf = 0, 0, true
		for k = 0, n - 1 do
			si = si + mr.read_int32(ms[k], off)
			local f = mr.read_float(ms[k], off)
			if f ~= f or f > 1e6 or f < -1e6 then okf = false else sf = sf + f end
		end
		if si == ammo or math.abs(si - ammo) <= 2 then hits[#hits + 1] = "int@" .. off .. "=" .. si end
		if okf and math.abs(sf - ammo) <= 2 then hits[#hits + 1] = "float@" .. off .. "=" .. sf end
		if okf and math.abs(sf - ammo / n) < 0.01 then hits[#hits + 1] = "avgfloat@" .. off end
	end
	return {ammo = ammo, men = n, hits = table.concat(hits, " ")}
end)
if ok then return res end
return "ERR " .. tostring(res)
