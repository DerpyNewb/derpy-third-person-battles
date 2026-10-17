-- Read zz_tp_zoomfp.lua's result. No string library calls.
local T = _G.TP_ZF
if not T then return "not run" end
return {done = T.done, why = T.why, err = T.err, type = T.type, strikes = T.strikes, at = T.at, log = T.log}
