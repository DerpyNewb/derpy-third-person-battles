-- memreader pass 1: battle state, memreader version, and the raw pointers behind the camera and
-- the general's script interfaces. Two bm:camera() calls show whether each call wraps a new object.
local ok, res = pcall(function()
	local r = {battle = core:is_battle()}
	r.memreader = _G.memreader_plus and _G.memreader_plus.plus_version or false
	if not r.battle then return r end
	local mr = _G.memreader_plus
	r.phase = bm:get_current_phase_name()
	r.multiplayer = bm:is_multiplayer()
	local cam = bm:camera()
	local p, t = cam:position(), cam:target()
	r.cam = {p:get_x(), p:get_y(), p:get_z(), t:get_x(), t:get_y(), t:get_z()}
	if mr then
		local c1, c2 = mr.ud_topointer(cam), mr.ud_topointer(bm:camera())
		r.cam_iface = {mr.tostring(c1), mr.tostring(c2), mr.tostring(mr.read_pointer(c1, 0x10)), mr.tostring(mr.read_pointer(c2, 0x10))}
	end
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		local u = units:item(i)
		if u:is_commanding_unit() then
			local q = u:position()
			r.lord = {u:name(), q:get_x(), q:get_y(), q:get_z(), u:bearing(), u:number_of_men_alive()}
			if mr then
				local a = mr.ud_topointer(u)
				r.lord_iface = {mr.tostring(a), mr.tostring(mr.read_pointer(a, 0x10))}
			end
		end
	end
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
