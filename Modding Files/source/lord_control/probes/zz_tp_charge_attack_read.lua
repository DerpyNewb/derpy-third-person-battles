local T = _G.TP_CHARGE_ATTACK
if not T then return "not run" end
return "ended " .. tostring(T.ended) .. " err " .. tostring(T.err) .. " has " .. T.has .. T.log
