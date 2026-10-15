-- Read-only: the pack's session state and the player's units. NO string library calls.
local E = _G.DERPY_TP
if not E then return "no DERPY_TP" end
local F = E.F
local out = {on = tostring(F.on), utype = tostring(F.utype), model = F.model and "one man" or "whole",
	solo = tostring(F.solo), ranged = tostring(F.ranged), arty = tostring(F.arty), men_ok = tostring(F.men_ok),
	firing = tostring(F.firing), held_fire = tostring(F.held_fire), driving = tostring(F.driving),
	shot = F.shot and tostring(F.shot.phase) or "none", one_man = tostring(E.S and E.S.one_man),
	steer = tostring(E.P.features.steer), anim = tostring(E.P.features.anim)}
local units = bm:get_player_alliance():armies():item(1):units()
local list = {}
for i = 1, units:count() do
	local u = units:item(i)
	list[i] = u:type() .. " men " .. u:number_of_men_alive() .. " range " .. u:missile_range() .. " moving "
		.. tostring(u:is_moving())
end
out.units = list
return out
