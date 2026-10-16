-- Experiment for the no-auto-attack fix, before it goes into combat.lua: after the guard each frame, an attack clip on
-- his body that he did not ask for (no action lock, not his own swing playing out, no native fallback attack) is ended
-- with WALK_1 at mask 0 through the engine's queue, at most every CUT_GAP s. Rides on P.guard, which main.lua calls for
-- the controlled man every unpaused frame - the same place the source change would run. Not shipped.
-- Send BEFORE zz_tp_auto_attack.lua. Undo: _G.TPCUT.unwrap(). No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.P and E.F) then return "load the pack in a battle first" end
	if _G.TPCUT then return "already on, " .. _G.TPCUT.n .. " cuts" end
	local P, F = E.P, E.F
	local WALK_1, CUT_GAP = 42, 0.3
	local X = {n = 0, by = {}, guard = P.guard}
	_G.TPCUT = X
	local function attack(s) return s and (s >= 454 and s <= 463 or s >= 484 and s <= 500) end
	P.guard = function(m)
		local r = X.guard(m)
		if not P.features.anim or F.lock or F.native_attack then return r end
		local b = P.mount(m) or m
		local s = P.anim_slot(b)
		local now = bm:time_elapsed_ms() / 1000
		if attack(s) and not (F.swung and F.swung[2] == s) and now >= (X.at or 0) and P.has_slot(b, WALK_1) then
			P.play(b, WALK_1, 0)
			X.at, X.n = now + CUT_GAP, X.n + 1
			X.by[s] = (X.by[s] or 0) + 1
		end
		return r
	end
	function X.unwrap() P.guard = X.guard end
	return "cut experiment on"
end)
return ok and res or "ERR " .. tostring(res)
