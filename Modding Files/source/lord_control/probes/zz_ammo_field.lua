-- is model +0x110 (int) each man's own ammo? its sum over the regiment against unit:ammo_left()
local IDX = 4
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = bm:get_player_army():units():item(IDX)
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local n, models = mr.read_int32(obj, 0xa4), mr.read_pointer(obj, 0xa8)
	local out = {}
	for _, off in ipairs({0x110, 0x10c, 0x114, 0x26c, 0x318}) do
		local sum, hist = 0, {}
		for k = 0, n - 1 do
			local x = mr.read_int32(mr.read_pointer(models, k * 8), off)
			sum = sum + x
			hist[x] = (hist[x] or 0) + 1
		end
		local h = {}
		for val, c in pairs(hist) do h[#h + 1] = val .. "x" .. c end
		out[#out + 1] = off .. ": sum " .. sum .. " values " .. table.concat(h, ",")
	end
	return {ammo = u:ammo_left(), men = n, fields = table.concat(out, " | ")}
end)
if ok then return res end
return "ERR " .. tostring(res)
