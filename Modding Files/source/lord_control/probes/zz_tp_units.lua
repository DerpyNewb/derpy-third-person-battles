-- Read-only: every unit in both alliances, its men, position, melee and whether it is cavalry. No string library calls.
local ok, res = pcall(function()
	local out = {}
	for side, al in ipairs({bm:get_player_alliance(), bm:get_non_player_alliance()}) do
		local armies = al:armies()
		for a = 1, armies:count() do
			local us = armies:item(a):units()
			for i = 1, us:count() do
				local u = us:item(i)
				local p = u:position()
				out[#out + 1] = (side == 1 and "P " or "E ") .. u:type() .. " men " .. u:number_of_men_alive() .. " at "
					.. math.floor(p:get_x()) .. "," .. math.floor(p:get_z()) .. (u:is_in_melee() and " MELEE" or "")
					.. (u:is_cavalry() and " cav" or "") .. (u:is_routing() and " ROUT" or "") .. (u:is_shattered() and " SHATTERED" or "") .. (u:missile_range() > 0 and (" range " .. u:missile_range()) or "")
			end
		end
	end
	return out
end)
return ok and res or "ERR " .. tostring(res)
