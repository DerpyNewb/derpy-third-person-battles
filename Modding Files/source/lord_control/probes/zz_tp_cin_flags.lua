-- Does the engine's cinematic switch bring the unit flags back? Flags off now; cinematic on at 0.8 s; both put
-- back at 2.2 s. Paired with screenshots. No string library calls.
bm.battle:set_banners_enabled(false)
local t0, done1 = os.clock(), false
bm:repeat_real_callback(function()
	local t = os.clock() - t0
	if t > 0.8 and not done1 then done1 = true bm:enable_cinematic_ui(true, false, false) end
	if t > 2.2 then
		bm:remove_real_callback("tp_cinflags")
		bm:enable_cinematic_ui(false, true, false)
		bm.battle:set_banners_enabled(true)
	end
end, 20, "tp_cinflags")
return "started"
