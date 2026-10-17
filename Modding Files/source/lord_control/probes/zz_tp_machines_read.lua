-- Read zz_tp_machines.lua's result, one unit at a time from _G.TP_MC_FROM (default 1). No string library calls.
local T = _G.TP_MC
if not T then return "not run" end
local out = {done = T.done, why = T.why, err = T.err, count = #T.units, units = {}}
local from = _G.TP_MC_FROM or 1
for i = from, math.min(#T.units, from + 2) do
	local r, c = T.units[i], {}
	for k, x in pairs(r) do if k ~= "u" then c[k] = x end end
	out.units[#out.units + 1] = c
end
return out
