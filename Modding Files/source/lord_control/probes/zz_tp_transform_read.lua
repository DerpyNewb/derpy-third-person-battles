-- Read zz_tp_transform.lua's result. No string library calls.
local T = _G.TP_TF
if not T then return "not run" end
return {done = T.done, err = T.err, mode = T.mode, type = T.type, key = T.key, cast = T.cast, cast_at = T.cast_at, stopped = T.stopped, tl = T.tl}
