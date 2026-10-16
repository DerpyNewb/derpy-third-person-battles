-- 2026-10-15 swing facing: third person on the selected unit; the played man's address for tp_cmd_trace.py
local E = _G.DERPY_TP
if not E then return "no DERPY_TP" end
if not E.F.on then E.main.start() end
local F = E.F
if not F.on then return "did not start" end
return "model " .. (F.model and memreader_plus.tostring(F.model) or "none") .. " bearing " .. tostring(F.unit:bearing()) .. " yaw " .. tostring(math.deg(E.rig.yaw)) .. " unit " .. F.unit:type()
