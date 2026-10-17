-- Read zz_tp_zoomsweep.lua's result. No string library calls.
local T = _G.TP_ZS
if not T then return "not run" end
return {done = T.done, why = T.why, err = T.err, type = T.type, at = T.at}
