-- Does a script unitcontroller order still work while bm:disable_orders(true) blocks the player's?
local ok, res = pcall(function()
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	bm:disable_orders(true)
	local q = lord:position()
	_G.DERPY_O1 = {q:get_x(), q:get_z()}
	local uc = create_unitcontroller(lord)
	uc:goto_location(v(q:get_x() + 8, q:get_y(), q:get_z()), true)
	uc:release_control()
	return "orders disabled, script order sent"
end)
if ok then return res end
return "ERR " .. tostring(res)
