-- Reads back zz_tp_charge_run.lua's rounds. No string library calls.
local T = _G.TP_CHARGE_RUN
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" error " .. T.err) or "")
for i, r in ipairs(T.rounds) do
	out = out .. " ### round " .. i .. " mask " .. tostring(r.mask) .. " sent " .. tostring(r.sent) .. ":" .. r.log
end
return out
