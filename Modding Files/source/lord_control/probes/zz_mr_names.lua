-- read-only: the names memreader Plus exports. No string library calls.
local ok, res = pcall(function()
	local out = {}
	for k, v in pairs(_G.memreader_plus) do out[#out + 1] = tostring(k) .. ":" .. type(v) end
	table.sort(out)
	return table.concat(out, " ")
end)
return ok and res or "ERR " .. tostring(res)
