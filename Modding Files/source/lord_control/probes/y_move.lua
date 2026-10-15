-- Walk the general 20 m sideways (x + 20) so position candidates can be watched moving.
local ok, res = pcall(function()
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	local q = lord:position()
	local uc = create_unitcontroller(lord)
	uc:goto_location(v(q:get_x() + 20, q:get_y(), q:get_z()), false)
	uc:release_control()
	return "moving"
end)
if ok then return res end
return "ERR " .. tostring(res)
