-- Command mode (docs/superpowers/specs/2026-10-22-third-person-command-mode-design.md): playing his lord in third
-- person, the command key slows the battle and he orders the rest of his army, as Bannerlord's order menu does.
-- return function(E) -> C. F.command: nil, or {picked = {[unique_ui_id] = true}, n = <group or nil>, v = <bumped on every
-- pick>, was = <speed to give back, or nil>}
return function(E)
	local F = E.F
	local C = {}

	-- the groups, in Bannerlord's order (spec 3.5); 6 is the characters but the one played: his heroes, or a hero's general.
	-- 0, everyone. Loc rows (E.loc), read when one is picked
	function C.name(n)
		return ({[0] = E.loc("derpy_tp_ui_group_all", "All"), E.loc("derpy_tp_ui_group_infantry", "Infantry"),
			E.loc("derpy_tp_ui_group_ranged", "Ranged"), E.loc("derpy_tp_ui_group_cavalry", "Cavalry"),
			E.loc("derpy_tp_ui_group_monsters", "Monsters"), E.loc("derpy_tp_ui_group_artillery", "Artillery"),
			E.loc("derpy_tp_ui_group_heroes", "Heroes")})[n]
	end
	-- by the category on the unit's card (data.lua castes, main_units.caste); a unit --gen never saw goes by CA's getters,
	-- which follow land_units.category: that files 218 of 271 monsters as infantry (read 2026-10-23)
	local CAVALRY = {melee_cavalry = true, missile_cavalry = true, monstrous_cavalry = true, chariot = true}
	local MONSTERS = {monster = true, war_beast = true, warmachine = true}
	local function group_of(u)
		if u:unit_class() == "com" then return 6 end
		if u:is_artillery() then return 5 end
		local caste = E.D.castes and E.D.castes[u:type()]
		if caste then
			if CAVALRY[caste] then return 3 end
			if MONSTERS[caste] then return 4 end
		elseif u:is_cavalry() or u:is_chariot() then return 3
		elseif u:is_war_beasts() or u:is_war_machine() then return 4 end
		return u:missile_range() > 0 and 2 or 1
	end

	-- group n of his army, 0 every group, never the unit he plays (spec 3.6); the plate names it
	local function pick(n)
		local c, mine = F.command, F.unit:unique_ui_id()
		local picked, count = {}, 0
		local units = E.army():units()
		for i = 1, units:count() do
			local u = units:item(i)
			if u:unique_ui_id() ~= mine and u:number_of_men_alive() > 0 and (n == 0 or group_of(u) == n) then
				picked[u:unique_ui_id()], count = true, count + 1
			end
		end
		c.picked, c.n, c.v = picked, n, c.v + 1
		E.hud.target(C.name(n) .. ": " .. (count > 0 and count or E.loc("derpy_tp_ui_group_none", "none")))
	end

	-- current_battle_speed reads the speed of the model's last tick, 0.65 s behind the call at a quarter (measured
	-- 2026-10-23: a Q 0.4 s after leaving read the mode's quarter as the speed to give back, and every leave after gave back
	-- a quarter), and asks in flight land one a tick, in order. So for ASK_LAG real s after the mode's last ask, that ask is
	-- the speed while the battle reads one the mode asked or read on the way; any other is the player's, on CA's controls.
	-- asked: {s = the last ask, at = its real s, seen = {[speed] = true}}. ponytail: a speed picked on CA's controls inside
	-- ASK_LAG that the mode also asked reads as the mode's till then
	local ASK_LAG = 1.5
	local asked
	local function read()
		local ok, s = pcall(function() return bm.battle:current_battle_speed() end)
		return ok and type(s) == "number" and s or nil
	end
	local function seen(s)
		for v in pairs(asked.seen) do if math.abs(v - s) < 0.01 then return true end end
	end
	local function speed_now()
		local s = read()
		if s and asked and os.clock() - asked.at < ASK_LAG and seen(s) then return asked.s end
		asked = nil
		return s
	end
	local function ask(s)
		local r = read()
		if not (asked and os.clock() - asked.at < ASK_LAG) then asked = {seen = {}} end
		if r then asked.seen[r] = true end
		asked.seen[s], asked.s, asked.at = true, s, os.clock()
		bm:modify_battle_speed(s)
	end
	-- every speed the mode sets is remembered, so leaving gives the speed from before Q back only while the battle still
	-- runs at one the mode set: a speed picked on CA's own controls is the player's (spec 3.3, vanilla spec 4.6)
	local function set_speed(s)
		ask(s)
		F.command.set = s
	end

	-- Space pauses and unpauses, both styles; a tap of Shift switches the command speed and 1x, the Vanilla style's (Shift
	-- is the run in the Bannerlord style). Single player only. A tap: let go under SHIFT_TAP real s after its press, with
	-- no other key or mouse button held meanwhile (vanilla spec 4.6), so CA's Shift+1-6 (the selection's abilities), a
	-- Shift+click and third person's Shift+W never switch it
	local SHIFT_TAP = 0.3
	local function time_keys(P, S, now)
		if bm:is_multiplayer() then return end
		local c = F.command
		if P.pressed(S.keys.cmd_pause) then
			local s = speed_now()
			if s and s > 0 then
				c.resume, c.resume_set = s, c.set
				set_speed(0)
			elseif s then
				-- back to the speed before the pause, and to whose it was; a battle entered paused runs at the command speed
				local resumed, set = c.resume ~= nil, c.resume_set
				set_speed(c.resume or (S.command_speed > 0 and S.command_speed) or (c.was and c.was > 0 and c.was) or 1)
				if resumed then c.set = set end
				c.resume = nil
			end
		end
		if not c.vanilla then return end
		if P.pressed(S.keys.cmd_speed) then c.shift = {at = now} end
		local t = c.shift
		if not t then return end
		if P.held(S.keys.cmd_speed) then
			for _, k in ipairs(E.K.names) do
				if t.spoiled then break end
				local vk = E.K.vk[k]
				if vk ~= S.keys.cmd_speed and P.held(vk) then t.spoiled = true end
			end
			return
		end
		c.shift = nil
		local s = speed_now()
		if not t.spoiled and now - t.at < SHIFT_TAP and s and s > 0 then
			set_speed(math.abs(s - 1) < 0.01 and S.command_speed or 1)
		end
	end

	-- command mode in the Vanilla style (docs/superpowers/specs/2026-10-23-third-person-command-mode-vanilla-design.md):
	-- CA's own clicks, selection and HUD at the crosshair; main.lua asks this wherever it hides CA's interface, blocks its
	-- orders or forces the selection
	function C.vanilla() return F.command ~= nil and F.command.vanilla == true end

	-- the cards in the order the player's panel shows them, his own left out (vanilla spec 4.3). The panel is the filter:
	-- it holds the cards he commands, his other armies' and summons' too. A dead unit keeps its card, so its number.
	-- And each card's component, in the same order
	local function cards()
		local by_id, list, comps = {}, {}, {}
		local armies = bm:get_player_alliance():armies()
		for a = 1, armies:count() do
			local us = armies:item(a):units()
			for i = 1, us:count() do local u = us:item(i) by_id[tostring(u:unique_ui_id())] = u end
		end
		by_id[tostring(F.unit:unique_ui_id())] = nil
		local function walk(c)
			for i = 0, c:ChildCount() - 1 do
				local k = UIComponent(c:Find(i))
				local u = by_id[k:Id()]
				if u then list[#list + 1], comps[#comps + 1] = u, k else walk(k) end -- a card is not walked into
			end
		end
		local panel = find_uicomponent(core:get_ui_root(), "cards_panel")
		if panel then walk(panel) end
		return list, comps
	end
	-- the number keys over the page's cards (hud.lua H.cards): read again every LABELS_EVERY real s, as cards come and go,
	-- and at once on a page
	local LABELS_EVERY, labels_at = 0.2, -1e9
	local function labels(now)
		if now - labels_at < LABELS_EVERY then return end
		labels_at = now
		local _, comps = cards()
		local list = {}
		for n = 1, 10 do
			local k, name = comps[F.command.page * 10 + n], E.S.names["cmd_unit_" .. n]
			if k and name then list[n] = {k, name} end
		end
		E.hud.cards(list)
	end
	local function say_page(n)
		local p = F.command.page * 10
		E.say("derpy_tp_command_page", (p + 1) .. "-" .. math.min(p + 10, n))
	end
	-- the number keys select card 1-10 of the page, one regiment each, replacing the selection (no call adds to it); the
	-- page key steps the tens
	local function number_keys(P, S)
		local c = F.command
		if P.pressed(S.keys.cmd_page) then
			local n = #cards()
			if n > 10 then c.page = (c.page + 1) % math.ceil(n / 10) say_page(n) labels_at = -1e9 end
		end
		for n = 1, 10 do
			if P.pressed(S.keys["cmd_unit_" .. n]) then
				local u = cards()[c.page * 10 + n]
				if u and u:number_of_men_alive() > 0 then E.select(u) end
			end
		end
	end

	local stray -- model s his unit began moving with no move key held (C.update); nil while it does not
	local faw_at = -1e9 -- model s his fire was last held again (C.update)
	-- ponytail: the two found on 9.0's HUD under the parked cursor; a patch that anchors another interactive one there
	-- needs it added here (the live check: a right-click at the crosshair gives no order)
	local CENTRE = {"spawn_zone_icons_parent", "reinforcement_icons_parent"}
	-- what is in CA's banner over his unit, under the crosshair too: its unit panel opened off the parked cursor (the author,
	-- 2026-10-23: "remove this"). CA shows the banner itself again every tenth of a second, its contents left as set
	-- (measured 2026-10-23)
	local function own_banner()
		return find_uicomponent(core:get_ui_root(), "unit_id_holder", tostring(F.unit:unique_ui_id()), "modular_parent")
	end

	local function enter()
		local S = E.S
		E.abilities.cancel() -- or its click would cast instead of order
		-- a lock-on would take every order (combat.lua C.aim_point answers the locked enemy) and turn the view to its
		-- enemy (C.track)
		F.target = nil
		local c = {picked = {}, v = 0, vanilla = S.command_style == "vanilla"}
		F.command = c
		F.cursor_shown = nil -- cursor() applies CA's interface again, for this style (main.lua)
		E.rig.command(true) -- the view tilts to place orders, his own pitch kept (rig.lua)
		-- one player cannot slow a shared battle; a battle already stopped stays stopped (spec 3.3), and its 0 is kept to
		-- give back: entered paused, it leaves paused (vanilla spec 4.6)
		c.was = speed_now()
		if not bm:is_multiplayer() and S.command_speed ~= 1 and c.was and c.was > 0 then set_speed(S.command_speed) end
		if not c.vanilla then E.hud.target(E.loc("derpy_tp_ui_pick_units", "Pick units: 1 to 6, 0 for all")) return end
		-- the selection is the player's from here (spec 4.1); CA's whole HUD comes back with the pack's panel standing on it
		-- and the way back over its bar (the author, 2026-10-23, live), the radar back in CA's own holder first (spec 4.8)
		bm:clear_selection()
		c.map = F.map
		if F.map then F.map = E.hud.map(false) end
		E.hud.back(true) -- first: the bar centres without the page tab it sets aside
		E.hud.place()
		-- CA's holders anchored 1x1 on the screen's centre pixel are interactive: the cursor parked there clicked them, not
		-- the world (no order, no selection), and drew CA's cursor over the pack's hide (measured 2026-10-23)
		c.centre = {}
		local hud = find_uicomponent(core:get_ui_root(), "hud_battle")
		for _, id in ipairs(CENTRE) do
			local h = hud and find_uicomponent(hud, id)
			if h then c.centre[#c.centre + 1] = {h, h:IsInteractive()} h:SetInteractive(false) end
		end
		local b = own_banner()
		if b then c.banner = b:Visible() b:SetVisible(false) end
		c.page = 0
		labels_at = -1e9
		local n = #cards()
		if n > 0 then say_page(n) end
	end

	-- leaves the mode. The speed goes back only while it is still the one the mode set: the freed mouse brings CA's time
	-- controls back, and a speed picked there is the player's. Follow me and orders waiting out the gap go on (spec 3.7,
	-- 3.8): they end with third person (C.stop)
	local function leave()
		local c = F.command
		if not c then return end
		F.command = nil
		F.cursor_shown, F.free_cursor = nil, nil -- the mouse-look back with the mode's end (main.lua look)
		E.rig.command(false)
		local s = speed_now()
		if c.set and c.was and s and math.abs(s - c.set) < 0.01 then ask(c.was) end
		if c.vanilla then
			for _, h in ipairs(c.centre) do h[1]:SetInteractive(h[2]) end
			local b = c.banner ~= nil and own_banner()
			if b then b:SetVisible(c.banner) end
			-- the parts set aside come back as they were and the panel goes back to the screen's floor; not drawn over
			-- from nothing, which put the ability bar back on its first page
			E.hud.back(false)
			E.hud.place()
			if c.map then F.map = E.hud.map(true) end
			-- a CA melee toggle on his unit left F.melee_on wrong: the tick sends his mode again (main.lua). Never one man's:
			-- his regiment takes no order from the pack. Not at third person's end either, whose stop reads it to put the
			-- melee mode back (the final review, 2026-10-23)
			if not F.model and F.on then F.melee_on = nil end
		end
		stray = nil
		E.hud.target(nil)
	end

	-- the general and his heroes command, any unit by the setting (spec 3.12; the author, 2026-10-23: "add command mode for
	-- only heroes and general, configurable by mct if the player wants all units to command"). Heroes are class "com"
	function C.toggle(gnow)
		if F.command then leave() return end
		local u = F.unit
		if not (E.S.command_any_unit or u:is_commanding_unit() or u:unit_class() == "com") then
			E.say("derpy_tp_command_general_and_heroes") return
		end
		enter()
	end

	-- the orders (spec 3.7, 3.8). ORDER_GAP: model s under which a second order to a unit is dropped silently (measured
	-- 2026-10-15); FOLLOW_EVERY: model s between follow me's moves; FOLLOW_BACK: m behind him it moves to; PING_FOR: real
	-- s CA's ping stays where an order landed; REACH: m from him the crosshair's ground point may be
	local ORDER_GAP, FOLLOW_EVERY, FOLLOW_BACK, PING_FOR, REACH = 0.5, 3, 10, 2, 300
	local sent, waiting, follow, pings = {}, {}, {}, {} -- by unique_ui_id: model s of its last order; {fn, unit}; unit
	local follow_at = 0

	-- an order reaches a unit alive and not routing; never the unit he plays, which no pick holds (pick) and whose session's
	-- end clears every order (C.stop). ponytail: no is_controllable() test - CA never calls it and what it answers while
	-- the mod holds orders off is unmeasured; the engine refuses a unit it will not let go
	local function can_order(u)
		return u:number_of_men_alive() > 0 and not u:is_routing()
	end

	-- fn(uc, units) on one controller over them, so they move as a player's selection does, then given back to him
	local function send(units, fn, gnow)
		if #units == 0 then return end
		local uc = create_unitcontroller(unpack(units))
		fn(uc, units)
		uc:release_control()
		for _, u in ipairs(units) do sent[u:unique_ui_id()] = gnow end
	end

	-- an order reaching a unit ordered under ORDER_GAP ago waits, whole, until the last of its units may take it: one order
	-- is one controller (spec 3.7). A unit's newest order replaces one waiting; any order but follow me's own moves ends
	-- follow me for that unit
	local function order(units, fn, gnow, following)
		local list, at = {}, gnow
		for _, u in ipairs(units) do
			if can_order(u) then
				local id = u:unique_ui_id()
				if not following then follow[id] = nil end
				list[#list + 1] = u
				at = math.max(at, (sent[id] or -1e9) + ORDER_GAP)
			end
		end
		local wait = at > gnow
		for _, u in ipairs(list) do waiting[u:unique_ui_id()] = wait and {fn = fn, at = at, unit = u} or nil end
		if not wait then send(list, fn, gnow) end
	end

	-- the waiting orders whose time has come, one controller for each order
	local function flush(gnow)
		local due = {}
		for id, w in pairs(waiting) do
			if gnow >= w.at then
				waiting[id] = nil
				if can_order(w.unit) then due[w.fn] = due[w.fn] or {} table.insert(due[w.fn], w.unit) end
			end
		end
		for fn, units in pairs(due) do send(units, fn, gnow) end
	end

	local function ping(x, y, z, kind, now)
		bm.battle:add_ping_icon(x, y, z, kind)
		pings[#pings + 1] = {x, y, z, now + PING_FOR}
	end
	local function unping(now)
		for i = #pings, 1, -1 do
			local p = pings[i]
			if not now or now >= p[4] then bm.battle:remove_ping_icon(p[1], p[2], p[3]) table.remove(pings, i) end
		end
	end

	-- FOLLOW_BACK m behind him: his own heading when one man or a unit of one is steered (platform.lua P.heading), else his
	-- unit's bearing, which is degrees
	local function behind_him()
		local m, x, z = F.model or F.single, nil, nil
		if m then local px, _, pz = E.P.model_pos(m) x, z = px, pz else local q = F.unit:position() x, z = q:get_x(), q:get_z() end
		local yaw = m and E.P.heading(m) or math.rad(F.unit:bearing())
		x, z = x - math.sin(yaw) * FOLLOW_BACK, z - math.cos(yaw) * FOLLOW_BACK
		return v(x, bm:get_terrain_height(x, z), z)
	end
	local function follow_me(uc) uc:goto_location(behind_him(), false) end

	local function nearest_enemy(u)
		local p, best, best_d = u:position(), nil, nil
		local armies = bm:get_non_player_alliance():armies()
		for a = 1, armies:count() do
			local list = armies:item(a):units()
			for i = 1, list:count() do
				local e = list:item(i)
				if e:number_of_men_alive() > 0 and not e:is_routing() and e:is_valid_target() then
					local q = e:position()
					local d = (q:get_x() - p:get_x()) ^ 2 + (q:get_z() - p:get_z()) ^ 2
					if not best_d or d < best_d then best, best_d = e, d end
				end
			end
		end
		return best
	end

	-- CA's halt turns fire at will off and it stays off (measured 2026-10-19): the shooters get it back
	local function hold(uc, units)
		uc:halt()
		local shooters = {}
		for _, u in ipairs(units) do if u:missile_range() > 0 then shooters[#shooters + 1] = u end end
		if #shooters > 0 then
			local s = create_unitcontroller(unpack(shooters))
			s:fire_at_will(true)
			s:release_control()
		end
	end

	-- the units picked, of his army as it is now
	local function picked_units()
		local c, out = F.command, {}
		local units = E.army():units()
		for i = 1, units:count() do
			local u = units:item(i)
			if c.picked[u:unique_ui_id()] then out[#out + 1] = u end
		end
		return out
	end

	local function give_orders(now, gnow)
		local S, P = E.S, E.P
		local units = picked_units()
		if #units == 0 then return end
		if P.pressed(S.keys.cmd_follow) then
			for _, u in ipairs(units) do if can_order(u) then follow[u:unique_ui_id()] = u end end
			order(units, follow_me, gnow, true)
			follow_at = gnow + FOLLOW_EVERY
		end
		if P.pressed(S.keys.cmd_charge) then
			for _, u in ipairs(units) do
				local e = nearest_enemy(u)
				if e then order({u}, function(uc) uc:attack_unit(e, true, true) end, gnow) end
			end
		end
		if P.pressed(S.keys.cmd_hold) then order(units, hold, gnow) end
		-- the clicks order only with the mouse grabbed: freed, they are CA's own orders (main.lua F.free_orders). Read either
		-- way, so a click held over the grab is not a press
		local move, attack = P.pressed(S.keys.attack) and F.dragging, P.pressed(S.keys.mode) and F.dragging
		if not (move or attack) then return end
		local x, y, z, enemy = E.combat.aim_point(REACH)
		if not x then return end
		if move then
			local run = P.held(S.keys.sprint)
			order(units, function(uc) uc:goto_location(v(x, y, z), run) end, gnow)
			ping(x, y, z, 2, now)
		elseif enemy then
			order(units, function(uc) uc:attack_unit(enemy, true, true) end, gnow)
			ping(x, y, z, 3, now)
		end
	end

	-- third person ends: the mode, follow me, the waiting orders and the pings with it; safe to call twice
	function C.stop()
		leave()
		follow, waiting = {}, {}
		unping(nil)
	end

	-- every tick while third person is on; keys: the window has focus and the mode is on. The ability keys pick: 1-6 a
	-- group, the tenth (0) every group; then the order keys. Waiting orders, follow me and the pings run on outside the mode
	function C.update(now, gnow, keys, walking)
		-- a unit he selects with the freed mouse is his to order with CA's (spec 3.7, 3.10): follow me lets go of it
		if F.free_orders then for id, u in pairs(follow) do if E.selected(u) then follow[id] = nil end end end
		flush(gnow)
		unping(now)
		if next(follow) and gnow >= follow_at then
			local units = {}
			for id, u in pairs(follow) do if can_order(u) then units[#units + 1] = u else follow[id] = nil end end
			order(units, follow_me, gnow, true)
			follow_at = gnow + FOLLOW_EVERY
		end
		-- he stays put (the author, 2026-10-23; vanilla spec 4.5): a unit played whole that CA's orders took along is halted
		-- once it has moved ORDER_GAP model s with no move key held, as a halt sooner after CA's order is dropped silently,
		-- and CA's fire at will on it is held again. One man's regiment is the player's: the pack sends it nothing
		if C.vanilla() and not F.model then
			local u = F.unit
			if u:is_moving() and not walking then
				stray = stray or gnow
				if gnow - stray >= ORDER_GAP then
					stray = nil
					F.uc:halt()
					F.uc:release_control()
					-- an order: his next walk waits its gap from it, as from move.lua's own halt, or the engine drops it
					F.driving, F.last_order = false, gnow
				end
			else
				stray = nil
			end
			-- once a gap: it lands on the engine's next tick and reads on till then, as every uc: call queues (the final
			-- review, 2026-10-23; MP_FEASIBILITY_20261021_THIRD_PERSON.md), and in multiplayer each send is a shared order
			if F.held_fire and u:is_behaviour_active("fire_at_will") and gnow - faw_at >= ORDER_GAP then
				faw_at = gnow
				F.uc:fire_at_will(false)
				F.uc:release_control()
			end
		end
		if C.vanilla() then labels(now) end -- paused and with the mouse freed too: CA's cards show there
		if not keys then return end
		local S, P = E.S, E.P
		time_keys(P, S, now)
		-- the groups, the clicks and F1/F3/F4 are the Bannerlord style's (vanilla spec 4.7)
		if C.vanilla() then number_keys(P, S) return end
		for n = 1, 6 do if P.pressed(S.keys["ability_" .. n]) then pick(n) end end
		if P.pressed(S.keys.ability_10) then pick(0) end
		give_orders(now, gnow)
	end

	return C
end
