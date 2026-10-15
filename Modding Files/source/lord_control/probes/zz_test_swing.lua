-- Fire one left-click swing from the bridge and screenshot at 0.5 / 0.9 / 1.3 / 1.8 s.
local ok, res = pcall(function()
	local F = _G.DERPY_FOLLOW
	F.attack_fn(true, false)
	local shots = {500, 900, 1300, 1800}
	for k = 1, #shots do
		bm:real_callback(function() common.take_screenshot("derpy_swing_" .. k .. ".tga") end, shots[k], "derpy_sw_" .. k)
	end
	return "swing queued"
end)
if ok then return res end
return "ERR " .. tostring(res)
