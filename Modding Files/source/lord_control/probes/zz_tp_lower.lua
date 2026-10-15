-- Lowering after a shot, 2026-10-14: third person on the Iron Hail Gunners, one shot (F.want_shot), and at 5.5 s
-- (the engine in its SHOOT_STAND idles by then) SHOOT_STAND_TO_STAND 1461 with mask 6; slots sampled every
-- 50 ms until 9.5 s, then off. Also which locomotion slots his set has. No string library calls.
local E = _G.DERPY_TP
if not (E and E.main) then return "load the bridge first" end
local GUN = "wh3_main_cth_inf_iron_hail_gunners_0"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GUN then u = units:item(i) end end
local T = {log = "", has = ""}
_G.TP_LOWER = T
local t0, last = os.clock(), -1
bm:repeat_real_callback(function()
	local t = os.clock() - t0
	local ok, err = pcall(function()
		if not T.started then T.started = true E.main.start(u)
			for _, s in ipairs({3, 34, 918, 1434, 1435, 1461, 1470, 1475}) do T.has = T.has .. s .. "=" .. tostring(E.P.has_slot(E.F.model, s)) .. " " end
		end
		if t > 0.3 and not T.fired then T.fired = true E.F.want_shot = true end
		if t > 5.5 and not T.lowered then T.lowered = true T.played = E.P.play(E.F.model, 1461, 6) T.log = T.log .. " [1461 played " .. tostring(T.played) .. "]" end
		local s = E.F.model and E.P.anim_slot(E.F.model)
		if s ~= last then T.log = T.log .. " " .. math.floor(t * 10) / 10 .. "s:" .. tostring(s) last = s end
	end)
	if not ok then T.err = tostring(err) end
	if t > 9.5 or not ok then bm:remove_real_callback("tp_lower") pcall(E.main.stop, "lower probe") T.ended = true end
end, 50, "tp_lower")
return "started"
