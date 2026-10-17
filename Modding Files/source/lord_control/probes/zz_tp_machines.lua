-- Test scaffolding (2026-10-17, the author: "test out artillery and warmachines with the mod"). Each unit of
-- _G.TP_MC_TYPES in turn (default: the player's artillery, war machines and 8-man Pyretitans), through the shipped frame
-- loop with synthetic keys: selected, F2 on, 3 s forward, then artillery the mode key into Manual fire and out again,
-- anything else that shoots fire held until 3 shots or the window ends, then F2 off. Enemies held and everyone
-- invincible. Read with zz_tp_machines_read.lua; _G.TP_MC_STOP = true cancels. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.main and E.P) then return "no pack" end
	if _G.TP_MC and not _G.TP_MC.done then return "already running" end
	local P, F = E.P, E.F
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
	local log_was, once_was = E.log, E.once
	local keys, edges = {}, {}
	local T = {units = {}, done = false, controllers = 0}
	_G.TP_MC, _G.TP_MC_STOP = T, false
	local cur -- the unit record whose log lines are being kept
	E.log = function(msg) if cur and #cur.log < 60 then cur.log[#cur.log + 1] = tostring(msg) end return log_was(msg) end
	E.once = function(tag, msg) if cur then cur.log[#cur.log + 1] = "ONCE " .. tostring(msg) end return once_was(tag, msg) end
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
	local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
	-- everyone invincible, the enemy held where it stands
	local ucs = {}
	local function hold(army, u, keep)
		local c = army:create_unit_controller()
		c:add_units(u)
		c:set_invincible(true)
		if keep then c:halt() else c:release_control() end
		ucs[#ucs + 1] = c
		T.controllers = T.controllers + 1
	end
	local enemies = {}
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local u = ar:units():item(i)
			if u:number_of_men_alive() > 0 then hold(ar, u, true) enemies[#enemies + 1] = u end
		end
	end
	local army = bm:get_player_army()
	local queue = {}
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		hold(army, u, false)
		local t = u:type()
		local wanted
		if _G.TP_MC_TYPES then
			for _, ty in ipairs(_G.TP_MC_TYPES) do if ty == t then wanted = true end end
		else
			wanted = u:is_artillery() or u:is_war_machine() or (u:number_of_men_alive() <= 8 and u:number_of_men_alive() > 1)
		end
		if wanted and u:number_of_men_alive() > 0 then queue[#queue + 1] = u end
	end
	local function nearest_enemy(u)
		local q = u:position()
		local best, bd
		for _, e in ipairs(enemies) do
			if e:number_of_men_alive() > 0 then
				local p = e:position()
				local d = (p:get_x() - q:get_x()) ^ 2 + (p:get_z() - q:get_z()) ^ 2
				if not bd or d < bd then best, bd = e, d end
			end
		end
		return best, bd and math.sqrt(bd)
	end
	local function finish(why)
		T.done, T.why = true, why
		for k in pairs(keys) do keys[k] = nil end
		if F.on then pcall(E.main.stop, "machines test") end
		for k, f in pairs(saved) do P[k] = f end
		E.log, E.once = log_was, once_was
		for _, c in ipairs(ucs) do pcall(function() c:set_invincible(false) c:release_control() end) end
		pcall(function() bm:remove_real_callback("tp_machines") end)
	end
	local idx, rec, t0, step = 0, nil, nil, nil
	local function next_unit()
		idx = idx + 1
		local u = queue[idx]
		if not u then finish("all done") return end
		rec = {type = u:type(), u = u, men = u:number_of_men_alive(), arty = u:is_artillery(), wm = u:is_war_machine(),
			range = u:missile_range(), log = {}, ammo = {}, shots = {}, readys = {}, strikes0 = E.strikes,
			faw0 = u:is_behaviour_active("fire_at_will"), defend0 = u:is_behaviour_active("defend")}
		T.units[#T.units + 1] = rec
		cur = rec
		local s = E.D.shots[rec.type]
		rec.reload = s and s[2]
		rec.window = math.min(40, 2 * (rec.reload or 8) * (E.S.reload_factor or 1) + 6)
		bm:clear_selection()
		u:select_in_ui()
		t0, step = now(), "toggle_on"
	end
	next_unit()
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if _G.TP_MC_STOP then finish("stopped") return end
			local u, t = rec.u, now() - t0
			if step == "toggle_on" and t >= 0.2 then set("toggle", true) step = "toggle_on_up"
			elseif step == "toggle_on_up" and t >= 0.4 then set("toggle", false) step = "check_on"
			elseif step == "check_on" and t >= 1 then
				local mine = F.unit and F.unit:unique_ui_id() == u:unique_ui_id()
				rec.on = F.on and mine
				rec.one_man, rec.solo, rec.ranged, rec.f_arty = F.model ~= nil, F.solo, F.ranged, F.arty
				rec.cannot_shoot, rec.held_fire = F.cannot_shoot, F.held_fire
				rec.faw_on = u:is_behaviour_active("fire_at_will")
				if not rec.on then step = "off_check" rec.t_off = t rec.skipped = "did not go on" return end
				local e, d = nearest_enemy(u)
				rec.enemy, rec.enemy_d = e and e:type(), d and r1(d)
				if e then
					local q, p = u:position(), e:position()
					E.rig.yaw = math.atan2(p:get_x() - q:get_x(), p:get_z() - q:get_z())
				end
				local q = u:position()
				rec.p0 = {q:get_x(), q:get_z()}
				set("forward", true)
				step = "walk"
			elseif step == "walk" and t >= 4 then
				set("forward", false)
				local q = u:position()
				rec.walked = r1(math.sqrt((q:get_x() - rec.p0[1]) ^ 2 + (q:get_z() - rec.p0[2]) ^ 2))
				step = "settle"
			elseif step == "settle" and t >= 5 then
				local e = nearest_enemy(u)
				if e then
					local q, p = u:position(), e:position()
					E.rig.yaw = math.atan2(p:get_x() - q:get_x(), p:get_z() - q:get_z())
				end
				if rec.f_arty then set("mode", true) step = "mode_down" rec.t_mode = t
				elseif rec.ranged then
					rec.ammo0, rec.n0, rec.ready0 = u:ammo_left(), F.shot_n or 0, F.ready_at
					rec.last_ammo, rec.last_n, rec.last_ready = rec.ammo0, rec.n0, rec.ready0
					set("attack", true) step = "fire" rec.t_fire = t
				else step = "toggle_off" rec.no_fire = "melee only" end
			elseif step == "mode_down" and t >= rec.t_mode + 0.15 then set("mode", false) step = "manual"
			elseif step == "manual" then
				local fp = find_uicomponent(core:get_ui_root(), "first_person_ui")
				local open = fp and fp:Visible() or false
				if open and not rec.manual_open_at then rec.manual_open_at = r1(t - rec.t_mode) end
				if t >= rec.t_mode + 1 and rec.fp_set == nil then rec.fp_set, rec.on_in_manual = E.fp ~= nil, F.on end
				if t >= rec.t_mode + 5 then set("mode", true) step = "manual_exit_down" rec.t_exit = t end
			elseif step == "manual_exit_down" and t >= rec.t_exit + 0.15 then set("mode", false) step = "manual_back"
			elseif step == "manual_back" and t >= rec.t_exit + 2 then
				local fp = find_uicomponent(core:get_ui_root(), "first_person_ui")
				rec.manual_closed = not (fp and fp:Visible())
				rec.back_on, rec.fp_cleared = F.on and F.unit and F.unit:unique_ui_id() == u:unique_ui_id(), E.fp == nil
				step = "toggle_off"
			elseif step == "fire" then
				local a, n = u:ammo_left(), F.shot_n or 0
				local tf = r1(t - rec.t_fire)
				if a ~= rec.last_ammo then rec.ammo[#rec.ammo + 1] = tf .. ":" .. a rec.last_ammo = a end
				if n ~= rec.last_n then rec.shots[#rec.shots + 1] = tf rec.last_n = n end
				if F.ready_at ~= rec.last_ready then
					rec.last_ready = F.ready_at
					rec.readys[#rec.readys + 1] = tf .. "->" .. r1((F.ready_at or 0) - (t0 + rec.t_fire))
				end
				if not F.on then rec.fell_off = tf rec.t_off = t step = "off_check" set("attack", false) return end
				if #rec.ammo >= 3 or #rec.shots >= 3 or t - rec.t_fire >= rec.window then set("attack", false) step = "toggle_off" end
			elseif step == "toggle_off" then set("toggle", true) step = "toggle_off_up" rec.t_off = t
			elseif step == "toggle_off_up" and t >= rec.t_off + 0.2 then set("toggle", false) step = "off_check"
			elseif step == "off_check" and t >= (rec.t_off or t) + 1 then
				rec.off = not F.on
				rec.faw_end, rec.defend_end = u:is_behaviour_active("fire_at_will"), u:is_behaviour_active("defend")
				rec.strikes = E.strikes - (rec.strikes0 or 0)
				rec.disabled = E.disabled
				rec.u = nil
				cur = nil
				if E.disabled then finish("pack disabled") return end
				next_unit()
			end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_machines")
	return "testing " .. #queue .. " units"
end)
return ok and res or "ERR " .. tostring(res)
