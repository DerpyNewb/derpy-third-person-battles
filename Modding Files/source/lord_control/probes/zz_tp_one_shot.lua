-- One shot through the pack's own code, as a left click (2026-10-16, for screenshots of the Streltsi's "aim high -> shoot
-- level"). Third person on one ranged man, the battle running; the crosshair stays where the camera is. Returns the
-- model time it was sent at; the shot log (MCT debug log) has its clips. No string library calls.
local E = _G.DERPY_TP
if not (E and E.F and E.F.on and E.F.model and E.F.ranged) then return "third person on one ranged man first" end
if E.F.shot or E.F.lock then return "a shot or an action is under way" end
local now = bm:time_elapsed_ms() / 1000
local ok, err = pcall(E.combat.attack, now, true, false)
return "sent at " .. now .. " " .. tostring(E.F.utype) .. (ok and "" or (" error " .. tostring(err)))
