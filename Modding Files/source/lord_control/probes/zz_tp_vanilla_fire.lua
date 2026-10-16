-- How CA's engine sequences a gunner's shot, 2026-10-16: the pack plays raise (1554) then fire (1557), and the raise's
-- end pose sits ~20 deg up (seen: probes/zz_tp_aim_seq.lua). Third person off; the regiment of TYPE is ordered by test
-- scaffolding (a script unit controller) to fire at the ground 60 m ahead, fire at will on; for SECS s every model tick, the
-- clip of its first 12 men, kept as each man's changes "slot@s". No string library calls.
-- Read back: zz_tp_vanilla_fire_read.lua.
local TYPE, SECS = "wh3_dlc24_ksl_inf_streltsi_ror", 20
local E = _G.DERPY_TP
local P, F = E.P, E.F
if F.on then E.main.stop("test") end
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == TYPE and x:number_of_men_alive() > 0 then u = x end
end
if not u then return "no " .. TYPE end
local q, best, bd = u:position(), nil, nil
local enemies = bm:get_non_player_alliance():armies()
for a = 1, enemies:count() do
	local l = enemies:item(a):units()
	for i = 1, l:count() do
		local e = l:item(i)
		if e:number_of_men_alive() > 0 then
			local d = e:position():distance_xz(q)
			if not bd or d < bd then best, bd = e, d end
		end
	end
end
if not best then return "no enemy" end
local uc = army:create_unit_controller()
uc:add_units(u)
uc:fire_at_will(true)
local b = math.rad(u:bearing())
local gx, gz = q:get_x() + math.sin(b) * 60, q:get_z() + math.cos(b) * 60
uc:attack_location(v(gx, bm:get_terrain_height(gx, gz), gz), false)
uc:release_control()
local men = P.models(u)
local T = {men = {}, done = false, target = best:type(), dist = math.floor(bd)}
_G.TP_VANILLA_FIRE = T
for i = 1, math.min(12, #men) do T.men[i] = {m = men[i], last = -1, log = ""} end
local t0, last_ms = os.clock(), nil
bm:repeat_real_callback(function()
	local ok, e = pcall(function()
		local t = os.clock() - t0
		if t > SECS then T.done = true return end
		if bm:time_elapsed_ms() == last_ms then return end
		last_ms = bm:time_elapsed_ms()
		for _, r in ipairs(T.men) do
			local s = P.anim_slot(r.m) or 0
			if s ~= r.last then r.last = s r.log = r.log .. " " .. s .. "@" .. math.floor(t * 10) / 10 end
		end
	end)
	if not ok then T.err = tostring(e) T.done = true end
	if T.done then bm:remove_real_callback("tp_vanilla_fire") end
end, 30, "tp_vanilla_fire")
return "recording " .. #T.men .. " men, firing at the ground 60 m ahead"
