local ok, res = pcall(function()
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	local q, s = lord:position(), _G.DERPY_O1
	bm:disable_orders(false)
	return {moved = math.sqrt((q:get_x() - s[1]) ^ 2 + (q:get_z() - s[2]) ^ 2)}
end)
if ok then return res end
return "ERR " .. tostring(res)
