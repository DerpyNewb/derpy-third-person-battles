-- Reads back zz_tp_self_move.lua. No string library calls.
local T = _G.TP_SELF_MOVE
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" error " .. T.err) or "") .. " ticks " .. T.ticks .. " base " .. T.base
	.. " | commands seen:"
for vt, n in pairs(T.vts) do out = out .. " " .. vt .. " x" .. n end
for _, e in ipairs(T.events) do out = out .. " ### " .. e end
return out
