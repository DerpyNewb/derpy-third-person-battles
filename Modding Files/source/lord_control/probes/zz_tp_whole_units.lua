-- 2026-10-15, "there are still instances where pressing f2 will still move the entire battalion": for every unit in the
-- player's army, what main.lua's start would decide - the men check and its reason, the front man, his fire clip (1557)
-- and reload clip, whether data.lua knows its shot - and the models' centre against the unit's position. Read-only; no
-- string library calls; under pcall.
local E = _G.DERPY_TP
if not E or not E.P then return "no DERPY_TP" end
local P = E.P
local ok, res = pcall(function()
	local out = ""
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		local u = units:item(i)
		local t = u:type()
		local men_ok, why = P.check_men(u)
		local ms = P.models(u)
		local sx, sz = 0, 0
		for _, m in ipairs(ms) do local x, _, z = P.model_pos(m) sx, sz = sx + x, sz + z end
		local q = u:position()
		local off = #ms > 0 and math.sqrt((sx / #ms - q:get_x()) ^ 2 + (sz / #ms - q:get_z()) ^ 2) or -1
		local front = men_ok and E.move.front_man(u)
		local m = front or ms[1]
		out = out .. " || " .. t .. " men " .. u:number_of_men_alive() .. " range " .. u:missile_range() .. " men_ok "
			.. tostring(men_ok) .. (why and (" (" .. tostring(why) .. ")") or "") .. " centre off " .. math.floor(off * 10) / 10
			.. " width " .. math.floor(u:ordered_width()) .. " fire1557 " .. tostring(m and P.has_slot(m, 1557))
			.. " reload " .. tostring(m and P.reload_slot(m)) .. " shot " .. tostring(E.D.shots[t] ~= nil) .. " fires "
			.. tostring(E.D.fires and E.D.fires[t] ~= nil) .. " fly " .. tostring(u:can_fly()) .. " wm "
			.. tostring(u:is_war_machine()) .. " arty " .. tostring(u:is_artillery())
	end
	return out
end)
return tostring(ok) .. " " .. tostring(res)
