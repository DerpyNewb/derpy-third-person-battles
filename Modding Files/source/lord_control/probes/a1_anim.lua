-- Does unit:play_anim_for_captain play an attack on command? Plays ANIM on the controlled unit and
-- screenshots at 0.1, 0.3, 0.55 and 0.85 s.
local ANIM = "ATTACK_1"
local ok, res = pcall(function()
	local F = _G.DERPY_FOLLOW
	local u = F.unit
	u:play_anim_for_captain(ANIM, false)
	local shots = {100, 300, 550, 850}
	for k = 1, #shots do
		bm:real_callback(function() common.take_screenshot("derpy_anim_" .. k .. ".tga") end, shots[k], "derpy_anim_shot_" .. k)
	end
	return "played " .. ANIM .. " on " .. u:name()
end)
if ok then return res end
return "ERR " .. tostring(res)
