-- Does the regiment move the man third person plays? 2026-10-16, run by the agent alone (the author: "battalion actions
-- also affect the unit which shouldnt be and its moving itself the unit whenever the battalion is affected"; "can you
-- not do it yourself"). The battle running. Third person goes on one man of the first regiment of TYPE; the test, not
-- the pack, orders the regiment (a script unit controller) to attack the enemy unit nearest it; for SECS s, nobody at the
-- keys, every model tick: how far he moves (path, net), how far the regiment's centre moves, every command on him (its
-- vtable), melee. GUARD true: the engine's commands on him (the regiment walk 0x3919350, moves 0x39199f8 / 0x3919b28,
-- melee 0x3ad24b8) are stopped with the engine's own stop (exe+306edd4) the moment they are seen. No string library
-- calls. Read back: zz_tp_regiment_test_read.lua.
local GUARD, SECS, TYPE = false, 30, "wh3_main_ksl_inf_tzar_guard_1"
-- ALL: the guard stops every command but the pack's three (walk, clip, stand), never while his hit points are 0
local ALL = false
local E = _G.DERPY_TP
if not (E and E.P and E.main and E.P.build == "6acec6f4") then return "the pack on build 6acec6f4 first" end
local mr = _G.memreader_plus
if not mr then return "no memreader_plus" end
if _G.TP_REG and not _G.TP_REG.done then return "already running" end
local P, F = E.P, E.F
local function at(hi, lo) return mr.add(mr.add(mr.base, hi), lo) end
local STOP = at(0x3060000, 0xedd4)
local NAMES = {
	{"walk(pack)", at(0x3ae0000, 0x2400)}, {"clip(pack)", at(0x3910000, 0x1fb0)}, {"stand", at(0x3910000, 0x26f0)},
	{"regiment walk", at(0x3910000, 0x9350), true}, {"move 9f8", at(0x3910000, 0x99f8), true},
	{"move b28", at(0x3910000, 0x9b28), true}, {"melee 4b8", at(0x3ad0000, 0x24b8), true},
}
local T = {guard = GUARD, all = ALL, seen = {}, stops = {}, metres = {}, clips = {}, log = "", done = false}
_G.TP_REG = T
local ok, why = pcall(function()
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if not u and x:type() == TYPE and x:number_of_men_alive() > 0 then u = x end
	end
	if not u then error("no " .. TYPE) end
	if F.on then E.main.stop("test") end
	E.main.start(u)
	if not (F.on and F.model) then error("third person did not go on one man") end
	local q, best, bd = u:position(), nil, nil
	local enemies = bm:get_non_player_alliance():armies()
	for a = 1, enemies:count() do
		local l = enemies:item(a):units()
		for i = 1, l:count() do
			local e = l:item(i)
			if e:number_of_men_alive() > 0 and not e:is_routing() then
				local d = e:position():distance_xz(q)
				if not bd or d < bd then best, bd = e, d end
			end
		end
	end
	if _G.TP_MELEE then best, bd = _G.TP_MELEE.enemy, _G.TP_MELEE.enemy:position():distance_xz(q) end -- zz_tp_melee_setup.lua's
	if not best then error("no enemy") end
	local uc = army:create_unit_controller()
	uc:add_units(u)
	-- the test's scaffold, not the pack's: his regiment takes no damage while it runs, so no death ends a run early
	uc:set_invincible(true)
	T.uc = uc
	uc:attack_unit(best, true, true)
	T.enemy, T.enemy_m = best:type(), math.floor(bd)
end)
if not ok then T.err = tostring(why) T.done = true return "not started: " .. T.err end
local m, u = F.model, F.unit
local x0, _, z0 = P.model_pos(m)
local q0 = u:position()
T.rx0, T.rz0 = q0:get_x(), q0:get_z()
local px, pz, path, t0, last_ms = x0, z0, 0, os.clock(), nil
local function name(c)
	for _, n in ipairs(NAMES) do if mr.eq(c, n[2]) then return n[1], n[3] end end
	return mr.tostring(c), false
end
bm:repeat_real_callback(function()
	local ok2, err = pcall(function()
		if os.clock() - t0 > SECS or not (F.on and F.model and P.same(F.model, m)) then
			T.why_end = os.clock() - t0 > SECS and "time" or "third person changed"
			T.done = true
			return
		end
		if bm:time_elapsed_ms() == last_ms then return end
		last_ms = bm:time_elapsed_ms()
		local c = mr.read_pointer(m, 0x330)
		local n, engine = name(c)
		local ours = n == "walk(pack)" or n == "clip(pack)" or n == "stand"
		local hp = P.model_hp(m)
		if ALL and not ours then engine = hp and hp > 0 end
		T.seen[n] = (T.seen[n] or 0) + 1
		local cl = tostring(P.anim_slot(m))
		T.clips[n] = T.clips[n] or {}
		if not T.clips[n][cl] then T.clips[n][cl] = true T.clips[n][#T.clips[n] + 1] = cl end
		if engine and GUARD then
			mr.call(STOP, "pointer(pointer)", m)
			T.stops[n] = (T.stops[n] or 0) + 1
		end
		local x, _, z = P.model_pos(m)
		local step = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		T.metres[n] = (T.metres[n] or 0) + step
		path = path + step
		px, pz = x, z
		T.path, T.net = path, math.sqrt((x - x0) ^ 2 + (z - z0) ^ 2)
		local q = u:position()
		T.reg = math.sqrt((q:get_x() - T.rx0) ^ 2 + (q:get_z() - T.rz0) ^ 2)
		T.apart = math.sqrt((q:get_x() - x) ^ 2 + (q:get_z() - z) ^ 2)
		T.melee = T.melee or u:is_in_melee()
		local s = math.floor(os.clock() - t0)
		if s ~= T.sec then
			T.sec = s
			T.log = T.log .. " " .. s .. "s:" .. math.floor(path * 10) / 10 .. "m," .. n .. "," .. tostring(u:is_in_melee())
		end
	end)
	if not ok2 then T.err = tostring(err) T.done = true end
	if T.done then
		if T.uc and not _G.TP_MELEE then pcall(function() T.uc:set_invincible(false) end) end
		bm:remove_real_callback("tp_reg")
	end
end, 30, "tp_reg")
return "running " .. SECS .. " s, guard " .. tostring(GUARD) .. ", attacking " .. tostring(T.enemy) .. " " .. tostring(T.enemy_m) .. " m away"
