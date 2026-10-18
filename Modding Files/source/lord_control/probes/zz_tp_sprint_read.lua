-- zz_tp_sprint.lua's result: one line per unit
local T = _G.TP_SP
if not T then return "not run" end
local out = {(T.done and "done" or "running") .. " (" .. tostring(T.why) .. ") lane " .. tostring(T.lane) .. (T.err and (" ERR " .. T.err) or "")}
for _, r in ipairs(T.units) do
	out[#out + 1] = tostring(r.type) .. ": steered " .. tostring(r.steered) .. (r.skipped and (" SKIPPED " .. r.skipped) or "")
		.. (r.start_err and (" START ERR " .. r.start_err) or "") .. ", its run " .. tostring(r.fast)
		.. " | run " .. tostring(r.run) .. " m/s, sprint " .. tostring(r.sprint) .. " m/s, x" .. tostring(r.ratio)
		.. " | flying " .. tostring(r.flying) .. ", sprinting " .. tostring(r.sprinting) .. ", charging " .. tostring(r.charging)
		.. ", CHARGE " .. tostring(r.charges) .. ", FLY_CHARGE " .. tostring(r.fly_charges)
		.. ", command speed " .. tostring(r.cmd_speed) .. (r.melee and " IN MELEE" or "")
end
return out
