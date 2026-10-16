-- Reads zz_tp_cam_lift.lua's samples. No string library calls.
local L = _G.TP_CAMLIFT
if not L then return "not sampled" end
local out = "err " .. tostring(L.err)
for _, r in ipairs(L.rows) do out = out .. " || " .. r end
return out
