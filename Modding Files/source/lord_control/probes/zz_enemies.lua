-- every enemy unit: distance from the crossbowmen (player unit 4), men alive, in melee, bearing to it
local IDX = 4
local ok, res = pcall(function()
	local me = _G.DERPY_TGT.shooter
	local q = me:position()
	local o = {}
	local armies = bm:get_non_player_alliance():armies()
	for a = 1, armies:count() do
		local list = armies:item(a):units()
		for i = 1, list:count() do
			local e = list:item(i)
			local p = e:position()
			local dx, dz = p:get_x() - q:get_x(), p:get_z() - q:get_z()
			o[#o + 1] = {d = math.floor(math.sqrt(dx * dx + dz * dz)), a = a, i = i, men = e:number_of_men_alive(), melee = e:is_in_melee(), brg = math.floor(math.deg(math.atan2(dx, dz)) % 360), name = e:type()}
		end
	end
	table.sort(o, function(x, y) return x.d < y.d end)
	local s = {}
	for k = 1, math.min(#o, 8) do local e = o[k] s[#s + 1] = e.d .. "m " .. e.name .. " men" .. e.men .. (e.melee and " MELEE" or "") .. " brg" .. e.brg .. " [" .. e.a .. "," .. e.i .. "]" end
	return {my_brg = math.floor(me:bearing()), nearest = table.concat(s, " | ")}
end)
if ok then return res end
return "ERR " .. tostring(res)
