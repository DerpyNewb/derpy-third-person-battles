local T = _G.TP_UNCLIP
if not T then return "no probe ran" end
return "ended " .. tostring(T.ended) .. " err " .. tostring(T.err) .. T.log
