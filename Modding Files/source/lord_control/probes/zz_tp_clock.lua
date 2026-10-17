-- is the battle clock moving, at what speed, and is the pack switched off (test scaffolding)
local ok, r = pcall(function()
	local tp = rawget(_G, "DERPY_TP")
	return {speed = bm:current_battle_speed(), ms = bm:time_elapsed_ms(), phase = bm:get_current_phase_name(),
		disabled = tostring(tp and tp.disabled), strikes = tostring(tp and tp.strikes)}
end)
if ok then return r end
return "ERR " .. tostring(r)
