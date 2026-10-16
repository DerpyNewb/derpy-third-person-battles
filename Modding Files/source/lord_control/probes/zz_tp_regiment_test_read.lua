-- Reads back zz_tp_regiment_test.lua. No string library calls.
local T = _G.TP_REG
if not T then return "not run" end
local function r1(n) return n and math.floor(n * 10) / 10 or "nil" end
local out = "done " .. tostring(T.done) .. " (" .. tostring(T.why_end) .. ")" .. (T.err and (" error " .. T.err) or "")
	.. " guard " .. tostring(T.guard) .. " all " .. tostring(T.all) .. " | he moved " .. r1(T.path) .. " m (net " .. r1(T.net) .. "), the regiment "
	.. r1(T.reg) .. " m, ends " .. r1(T.apart) .. " m apart, melee " .. tostring(T.melee) .. " | commands (ticks):"
for k, n in pairs(T.seen) do
	out = out .. " " .. k .. " x" .. n .. " " .. r1(T.metres and T.metres[k]) .. "m clips"
	for _, c in ipairs(T.clips and T.clips[k] or {}) do out = out .. " " .. c end
	out = out .. ";"
end
out = out .. " | stops:"
for k, n in pairs(T.stops) do out = out .. " " .. k .. " x" .. n end
return out .. " | per second:" .. T.log
