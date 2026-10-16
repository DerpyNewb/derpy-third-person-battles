-- Reads back zz_tp_clip_side.lua. No string library calls.
local T = _G.TP_CLIP_SIDE
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" error " .. T.err) or "") .. " raised " .. tostring(T.raised)
	.. " fired " .. tostring(T.fired)
for _, f in ipairs(T.frames) do out = out .. " | " .. f end
return out
