-- Read zz_tp_fly_gate.lua's result. No string library calls.
local T = _G.TP_FG
if not T then return "not run" end
return {done = T.done, why = T.why, err = T.err, at = T.at, log = T.log}
