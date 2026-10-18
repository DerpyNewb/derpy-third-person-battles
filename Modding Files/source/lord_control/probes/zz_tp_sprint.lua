-- Test scaffolding (2026-10-17, the author: "charging doesnt even speedup units. check chaos units in your testing").
-- Each unit of _G.TP_SP_TYPES in turn (default: every unit of one in the player's army that is not artillery or a war
-- machine) is teleported to the clearest 150 m of ground between the armies and played through the shipped frame loop
-- with synthetic keys: started directly, W held 4 s (the run), then W and Shift held 4 s (the sprint), stopped. Speeds are
-- over the last 3 s of each, from his body's position (the mount of a rider). Also read during the sprint: F.sprinting,
-- F.charging, his flying, the CHARGE (135) and FLY_CHARGE_AIR_TO_AIR (102) clips sent, and the walk speed in his command
-- (+0x394). Everyone invincible; the enemy stays held after (2026-10-18: let go, its AI ended two battles). Teleporting a
-- regiment broke its steering check ("a steering copy is not near its man"), so a regiment is not a default. Read with
-- zz_tp_sprint_read.lua; _G.TP_SP_STOP = true cancels. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.main and E.P) then return "no pack" end
	if _G.TP_SP and not _G.TP_SP.done then return "already running" end
	local P, F, mr = E.P, E.F, _G.memreader_plus
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel", "play"}) do saved[k] = P[k] end
	local keys, edges = {}, {}
	local T = {units = {}, done = false}
	_G.TP_SP, _G.TP_SP_STOP = T, false
	local cur
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
	P.play = function(m, slot, mask)
		if cur and slot == 135 then cur.charges = cur.charges + 1 end
		if cur and slot == 102 then cur.fly_charges = cur.fly_charges + 1 end
		return saved.play(m, slot, mask)
	end
	local function set(action, down)
		local k = E.S.keys[action]
		keys[type(k) == "table" and k[1] or k] = down or nil
	end
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function r1(x) return math.floor(x * 100 + 0.5) / 100 end
	local ours, uc_of, others = {}, {}, {}
	local function hold(army, u, mine)
		local c = army:create_unit_controller()
		c:add_units(u)
		c:set_invincible(true)
		c:halt()
		if mine then ours[#ours + 1] = c end
		uc_of[u:unique_ui_id()] = c
	end
	local ex, ez, en, px, pz, pn = 0, 0, 0, 0, 0, 0
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local u = ar:units():item(i)
			if u:number_of_men_alive() > 0 then
				hold(ar, u, false)
				local q = u:position()
				ex, ez, en = ex + q:get_x(), ez + q:get_z(), en + 1
				others[#others + 1] = u
			end
		end
	end
	local army = bm:get_player_army()
	local queue = {}
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		if u:number_of_men_alive() > 0 then
			hold(army, u, true)
			local q = u:position()
			px, pz, pn = px + q:get_x(), pz + q:get_z(), pn + 1
			local wanted
			if _G.TP_SP_TYPES then
				for _, ty in ipairs(_G.TP_SP_TYPES) do if ty == u:type() then wanted = true end end
			else
				wanted = u:number_of_men_alive() == 1 and not u:is_artillery() and not u:is_war_machine()
			end
			if wanted then queue[#queue + 1] = u else others[#others + 1] = u end
		end
	end
	if en == 0 or pn == 0 then return "no armies" end
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
	local function finish(why)
		T.done, T.why = true, why
		for k in pairs(keys) do keys[k] = nil end
		if F.on then pcall(E.main.stop, "sprint test") end
		for k, f in pairs(saved) do P[k] = f end
		for _, c in ipairs(ours) do pcall(function() c:release_control() end) end
		pcall(function() bm:remove_real_callback("tp_sprint") end)
	end
	local idx, rec, t0, step = 0, nil, nil, nil
	local function body()
		local man = F.model or F.single
		return man and (P.mount(man) or man)
	end
	local function pos() local b = body() if b then local x, _, z = P.model_pos(b) return x, z end local q = rec.u:position() return q:get_x(), q:get_z() end
	local function next_unit()
		idx = idx + 1
		local u = queue[idx]
		if not u then finish("all done") return end
		rec = {type = u:type(), u = u, charges = 0, fly_charges = 0, fast = r1(u:fast_speed())}
		T.units[#T.units + 1] = rec
		cur = rec
		local c = uc_of[u:unique_ui_id()]
		c:teleport_to_location(v(sx, bm:get_terrain_height(sx, sz), sz), math.deg(yaw) % 360, 30)
		c:release_control()
		bm:clear_selection()
		u:select_in_ui()
		t0, step = now(), "toggle_on"
	end
	next_unit()
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if _G.TP_SP_STOP then finish("stopped") return end
			local t = now() - t0
			if step == "toggle_on" and t >= 1.5 then
				local s_ok, s_err = pcall(E.main.start, rec.u)
				if not s_ok then rec.start_err = tostring(s_err) end
				step = "check_on"
			elseif step == "check_on" and t >= 2.3 then
				rec.on = F.on and F.unit and F.unit:unique_ui_id() == rec.u:unique_ui_id()
				rec.steered = (F.model or F.single) ~= nil
				if not rec.on then rec.skipped = "did not go on" step = "toggle_off" return end
				E.rig.yaw, E.rig.want_yaw = yaw, yaw
				set("forward", true)
				step = "run"
			elseif step == "run" then
				if t >= 3.3 and not rec.r0 then rec.r0 = {pos()} rec.r0[3] = t end
				if t >= 6.3 then
					local x, z = pos()
					rec.run = r1(math.sqrt((x - rec.r0[1]) ^ 2 + (z - rec.r0[2]) ^ 2) / (t - rec.r0[3]))
					rec.charges, rec.fly_charges = 0, 0
					set("sprint", true)
					step, rec.t_sprint = "sprint", t
				end
			elseif step == "sprint" then
				local ts = t - rec.t_sprint
				if ts >= 1 and not rec.s0 then rec.s0 = {pos()} rec.s0[3] = t end
				if ts >= 2 and not rec.seen then
					rec.seen = true
					rec.sprinting, rec.charging, rec.flying = F.sprinting, F.charging, rec.u:is_currently_flying()
					local b = body()
					if b then rec.cmd_speed = r1(mr.read_float(b, 0x394)) end
				end
				if ts >= 4 then
					local x, z = pos()
					rec.sprint = r1(math.sqrt((x - rec.s0[1]) ^ 2 + (z - rec.s0[2]) ^ 2) / (t - rec.s0[3]))
					rec.ratio = rec.run > 0 and r1(rec.sprint / rec.run) or -1
					rec.melee = rec.u:is_in_melee()
					set("sprint", false) set("forward", false)
					step = "toggle_off"
				end
			elseif step == "toggle_off" then pcall(E.main.stop, "sprint test") step = "off_check" rec.t_off = t
			elseif step == "off_check" and t >= rec.t_off + 1 then
				rec.u = nil
				cur = nil
				if E.disabled then finish("pack disabled") return end
				next_unit()
			end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_sprint")
	return "testing " .. #queue .. " units, lane " .. T.lane
end)
return ok and res or "ERR " .. tostring(res)
