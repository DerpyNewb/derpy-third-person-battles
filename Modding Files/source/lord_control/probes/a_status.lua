-- Status: are we in a battle, which phase, is memreader here, where are the camera and the general.
local ok, res = pcall(function()
	local r = {battle = core:is_battle()}
	if not r.battle then return r end
	r.phase = bm:get_current_phase_name()
	r.multiplayer = bm:is_multiplayer()
	r.memreader = _G.memreader_plus and _G.memreader_plus.plus_version or false
	local cam = bm:camera()
	local p, t = cam:position(), cam:target()
	r.cam = {p:get_x(), p:get_y(), p:get_z(), t:get_x(), t:get_y(), t:get_z()}
	local units = bm:get_player_army():units()
	r.units = units:count()
	for i = 1, units:count() do
		local u = units:item(i)
		if u:is_commanding_unit() then
			local q = u:position()
			r.lord = {u:name(), q:get_x(), q:get_y(), q:get_z(), u:number_of_men_alive()}
		end
	end
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
