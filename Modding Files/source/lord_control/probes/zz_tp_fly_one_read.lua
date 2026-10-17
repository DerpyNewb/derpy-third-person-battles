-- Read zz_tp_fly_one.lua's result. No string library calls.
local T = _G.TP_FO
if not T then return "not run" end
return {done = T.done, why = T.why, err = T.err, type = T.type, one_man = T.one_man, at = T.at, log = T.log}
