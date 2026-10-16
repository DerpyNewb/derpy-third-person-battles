-- The address of the man third person is playing, for tp_cmd_trace.py (2026-10-16: "battalion actions also affect the
-- unit which shouldnt be"). Read only. No string library calls.
local E = _G.DERPY_TP
if not (E and E.F and E.F.on and E.F.model) then return "ERR third person on one man first" end
return "model " .. memreader_plus.tostring(E.F.model) .. " utype " .. tostring(E.F.utype) .. " ms " .. bm:time_elapsed_ms()
