-- the recorder's events and pull-ins only, no samples. No string library calls.
local REC = _G.TP_REC
if not REC then return "not recording" end
local out = {"samples " .. REC.n .. " err " .. tostring(REC.err) .. " events " .. #REC.ev .. " lifts " .. tostring(REC.lifts) .. " heads " .. tostring(REC.heads)}
for _, e in ipairs(REC.ev) do out[#out + 1] = e end
for _, e in ipairs(REC.pull or {}) do out[#out + 1] = e end
return out
