-- Experiment for the walk_stop race (2026-10-16): with his attack clips gone (P.disarm), does the engine's melee order
-- still need stopping? The guard leaves melee (3ad24b8) alone; walk and moves are still stopped. Send BEFORE
-- zz_tp_auto_attack.lua, read its "carried" and "no_auto_attack". Undo: _G.TPNM.unwrap(). Not shipped.
-- No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.P and mr) then return "load the pack in a battle first" end
	if _G.TPNM then return "already on" end
	local P = E.P
	local melee = mr.add(mr.add(mr.base, 0x3ad0000), 0x24b8)
	local X = {guard = P.guard, left = 0}
	_G.TPNM = X
	P.guard = function(m)
		local b = P.mount(m) or m
		if mr.eq(mr.read_pointer(b, 0x330), melee) then X.left = X.left + 1 return false end
		return X.guard(m)
	end
	function X.unwrap() P.guard = X.guard _G.TPNM = nil end
	return "guard leaves melee alone"
end)
return ok and res or "ERR " .. tostring(res)
