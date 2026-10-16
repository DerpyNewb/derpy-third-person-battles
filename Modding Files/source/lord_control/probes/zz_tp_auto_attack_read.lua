local T = _G.TP_AA
if not T then return "not run" end
local result = {done = T.done, error = T.err, i = T.i, units = {}}
for _, r in ipairs(T.units) do
	result.units[#result.units + 1] = {type = r.type, phase = r.phase, one_man = r.one_man, checks = r.checks, by = r.by,
		stops = r.stops, cmds = r.cmds, starts = r.starts, stop_slots = r.stop_slots}
end
return result
