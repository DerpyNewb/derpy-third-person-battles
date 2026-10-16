-- Third person's state on the unit it plays, for a start that did not go ranged. No string library calls.
local E = _G.DERPY_TP
local F, P = E.F, E.P
local u = F.unit
local s = "on " .. tostring(F.on) .. " model " .. tostring(F.model ~= nil) .. " ranged " .. tostring(F.ranged) .. " solo "
	.. tostring(F.solo) .. " cannot_shoot " .. tostring(F.cannot_shoot) .. " fire_slot " .. tostring(F.fire_slot)
	.. " men_ok " .. tostring(F.men_ok) .. " anim " .. tostring(P.features.anim) .. " steer " .. tostring(P.features.steer)
if u then s = s .. " | unit " .. u:type() .. " range " .. u:missile_range() .. " ammo " .. u:ammo_left() .. " melee " .. tostring(u:is_in_melee()) .. " men " .. u:number_of_men_alive() end
local l = E.lines or E.log_lines
if type(l) == "table" then for i = math.max(1, #l - 6), #l do s = s .. " | " .. tostring(l[i]) end end
return s
