-- Read zz_tp_shot_frames.lua's result. No string library calls.
local T = _G.TP_SF
if not T then return "not run" end
return {done = T.done, err = T.err, type = T.type, seq = T.seq, sent = T.sent, frames = T.frames, gap_frames = T.gap_frames}
