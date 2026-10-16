-- Set the battle speed to _G.TP_SPEED (1 runs, 0 pauses). No string library calls.
local ok, err = pcall(function() bm:modify_battle_speed(_G.TP_SPEED or 1) end)
return ok and ("speed " .. tostring(_G.TP_SPEED or 1) .. ", model ms " .. bm:time_elapsed_ms()) or "ERR " .. tostring(err)
