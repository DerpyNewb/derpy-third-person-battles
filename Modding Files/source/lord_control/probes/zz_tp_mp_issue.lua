-- Test scaffolding (2026-10-21, multiplayer plan Task 2 step 2 and step 6), never shipped. Issues each call class the
-- third-person pack makes to its own unit at its own model time, 5 s apart, so every effect in zz_tp_mp_watch.lua's log
-- is attributable; then the override commands of step 6 (zz_tp_mp_override.lua, loaded first). Logs every issue to the
-- script log as "TPI <model ms> <step> <detail>".
-- Bridge-only, loaded from disk: local f = loadfile("<this path>") setfenv(f, core:get_env()) f()
--   TPI.units()          the two armies, one entry per unit
--   TPI.plan(assign)     assign: player unit indices by role (A B C D M1 M2 MR G H L J K S N1..N5) and enemy (X Y Z),
--                        plus ability = key. Picks the men, sets _G.TPW_MEN for the watch, returns the plan
--   TPI.run()            starts the timeline (model time), first step 0 s after the call
-- No string library calls.
local mr = _G.memreader_plus
local E = _G.DERPY_TP
local TPO = _G.TPO
if not (mr and E and E.P and E.P.models and TPO) then return "no platform, or zz_tp_mp_override.lua not loaded" end
local P = E.P
local mine, theirs
local armies_ok, armies_err = pcall(function() mine, theirs = bm:get_player_army(), bm:get_non_player_alliance():armies():item(1) end)
if not armies_ok then return "ERR armies: " .. tostring(armies_err) end
local TPI = _G.TPI or {}
_G.TPI = TPI
local function now() return bm:time_elapsed_ms() end
local function log(s) out("TPI " .. now() .. " " .. s) end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
-- a man is kept as {u, id} and found again by his +0x258 id at every use: a pointer kept from the plan outlived its man
-- (2026-10-21, run 1: a MOVE 60 s after the plan went to a man who had died). nil when he is gone
local function live(w)
	if not (w and w.u) then return nil end
	for _, m in ipairs(P.models(w.u)) do if TPO.model_id(m) == w.id then return m end end
	return nil
end
TPI.live = live

