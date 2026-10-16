-- Read zz_tp_run_speed.lua's result. No string library calls.
local T = _G.TP_RS
if not T then return "not run" end
local ph = {}
for _, R in ipairs(T.phases) do
	ph[#ph + 1] = {name = R.name, mps = R.mps, moved = R.moved, cmds = R.cmds, clips = R.clips, flags = R.flags, speeds = R.speeds,
		sprinting = R.sprinting, running = R.running}
end
return {done = T.done, err = T.err, type = T.type, lead = T.lead, native_horse = T.native_horse, native_rider = T.native_rider, phases = ph}
