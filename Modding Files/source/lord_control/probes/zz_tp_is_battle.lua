-- Is a battle loaded, and which phase. No string library calls.
if not bm then return "no battle" end
local E = _G.DERPY_TP
return "battle; model ms " .. bm:time_elapsed_ms() .. "; pack " .. tostring(E ~= nil) .. " disabled " .. tostring(E and E.disabled) .. " build " .. tostring(E and E.P and E.P.build)