local function describe(army, side)
	local t = {}
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		t[#t + 1] = side .. i .. " " .. u:type() .. " men " .. u:number_of_men_alive() .. (u:is_commanding_unit() and " LORD" or "")
			.. (u:is_infantry() and " inf" or "") .. (u:is_cavalry() and " cav" or "") .. (u:is_artillery() and " art" or "")
			.. " range " .. u:missile_range() .. " ammo " .. u:ammo_left() .. " id " .. u:unique_ui_id()
	end
	return table.concat(t, " ; ")
end
function TPI.units() return describe(mine, "P") .. " ;; " .. describe(theirs, "E") end

local function middle(u)
	local ms = P.models(u)
	return ms[math.floor(#ms / 2) + 1], #ms
end
local function pos(u) local p = u:position() return p:get_x(), p:get_z() end
local function clip_for(m)
	for s = 454, 463 do if P.has_slot(m, s) then return s end end
	return nil
end
local function vec(x, z, up) return v(x, bm:get_terrain_height(x, z) + (up or 0), z) end

function TPI.plan(a)
	TPI.a = a
	local U, Y = {}, {}
	for _, k in ipairs({"A", "B", "C", "D", "M1", "M2", "MR", "G", "H", "L", "J", "K", "S", "N1", "N2", "N3", "N4", "N5"}) do
		if a[k] then U[k] = mine:units():item(a[k]) end
	end
	for _, k in ipairs({"X", "Y", "Z"}) do Y[k] = theirs:units():item(a[k]) end
	TPI.U, TPI.Y = U, Y
	-- forward: from my army's centre to theirs; right: across it
	local function centre(army)
		local sx, sz, n = 0, 0, 0
		for i = 1, army:units():count() do local x, z = pos(army:units():item(i)) sx, sz, n = sx + x, sz + z, n + 1 end
		return sx / n, sz / n
	end
	local mx, mz = centre(mine)
	local ex, ez = centre(theirs)
	local d = math.sqrt((ex - mx) ^ 2 + (ez - mz) ^ 2)
	TPI.f = {(ex - mx) / d, (ez - mz) / d}
	TPI.r = {TPI.f[2], -TPI.f[1]}
	TPI.ucs = {}
	local men, lines = {}, {}
	local function man(name, role, pick)
		local u = U[role]
		local m, n = middle(u)
		pick = pick or a["pick_" .. name]
		if pick then m = P.models(u)[pick] end
		TPI[name] = {u = u, id = TPO.model_id(m)}
		men[#men + 1] = {name = name, tag = "1.1." .. a[role], id = TPO.model_id(m)}
		lines[#lines + 1] = name .. " " .. role .. " " .. u:type() .. " model " .. TPO.model_id(m) .. " of " .. n
	end
	man("play", "K") man("steer", "S") man("lord", "L", 1)
	man("n1", "N1") man("n2", "N2") man("n3", "N3") man("n4", "N4") man("n5", "N5")
	_G.TPW_MEN = men -- d1 and d2 are added at their steps: the man of D nearest Z then
	lines[#lines + 1] = "forward " .. r1(TPI.f[1]) .. "," .. r1(TPI.f[2]) .. " gap " .. r1(d)
	lines[#lines + 1] = "abilities " .. table.concat(U.L:owned_special_abilities(), ",")
	return table.concat(lines, " ; ")
end

local function uc(u) local c = create_unitcontroller(u) TPI.ucs[#TPI.ucs + 1] = c return c end
local function ahead(u, fwd, side)
	local x, z = pos(u)
	return x + TPI.f[1] * fwd + TPI.r[1] * (side or 0), z + TPI.f[2] * fwd + TPI.r[2] * (side or 0)
end
local function ok_s(okv, why) return tostring(okv) .. " " .. tostring(why) end
local function move_man(w, fwd, side, run)
	local m = live(w)
	if not m then return "MOVE: " .. tostring(w and w.id) .. " is gone" end
	local body = P.mount(m) or m
	local x, _, z = P.model_pos(body)
	local tx, tz = x + TPI.f[1] * fwd + TPI.r[1] * side, z + TPI.f[2] * fwd + TPI.r[2] * side
	local speed = TPO.speed(body, run)
	return "MOVE " .. ok_s(TPO.move(body, tx, bm:get_terrain_height(tx, tz), tz, run, speed)) .. " from " .. r1(x) .. "," .. r1(z)
		.. " to " .. r1(tx) .. "," .. r1(tz) .. " speed " .. r1(speed) .. " heading " .. mr.read_uint16(body, 0xb0)
end
local function play(w)
	local m = live(w)
	if not m then return "play: " .. tostring(w and w.id) .. " is gone" end
	local s = clip_for(m)
	if not s then return "play: no attack slot" end
	return "play " .. s .. " " .. tostring(P.play(m, s, 0))
end

-- the timeline: {seconds, name, fn}; reps run every tick from t to t1
local steps, reps = {}, {}
local function at(t, name, fn) steps[#steps + 1] = {t = t, name = name, fn = fn} end
local function rep(t, t1, name, fn) reps[#reps + 1] = {t = t, t1 = t1, name = name, fn = fn, n = 0} end

at(0, "setup", function()
	-- the enemy held: every unit halted under its own controller; X before my missile units, Z before D (invincible, so the
	-- melee lasts); Y, the projectile target, stays in its own line
	for i = 1, theirs:units():count() do
		local c = uc(theirs:units():item(i))
		c:take_control()
		c:halt()
	end
	local sx, sz, n = 0, 0, 0
	for _, k in ipairs({"M1", "M2", "MR"}) do if TPI.U[k] then local x, z = pos(TPI.U[k]) sx, sz, n = sx + x, sz + z, n + 1 end end
	local bearing = math.deg(math.atan2(-TPI.f[1], -TPI.f[2]))
	local function place(k, x, z)
		local c = uc(TPI.Y[k])
		c:take_control()
		c:teleport_to_location(vec(x, z), bearing, 20)
		c:morale_behavior_fearless()
		c:halt()
		return c
	end
	place("X", sx / n + TPI.f[1] * 70, sz / n + TPI.f[2] * 70):set_invincible(true) -- shot at to the end: fire rate
	local zx, zz = ahead(TPI.U.D, 30)
	place("Z", zx, zz):set_invincible(true)
	return "enemy halted; X, Z placed (invincible, fearless); Y left in its line"
end)
at(5, "goto_location", function() local x, z = ahead(TPI.U.A, 30) uc(TPI.U.A):goto_location(vec(x, z), false) return "A +30" end)
at(8, "halt_setup_goto", function() local x, z = ahead(TPI.U.B, 40) TPI.ucB = uc(TPI.U.B) TPI.ucB:goto_location(vec(x, z), false) return "B +40" end)
at(10, "halt", function() TPI.ucB:halt() return "B" end)
at(15, "attack_location", function() local x, z = ahead(TPI.U.C, 25) uc(TPI.U.C):attack_location(vec(x, z), false) return "C +25" end)
at(20, "attack_unit", function() TPI.ucD = uc(TPI.U.D) TPI.ucD:attack_unit(TPI.Y.Z, true, true) return "D at Z" end)
at(25, "fire_at_will", function() TPI.ucM1 = uc(TPI.U.M1) TPI.ucM1:fire_at_will(false) return "M1 off" end)
at(30, "melee", function() uc(TPI.U.M2):melee(true) return "M2 on" end)
at(35, "change_behaviour_active", function() uc(TPI.U.G):change_behaviour_active("defend", true, false) return "G defend on" end)
at(40, "change_current_walk_speed", function()
	local x, z = ahead(TPI.U.H, 30)
	local c = uc(TPI.U.H)
	c:goto_location(vec(x, z), false)
	c:change_current_walk_speed(0.4)
	return "H goto +30 then speed 0.4"
end)
at(45, "set_invincible", function() TPI.ucD:set_invincible(true) return "D" end)
at(50, "set_current_ammo_unary", function() local u = TPI.U.M1 local a0 = u:ammo_left() u:set_current_ammo_unary(0.5) return "M1 0.5, ammo was " .. a0 end)
at(55, "trigger_projectile_launch", function()
	local x, z = pos(TPI.Y.Y)
	local key = TPI.a.projectile or "wh2_main_skv_death_globe"
	for k = -1, 1 do bm:trigger_projectile_launch(key, vec(x - TPI.f[1] * 15, z - TPI.f[2] * 15, 20), vec(x + TPI.r[1] * k * 3, z + TPI.r[2] * k * 3)) end
	return "3x " .. key .. " at Y, men " .. TPI.Y.Y:number_of_men_alive()
end)
at(60, "ability", function()
	local key = TPI.a.ability
	local c = uc(TPI.U.L)
	c:perform_special_ability(key, TPI.U.L)
	return "L " .. tostring(key) .. " could " .. tostring(TPI.U.L:can_perform_special_ability(key))
end)
at(65, "take_control", function() TPI.ucJ = uc(TPI.U.J) TPI.ucJ:take_control() return "J" end)
at(70, "P.play", function() return play(TPI.play) end)
at(75, "release_control", function() TPI.ucJ:release_control() return "J" end)
at(80, "P.steer", function()
	local m = live(TPI.steer)
	if not m then return "steer: gone" end
	local x, _, z = P.model_pos(m)
	TPI.steer_to = {x + TPI.r[1] * 12, z + TPI.r[2] * 12}
	return "from " .. r1(x) .. "," .. r1(z) .. " to " .. r1(TPI.steer_to[1]) .. "," .. r1(TPI.steer_to[2]) .. " mailbox " .. tostring(P.mailbox ~= nil)
end)
rep(80, 84, "P.steer", function() local m = live(TPI.steer) if m and TPI.steer_to then P.steer(m, TPI.steer_to[1], TPI.steer_to[2], false, nil, nil) end end)
-- step 6: the overrides
at(90, "MOVE open", function() return move_man(TPI.n1, 0, 15, false) end)
at(100, "MOVE long", function() return move_man(TPI.n2, 40, 0, false) end)
at(103, "HALT", function() local m = live(TPI.n2) if not m then return "HALT: gone" end return "HALT " .. ok_s(TPO.halt(m)) end)
at(108, "FOLLOW", function()
	local m = live(TPI.n3)
	if not m then return "FOLLOW: gone" end
	local h = mr.read_uint16(m, 0xb0)
	local want = (h + 0x4000) % 0x10000
	return "FOLLOW " .. ok_s(TPO.follow(m, want)) .. " heading " .. h .. " to " .. want
end)
at(113, "MOVE then clip", function() return move_man(TPI.n4, 0, 15, false) .. " ; " .. play(TPI.n4) end)
at(118, "clip then MOVE", function() return play(TPI.n5) .. " ; " .. move_man(TPI.n5, 0, 15, false) end)
at(123, "RELOAD_TIME 0.2", function()
	local g0 = TPO.reload_global()
	local okr, why = TPO.reload(0.2)
	return "push " .. ok_s(okr, why) .. " global before " .. tostring(g0)
end)
at(124, "RELOAD_TIME read", function() return "global " .. tostring(TPO.reload_global()) end)
-- the man of D nearest Z's centre, not one already picked, added to the watch's list
local function front(name)
	local zx, zz = pos(TPI.Y.Z)
	local best, bd
	for _, m in ipairs(P.models(TPI.U.D)) do
		local x, _, z = P.model_pos(m)
		local d = (x - zx) ^ 2 + (z - zz) ^ 2
		local id = TPO.model_id(m)
		if (not bd or d < bd) and not (TPI.d1 and TPI.d1.id == id) then best, bd = m, d end
	end
	TPI[name] = {u = TPI.U.D, id = TPO.model_id(best)}
	local men = _G.TPW_MEN
	men[#men + 1] = {name = name, tag = "1.1." .. TPI.a.D, id = TPO.model_id(best)}
	return name .. " " .. TPO.model_id(best) .. " " .. r1(math.sqrt(bd)) .. " m from Z's centre"
end
at(128, "melee MOVE gate off", function() return front("d1") .. " in melee " .. tostring(TPI.U.D:is_in_melee()) .. " gate " .. tostring(P.gate(false)) end)
rep(128, 133, "melee MOVE gate off", function(w) w.res = move_man(TPI.d1, -20, 0, true) end)
at(138, "melee MOVE gate on", function() return front("d2") .. " gate " .. tostring(P.gate(true)) .. " in melee " .. tostring(TPI.U.D:is_in_melee()) end)
rep(138, 143, "melee MOVE gate on", function(w) w.res = move_man(TPI.d2, -20, 0, true) end)
at(143.5, "gate out", function() return "gate " .. tostring(P.gate(false)) end)
at(148, "RELOAD_TIME -1", function() return ok_s(TPO.reload(-1.0)) end)
at(149, "RELOAD_TIME read", function() return "global " .. tostring(TPO.reload_global()) end)
at(153, "done", function() return TPO.snapshot() end)

-- The follow-up run (2026-10-21): the two classes run 1 left with no visible effect, and a sideways MOVE on a man who is
-- alive. attack_location on a missile unit not firing (its ammo must drop), the lord's single-use item ability (its
-- can_perform reading, logged by the watch through _G.TPW_AB, must go false), a MOVE 15 m to his right. Nothing else.
-- a2: {MA = missile unit index, L = lord index, N = infantry index, pick = model index, ability = key}
function TPI.run2(a2)
	if TPI.on then return "already running" end
	TPI.on, TPI.t0 = true, now()
	local MA, L, N = mine:units():item(a2.MA), mine:units():item(a2.L), mine:units():item(a2.N)
	local w = {u = N, id = TPO.model_id(P.models(N)[a2.pick])}
	TPI.n1 = w
	local two = {
		{t = 25, name = "attack_location", fn = function()
			local x, z = pos(MA)
			local f = TPI.f or {0, 1}
			TPI.f, TPI.r = f, {f[2], -f[1]}
			uc(MA):attack_location(vec(x + f[1] * 60, z + f[2] * 60), false)
			return "MA +60, ammo " .. MA:ammo_left()
		end},
		{t = 35, name = "ability", fn = function()
			local c = uc(L)
			c:perform_special_ability(a2.ability, L)
			return "L " .. a2.ability .. " could " .. tostring(L:can_perform_special_ability(a2.ability))
		end},
		{t = 45, name = "MOVE right", fn = function() return move_man(w, 0, 15, false) end},
	}
	TPI.ucs = TPI.ucs or {}
	log("run2 t0 " .. TPI.t0 .. " n1 " .. w.id)
	bm:repeat_callback(function()
		local rel = (now() - TPI.t0) / 1000
		for _, s in ipairs(two) do
			if not s.done and rel >= s.t then
				s.done = true
				local okf, res = pcall(s.fn)
				log(s.name .. " " .. tostring(okf) .. " " .. tostring(res))
			end
		end
		if rel > 70 then TPI.on = false bm:remove_process("tp_mp_issue") log("finished") end
	end, 100, "tp_mp_issue")
	return "run2 from " .. TPI.t0
end

-- The ability, observed through CA's own unit context (the hud's reads): run 1 and run 2 saw no field of the unit move.
-- TPI.abilities(id) lists CA's list for the unit context id (its unique_ui_id); TPI.cco_watch(id, secs) logs every
-- non-passive entry's IsActive, WindUp, Active, Recharge and RemainingUses as "TPC <ms> ..." every 100 ms of model time;
-- TPI.cast(id, i) is the mod's own cast (abilities.lua: PerformAbilityForOwner); TPI.cast_uc(n, key) its fallback.
local function cv(id, e) local okv, val = pcall(common.get_context_value, "CcoBattleUnit", id, e) if okv then return val end return nil end
function TPI.abilities(id)
	local t = {}
	for i = 0, (cv(id, "BattleAbilityList.Size") or 0) - 1 do
		local at = "BattleAbilityList.At(" .. i .. ")."
		t[#t + 1] = i .. " " .. tostring(cv(id, at .. "SetupAbilityContext.RecordKey")) .. " passive " .. tostring(cv(id, at .. "SetupAbilityContext.IsPassive"))
	end
	return table.concat(t, " ; ")
end
function TPI.cco_watch(id, idx, secs)
	local t0 = now()
	bm:repeat_callback(function()
		if now() - t0 > secs * 1000 then bm:remove_process("tp_mp_cco") return end
		local parts = {"TPC", tostring(now())}
		for _, i in ipairs(idx) do
			local at = "BattleAbilityList.At(" .. i .. ")."
			parts[#parts + 1] = i .. "=" .. tostring(cv(id, at .. "IsActive")) .. "," .. tostring(cv(id, at .. "WindUpTimeRemainingSecs")) .. ","
				.. tostring(cv(id, at .. "ActiveTimeRemainingSecs")) .. "," .. tostring(cv(id, at .. "RechargeTimeRemainingSecs")) .. "," .. tostring(cv(id, at .. "RemainingUses"))
		end
		out(table.concat(parts, " "))
	end, 100, "tp_mp_cco")
	return "cco watch from " .. t0
end
function TPI.cast(id, i)
	common.call_context_command("CcoBattleUnit", id, "BattleAbilityList.At(" .. i .. ").PerformAbilityForOwner")
	log("cast CCO " .. id .. " " .. i)
	return "cast at " .. now()
end
function TPI.cast_uc(n, key)
	local u = mine:units():item(n)
	create_unitcontroller(u):perform_special_ability(key, u)
	log("cast uc " .. n .. " " .. key)
	return "cast at " .. now()
end

function TPI.run()
	if TPI.on then return "already running" end
	TPI.on, TPI.t0 = true, now()
	local anim_ok, why = P.check_anim() -- P.play refuses until it has run (2026-10-21: three plays returned false)
	log("check_anim " .. tostring(anim_ok) .. " " .. tostring(why))
	for _, s in ipairs(steps) do s.done = false end
	log("run t0 " .. TPI.t0 .. " " .. TPO.snapshot())
	bm:repeat_callback(function()
		local rel = (now() - TPI.t0) / 1000
		for _, s in ipairs(steps) do
			if not s.done and rel >= s.t then
				s.done = true
				local okf, res = pcall(s.fn)
				log(s.name .. " " .. tostring(okf) .. " " .. tostring(res))
			end
		end
		for _, w in ipairs(reps) do
			if rel >= w.t and rel < w.t1 then
				local okf, err = pcall(w.fn, w)
				w.n = w.n + 1
				if not okf then log(w.name .. " rep error " .. tostring(err)) elseif w.res and w.n % 10 == 1 then log(w.name .. " rep " .. w.n .. " " .. w.res) end
			end
		end
		if rel > 155 then
			TPI.on = false
			bm:remove_process("tp_mp_issue")
			log("finished")
		end
	end, 100, "tp_mp_issue")
	return "running from " .. TPI.t0
end
return "TPI loaded"
