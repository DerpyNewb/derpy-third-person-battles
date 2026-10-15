-- reads back zz_tp_ui_tree.lua as one string, sections split by " | ", lines by " ; ". Never throws.
local ok, res = pcall(function()
	local T = _G.TP_UI_TREE
	if not T then return "no survey has run" end
	local roots = {}
	for id, n in pairs(T.roots) do roots[#roots + 1] = n .. " " .. id end
	table.sort(roots)
	return "ended " .. tostring(T.ended) .. " samples " .. tostring(T.samples) .. " error " .. tostring(T.error)
		.. " | " .. table.concat(T.porthole, " ; ") .. " | " .. table.concat(roots, " ; ")
end)
return tostring(ok) .. " " .. tostring(res)
