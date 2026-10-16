-- Exercise the shipped frame loop with synthetic keys, not direct combat calls. Single-player test only.
-- Read with zz_tp_input_sweep_read.lua; set TP_INPUT_STOP to cancel and restore input/controllers.
-- TP_INPUT_DEATH writes real HP zero. Restart the unsaved battle afterward; restoring HP does not undo death state.
local ok, result = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.main and mr) then return "load the pack in a battle first" end
	if _G.TP_INPUT and not _G.TP_INPUT.done then return "already running" end
	local P, F, keys, edges = E.P, E.F, {}, {}
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
	local T = {units = {}, controllers = {}, done = false, i = 0}
	_G.TP_INPUT, _G.TP_INPUT_STOP = T, false
	function P.held(k)
		if type(k) == "table" then for _, v in ipairs(k) do if keys[v] then return true end end return false end
		return keys[k] == true
	end
	function P.pressed(k)
		local id = type(k) == "table" and k[1] or k
		if not id then return false end
		local down = P.held(k)
		local edge = down and not edges[id]
		edges[id] = down
		return edge
	end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	local function key(action)
		local k = E.S.keys[action]
		keys[type(k) == "table" and k[1] or k] = true
	end
	local function controller(army, u, hold)
		local c = army:create_unit_controller()
		c:add_units(u)
		c:set_invincible(true)
		if hold then c:halt() else c:release_control() end
		T.controllers[#T.controllers + 1] = c
		return c
	end
	local army, enemies = bm:get_player_army(), {}
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local u = ar:units():item(i)
			if u:number_of_men_alive() > 0 then enemies[#enemies + 1] = {u = u, uc = controller(ar, u, true)} end
		end
	end
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		local uc = controller(army, u)
		local hx, hz = -190 + ((i - 1) % 5) * 45, -230 + math.floor((i - 1) / 5) * 35
		uc:halt()
		uc:teleport_to_location(v(hx, bm:get_terrain_height(hx, hz), hz), 0, 30)
		uc:release_control()
		local wanted = not _G.TP_INPUT_TYPES
		for _, ty in ipairs(_G.TP_INPUT_TYPES or {}) do if ty == u:type() then wanted = true end end
		if wanted and u:number_of_men_alive() > 0 then
			T.units[#T.units + 1] = {type = u:type(), u = u, uc = uc, home = {hx, hz}, checks = {}, events = {}, clips = {}, commands = {}}
		end
	end
	local priority = {hef_calith_gatekeepers = 1, wh2_dlc10_hef_inf_everqueens_court_guards_ror_0 = 2,
		wh2_main_hef_cha_tyrion_1 = 3, wh2_main_hef_cav_dragon_princes = 4, wh2_dlc10_hef_cav_the_fireborn_ror_0 = 5,
		wh2_dlc10_hef_inf_keepers_of_the_flame_ror_0 = 6}
	table.sort(T.units, function(a, b)
		local pa, pb = priority[a.type] or 100, priority[b.type] or 100
		if pa ~= pb then return pa < pb end
		return a.u:unique_ui_id() < b.u:unique_ui_id()
	end)
	local R, phase, began, sent, swing
	local guard = P.guard
	local melee_cmd = mr.add(mr.add(mr.base, 0x3ad0000), 0x24b8)
	local clip_cmd = mr.add(mr.add(mr.base, 0x3910000), 0x1fb0)
	P.guard = function(m)
		local stopped = guard(m)
		if R and phase == "idle_melee" then
			local b = P.mount(m) or m
			if mr.eq(mr.read_pointer(b, 0x330), melee_cmd) then R.guard_survived = (R.guard_survived or 0) + 1 end
		end
		return stopped
	end
	local launch = bm.trigger_projectile_launch
	bm.trigger_projectile_launch = function(self, projectile, from, to)
		if R and (phase == "shot" or phase == "shot_high") then
			R.launches = (R.launches or 0) + 1
			R.last_launch = {from:get_x(), from:get_y(), from:get_z(), to:get_x(), to:get_y(), to:get_z()}
		end
		return launch(self, projectile, from, to)
	end
	P.look_delta = function()
		if phase == "shot_high" then return 0, E.S.invert_y and 1000 or -1000 end
		if phase ~= "shot" or not (R.enemy and E.rig.ex) then return 0, 0 end
		local target = P.models(R.enemy.u)[1]
		if not target then return 0, 0 end
		local x, y, z = P.model_pos(target)
		local body = E.D.bodies[R.enemy.u:type()] or {0.5, 1.8}
		y = y + body[2] * 0.6
		R.chest = {x, y, z}
		local dx, dz = x - E.rig.ex, z - E.rig.ez
		local yaw = math.atan2(dx, dz)
		local pitch = -math.atan2(y - E.rig.ey, math.sqrt(dx * dx + dz * dz))
		local turn = (yaw - E.rig.yaw + math.pi) % (2 * math.pi) - math.pi
		return turn / E.S.sensitivity, (pitch - E.rig.pitch) / E.S.sensitivity * (E.S.invert_y and -1 or 1)
	end
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function note(s) if R and #R.events < 120 then R.events[#R.events + 1] = s end end
	local function pos()
		if F.model then return P.model_pos(F.model) end
		local q = R.u:position() return q:get_x(), q:get_y(), q:get_z()
	end
	local function enter(p)
		phase, began, sent, swing = p, now(), false, nil
		keys = {}
		R.phase = p
		note(p)
		if F.on then R.x0, R.y0, R.z0 = pos() end
	end
	local function verdict(k, pass, detail) R.checks[k] = (pass and "PASS " or "FAIL ") .. detail end
	local function finish()
		keys = {}
		if F.on then pcall(E.main.stop, "input sweep") end
		for k, v in pairs(saved) do P[k] = v end
		P.guard = guard
		bm.trigger_projectile_launch = launch
		for _, c in ipairs(T.controllers) do pcall(function() c:set_invincible(false) c:release_control() end) end
		T.done = true
		bm:remove_real_callback("tp_input_sweep")
	end
	T.finish = finish
	local function next_unit()
		if F.on then E.main.stop("input sweep next") end
		if R and R.home then
			local h = R.home
			R.uc:halt()
			R.uc:teleport_to_location(v(h[1], bm:get_terrain_height(h[1], h[2]), h[2]), 0, 30)
			R.uc:release_control()
		end
		if R and R.enemy then R.enemy.uc:halt() end
		T.i = T.i + 1 R = T.units[T.i]
		if not R then finish() return end
		R.uc:halt()
		R.uc:teleport_to_location(v(-100, bm:get_terrain_height(-100, -350), -350), 180, 30)
		R.uc:release_control()
		local bd
		for _, e in ipairs(enemies) do
			local d = R.u:position():distance_xz(e.u:position())
			if not bd or d < bd then R.enemy, bd = e, d end
		end
		if R.enemy then
			R.enemy.uc:halt()
			R.enemy.uc:teleport_to_location(v(-100, bm:get_terrain_height(-100, -150), -150), 180, 30)
		end
		enter("prepare")
	end
	local function sample()
		local m = F.model or P.models(R.u)[1]
		if not m then return end
		m = P.mount(m) or m
		R.m = m
		local cl = P.anim_slot(m)
		local cmd = mr.tostring(mr.read_pointer(m, 0x330))
		local k = phase .. ":" .. cmd .. ":" .. tostring(cl)
		R.commands[k] = (R.commands[k] or 0) + 1
		if cl then R.clips[phase .. ":" .. cl] = (R.clips[phase .. ":" .. cl] or 0) + 1 end
		if F.lock then
			swing = swing or F.lock
			if F.lock.seen then R.seen = true end
		end
		if swing and swing.slot and swing.seen then R.seen = true end
		if phase == "sprint" and now() - began > 0.6 then
			R.charge_n = (R.charge_n or 0) + 1
			if cl ~= 135 then R.charge_bad = (R.charge_bad or 0) + 1 end
		end
		local attack = cl and (cl >= 454 and cl <= 463 or cl >= 484 and cl <= 500)
		if phase == "idle_melee" and now() - began > 3 and attack and not mr.eq(mr.read_pointer(m, 0x330), clip_cmd) then
			R.auto = (R.auto or 0) + 1
		end
		if phase == "idle_melee" and now() - began > 3 and cmd == mr.tostring(mr.add(mr.add(mr.base, 0x3ad0000), 0x24b8)) then
			R.engine_attack = (R.engine_attack or 0) + 1
		end
		if (phase == "shot" or phase == "shot_high") and F.shot then
			local s = F.shot
			R.pair = s.pair
			R.raise_slot, R.hold_slot, R.fire_slot = s.aim_slot, s.hold_slot, s.fire_slot
			if cl == s.aim_slot then R.raise_seen = true end
			if cl == s.hold_slot then R.hold_seen = true end
			if cl == s.fire_slot then R.fire_seen = true end
		end
		if P.model_hp(m) <= 0 then
			R.death_at = R.death_at or now()
			if F.model and P.same(F.model, m) then R.dead_control = now() - R.death_at end
		end
	end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if _G.TP_INPUT_STOP or E.disabled then finish() return end
			if not R then next_unit() return end
			local elapsed = now() - began
			keys = {}
			if phase == "prepare" then
				if elapsed > 1 then
					for _, m in ipairs(P.models(R.u)) do
						local x, _, z = P.model_pos(P.mount(m) or m)
						P.hold(m, x, z) -- teleport setup: discard destination copies from the previous arena
					end
					E.main.start(R.u)
					if not F.on then verdict("start", false, "could not start") next_unit() return end
					R.one_man = F.model ~= nil
					R.model = mr.tostring(F.model or P.models(R.u)[1])
					enter("settle")
				end
				return
			end
			if not F.on and phase ~= "death" then verdict("control", false, "ended in " .. phase) next_unit() return end
			if F.on then sample() end
			if phase == "settle" and elapsed > 5 then enter("walk")
			elseif phase == "walk" then
				key("forward")
				if elapsed > 3 then
					local x, _, z = pos() local d = math.sqrt((x - R.x0)^2 + (z - R.z0)^2)
					verdict("walk", d > 1, tostring(d) .. " m") enter("sprint")
				end
			elseif phase == "sprint" then
				key("forward") key("sprint")
				if elapsed > 3 then
					local x, _, z = pos()
					R.sprint_metres = math.sqrt((x - R.x0)^2 + (z - R.z0)^2)
				verdict("sprint", R.sprint_metres > 1 and (R.charge_n or 0) > 0 and (R.charge_bad or 0) == 0,
						tostring(R.charge_bad or 0) .. "/" .. tostring(R.charge_n or 0) .. " frames without CHARGE; " .. R.sprint_metres .. " m")
					enter("rest")
				end
			elseif phase == "rest" and elapsed > 1 and not R.stop_distance then
				local x, _, z = pos()
				R.stop_distance = math.sqrt((x - R.x0)^2 + (z - R.z0)^2)
				verdict("sprint_stop", R.stop_distance < 1, tostring(R.stop_distance) .. " m after release")
			elseif phase == "rest" then
				if F.ranged and elapsed < 0.2 then key("mode") end
				if elapsed > 2 then R.seen = false enter("swing_out") end
			elseif phase == "swing_out" or phase == "swing_melee" then
				if elapsed < 0.2 then key("attack") end
				if elapsed > 3 then
					verdict(phase, swing and swing.slot ~= nil and R.seen == true, "clip " .. tostring(swing and swing.slot) .. " seen " .. tostring(R.seen))
					if phase == "swing_out" then enter("approach")
					else enter("idle_melee") end
				end
			elseif phase == "approach" then
				if not R.enemy then verdict("melee", false, "no enemy") next_unit() return end
				if not sent then
					local x, _, z = pos()
					local tx, tz = x + math.sin(E.rig.yaw) * 15, z + math.cos(E.rig.yaw) * 15
					R.enemy.uc:teleport_to_location(v(tx, bm:get_terrain_height(tx, tz), tz), math.deg(E.rig.yaw) + 180, 30)
					R.uc:attack_unit(R.enemy.u, true, true) R.uc:release_control()
					R.enemy.uc:attack_unit(R.u, true, true) sent = true
				end
				if R.u:is_in_melee() and elapsed > 2 then R.seen = false enter("swing_melee")
				elseif elapsed > 40 then verdict("melee", false, "not reached in 40 s") next_unit() end
			elseif phase == "idle_melee" and elapsed > 6 then
				verdict("idle_melee", not R.auto and not R.guard_survived,
					tostring(R.auto or 0) .. " unsolicited attack frames; guard left " .. tostring(R.guard_survived or 0)
					.. " melee commands; " .. tostring(R.engine_attack or 0) .. " incoming melee frames sampled")
				if R.u:missile_range() > 0 and F.solo then enter("shot") else enter("death") end
			elseif phase == "shot" or phase == "shot_high" then
				if not sent then
					local x, _, z = pos()
					R.enemy.uc:halt()
					R.enemy.uc:teleport_to_location(v(x, bm:get_terrain_height(x, z + 60), z + 60), 180, 30)
					R.launches, R.raise_seen, R.hold_seen, R.fire_seen = 0, false, false, false
					if phase == "shot_high" then F.ready_at = 0 end -- test setup: waive the previous shot's reload
					sent = true
				end
				if not F.ranged and elapsed < 0.2 then key("mode")
				elseif elapsed > 2 and elapsed < 2.2 then key("attack") end
				if phase == "shot" and elapsed > 1.5 and elapsed < 2 then
					local ax, ay, az = E.combat.aim_point(R.u:missile_range())
					local c = R.chest
					if ax and c then R.aim_error = math.sqrt((ax-c[1])^2 + (ay-c[2])^2 + (az-c[3])^2) end
				end
				if elapsed > 8 then
					local played = R.launches > 0 and R.fire_seen and R.raise_seen and (not R.hold_slot or R.hold_seen)
					verdict(phase, played and (phase ~= "shot_high" or R.pair == "high"),
						tostring(R.pair) .. " pair, launches " .. R.launches .. ", raise/hold/fire " .. tostring(R.raise_seen) .. "/" .. tostring(R.hold_seen) .. "/" .. tostring(R.fire_seen))
					if phase == "shot_high" and not P.has_slot(F.model, 1558) and played then
						R.checks.shot_high = "SKIP no high fire clip; level fallback played and launched"
					end
					if phase == "shot" then
						verdict("aim_chest", R.aim_error and R.aim_error < 2, tostring(R.aim_error) .. " m from target chest")
						E.combat.drop(now()) enter("shot_high")
					else enter("death") end
				end
			elseif phase == "death" then
				if not _G.TP_INPUT_DEATH then R.checks.death = "SKIP HP-zero injection disabled" next_unit() return end
				if not F.model and R.u:number_of_men_alive() > 1 then
					R.checks.death = "SKIP whole regiment: no individual subject" next_unit() return
				end
				if not sent then
					R.dead = F.model or P.models(R.u)[1]
					local body = P.mount(R.dead) or R.dead
					R.dead_at = now()
					mr.write(body, 0xb1c, mr.int32(0)) -- test setup: retain the roster entry while its carrier reaches HP 0
					sent = true
				end
				local changed = not F.on or F.model and not P.same(F.model, R.dead)
				if changed or now() - R.dead_at >= 1 then
					verdict("death", changed and now() - R.dead_at <= 1,
						"HP-zero injection: control changed " .. tostring(changed) .. " in " .. tostring(now() - R.dead_at) .. " s")
					next_unit()
				end
			end
		end)
		if not worked then T.err = tostring(err) pcall(finish) end
	end, 1, "tp_input_sweep")
	return "testing " .. #T.units .. " player units via faked keys"
end)
return ok and result or "ERR " .. tostring(result)
