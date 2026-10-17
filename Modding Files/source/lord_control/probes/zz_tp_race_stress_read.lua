-- zz_tp_race_stress.lua's count
local T = _G.TP_RS
if not T then return "not run" end
return (T.done and "done" or "running") .. ": " .. T.calls .. " script-thread stops in " .. T.ticks .. " ticks, "
	.. (os.time() - T.t0) .. " s" .. (T.err and (" ERR " .. T.err) or "")
