local ok, res = pcall(function()
	local r = {battle = core:is_battle(), pref = core:get_integer_preference("default_battle_camera_type")}
	if r.battle then
		r.phase = bm:get_current_phase_name()
		local p, t = bm:camera():position(), bm:camera():target()
		r.cam = {p:get_x(), p:get_y(), p:get_z(), t:get_x(), t:get_y(), t:get_z()}
	end
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
