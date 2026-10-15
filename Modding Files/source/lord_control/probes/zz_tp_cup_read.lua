-- Reads back zz_tp_cup.lua. No string library calls.
local T = _G.TP_CUP
if not T then return "no probe ran" end
return "ended " .. tostring(T.ended) .. " error " .. tostring(T.error) .. " | " .. T.log
