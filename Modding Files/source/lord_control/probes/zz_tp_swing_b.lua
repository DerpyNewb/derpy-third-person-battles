-- 2026-10-15 swing facing: camera 90 deg right of the regiment, one swing, the man's facing sampled each frame for 4 s
local E = _G.DERPY_TP
local F, P = E.F, E.P
if not (F.on and F.model) then return "not on one man" end
local mr = memreader_plus
local b = F.unit:bearing()
E.rig.yaw = math.rad(b + 90)
local want = math.floor(((b + 90) % 360) * 65536 / 360)
_G.TPSW = {b = b, want = want, rows = {}}
local t0 = bm:time_elapsed_ms()
local n = 0
bm:repeat_real_callback(function()
	n = n + 1
	local m = F.model
	if n > 240 or not m then bm:remove_real_callback("tpsw") return end
	local r = TPSW.rows
	r[#r + 1] = (bm:time_elapsed_ms() - t0) .. " face " .. mr.read_uint16(m, 0xb0) .. " slot " .. tostring(P.anim_slot(m)) .. " lock " .. tostring(F.lock ~= nil) .. " x " .. math.floor(mr.read_float(m, 0x88) * 100) / 100 .. " z " .. math.floor(mr.read_float(m, 0x90) * 100) / 100 .. " ub " .. math.floor(F.unit:bearing())
end, 16, "tpsw")
E.combat.melee(bm:time_elapsed_ms() / 1000, true)
return "swung: bearing " .. b .. " want face " .. want .. " lock " .. tostring(F.lock ~= nil) .. " slot " .. tostring(F.lock and F.lock.slot)
