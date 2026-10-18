-- Test scaffolding (2026-10-18, the author: "mutalith is spamming the melee button, its like the actions are queued or
-- still auto attacking", "pressing charge attack as well repeats the charge animation randomly", "harald hammerstorm
-- running/sprinting not even fixed"). A unit of one (_G.TP_OT_TYPE) is teleported to the clearest 150 m between the
-- armies and played through the shipped frame loop with synthetic keys, on a script (_G.TP_OT_SCRIPT):
--   "walk"   W 3 s, then a click at 3, 5.5 and 8 s with W still held, W up at 10 s
--   "sprint" W 3 s, Shift from 3 s, a click at 5 s (the charge attack) and 7.5 s, Shift up at 9.5 s, W up at 11 s
--   "spam"   standing, a click every 0.3 s for 6 s
-- _G.TP_OT_GATE = true puts the pack's order gate (platform.lua P.gate) in for him, as for one man of a regiment.
-- Every frame his state is read and a row kept each time it changes: his body's clip (and a rider's), his command's
-- kind, his two action slots and his order word +0x324 (melee_spam's acts()), the pack's lock, pending, sprint and
-- charge. Also: each clip the pack sends, each attack clip that starts on him, the frames with an order word set, and
-- his speed every 0.5 s. Read with zz_tp_one_timeline_read.lua; _G.TP_OT_STOP = true cancels. No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.main and E.P and mr) then return "no pack" end
	if _G.TP_OT and not _G.TP_OT.done then return "already running" end
	local P, F = E.P, E.F
	local want = _G.TP_OT_TYPE or "wh3_pro11_chs_cha_harald_hammerstorm"
	local script = _G.TP_OT_SCRIPT or "walk"
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel", "play"}) do saved[k] = P[k] end
	local keys, edges = {}, {}
	local T = {done = false, type = want, script = script, gate = _G.TP_OT_GATE == true, rows = {}, sent = {}, starts = {},
		orders = {}, speeds = {}, clicks = {}}
	_G.TP_OT, _G.TP_OT_STOP = T, false
	function P.held(k)
		if type(k) == "table" then for _, x in ipairs(k) do if keys[x] then return true end end return false end
		return keys[k] == true
	end
	function P.pressed(k)
		local i = type(k) == "table" and k[1] or k
		if not i then return false end
		local d = P.held(k)
		local e = d and not edges[i]
		edges[i] = d
		return e
	end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function r1(x) return math.floor(x * 100 + 0.5) / 100 end
	local function at(off) return mr.add(mr.add(mr.base, off - off % 0x10000), off % 0x10000) end
	local VT = {[mr.tostring(at(0x3919350))] = "walkA", [mr.tostring(at(0x3ae2400))] = "walkB",
		[mr.tostring(at(0x39199f8))] = "moveA", [mr.tostring(at(0x3ae1928))] = "moveB",
		[mr.tostring(at(0x3ad24b8))] = "melee", [mr.tostring(at(0x3ae2de8))] = "defend"}
	local clip_act = at(0x390c0b8)
	local function vt(m) -- the command lives at +0x330, its vtable first (platform.lua P.command)
		local p = mr.tostring(mr.read_pointer(m, 0x330))
		return VT[p] or p
	end
	local function slot_state(m, has, act)
		if mr.read_uint8(m, has) ~= 1 then return "-" end
		local a = mr.read_pointer(m, act)
		return (mr.eq(a, clip_act) and "c" or "x") .. mr.read_uint8(m, has + 1) .. mr.read_uint8(m, act + 0x20)
	end
	local function acts(m) return slot_state(m, 0x6f8, 0x5e0) .. "/" .. slot_state(m, 0x5c0, 0x4a8) end
	-- his main update's other inputs (zz_tp_melee_spam.lua gate()): flags +0x108 (0x10: his actions can run), +0xb10,
	-- +0x88a, his wait tick +0x884 against the battle's
	local function inputs(m)
		local bat = mr.read_pointer(mr.read_pointer(m, 0x58), 0x440)
		return " f" .. mr.read_uint8(m, 0x108) .. " b" .. mr.read_uint8(m, 0xb10) .. " a" .. mr.read_uint8(m, 0x88a)
			.. " t" .. (mr.read_uint32(m, 0x884) - mr.read_uint32(bat, 0x98))
			-- +0xb20 set: his update calls vtable +0x490 instead of the action branch the gate is in (exe+3086f04);
			-- +0x128 set: a queued order he waits on (condition A)
			.. (mr.is_null(mr.read_pointer(m, 0xb20)) and "" or " B") .. (mr.is_null(mr.read_pointer(m, 0x128)) and "" or " Q")
	end
	local function attack(s) return s and (s >= 454 and s <= 463 or s >= 484 and s <= 500 or s >= 1901 and s <= 1950) end
	local t0 = now()
	-- each click the frame loop hands combat, with what could refuse it
	local attack0 = E.combat.attack
	T.got = {}
	E.combat.attack = function(gnow, clicked, held)
		if clicked and #T.got < 20 then
			local L = F.lock
			T.got[#T.got + 1] = r1(now() - t0) .. " lock " .. tostring(L and L.slot) .. " till " .. tostring(L and r1(L.till - gnow))
				.. " next_swing " .. r1((F.next_swing or 0) - gnow) .. " queued " .. tostring(F.queued ~= nil) .. " ranged "
				.. tostring(F.ranged) .. " charging " .. tostring(F.charging)
		end
		return attack0(gnow, clicked, held)
	end
	-- _G.TP_OT_NORESEND: the sprint's charge clip (CHARGE 135, FLY_CHARGE 102) is not sent again while it still plays
	P.play = function(m, slot, mask)
		if _G.TP_OT_NORESEND and (slot == 135 or slot == 102) and P.anim_slot(m) == slot then
			if #T.sent < 120 then T.sent[#T.sent + 1] = r1(now() - t0) .. " " .. slot .. " dropped" end
			return true
		end
		local r = saved.play(m, slot, mask)
		if #T.sent < 120 then T.sent[#T.sent + 1] = r1(now() - t0) .. " " .. slot .. " m" .. tostring(mask or 0) .. (r and "" or " refused") end
		return r
	end
	local function set(action, down)
		local k = E.S.keys[action]
		keys[type(k) == "table" and k[1] or k] = down or nil
	end
	-- the clearest lane, as zz_tp_sprint.lua
	local army, u = bm:get_player_army(), nil
	local ex, ez, en, px, pz, pn, others, foes = 0, 0, 0, 0, 0, 0, {}, {}
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local l = all:item(a):units()
		for i = 1, l:count() do
			local e = l:item(i)
			if e:number_of_men_alive() > 0 then local q = e:position() ex, ez, en = ex + q:get_x(), ez + q:get_z(), en + 1 others[#others + 1] = e foes[#foes + 1] = e end
		end
	end
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:number_of_men_alive() > 0 then
			local q = x:position()
			px, pz, pn = px + q:get_x(), pz + q:get_z(), pn + 1
			if not u and x:type() == want then u = x else others[#others + 1] = x end
		end
	end
	if not u then return "no " .. want end
	if en == 0 then return "no enemy" end
	ex, ez, px, pz = ex / en, ez / en, px / pn, pz / pn
	local dx, dz = ex - px, ez - pz
	local dn = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / dn, dz / dn
	local mx, mz = (px + ex) / 2, (pz + ez) / 2
	local function room(ax, az, lx, lz)
		local best = 1e9
		for _, o in ipairs(others) do
			local q = o:position()
			local rx, rz = q:get_x() - ax, q:get_z() - az
			local t = math.max(0, math.min(150, rx * lx + rz * lz))
			local d = math.sqrt((rx - lx * t) ^ 2 + (rz - lz * t) ^ 2)
			if d < best then best = d end
		end
		return best
	end
	local sx, sz, lx, lz, best
	for k = -4, 4 do
		for side = -2, 2 do
			for dir = -1, 1, 2 do
				local ax, az = mx + dx * k * 25 + dz * side * 50, mz + dz * k * 25 - dx * side * 50
				local r = room(ax, az, dz * dir, -dx * dir)
				if not best or r > best then sx, sz, lx, lz, best = ax, az, dz * dir, -dx * dir, r end
			end
		end
	end
	local yaw = math.atan2(lx, lz)
	T.lane = r1(sx) .. "," .. r1(sz) .. " room " .. r1(best) .. " m"
	if F.on then pcall(E.main.stop, "timeline test") end
	local c = army:create_unit_controller()
	c:add_units(u)
	c:set_invincible(true)
	-- _G.TP_OT_STAY: where he is (a melee zz_tp_engage.lua set up), facing the nearest enemy
	if _G.TP_OT_STAY then
		local q, bd = u:position(), nil
		for _, e in ipairs(foes) do
			local p = e:position()
			local d = (p:get_x() - q:get_x()) ^ 2 + (p:get_z() - q:get_z()) ^ 2
			if not bd or d < bd then bd, yaw = d, math.atan2(p:get_x() - q:get_x(), p:get_z() - q:get_z()) end
		end
	else
		c:teleport_to_location(v(sx, bm:get_terrain_height(sx, sz), sz), math.deg(yaw) % 360, 30)
	end
	c:release_control()
	_G.TP_OT_UC = c -- kept for the battle: a local one dies with the probe
	bm:clear_selection()
	u:select_in_ui()
	local gated = false
	local function finish(why)
		T.done, T.why = true, why
		for k in pairs(keys) do keys[k] = nil end
		if F.on then pcall(E.main.stop, "timeline test") end
		if gated then T.ungated = tostring(P.gate(false)) end
		for k, f in pairs(saved) do P[k] = f end
		E.combat.attack = attack0
		pcall(function() bm:remove_real_callback("tp_one_timeline") end)
	end
	-- the script: {t from the first key, action, down}
	local plan = {}
	local function click(t) plan[#plan + 1] = {t, "attack", true} plan[#plan + 1] = {t + 0.05, "attack", false} end
	if script == "walk" then
		plan[1] = {0, "forward", true}
		click(3) click(5.5) click(8)
		plan[#plan + 1] = {10, "forward", false}
		T.length = 12
	elseif script == "sprint" then
		plan[1] = {0, "forward", true}
		plan[2] = {3, "sprint", true}
		click(5) click(7.5)
		plan[#plan + 1] = {9.5, "sprint", false}
		plan[#plan + 1] = {11, "forward", false}
		T.length = 13
	elseif script == "sprintturn" then -- the sprint, the camera turned 35 deg (past swing()'s TURN_DEG) just before the click
		plan[1] = {0, "forward", true}
		plan[2] = {2, "sprint", true}
		plan[3] = {4.9, "yaw", 0.6}
		click(5)
		plan[#plan + 1] = {9.5, "sprint", false}
		plan[#plan + 1] = {11, "forward", false}
		T.length = 13
	elseif script == "turn" then -- walk, stop, the camera turned 60 deg, a click (swing()'s turn order), again, a jump
		plan[1] = {0, "forward", true} plan[2] = {2, "forward", false}
		plan[3] = {2.5, "yaw", 1.05}
		click(3) click(7.5)
		plan[#plan + 1] = {8.5, "yaw", -1.05}
		plan[#plan + 1] = {9, "jump", true} plan[#plan + 1] = {9.05, "jump", false}
		T.length = 13
	elseif script == "combo" then -- the author's log: swings lost after a jump attack
		plan[1] = {0, "jump", true} plan[2] = {0.05, "jump", false}
		for k = 1, 20 do click(k * 0.4) end
		plan[#plan + 1] = {4.1, "jump", true} plan[#plan + 1] = {4.15, "jump", false}
		table.sort(plan, function(a, b) return a[1] < b[1] end)
		T.length = 11
	else
		for k = 0, 19 do click(k * 0.3) end
		T.length = 9
	end
	local step, tk, pi, last, lpos = "toggle_on", nil, 1, nil, nil
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = now() - t0
			if _G.TP_OT_STOP then finish("stopped") return end
			if step == "toggle_on" and t >= 1.5 then
				pcall(E.main.start, u)
				step = "check_on"
			elseif step == "check_on" and t >= 2.3 then
				if not (F.on and F.single) then finish("not steered as a unit of one: model " .. tostring(F.model ~= nil)) return end
				if T.gate then gated = P.gate(true) T.gated = gated end
				-- _G.TP_OT_YAW_OFF: the camera that many radians off his bearing, as the author plays (the hard case: a probe
				-- that kept the camera on his bearing never took swing()'s turn order)
				local y = yaw + (_G.TP_OT_YAW_OFF or 0)
				E.rig.yaw, E.rig.want_yaw = y, y
				T.yaw0 = r1(math.deg(yaw) % 360)
				step, tk = "run", t
			end
			if step ~= "run" then return end
			local tt = t - tk
			while plan[pi] and tt >= plan[pi][1] do
				if plan[pi][2] == "yaw" then
					local y = E.rig.yaw + plan[pi][3]
					E.rig.yaw, E.rig.want_yaw = y, y
				else set(plan[pi][2], plan[pi][3]) end
				if plan[pi][3] and plan[pi][2] ~= "forward" then T.clicks[#T.clicks + 1] = r1(tt) .. plan[pi][2] .. tostring(plan[pi][3]) end
				pi = pi + 1
				-- a press gets a frame of its own: the model clock steps 0.1-0.2 s, and a press and its release 0.05 s later
				-- taken in one callback were never down (the second click of "turn", twice)
				if plan[pi - 1][3] == true then break end
			end
			if tt >= T.length then finish("time") return end
			if not (F.on and F.single) then finish("off") return end
			local man = F.single
			local b = P.mount(man) or man
			local cl, rc = P.anim_slot(b), P.mount(man) and P.anim_slot(man)
			local word = mr.read_uint32(b, 0x324)
			if word ~= 0 then T.orders[tostring(word)] = (T.orders[tostring(word)] or 0) + 1 end
			if attack(cl) and cl ~= T.lastcl then T.starts[#T.starts + 1] = r1(tt) .. " " .. cl end
			T.lastcl = cl
			local L = F.lock
			local key = tostring(cl) .. (rc and ("/r" .. rc) or "") .. " " .. vt(b) .. " " .. acts(b) .. " w" .. word .. inputs(b)
				.. " L" .. tostring(L and L.slot) .. (L and L.seen and "s" or "") .. (F.pending and (" P" .. F.pending.slot) or "")
				.. (F.sprinting and " SPR" or "") .. (F.charging and " CHG" or "")
			if key ~= last and #T.rows < 400 then T.rows[#T.rows + 1] = r1(tt) .. " " .. key last = key end
			local x, _, z = P.model_pos(b)
			if not lpos then lpos = {x, z, tt}
			elseif tt - lpos[3] >= 0.5 then
				T.speeds[#T.speeds + 1] = r1(lpos[3]) .. ":" .. r1(math.sqrt((x - lpos[1]) ^ 2 + (z - lpos[2]) ^ 2) / (tt - lpos[3]))
					.. " unit " .. r1(F.unit:bearing()) .. " his " .. r1(mr.read_uint16(b, 0xb0) * 360 / 0x10000)
				lpos = {x, z, tt}
			end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_one_timeline")
	return "running " .. script .. " on " .. want .. (T.gate and ", gated" or "") .. ", lane " .. T.lane
end)
return ok and res or "ERR " .. tostring(res)
