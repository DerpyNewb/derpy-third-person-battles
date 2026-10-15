local T = _G.TP_LOWER
if not T then return "no probe ran" end
return "ended " .. tostring(T.ended) .. " err " .. tostring(T.err) .. " || has: " .. T.has .. " ||" .. T.log
