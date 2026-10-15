-- Halt the general and report where he stands (script position) and his bearing.
local ok, res = pcall(function()
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	local uc = create_unitcontroller(lord)
	uc:halt()
	uc:release_control()
	local q = lord:position()
	return {q:get_x(), q:get_y(), q:get_z(), lord:bearing()}
end)
if ok then return res end
return "ERR " .. tostring(res)
