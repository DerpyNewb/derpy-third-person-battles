-- zz_tp_walk_scalar.lua's result: one line per case
local T = _G.TP_WS
if not T then return "not run" end
local out = {(T.done and "done" or "running") .. " (" .. tostring(T.why) .. ") " .. tostring(T.lane) .. (T.err and (" ERR " .. T.err) or "")}
for _, r in ipairs(T.cases) do
	out[#out + 1] = tostring(r.type) .. " walk/run " .. tostring(r.slow) .. "/" .. tostring(r.fast) .. ": "
		.. (r.run and "run" or "walk") .. " x" .. tostring(r.s or "none") .. " -> " .. tostring(r.speed) .. " m/s"
		.. (r.melee and " IN MELEE" or "")
end
return out
