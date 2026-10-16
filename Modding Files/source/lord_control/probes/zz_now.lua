-- read-only: battle clock and whether the pack is on. No string library calls.
local E = _G.DERPY_TP
return {ms = bm:time_elapsed_ms(), disabled = E and E.disabled or false, on = E and E.F.on or false}
