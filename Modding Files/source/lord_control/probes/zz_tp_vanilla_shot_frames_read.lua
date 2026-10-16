-- Reads back zz_tp_vanilla_shot_frames.lua. No string library calls.
local T = _G.TP_VANILLA_FRAMES
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" error " .. T.err) or "") .. " |"
for _, f in ipairs(T.frames) do out = out .. " " .. f end
return out
