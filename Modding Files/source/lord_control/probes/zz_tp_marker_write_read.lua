local T = _G.TP_MCHAIN
if not T then return "no probe ran" end
return "ended " .. tostring(T.ended) .. " | " .. T.log
