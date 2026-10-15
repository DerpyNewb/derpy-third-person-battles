-- reads back TP_F2_DRIFT (zz_tp_f2_drift.lua) as compact lines; summarise with tp_f2_drift.py
local T = _G.TP_F2_DRIFT
if not T then return "ERR no drift test has run" end
local function f(n) return n and string.format("%.3f", n) or "" end
local out = {}
for i, s in ipairs(T.samples) do
	out[i] = table.concat({s.t, s.s, f(s.x), f(s.z), f(s.nx), f(s.nz), f(s.ux), f(s.uz), s.cmd, f(s.px), f(s.pz), s.hold or "", tostring(s.on), f(s.yaw)}, "|")
end
return {unit = T.unit, ended = T.ended == true, strikes = T.strikes, error = T.error, log = T.log, rows = out}
