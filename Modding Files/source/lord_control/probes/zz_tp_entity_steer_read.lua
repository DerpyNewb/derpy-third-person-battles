-- zz_tp_entity_steer.lua's result: one line per case
local T = _G.TP_ES
if not T then return "not run" end
local out = {(T.done and "done" or "running") .. " (" .. tostring(T.why) .. ") " .. tostring(T.lane) .. (T.err and (" ERR " .. T.err) or "")}
for _, r in ipairs(T.cases) do
	out[#out + 1] = tostring(r.type) .. " run " .. tostring(r.fast) .. (r.flying and " flying" or "") .. ": lead " .. r.lead
		.. " m x" .. r.scale .. " -> " .. tostring(r.speed) .. " m/s, command speed " .. tostring(r.cmd_speed)
		.. (r.flying_after ~= r.flying and " (flying changed)" or "")
end
return out
