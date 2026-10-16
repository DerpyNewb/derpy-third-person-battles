-- Reads back zz_tp_aim_seq.lua. No string library calls.
local T = _G.TP_AIM_SEQ
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" error " .. T.err) or "") .. " sent"
for _, s in ipairs(T.sent) do out = out .. " " .. s end
out = out .. " | clips"
for _, f in ipairs(T.frames) do out = out .. " " .. f end
return out
