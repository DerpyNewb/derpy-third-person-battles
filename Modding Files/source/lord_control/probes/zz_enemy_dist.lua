local ok, res = pcall(function()
	local F = _G.DERPY_FOLLOW
	local q = F.unit:position()
	local fx, fz = math.sin(F.cyaw), math.cos(F.cyaw)
	local best, n = nil, 0
	local armies = bm:get_non_player_alliance():armies()
	for a = 1, armies:count() do
		local list = armies:item(a):units()
		for i = 1, list:count() do
			local e = list:item(i)
			n = n + 1
			local p = e:position()
			local dx, dz = p:get_x() - q:get_x(), p:get_z() - q:get_z()
			local d = math.sqrt(dx * dx + dz * dz)
			if not best or d < best[1] then best = {d, (dx * fx + dz * fz) / d, e:is_valid_target()} end
		end
	end
	return {enemy_units = n, nearest_m = best and best[1], cos_to_aim = best and best[2], valid = best and best[3]}
end)
if ok then return res end
return "ERR " .. tostring(res)
