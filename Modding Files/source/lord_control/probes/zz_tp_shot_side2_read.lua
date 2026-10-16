-- Reads back zz_tp_shot_side2.lua. No string library calls.
local T = _G.TP_SHOT_SIDE2
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" error " .. T.err) or "")
for i, s in ipairs(T.shots) do out = out .. " | shot " .. i .. " pair " .. tostring(s.pair) .. " pitch " .. tostring(s.pitch) end
for _, f in ipairs(T.frames) do out = out .. " | " .. f end
return out
