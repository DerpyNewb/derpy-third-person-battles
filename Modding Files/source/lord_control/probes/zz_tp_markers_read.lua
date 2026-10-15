-- Reads back zz_tp_markers.lua. No string library calls.
local T = _G.TP_MARKERS
if not T then return "no probe ran" end
return "ended " .. tostring(T.ended) .. " error " .. tostring(T.error) .. " | " .. T.log
