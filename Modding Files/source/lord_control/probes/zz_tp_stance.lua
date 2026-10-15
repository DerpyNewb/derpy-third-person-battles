-- Stance after a shot, 2026-10-14: third person on the Iron Hail Gunners; forward 1-3 s from the plain stance,
-- one shot at 3.5 s, F.raised cleared at 9.9 s (no lowering clip) and forward 10-12.5 s from the shooting
-- stance, off at 13 s. Our own E.move.drive is wrapped to press forward; nothing of the game's is patched.
-- Logs the clip slot, model+0x310..0x32c and the command type at +0x330 on each change, with his position.
-- No string library calls. Read back: zz_tp_stance_read.lua.
local E = _G.DERPY_TP
if not (E and E.main) then return "load the bridge first" end
if E.F.on then return "switch third person off first" end
local mr = memreader_plus
local GUN = "wh3_main_cth_inf_iron_hail_gunners_0"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GUN then u = units:item(i) end end
if not u then return "no gunners" end
local T = {log = "", walk = false}
_G.TP_STANCE = T
local drive = E.move.drive
T.drive = drive
E.move.drive = function(now, kf, kr, run) if T.walk then kf = 1 end return drive(now, kf, kr, run) end
local t0, last = os.clock(), ""
bm:repeat_real_callback(function()
	local t = os.clock() - t0
	local ok, err = pcall(function()
		if not T.started then T.started = true E.main.start(u) E.F.ranged = true end
		T.walk = (t > 1 and t < 3) or (t > 10 and t < 12.5)
		if t > 3.5 and not T.fired then T.fired = true E.F.want_shot = true end
		if t > 9.9 and not T.cleared then T.cleared = true T.raised = tostring(E.F.raised) E.F.raised = false end
		local m = E.F.model
		if not m then return end
		local s = "slot " .. tostring(E.P.anim_slot(m)) .. " cmd " .. mr.tostring(mr.read_pointer(m, 0x330)) .. " st"
		for o = 0x310, 0x32c, 4 do s = s .. " " .. mr.read_uint32(m, o) end
		if s ~= last then
			local x, _, z = E.P.model_pos(m)
			T.log = T.log .. " || " .. math.floor(t * 100) / 100 .. "s " .. (T.walk and "W " or "") .. s .. " at " .. math.floor(x * 10) / 10 .. "," .. math.floor(z * 10) / 10
			last = s
		end
	end)
	if not ok then T.err = tostring(err) end
	if t > 13 or not ok then
		bm:remove_real_callback("tp_stance")
		E.move.drive = drive
		pcall(E.main.stop, "stance probe")
		T.ended = true
	end
end, 50, "tp_stance")
return "started"
