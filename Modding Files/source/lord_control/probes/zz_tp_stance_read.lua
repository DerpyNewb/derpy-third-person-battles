local T = _G.TP_STANCE
if not T then return "no probe ran" end
return "ended " .. tostring(T.ended) .. " raised at 9.9 s " .. tostring(T.raised) .. " err " .. tostring(T.err) .. T.log
