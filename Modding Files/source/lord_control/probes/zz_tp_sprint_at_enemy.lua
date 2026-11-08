-- The sprint INTO an enemy (LockeNLoad 2026-11-03: "i cant sprint on Skarbrand, it takes the bar down but he doesnt
-- move faster"). zz_tp_sprint.lua runs in a clear lane; a player sprints at the enemy, where C.charge sends CA's attack order
-- within CHARGE_REACH. Each unit of one of the player's army (or _G.TP_CH_TYPES) is teleported START m from the
-- nearest held enemy regiment, facing it, and played through the shipped frame loop: W held RUN_S s, off, back to the
-- start, then W and Shift held RUN_S s. A sample every SAMPLE model s: time, distance to the enemy, F.sprinting,
-- F.charge_order, his command. Read with zz_tp_sprint_at_enemy_read.lua; _G.TP_CH_STOP = true cancels. No string library calls.
-- Switches: _G.TP_CH_START (m, default 40), _G.TP_CH_RUN_S (s), _G.TP_CH_SPRINT_ONLY (no run pass), _G.TP_CH_NOCHARGE
-- (C.charge stubbed out: the sprint without its attack order).
local START, RUN_S, SAMPLE = _G.TP_CH_START or 40, _G.TP_CH_RUN_S or 2.6, 0.2
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.main and E.P) then return "no pack" end
	if _G.TP_CH and not _G.TP_CH.done then return "already running" end
	local P, F = E.P, E.F
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
	-- the variant: no charge order from the sprint (C.sprint calls C.charge through the module table)
	local charge_was = E.combat.charge
	if _G.TP_CH_NOCHARGE then E.combat.charge = function() end end
	local keys, edges = {}, {}
	local T = {units = {}, done = false}
	_G.TP_CH, _G.TP_CH_STOP = T, false
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
	local function set(action, down)
		local k = E.S.keys[action]
		keys[type(k) == "table" and k[1] or k] = down or nil
	end
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function r1(x) return math.floor(x * 100 + 0.5) / 100 end
	local ours, uc_of = {}, {}
	local function hold(army, u, mine)
		local c = army:create_unit_controller()
		c:add_units(u)
		c:set_invincible(true)
		c:halt()
		if mine then ours[#ours + 1] = c end
		uc_of[u:unique_ui_id()] = c
	end
	local enemies = {}
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local u = ar:units():item(i)
			if u:number_of_men_alive() > 0 then
				hold(ar, u, false)
				if u:number_of_men_alive() > 1 then enemies[#enemies + 1] = u end
			end
		end
	end
	if #enemies == 0 then return "no enemy regiment" end
	local army = bm:get_player_army()
	local queue = {}
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		if u:number_of_men_alive() > 0 then
			hold(army, u, true)
			local wanted
			if _G.TP_CH_TYPES then
				for _, ty in ipairs(_G.TP_CH_TYPES) do if ty == u:type() then wanted = true end end
			else
				wanted = u:number_of_men_alive() == 1 and not u:is_artillery() and not u:is_war_machine()
			end
			if wanted then queue[#queue + 1] = u end
		end
	end
	local target = enemies[1]
	local tq = target:position()
	local tx, tz = tq:get_x(), tq:get_z()
	-- the start: START m from the target on the player's side of it
	local pq = army:units():item(1):position()
	local dx, dz = pq:get_x() - tx, pq:get_z() - tz
	local dn = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / dn, dz / dn
	local sx, sz = tx + dx * START, tz + dz * START
	local yaw = math.atan2(-dx, -dz)
	T.target = target:type()
	local function finish(why)
		T.done, T.why = true, why
		for k in pairs(keys) do keys[k] = nil end
		if F.on then pcall(E.main.stop, "charge test") end
		for k, f in pairs(saved) do P[k] = f end
		E.combat.charge = charge_was
		for _, c in ipairs(ours) do pcall(function() c:release_control() end) end
		pcall(function() bm:remove_real_callback("tp_charge") end)
	end
	local idx, rec, t0, step, pass, last = 0, nil, nil, nil, nil, nil
	local function body()
		local man = F.model or F.single
		return man and (P.mount(man) or man)
	end
	local function pos()
		local b = body()
		if b then local x, _, z = P.model_pos(b) return x, z end
		local q = rec.u:position() return q:get_x(), q:get_z()
	end
	local function place()
		-- a fresh controller each time: the one made at the start lost the unit to third person's own (pass 2 stayed put)
		local c = army:create_unit_controller()
		c:add_units(rec.u)
		c:halt()
		c:teleport_to_location(v(sx, bm:get_terrain_height(sx, sz), sz), math.deg(yaw) % 360, 30)
		ours[#ours + 1] = c
		c:release_control()
		bm:clear_selection()
		rec.u:select_in_ui()
	end
	local function next_unit()
		idx = idx + 1
		local u = queue[idx]
		if not u then finish("all done") return end
		rec = {type = u:type(), u = u, run = {}, sprint = {}}
		T.units[#T.units + 1] = rec
		pass = _G.TP_CH_SPRINT_ONLY and "sprint" or "run"
		place()
		t0, step = now(), "on"
	end
	next_unit()
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if _G.TP_CH_STOP then finish("stopped") return end
			local t = now() - t0
			if step == "on" and t >= 1.5 then
				local s_ok, s_err = pcall(E.main.start, rec.u)
				if not s_ok then rec.start_err = tostring(s_err) end
				step = "check"
			elseif step == "check" and t >= 2.3 then
				if not (F.on and F.single) then rec.skipped = "on " .. tostring(F.on) .. ", single " .. tostring(F.single ~= nil) step = "off" return end
				E.rig.yaw, E.rig.want_yaw = yaw, yaw
				set("forward", true)
				if pass == "sprint" then set("sprint", true) end
				step, rec.t_go, last = "go", t, -1
			elseif step == "go" then
				local tg = t - rec.t_go
				if tg - last >= SAMPLE then
					last = tg
					local x, z = pos()
					local b = body()
					local s = rec[pass]
					s[#s + 1] = {t = tg, x = x, z = z, d = math.sqrt((x - tx) ^ 2 + (z - tz) ^ 2), sp = F.sprinting,
						co = F.charge_order ~= nil, cmd = b and P.command(b), stam = F.stamina, melee = rec.u:is_in_melee(),
						slot = b and P.anim_slot(b), na = F.native_attack}
				end
				if tg >= RUN_S then set("forward", false) set("sprint", false) step = "off" end
			elseif step == "off" then pcall(E.main.stop, "charge test") step = "off_wait" rec.t_off = t
			elseif step == "off_wait" and t >= rec.t_off + 1 then
				if E.disabled then finish("pack disabled") return end
				if pass == "run" and not rec.skipped then
					pass = "sprint"
					place()
					t0, step = now(), "on"
				else
					rec.u = nil
					next_unit()
				end
			end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_charge")
	return "testing " .. #queue .. " units at " .. T.target
end)
return ok and res or "ERR " .. tostring(res)
