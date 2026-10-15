local ok, res = pcall(function()
	local t = {}
	for k in pairs(_G.memreader_plus) do t[#t + 1] = k end
	table.sort(t)
	return table.concat(t, " ")
end)
if ok then return res end
return "ERR " .. tostring(res)
