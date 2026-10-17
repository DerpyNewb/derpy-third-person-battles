-- Read zz_tp_manual.lua's result. No string library calls.
local T = _G.TP_MV
if not T then return "not run" end
return {type = T.type, mode = T.mode, done = T.done, err = T.err, clicked = T.clicked, samples = T.samples}
