-- which 8-byte fields of a model object split a regiment into a big majority and 1-4 odd ones out
-- (officers: captain, standard bearer, musician would be the odd ones)
local IDX, SPAN = 4, 0x700
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u = bm:get_player_army():units():item(IDX)
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local n = mr.read_int32(obj, 0xa4)
	local models = mr.read_pointer(obj, 0xa8)
	local ms = {}
	for k = 0, n - 1 do ms[k] = mr.read_pointer(models, k * 8) end
	local out = {}
	for off = 0, SPAN - 8, 8 do
		local count, who = {}, {}
		for k = 0, n - 1 do
			local key = mr.tostring(mr.read_pointer(ms[k], off))
			count[key] = (count[key] or 0) + 1
			who[key] = who[key] or {}
			if #who[key] < 5 then who[key][#who[key] + 1] = k end
		end
		local distinct, top = 0, 0
		for key, c in pairs(count) do distinct = distinct + 1 if c > top then top = c end end
		if top >= n - 4 and top < n then
			local odd = {}
			for key, c in pairs(count) do if c < top then odd[#odd + 1] = key .. "=" .. table.concat(who[key], ",") end end
			out[#out + 1] = off .. " [" .. table.concat(odd, " ") .. "]"
		end
	end
	return {n = n, splits = table.concat(out, " | ")}
end)
if ok then return res end
return "ERR " .. tostring(res)
