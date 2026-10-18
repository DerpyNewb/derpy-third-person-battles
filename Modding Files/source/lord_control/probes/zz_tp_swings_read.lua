-- zz_tp_swings.lua's result: attack clips started per click, and the timeline
local T = _G.TP_SW
if not T then return "not run" end
local per = {}
for _, s in ipairs(T.starts) do if s[3] > 0 then per[s[3]] = (per[s[3]] or 0) + 1 end end
local counts = ""
for i = 1, #T.clicks do counts = counts .. (per[i] or 0) .. " " end
local starts = ""
for _, s in ipairs(T.starts) do starts = starts .. s[1] .. ":" .. s[2] .. (s[4] and "r" or "") .. "#" .. s[3] .. " " end
local sent = ""
for _, s in ipairs(T.sent) do sent = sent .. s[1] .. ":" .. s[2] .. " " end
local clicks = ""
for _, c in ipairs(T.clicks) do clicks = clicks .. c .. " " end
return (T.done and "done" or "running") .. " (" .. tostring(T.why) .. ")" .. (T.err and (" ERR " .. T.err) or "")
	.. " | horse " .. tostring(T.horse) .. ", in melee " .. tostring(T.in_melee) .. ", engine swings with no click " .. T.quiet
	.. " | attack clips started per click: " .. counts .. "| clicks " .. clicks .. "| started " .. starts .. "| sent " .. sent
