-- 2026-10-15, "it happens when switching to ranged ... triggers the whole battalion to shoot or throw": which missile
-- clips an Exalted Plaguebearer's model has (no FIRE_LEVEL 1557). Read-only; no string library calls.
local E = _G.DERPY_TP
if not E or not E.P then return "no DERPY_TP" end
local P = E.P
local units = bm:get_player_army():units()
local out = ""
for i = 1, units:count() do
	local u = units:item(i)
	if u:type() == "wh3_main_nur_inf_plaguebearers_1" then
		local m = P.models(u)[1]
		out = out .. u:type() .. " models " .. #P.models(u) .. " range " .. u:missile_range() .. " ammo " .. u:ammo_left()
			.. " shots data " .. tostring(E.D.shots[u:type()] ~= nil) .. " slot now " .. tostring(m and P.anim_slot(m)) .. " has:"
		if m then
			for _, r in ipairs({{940, 960}, {1540, 1600}}) do
				for s = r[1], r[2] do if P.has_slot(m, s) then out = out .. " " .. s end end
			end
		end
	end
end
return out == "" and "no exalted plaguebearers" or out
