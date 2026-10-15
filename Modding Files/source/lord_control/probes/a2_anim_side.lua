-- Side-on test of unit:play_anim_for_captain: pause the follow camera, halt the unit, frame it from
-- 5 m to its side, screenshot before (shot 0) and after the animation starts (shots 1-3).
local ANIM = "ATTACK_1"
local ok, res = pcall(function()
	local F = _G.DERPY_FOLLOW
	bm:remove_real_callback("derpy_follow")
	local u = F.unit
	F.uc:halt()
	F.uc:release_control()
	local q = u:position()
	local b = math.rad(u:bearing())
	local fx, fz = math.sin(b), math.cos(b)
	local rx, rz = fz, -fx
	bm:camera():move_to(v(q:get_x() + rx * 5, q:get_y() + 2, q:get_z() + rz * 5), v(q:get_x(), q:get_y() + 1.2, q:get_z()), 0, false, -1, false)
	bm:real_callback(function() common.take_screenshot("derpy_anim_0.tga") end, 250, "derpy_anim_shot_0")
	bm:real_callback(function() u:play_anim_for_captain(ANIM, false) end, 400, "derpy_anim_play")
	local shots = {650, 900, 1250}
	for k = 1, #shots do
		bm:real_callback(function() common.take_screenshot("derpy_anim_" .. k .. ".tga") end, shots[k], "derpy_anim_shot_" .. k)
	end
	return "framed; playing " .. ANIM
end)
if ok then return res end
return "ERR " .. tostring(res)
