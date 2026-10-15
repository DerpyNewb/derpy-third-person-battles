local T = _G.TP_AFTER
if not T then return "no probe ran" end
return "ended " .. tostring(T.ended) .. " err " .. tostring(T.err) .. " solo " .. tostring(T.solo) .. " || has: " .. T.has .. " || slots: " .. T.log
