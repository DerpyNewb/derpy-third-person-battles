-- Bug 4 (the author, 2026-10-14: "the player should always have absolute control of the unit and no auto attack").
-- Sets one way of keeping the controlled unit from engaging on its own, per send: _G.DERPY_TP_ENGAGE_WAY =
-- "defend" (the defend behaviour on - guard mode, if that is what it is), "undefend" (off again), "hold" (script
-- keeps control: take_control and halt, no release) or "release" (control back to the player, as the pack does
-- after every order). Stand still near an enemy, then read zz_tp_ability_state.lua (in_melee, defend) a few
-- seconds later. NO string library calls.
local E = _G.DERPY_TP
if not (E and E.F.on) then return "not in third person" end
local F = E.F
local way = _G.DERPY_TP_ENGAGE_WAY or "defend"
local ok, err = true, nil
if way == "defend" or way == "undefend" then
	ok, err = pcall(F.uc.change_behaviour_active, F.uc, "defend", way == "defend", false)
elseif way == "hold" then
	ok, err = pcall(function() F.uc:take_control() F.uc:halt() end)
else
	ok, err = pcall(F.uc.release_control, F.uc)
end
local best
local armies = bm:get_non_player_alliance():armies()
local q = F.unit:position()
for a = 1, armies:count() do
	local us = armies:item(a):units()
	for i = 1, us:count() do
		local d = us:item(i):position():distance(q)
		if not best or d < best then best = d end
	end
end
return {way = way, ok = tostring(ok), err = tostring(err), in_melee = tostring(F.unit:is_in_melee()),
	defend = tostring(F.unit:is_behaviour_active("defend")), nearest_enemy_m = tostring(best)}
