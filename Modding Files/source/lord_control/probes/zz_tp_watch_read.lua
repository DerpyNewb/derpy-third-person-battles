-- Reads back zz_tp_watch.lua. No string library calls.
local T = _G.TP_WATCH
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" error " .. T.err) or "") .. " ticks " .. T.ticks .. " base " .. T.base
	.. " | commands:"
for vt, c in pairs(T.cmds) do
	out = out .. " " .. vt .. " x" .. c.n .. " clips"
	for clip in pairs(c.clips) do out = out .. " " .. clip end
	out = out .. ";"
end
for _, e in ipairs(T.events) do out = out .. " ### " .. e end
return out
