-- Hypothesis test v6, 2026-10-14 (traces in tp_cmd_trace.py): a finished walk keeps him moving until something
-- replaces the command, and while F2 holds him nothing does. The engine's own stop is exe+3069d7c(model): it
-- destroys the command and builds 390cba8, "stand in state +0x318" (what uc:halt leaves on each man).
-- Wraps E.P.steer (the true original stays in TP_STEER_ORIG): keys held -> the original; holding still -> the two
-- slot copies take the hold point, a running walk (walk_a or walk_b) gets the native stop, then only his facing.
-- zz_tp_steer_restore.lua puts the original back. Top level never throws.
local E = _G.DERPY_TP
if not (E and E.P) then return "ERR load the bridge first" end
_G.TP_STEER_ORIG = _G.TP_STEER_ORIG or E.P.steer
local orig, mr = _G.TP_STEER_ORIG, memreader_plus
local stop = mr.add(mr.add(mr.base, 0x306 * 0x10000), 0x9d7c) -- exact halves: Lua numbers are float32
local WALKS = {["0000000143ADD278"] = true, ["0000000143912B98"] = true}
_G.TP_V6 = {stops = 0}
E.P.steer = function(m, x, z, run, yaw)
	local mx, _, mz = E.P.model_pos(m)
	if (x - mx) ^ 2 + (z - mz) ^ 2 > 0.25 then return orig(m, x, z, run, yaw) end
	for _, f in ipairs({{0x1e0, 0x1e8}, {0x194, 0x198}}) do mr.write(m, f[1], x) mr.write(m, f[2], z) end
	if WALKS[mr.tostring(mr.read_pointer(m, 0x330))] then
		mr.call(stop, "pointer(pointer)", m)
		TP_V6.stops = TP_V6.stops + 1
	end
	E.P.face(m, yaw)
end
return {installed = "v6", stop = mr.tostring(stop)}
