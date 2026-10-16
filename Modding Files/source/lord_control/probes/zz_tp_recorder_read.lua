-- Reads zz_tp_recorder.lua's events and its last 60 samples. No string library calls.
local REC = _G.TP_REC
if not REC then return "not recording" end
local out = "samples " .. REC.n .. " err " .. tostring(REC.err) .. " || EVENTS " .. #REC.ev
for _, e in ipairs(REC.ev) do out = out .. " || " .. e end
out = out .. " || LAST"
for k = math.max(1, REC.n - 59), REC.n do out = out .. " || " .. REC.rows[(k - 1) % 400 + 1] end
return out
