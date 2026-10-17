-- Read zz_tp_fp.lua's result. No string library calls.
local T = _G.TP_FP
if not T then return "not run" end
return {done = T.done, why = T.why, err = T.err, type = T.type, first_on = T.first_on, first_after = T.first_after,
	eye_y_above_man = T.eye_y_above_man, yaw_turned = T.yaw_turned, strikes = T.strikes, smooth = T.smooth, w = T.w, log = T.log}
