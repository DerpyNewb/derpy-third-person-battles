-- Read zz_tp_arty_walk.lua's result. No string library calls.
local T = _G.TP_AW
if not T then return "not run" end
return {type = T.type, mode = T.mode, bearing = T.bearing, done = T.done, err = T.err, at = T.at, log = T.log}
