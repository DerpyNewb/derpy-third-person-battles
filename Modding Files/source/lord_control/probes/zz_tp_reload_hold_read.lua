-- Read zz_tp_reload_hold.lua's result. No string library calls.
local T = _G.TP_RH
if not T then return "not run" end
return {done = T.done, err = T.err, type = T.type, reload = T.reload, factor = T.factor, reload_slot = T.reload_slot,
	shots = T.shots, readys = T.readys}
