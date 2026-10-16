-- Reads back zz_tp_charge_watch.lua. No string library calls.
local T = _G.TP_CW
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" ERROR " .. T.err) or "") .. " frames " .. T.frames .. " sends " .. T.runs
for _, e in ipairs(T.events) do out = out .. " | " .. e end
return out
