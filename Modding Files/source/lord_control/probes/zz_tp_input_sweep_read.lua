local T = _G.TP_INPUT
if not T then return "not run" end
local result = {done = T.done, error = T.err, i = T.i, units = {}}
for _, r in ipairs(T.units) do
	local row = {type = r.type, phase = r.phase, one_man = r.one_man, model = r.model, checks = r.checks,
		clips = r.clips, commands = r.commands, dead_control = r.dead_control, aim_error = r.aim_error,
		pair = r.pair, last_launch = r.last_launch}
	result.units[#result.units + 1] = row
end
return result
