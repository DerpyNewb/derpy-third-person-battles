-- Melee spam in a real melee (the author, 2026-10-16: "spamming melee button when near enemy still doesnt work. can you
-- test properly this time"). The pack plays one man of a regiment already in melee, where it stands; the attack key goes
-- down every PERIOD s for DURATION s through the shipped frame loop. Per swing the pack sends: its slot, his clip and
-- command then, whether his fragment was his regiment's (armed) at the send and at each frame until the clip started, and
-- when it started. His regiment is invincible for the test. _G.TP_MS_TYPE picks the unit type; _G.TP_MS_NODISARM = true
-- runs with P.disarm off (the comparison). _G.TP_MS_MODE: "pending" keeps him armed from a swing's send until it starts
-- (3 s at most); "cut" ends his block (the engine's defend command 3ae2de8) with the engine's own stop before the swing
-- is pushed. Read with zz_tp_melee_spam_read.lua; _G.TP_MS_STOP = true cancels.
-- Test scaffolding, not shipped. No string library calls.
local ok, result = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.main and mr) then return "load the pack in a battle first" end
	if _G.TP_MS and not _G.TP_MS.done then return "already running" end
	local P, F = E.P, E.F
	local PERIOD, DURATION, WAIT = _G.TP_MS_PERIOD or 0.25, _G.TP_MS_DURATION or 15, 2
	local function now() return bm:time_elapsed_ms() / 1000 end
	local want = _G.TP_MS_TYPE or "wh3_dlc29_emp_inf_teutogen_guard_ror"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 1 and x:is_in_melee() then u = x break end
	end
	if not u then return "no " .. want .. " in melee" end
	-- "gate": his update (exe+3086f04) sends a man with a queued action to the reset path (exe+30873e6) on any tick an
	-- order reached him; the engine's formation logic orders him every tick in melee, so a queued clip never starts. The
	-- jump at exe+3087388 is pointed at his action update (exe+30873dc) instead, for every man, for the test only
	local unpatch
	if _G.TP_MS_MODE == "gate" then
		local at = mr.add(mr.add(mr.base, 0x3080000), 0x7388)
		if mr.read_uint8(at, 0) ~= 0x75 or mr.read_uint8(at, 1) ~= 0x5c then error("gate bytes are not 75 5c on this build") end
		local site = mr.add(at, 1)
		local h = assert(mr.patcher("derpy_tp_probe"))
		local done, why = h:patch("queued_beats_order", site, mr.read(site, 0, 1), "R")
		if not done then error("gate patch refused: " .. tostring(why)) end
		unpatch = function() return h:remove("queued_beats_order") end
	end
	if F.on then E.main.stop("melee spam test") end
	local saved, saved_log = {}, E.log
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel", "play", "disarm", "gate"}) do saved[k] = P[k] end
	local T = {done = false, type = want, nodisarm = _G.TP_MS_NODISARM == true, sends = {}, log = {}, frames = 0,
		swing_frames = 0, presses = 0, clips = {}, cmds = {}, others = {}}
	_G.TP_MS, _G.TP_MS_STOP = T, false
	local attack = E.S.keys.attack
	local id = type(attack) == "table" and attack[1] or attack
	local function ours(k) return (type(k) == "table" and k[1] or k) == id end
	local down, was = false, false
	P.held = function(k) return down and ours(k) end
	P.pressed = function(k)
		if not ours(k) then return false end
		local e = down and not was
		was = down
		return e
	end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	if T.nodisarm then P.disarm = function() end end
	T.mode, T.cuts = _G.TP_MS_MODE, 0
	T.unpatch = unpatch
	-- "nogate": as shipped, with the pack's gate (platform.lua P.gate) left out - the comparison
	if T.mode == "nogate" then P.gate = function() return false end end
	if T.mode == "pending" or T.mode == "mask6" then
		P.disarm = function(m) if T.pending_until and now() < T.pending_until then return end return saved.disarm(m) end
	end
	-- "engine": a click lets the engine's own swing through once - armed, and its melee order left alone, from the send until
	-- an attack clip starts on him (1.5 s at most), then until that clip ends
	local melee_cmd = mr.add(mr.add(mr.base, 0x3ad0000), 0x24b8)
	if T.mode == "engine" then
		saved.guard = P.guard
		P.guard = function(m)
			if T.allow_until and now() < T.allow_until and mr.eq(mr.read_pointer(P.mount(m) or m, 0x330), melee_cmd) then return false end
			return saved.guard(m)
		end
		P.disarm = function(m) if T.allow_until and now() < T.allow_until then return end return saved.disarm(m) end
	end
	-- "nodefend": as shipped, but he never has a block clip (DEFEND_1-10, 474-483): armed, his regiment's fragment is swapped
	-- for a probe copy without them; disarmed, the pack's copy loses them too. Copies kept in _G.TP_MS_DEF for the battle
	if T.mode == "nodefend" then
		local D = _G.TP_MS_DEF or {of = {}, mine = {}, keep = {}}
		_G.TP_MS_DEF = D
		local SIZE = 0x50 + 6004 * 2
		local function nodef(c) for s = 474, 483 do mr.write(c, 0x50 + s * 2, mr.uint16(0xffff)) end end
		local function swap(x)
			local a = mr.read_pointer(x, 0x308)
			local k = mr.tostring(a)
			if mr.is_null(a) or D.mine[k] then return end
			local c = D.of[k]
			if not c then
				local b = mr.alloc(SIZE)
				D.keep[#D.keep + 1] = b
				c = mr.add(b, 0)
				for off = 0, SIZE - 8, 8 do mr.write(c, off, mr.read_pointer(a, off)) end
				nodef(c)
				D.of[k], D.mine[mr.tostring(c)] = c, a
			end
			mr.write(x, 0x308, c)
		end
		local function unswap(x)
			local o = D.mine[mr.tostring(mr.read_pointer(x, 0x308))]
			if o then mr.write(x, 0x308, o) end
		end
		saved.arm = P.arm
		P.arm = function(m)
			saved.arm(m)
			local b = P.mount(m)
			if b then swap(b) end
			swap(m)
		end
		-- the regiment's fragment for x's role, off another man: never written
		local function shared(x, m)
			for _, o in ipairs(P.models(u)) do
				if not P.same(o, m) then return mr.read_pointer(P.same(x, m) and o or (P.mount(o) or o), 0x308) end
			end
		end
		P.disarm = function(m)
			local b = P.mount(m)
			if b then unswap(b) end
			unswap(m)
			saved.disarm(m)
			local function strip(x)
				local c, s = mr.read_pointer(x, 0x308), shared(x, m)
				if not mr.is_null(c) and s and not mr.eq(c, s) and not D.mine[mr.tostring(c)] then nodef(c) end
			end
			if b then strip(b) end
			strip(m)
		end
		T.unswap = function() local m = F.model if m then local b = P.mount(m) if b then unswap(b) end unswap(m) end end
	end
	local defend = mr.add(mr.add(mr.base, 0x3ae0000), 0x2de8)
	local walk_stop = mr.add(mr.add(mr.base, 0x3060000), 0xedd4)
	E.log = function(msg)
		if #T.log < 80 then T.log[#T.log + 1] = math.floor(now() * 10) / 10 .. " " .. tostring(msg) end
		saved_log(msg)
	end
	local function attack_slot(s) return s and (s >= 454 and s <= 500 or s >= 1901 and s <= 1950) end
	local function vt(m) return mr.tostring(mr.read_pointer(P.mount(m) or m, 0x330)) end
	-- his two action slots: the queued one at +0x5c8 (has +0x6f8, started +0x6f9, action +0x5e0, done +0x600) and the
	-- running one at +0x490 (has +0x5c0, started +0x5c1, action +0x4a8, done +0x4c8); "c" = the clip action's vtable
	local clip_act = mr.add(mr.add(mr.base, 0x3900000), 0xc0b8)
	local function slot_state(m, has, act)
		if mr.read_uint8(m, has) ~= 1 then return "-" end
		local v = mr.read_pointer(m, act)
		return (mr.eq(v, clip_act) and "c" or mr.tostring(v)) .. mr.read_uint8(m, has + 1) .. mr.read_uint8(m, act + 0x20)
	end
	-- and his state word +0x324: the main update runs his actions only while it is 0 (exe+3087356); "q" when +0x128 is set
	local function acts(m)
		return slot_state(m, 0x6f8, 0x5e0) .. "/" .. slot_state(m, 0x5c0, 0x4a8) .. " s" .. mr.read_uint32(m, 0x324)
			.. (mr.is_null(mr.read_pointer(m, 0x128)) and "" or "q")
	end
	-- the main update's other inputs: flags +0x108 (bit 0x10 = his actions can run at all), +0xb10, +0x88a, his wait tick
	-- +0x884 against the battle's tick, and whether +0xb20 / +0x898 are set
	local function gate(m)
		local bat = mr.read_pointer(mr.read_pointer(m, 0x58), 0x440)
		return " f" .. mr.read_uint8(m, 0x108) .. " b" .. mr.read_uint8(m, 0xb10) .. " a" .. mr.read_uint8(m, 0x88a)
			.. " w" .. (mr.read_uint32(m, 0x884) - mr.read_uint32(bat, 0x98))
			.. (mr.is_null(mr.read_pointer(m, 0xb20)) and "" or " B") .. (mr.is_null(mr.read_pointer(m, 0x898)) and "" or " N")
	end
	-- his regiment's fragment for his role (a rider's or a horse's), off another man of the regiment
	local function armed(m)
		for _, o in ipairs(P.models(u)) do
			if not P.same(o, F.model) then
				local x = o
				if not P.same(m, F.model) then x = P.mount(o) or o end
				return mr.eq(mr.read_pointer(m, 0x308), mr.read_pointer(x, 0x308))
			end
		end
	end
	P.play = function(m, slot, mask)
		local s = attack_slot(slot) and {t = now(), slot = slot, clip = tostring(P.anim_slot(m)), cmd = vt(m), m = m,
			armed_before = armed(m), waits = {}, armed_frames = 0, disarmed_frames = 0}
		if s and T.mode == "cut" then
			local b = P.mount(m) or m
			if mr.eq(mr.read_pointer(b, 0x330), defend) then mr.call(walk_stop, "pointer(pointer)", b) T.cuts = T.cuts + 1 s.cut = true end
		end
		if s and (T.mode == "pending" or T.mode == "mask6") then T.pending_until = now() + 3 end
		if s and T.mode == "engine" then T.allow_until, T.allow_swing = now() + 1.5, nil end
		-- mask6: a swing sent while he blocks (ATTACK_IDLE / DEFEND, 464-483) goes full body
		local c0 = s and P.anim_slot(P.mount(m) or m)
		if s and T.mode == "mask6" and c0 and c0 >= 464 and c0 <= 483 then mask = 6 s.mask6 = true end
		local r = saved.play(m, slot, mask)
		if s then
			s.ok, s.armed_after, s.acts = r, armed(m), acts(m)
			T.sends[#T.sends + 1] = s
		end
		return r
	end
	local c = army:create_unit_controller()
	c:add_units(u)
	c:set_invincible(true)
	c:release_control()
	local function finish()
		down = false
		if F.on then pcall(E.main.stop, "melee spam test") end
		for k, f in pairs(saved) do P[k] = f end
		if T.unpatch then T.unpatched = tostring(select(2, pcall(T.unpatch))) end
		if T.unswap then pcall(T.unswap) end -- the stop's arm put him on the probe copy: his regiment's fragment back
		E.log = saved_log
		pcall(function() c:set_invincible(false) c:release_control() end)
		for _, s in ipairs(T.sends) do s.m = nil end
		T.done = true
		bm:remove_real_callback("tp_melee_spam")
	end
	T.finish = finish
	E.main.start(u)
	if not F.on or not F.model then finish() T.err = "could not start one man" return T.err end
	T.began, T.next_press, T.release = now(), now() + 0.5, nil
	local function bump(t, k) t[k] = (t[k] or 0) + 1 end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = now()
			if _G.TP_MS_STOP or E.disabled or not F.on or t - T.began > DURATION then finish() return end
			if T.release and t >= T.release then down, T.release = false, nil end
			if not down and t >= T.next_press then
				down, T.release, T.next_press = true, t + 0.05, t + PERIOD
				T.presses = T.presses + 1
			end
			local m = F.model
			if not m then return end
			T.frames = T.frames + 1
			local b = P.mount(m) or m
			local cl = P.anim_slot(b)
			bump(T.clips, tostring(cl))
			bump(T.cmds, vt(m))
			if attack_slot(cl) or attack_slot(P.anim_slot(m)) then T.swing_frames = T.swing_frames + 1 end
			-- a swing he did not send: the engine's own
			local last = T.sends[#T.sends]
			local mine = last and (cl == last.slot or P.anim_slot(m) == last.slot)
			if (attack_slot(cl) or attack_slot(P.anim_slot(m))) and not mine then
				T.other_frames = (T.other_frames or 0) + 1
				bump(T.others, tostring(cl) .. "/" .. tostring(P.anim_slot(m)))
			end
			-- any swing that starts after a send, the engine's or ours: the first frame an attack clip is on him that was not
			-- on him at the send
			local hc = P.anim_slot(m)
			local swinging = hc and (hc >= 454 and hc <= 463 or hc >= 484 and hc <= 500)
			for _, s in ipairs(T.sends) do
				if not s.any_at and t - s.t <= WAIT and swinging and tostring(hc) ~= s.clip then
					s.any_at, s.any_slot = math.floor((t - s.t) * 1000), hc
				end
			end
			if T.mode == "engine" and T.allow_until then
				-- once a swing is on him, armed until it ends; none within the window, the window closes
				if swinging then T.allow_swing = hc T.allow_until = math.max(T.allow_until, t + 0.1)
				elseif T.allow_swing then T.allow_until, T.allow_swing = nil, nil end
			end
			for _, s in ipairs(T.sends) do
				if s.m and not s.started_at and not s.failed then
					local now_clip = P.anim_slot(s.m)
					if now_clip == s.slot then
						s.started_at = math.floor((t - s.t) * 1000)
						T.pending_until = nil -- started: the lock and his swing arm him through the clip
					elseif t - s.t > WAIT then
						s.failed = true
					else
						bump(s.waits, tostring(now_clip) .. "@" .. vt(s.m) .. "@" .. acts(s.m))
						-- the same, in order: a row each time it changes
						local key = tostring(now_clip) .. "@" .. vt(s.m) .. "@" .. acts(s.m) .. gate(s.m)
						s.tl = s.tl or {}
						if key ~= s.last_key and #s.tl < 40 then s.tl[#s.tl + 1] = math.floor((t - s.t) * 1000) .. " " .. key s.last_key = key end
						if armed(s.m) then s.armed_frames = s.armed_frames + 1 else s.disarmed_frames = s.disarmed_frames + 1 end
					end
				end
			end
		end)
		if not worked then T.err = tostring(err) pcall(finish) end
	end, 1, "tp_melee_spam")
	return "melee spam on " .. want .. (T.nodisarm and ", disarm off" or ", disarm on") .. " for " .. DURATION .. " s"
end)
return ok and result or "ERR " .. tostring(result)
