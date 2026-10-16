-- The charge attack thrown out of the charge, 2026-10-15 ("pressing q then melee attacking doesnt trigger the attack
-- charge animation at all"; the log shows "charge attack" sent). Third person on, his man standing. Four rounds 4 s
-- apart, each logging the clip slot on every change: A MOVING_ATTACK_1 (484) at the default mask alone; B CHARGE (135)
-- at mask 6, then 484 at the default mask 0.5 s later (what combat.lua sends); C the same with 484 at mask 6; D CHARGE,
-- then WALK_1 at mask 0, then 484 the next tick. No string library calls. Read back: zz_tp_charge_attack_read.lua.
local E = _G.DERPY_TP
if not (E and E.F and E.F.on and E.F.model) then return "third person on one man first" end
local P, m = E.P, E.F.model
local T = {log = "", has = "135 " .. tostring(P.has_slot(m, 135)) .. " 484 " .. tostring(P.has_slot(m, 484))
	.. " 485 " .. tostring(P.has_slot(m, 485)) .. " 42 " .. tostring(P.has_slot(m, 42)), done = {}}
_G.TP_CHARGE_ATTACK = T
bm:modify_battle_speed(1)
local t0, last = os.clock(), "x"
local function note(s) T.log = T.log .. " || " .. math.floor((os.clock() - t0) * 100) / 100 .. "s " .. s end
local steps = {
	{0.2, "A 484", function() return P.play(m, 484) end},
	{4.0, "B 135 m6", function() return P.play(m, 135, 6) end},
	{4.5, "B 484", function() return P.play(m, 484) end},
	{8.0, "C 135 m6", function() return P.play(m, 135, 6) end},
	{8.5, "C 484 m6", function() return P.play(m, 484, 6) end},
	{12.0, "D 135 m6", function() return P.play(m, 135, 6) end},
	{12.5, "D 42 m0", function() return P.play(m, 42, 0) end},
	{12.55, "D 484", function() return P.play(m, 484) end},
}
bm:repeat_real_callback(function()
	local t = os.clock() - t0
	local ok, err = pcall(function()
		for i, s in ipairs(steps) do
			if t >= s[1] and not T.done[i] then T.done[i] = true note(s[2] .. " sent " .. tostring(s[3]())) end
		end
		local slot = tostring(P.anim_slot(m))
		if slot ~= last then note("slot " .. slot) last = slot end
	end)
	if not ok then T.err = tostring(err) end
	if t > 16 or not ok then
		bm:remove_real_callback("tp_charge_attack")
		T.ended = true
	end
end, 30, "tp_charge_attack")
return "started"
