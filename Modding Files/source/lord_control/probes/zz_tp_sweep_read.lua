-- Reads back zz_tp_sweep.lua. No string library calls.
local T = _G.TP_SWEEP
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" ERROR " .. T.err) or "") .. " base " .. T.base
for _, R in ipairs(T.units) do
	out = out .. " ##### " .. R.type .. (R.err and (" ERR " .. R.err) or "") .. " | " .. tostring(R.kind) .. " | enemy "
		.. tostring(R.enemy) .. " " .. tostring(R.dist0) .. " m | swings:"
	for _, sw in ipairs(R.swings) do
		out = out .. " [" .. sw.t .. "s guard " .. tostring(sw.guard) .. " melee " .. tostring(sw.melee) .. " lock " .. tostring(sw.lock)
			.. " slot " .. tostring(sw.slot) .. " seen " .. tostring(sw.seen) .. " after " .. tostring(sw.first) .. "]"
	end
	out = out .. " | commands:"
	for k, e in pairs(R.cmds) do out = out .. " " .. k .. " x" .. e.n .. " {" .. e.list .. "}" end
	out = out .. " | events:"
	for _, e in ipairs(R.events) do out = out .. " # " .. e end
end
return out
