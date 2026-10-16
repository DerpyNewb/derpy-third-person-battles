-- Why the pack differs by unit, 2026-10-16, run by the agent alone (the author: "still auto attacking", "headless but
-- still controlling the character", "no attack being triggered as tyrion", "why is this mod very inconsistent across
-- units"; earlier: "can you not do it yourself"). The battle running. For each player unit in TYPES, in turn:
--   one man: third person on him; the TEST (a script unit controller, his regiment invincible) sends his regiment at the
--   nearest enemy; once in melee, four of the pack's own swings (E.combat.melee) with the pack's guard, four with the
--   guard switched off, 8 s with nobody at the keys; then the invincibility off and his death watched: every frame his
--   hit points, whether he is still in the unit's list, and whether the pack still plays him.
--   played whole: the pack's swing every 3 s for 15 s, the unit's distance to its target and melee each second.
-- Every command on him (+0x330) with the clips seen under it, per phase. The pack's tick runs as it does in play. No
-- string library calls. Read back: zz_tp_sweep_read.lua.
local TYPES = _G.TP_SWEEP_TYPES or {"hef_calith_gatekeepers", "wh2_dlc10_hef_cav_the_fireborn_ror_0", "wh2_main_hef_cha_tyrion_1",
	"wh2_dlc10_hef_inf_keepers_of_the_flame_ror_0", "wh2_dlc10_hef_inf_everqueens_court_guards_ror_0"}
local E = _G.DERPY_TP
if not (E and E.P and E.main and E.combat) then return "load the pack first" end
local mr = _G.memreader_plus
if not mr then return "no memreader_plus" end
if _G.TP_SWEEP and not _G.TP_SWEEP.done then return "already running" end
local P, F = E.P, E.F
local function at(hi, lo) return mr.add(mr.add(mr.base, hi), lo) end
local NAMES = {
	{"walk(pack)", at(0x3ae0000, 0x2400)}, {"clip(pack)", at(0x3910000, 0x1fb0)}, {"stand", at(0x3910000, 0x26f0)},
	{"regiment walk", at(0x3910000, 0x9350)}, {"move 9f8", at(0x3910000, 0x99f8)}, {"idle b28", at(0x3910000, 0x9b28)},
	{"move 928", at(0x3ae0000, 0x1928)}, {"melee 4b8", at(0x3ad0000, 0x24b8)}, {"knockback", at(0x3ae0000, 0x2b38)},
	{"knockdown", at(0x3ae0000, 0x2a08)}, {"get up", at(0x3910000, 0x2820)},
}
local function name(c)
	for _, n in ipairs(NAMES) do if mr.eq(c, n[2]) then return n[1] end end
	return mr.tostring(c)
end
local ROWS = {454, 455, 456, 457, 458, 459, 460, 484, 485, 489, 1901, 1902, 1903, 1904, 1941}
local function rows(m)
	if not m then return "none" end
	local s = ""
	for _, r in ipairs(ROWS) do if P.has_slot(m, r) then s = s .. r .. " " end end
	return s == "" and "none" or s
end
local T = {done = false, units = {}, i = 0, base = mr.tostring(mr.base)}
_G.TP_SWEEP = T
local guard = P.guard
local R, st, t_phase, last_ms
local function now() return bm:time_elapsed_ms() / 1000 end
local function note(s)
	if R and #R.events < 120 then R.events[#R.events + 1] = math.floor((os.clock() - R.t0) * 10) / 10 .. "s " .. s end
end
local function phase(p) st, t_phase = p, os.clock() note("phase " .. p) end
local function nearest(u)
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
	return best, bd
end
local function find(ty)
	local army = bm:get_player_army()
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == ty and x:number_of_men_alive() > 0 then return x end
	end
end
local function finish_unit()
	P.guard = guard
	if R and R.uc then pcall(function() R.uc:set_invincible(false) R.uc:release_control() end) end
	if F.on then pcall(E.main.stop, "sweep") end
	R = nil
	st = "next"
end
local function next_unit()
	T.i = T.i + 1
	local ty = TYPES[T.i]
	if not ty then T.done = true return end
	R = {type = ty, t0 = os.clock(), events = {}, cmds = {}, swings = {}}
	T.units[#T.units + 1] = R
	local u = find(ty)
	if not u then R.err = "not in the army" finish_unit() return end
	if F.on then E.main.stop("sweep") end
	E.main.start(u)
	if not F.on then R.err = "third person did not go on" finish_unit() return end
	R.u, R.whole = u, F.model == nil
	local m = F.model or P.models(u)[1]
	R.m = m
	local mount = m and P.mount(m)
	R.kind = (R.whole and "whole" or "one man") .. ", men " .. u:number_of_men_alive() .. ", cavalry " .. tostring(u:is_cavalry())
		.. ", class " .. mr.tostring(mr.read_pointer(m, 0)) .. ", rows " .. rows(m) .. "| mount " .. tostring(mount ~= nil)
		.. " rows " .. rows(mount) .. "| can_charge " .. tostring(F.can_charge) .. " can_jump " .. tostring(F.can_jump)
	local e, d = nearest(u)
	R.enemy, R.dist0 = e and e:type(), d and math.floor(d)
	R.target = e
	if R.whole then phase("whole") return end
	local uc = bm:get_player_army():create_unit_controller()
	uc:add_units(u)
	uc:set_invincible(true) -- the test's scaffold, not the pack's
	R.uc = uc
	uc:attack_unit(e, true, true)
	phase("approach")
end
local function swing_now()
	local L0 = F.lock
	E.combat.melee(now(), true)
	local L = F.lock
	local sw = {t = math.floor((os.clock() - R.t0) * 10) / 10, guard = P.guard == guard, lock = L ~= nil and L ~= L0,
		slot = L and L.slot, L = L, melee = R.u:is_in_melee()}
	R.swings[#R.swings + 1] = sw
end
local function sample()
	local m = R.whole and P.models(R.u)[1] or R.m
	if not m then return end
	local c = name(mr.read_pointer(m, 0x330))
	local k = st .. ":" .. c
	local e = R.cmds[k]
	if not e then e = {n = 0, clips = {}, list = ""} R.cmds[k] = e end
	e.n = e.n + 1
	local clip = tostring(P.anim_slot(m))
	if not e.clips[clip] then e.clips[clip] = true e.list = e.list .. clip .. " " end
	for _, sw in ipairs(R.swings) do
		if sw.L and sw.L.seen then sw.seen = true end
		if sw.L and not sw.first and P.anim_slot(m) == sw.slot then sw.first = math.floor((os.clock() - R.t0 - sw.t) * 100) / 100 end
	end
end
local SWING_GAP = 3
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		if T.done then return end
		if not R then next_unit() return end
		if st == "next" then return end
		if bm:time_elapsed_ms() == last_ms then return end
		last_ms = bm:time_elapsed_ms()
		local el = os.clock() - t_phase
		if R.u:number_of_men_alive() == 0 then note("unit dead") finish_unit() return end
		if not F.on and st ~= "death" then note("third person went off") finish_unit() return end
		sample()
		if st == "whole" then
			if math.floor(el) ~= R.sec then
				R.sec = math.floor(el)
				local q = R.u:position()
				note("dist " .. math.floor(q:distance_xz(R.target:position())) .. " melee " .. tostring(R.u:is_in_melee())
					.. " moving " .. tostring(R.u:is_moving()) .. " lock " .. tostring(F.lock and F.lock.slot))
			end
			if not R.next_sw or el >= R.next_sw then R.next_sw = el + SWING_GAP swing_now() end
			if el > 15 then finish_unit() end
		elseif st == "approach" then
			if R.u:is_in_melee() and el > 2 then phase("swings_guard") R.next_sw = 0
			elseif el > 35 then note("never reached melee") phase("swings_guard") R.next_sw = 0 end
		elseif st == "swings_guard" or st == "swings_noguard" then
			if el >= R.next_sw and el < 4 * SWING_GAP then R.next_sw = R.next_sw + SWING_GAP swing_now() end
			if el >= 4 * SWING_GAP + 1 then
				if st == "swings_guard" then P.guard = function() return false end phase("swings_noguard") R.next_sw = 0
				else P.guard = guard phase("idle") end
			end
		elseif st == "idle" then
			if el > 8 then
				R.uc:set_invincible(false)
				R.dm = F.model
				phase("death")
			end
		elseif st == "death" then
			local m = R.dm
			if not m then note("no man played at the death phase") finish_unit() return end
			local hp = P.model_hp(m)
			local inl = P.alive(R.u, m)
			local played = F.on and F.model ~= nil and mr.eq(F.model, m)
			local s = "hp " .. tostring(hp) .. " in list " .. tostring(inl) .. " played " .. tostring(played) .. " clip "
				.. tostring(P.anim_slot(m)) .. " cmd " .. name(mr.read_pointer(m, 0x330))
			if s ~= R.last_s then
				R.last_s = s
				if hp <= 0 or not inl or not played then note(s) end
			end
			if (hp <= 0 or not inl) and not R.died then R.died = os.clock() end
			if R.died and os.clock() - R.died > 4 or el > 45 then
				if not R.died then note("he did not die in 45 s; hp " .. tostring(hp)) end
				finish_unit()
			end
		end
	end)
	if not ok then
		T.err = tostring(err)
		P.guard = guard
		pcall(finish_unit)
		T.done = true
	end
	if T.done then
		P.guard = guard
		if F.on then pcall(E.main.stop, "sweep over") end
		bm:remove_real_callback("tp_sweep")
	end
end, 30, "tp_sweep")
return "sweeping " .. #TYPES .. " units"
