local E = _G.DERPY_TP
if not E then return "no DERPY_TP" end
local F = E.F
local u = F.unit
local out = "on " .. tostring(F.on) .. " rec " .. tostring(_G.REC ~= nil)
if _G.REC and REC.pull then out = out .. " pulls " .. tostring(#REC.pull) end
if u then out = out .. " unit " .. u:type() .. " bearing " .. tostring(u:bearing()) .. " men " .. tostring(u:number_of_men_alive()) .. " melee " .. tostring(u:is_in_melee()) end
out = out .. " t " .. tostring(bm:time_elapsed_ms())
return out
