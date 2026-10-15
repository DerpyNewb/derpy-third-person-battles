local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local feats = {}
	for k, val in pairs(P.features) do feats[#feats + 1] = k .. "=" .. tostring(val) end
	return {features = table.concat(feats, " "), problems = table.concat(P.problems, "; "), source = P.source,
		on = F.on, unit = F.utype, one_man = F.model ~= nil, solo = F.solo, men_ok = F.men_ok, ranged = F.ranged,
		frames = F.frames, strikes = E.strikes, disabled = E.disabled}
end)
if ok then return res end
return "ERR " .. tostring(res)
