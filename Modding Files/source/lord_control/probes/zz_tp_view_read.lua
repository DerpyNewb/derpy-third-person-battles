local T = _G.TP_VIEW
if not T then return "no probe ran" end
return "ended " .. tostring(T.ended) .. " dragging " .. tostring(T.dragging) .. " cinematic " .. tostring(T.cin)
