-- Reads back zz_tp_guard.lua. No string library calls.
local T = _G.TP_GUARD
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" error " .. T.err) or "") .. " ticks " .. T.ticks
	.. " | most stops in one second " .. T.peak .. " | stops:"
for k, n in pairs(T.stops) do out = out .. " " .. k .. " x" .. n end
for _, e in ipairs(T.events) do out = out .. " ### " .. e end
return out
