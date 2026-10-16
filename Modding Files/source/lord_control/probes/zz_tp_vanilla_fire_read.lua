-- Reads back zz_tp_vanilla_fire.lua. No string library calls.
local T = _G.TP_VANILLA_FIRE
if not T then return "not run" end
local out = "done " .. tostring(T.done) .. (T.err and (" error " .. T.err) or "")
for i, r in ipairs(T.men) do out = out .. " | man " .. i .. ":" .. r.log end
return out
