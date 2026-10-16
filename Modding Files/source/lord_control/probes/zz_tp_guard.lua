-- Holding the regiment's commands off the man third person plays, 2026-10-16 (the author: "battalion actions also affect
-- the unit which shouldnt be and its moving itself the unit whenever the battalion is affected, is it difficult to
-- completely separate the unit from the battalion actions?"). zz_tp_self_move.lua saw the engine put three commands of
-- its own on him besides the regiment's walk: 0x3ad24b8 (its melee: ATTACK clips with no click, once over a shot) and
-- 0x39199f8 / 0x3919b28 (moves: 1.1 m by himself, the regiment in melee). The engine's stop (exe+306edd4) destroys
-- whatever command he has and builds a stand (0x39126f0), no type check (disassembled). For 3 minutes, every 30 ms real
-- time, any of the four is stopped the moment it is on him; counted per command and per second, with the self-moves.
-- Build 6acec6f4 only. Writes: one native stop per engine command seen. No string library calls.
-- Read back: zz_tp_guard_read.lua. Stop early: _G.TP_GUARD.stop = true.
local E = _G.DERPY_TP
if not (E and E.P and E.S and E.P.build == "6acec6f4") then return "build 6acec6f4 and the pack first" end
local mr = _G.memreader_plus
if not mr then return "no memreader_plus" end
if _G.TP_GUARD and not _G.TP_GUARD.done then return "already running" end
local P, F, S = E.P, E.F, E.S
local function at(hi, lo) return mr.add(mr.add(mr.base, hi), lo) end
local STOP = at(0x3060000, 0xedd4)
local ENGINE = {
	{"regiment walk", at(0x3910000, 0x9350)}, {"move 9f8", at(0x3910000, 0x99f8)}, {"move b28", at(0x3910000, 0x9b28)},
	{"melee 4b8", at(0x3ad0000, 0x24b8)},
}
local T = {stops = {}, events = {}, done = false, ticks = 0, peak = 0}
_G.TP_GUARD = T
local t0, last_m, win, sec, in_sec = os.clock(), nil, nil, -1, 0
local function note(s)
	if #T.events < 300 then T.events[#T.events + 1] = math.floor((os.clock() - t0) * 10) / 10 .. "s " .. s end
end
local function keys()
	local k = S.keys
	return P.held(k.forward) or P.held(k.back) or P.held(k.left) or P.held(k.right)
end
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		T.ticks = T.ticks + 1
		if T.stop or os.clock() - t0 > 180 then T.done = true return end
		if not (F.on and F.model) or bm:time_elapsed_ms() == T.last_ms then return end
		T.last_ms = bm:time_elapsed_ms()
		local m, u = F.model, F.unit
		if not (last_m and P.same(last_m, m)) then last_m, win = m, nil note("playing " .. tostring(F.utype)) end
		local c = mr.read_pointer(m, 0x330)
		for _, e in ipairs(ENGINE) do
			if mr.eq(c, e[2]) then
				mr.call(STOP, "pointer(pointer)", m)
				T.stops[e[1]] = (T.stops[e[1]] or 0) + 1
				local s = math.floor(os.clock() - t0)
				if s ~= sec then sec, in_sec = s, 0 end
				in_sec = in_sec + 1
				if in_sec > T.peak then T.peak = in_sec end
				if T.stops[e[1]] <= 5 then
					note("stopped " .. e[1] .. ": melee " .. tostring(u:is_in_melee()) .. ", keys " .. tostring(keys())
						.. ", shot " .. tostring(F.shot ~= nil) .. ", action " .. tostring(F.lock ~= nil) .. ", now "
						.. mr.tostring(mr.read_pointer(m, 0x330)))
				end
			end
		end
		local x, _, z = P.model_pos(m)
		if keys() or F.shot or F.lock or not win then win = {t = os.clock(), x = x, z = z}
		elseif os.clock() - win.t >= 1 then
			local d = math.sqrt((x - win.x) ^ 2 + (z - win.z) ^ 2)
			if d > 0.5 then
				note("moved " .. math.floor(d * 10) / 10 .. " m by himself in 1 s, command " .. mr.tostring(c) .. ", melee "
					.. tostring(u:is_in_melee()) .. ", his clip " .. tostring(P.anim_slot(m)))
			end
			win = {t = os.clock(), x = x, z = z}
		end
	end)
	if not ok then T.err = tostring(err) T.done = true end
	if T.done then bm:remove_real_callback("tp_guard") end
end, 30, "tp_guard")
return "guarding 3 minutes"
