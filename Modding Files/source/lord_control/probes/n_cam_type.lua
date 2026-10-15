-- Camera type preference: read it, set 4 (arena), read back. Restore with o_cam_type_restore.lua.
local ok, res = pcall(function()
	local r = {before = core:get_integer_preference("default_battle_camera_type")}
	core:set_integer_preference("default_battle_camera_type", 4)
	r.after = core:get_integer_preference("default_battle_camera_type")
	local p = bm:camera():position()
	r.cam = {p:get_x(), p:get_y(), p:get_z()}
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
