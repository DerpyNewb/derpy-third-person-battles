-- Read zz_tp_takeover.lua's result. No string library calls.
local T = _G.TP_TO
if not T then return "not run" end
return {done = T.done, why = T.why, err = T.err, type = T.type, ids = T.ids, take1 = T.take1, take2 = T.take2,
	casts = T.casts, hud_cmd = T.hud_cmd, tl = T.tl, log = T.log}
