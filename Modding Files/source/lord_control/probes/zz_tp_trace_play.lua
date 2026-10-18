-- Test scaffolding (2026-10-18, the author: "the artillery in melee still makes all the crew do a melee attack"; their
-- log had a flame cannon's lock on ATTACK_1, 454, with no jump, charge or cheer logged). Mode "on" (the default): wraps
-- the pack's P.play so every attack clip (454-500) records its caller's stack, with F.arty and F.ranged, and wraps
-- C.attack to count clicks. Mode "read": returns what was recorded. Mode "off": puts both back. No string library calls.
local ok, res = pcall(function()
	local T = _G.DERPY_TP
	local mode = _G.TP_TR_MODE or "on"
	if mode == "read" then
		local s = "clicks " .. tostring(_G.TP_TR_CLICKS or 0) .. "; "
		for i, e in ipairs(_G.TP_TR or {}) do s = s .. "#" .. i .. " " .. e .. " || " end
		return s
	end
	if mode == "off" then
		if _G.TP_TR_PLAY then T.P.play = _G.TP_TR_PLAY end
		if _G.TP_TR_ATTACK then T.combat.attack = _G.TP_TR_ATTACK end
		_G.TP_TR_PLAY, _G.TP_TR_ATTACK = nil, nil
		return "trace off"
	end
	_G.TP_TR, _G.TP_TR_CLICKS = {}, 0
	if not _G.TP_TR_PLAY then
		local play, attack = T.P.play, T.combat.attack
		_G.TP_TR_PLAY, _G.TP_TR_ATTACK = play, attack
		T.P.play = function(m, slot, mask)
			if slot and slot >= 454 and slot <= 500 and #_G.TP_TR < 12 then
				local F = T.F
				_G.TP_TR[#_G.TP_TR + 1] = "slot " .. slot .. " unit " .. tostring(F.utype) .. " arty " .. tostring(F.arty)
					.. " ranged " .. tostring(F.ranged) .. " crew " .. tostring(F.crew) .. " t " .. bm:time_elapsed_ms()
					.. " | " .. debug.traceback("", 2)
			end
			return play(m, slot, mask)
		end
		T.combat.attack = function(now, clicked, held)
			if clicked then _G.TP_TR_CLICKS = _G.TP_TR_CLICKS + 1 end
			return attack(now, clicked, held)
		end
	end
	return "trace on"
end)
return ok and res or "ERR " .. tostring(res)
