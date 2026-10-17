-- The mailbox, live (2026-10-17, the crash fix: the guard's stop, the hold's stop and the steer's walk builder moved off
-- the script thread into a code cave at the top of his update; platform.lua, tools/third_person_cave.py). Test
-- scaffolding, run by the agent. Third person goes on one man of _G.TP_MB_TYPE (default teb_montante_greatswords);
-- nobody at the keys. Phases, every model tick:
--   walk  (_G.TP_MB_WALK s, default 6): the pack's own drive with W held and running (its tick's E.move.drive, forward
--         forced): how far he goes
--   hold  (4 s): the same drive, no key: how far he drifts after the first second
--   melee (_G.TP_MB_SECS s, default 60): his regiment ordered (a script unit controller, the test's) onto the nearest
--         enemy, invincible; how far he is carried, and the cave's counters
-- The block's counters (met: updates the cave matched him in; stops: the guard's stops) are what proves the cave runs
-- for him, on a horse too. No string library calls. Read back: zz_tp_mailbox_read.lua.
local E = _G.DERPY_TP
if not (E and E.P and E.main and E.P.build == "6acec6f4") then return "the pack on build 6acec6f4 first" end
local mr = _G.memreader_plus
if not mr then return "no memreader_plus" end
if _G.TP_MB and not _G.TP_MB.done then return "already running" end
local P, F = E.P, E.F
local MET, STOPS, MAN = 0x4c, 0x48, 0x0 -- the block's offsets (platform.lua MB)
local T = {phase = "start", log = "", done = false, mailbox = P.features.mailbox == true, problems = table.concat(P.problems, "; ")}
_G.TP_MB = T
if not P.mailbox then T.done = true T.err = "no mailbox: " .. T.problems return T.err end
local function at(hi, lo) return mr.add(mr.add(mr.base, hi), lo) end
local info = mr.hook_info(at(0x3080000, 0x6f04))
T.cave = info and info.kind or "none"
T.block_in_cave = info and info.cave and mr.eq(mr.read_pointer(info.cave, 2), P.mailbox) or false
T.block = mr.tostring(P.mailbox)
local function count(off) return mr.read_int32(P.mailbox, off) end
local want = _G.TP_MB_TYPE or "teb_montante_greatswords"
local WALK, SECS = _G.TP_MB_WALK or 6, _G.TP_MB_SECS or 60
local drive = E.move.drive
local ok, why = pcall(function()
	local army, u, have = bm:get_player_army(), nil, ""
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		have = have .. " " .. x:type()
		if not u and x:type() == want and x:number_of_men_alive() > 0 then u = x end
	end
	if not u then error("no " .. want .. "; the army:" .. have) end
	if F.on then E.main.stop("test") end
	E.main.start(u)
	if not (F.on and F.model) then error("third person did not go on one man") end
	T.unit = u
end)
if not ok then T.err = tostring(why) T.done = true return "not started: " .. T.err end
local m = F.model
local body = P.mount(m) or m
T.horse = not P.same(body, m)
T.man_is_body = mr.eq(mr.read_pointer(P.mailbox, MAN), body)
-- the pack's own drive, W forced while walking, nothing while holding: everything after the keys is the pack's
E.move.drive = function(now, kf, kr, run, speed)
	if T.phase == "walk" then return drive(now, 1, 0, true, 1) end
	return drive(now, 0, 0, run, speed)
end
local t0, last_ms, phase_t = os.clock(), nil, os.clock()
local x0, _, z0 = P.model_pos(body)
local px, pz, path = x0, z0, 0
local met0, stops0 = count(MET), count(STOPS)
T.walk_m, T.hold_m, T.melee_m, T.melee_net = 0, 0, 0, 0
local hx, hz
local function enter(name)
	T[T.phase .. "_met"] = count(MET) - met0
	T[T.phase .. "_stops"] = count(STOPS) - stops0
	met0, stops0 = count(MET), count(STOPS)
	T.phase, phase_t, path = name, os.clock(), 0
	T.log = T.log .. name .. " at " .. math.floor((os.clock() - t0) * 10) / 10 .. "; "
end
local function finish(why2)
	E.move.drive = drive
	pcall(function() if T.uc then T.uc:set_invincible(false) T.uc:release_control() end end)
	pcall(function() bm:remove_real_callback("zz_tp_mailbox") end)
	T.why_end = why2
	T.done = true
end
enter("walk")
bm:repeat_real_callback(function()
	local ok2, err = pcall(function()
		if T.done then return end
		if not (F.on and F.model and P.same(F.model, m)) then finish("third person changed") return end
		if bm:time_elapsed_ms() == last_ms then return end
		last_ms = bm:time_elapsed_ms()
		local x, _, z = P.model_pos(body)
		local step = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		px, pz, path = x, z, path + step
		local el = os.clock() - phase_t
		if T.phase == "walk" then
			T.walk_m = path
			if el >= WALK then enter("hold") end
		elseif T.phase == "hold" then
			if el >= 1 and not hx then hx, hz = x, z end
			if hx then T.hold_m = math.sqrt((x - hx) ^ 2 + (z - hz) ^ 2) end
			if el >= 4 then
				enter("melee")
				hx, hz = x, z
				local q, best, bd = T.unit:position(), nil, nil
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
				if not best then finish("no enemy") return end
				local uc = bm:get_player_army():create_unit_controller()
				uc:add_units(T.unit)
				uc:set_invincible(true)
				uc:attack_unit(best, true, true)
				T.uc, T.enemy, T.enemy_m = uc, best:type(), math.floor(bd)
			end
		elseif T.phase == "melee" then
			T.melee_m, T.melee_net = path, math.sqrt((x - hx) ^ 2 + (z - hz) ^ 2)
			T.melee_met, T.melee_stops = count(MET) - met0, count(STOPS) - stops0
			if el >= SECS then enter("end") finish("time") end
		end
	end)
	if not ok2 then T.err = tostring(err) finish("error") end
end, 30, "zz_tp_mailbox")
return "running: " .. want .. (T.horse and " (a rider)" or "") .. ", block " .. T.block
