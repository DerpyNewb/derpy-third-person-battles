-- Third-person battle control: the toggle, starting and stopping one session, and the per-frame loop that
-- reads the keys and drives the rig, movement and combat (spec sections 5-8). return function(E) -> M.
-- Two clocks: real time (os.clock) for the camera and the Manual fire hand-over, model time
-- (bm:time_elapsed_ms) for everything that acts in the battle, so cooldowns, reloads and order gaps follow
-- game speed and stop with the pause.
local MAX_ERRORS, ZOOM_LARGE, ZOOM_NOTCH = 3, 2, 0.15
-- no documented call says "paused", and model time moves in 100-200 ms ticks, so a pause is model time
-- standing still this long in real time. ponytail: the first half second of a pause still acts; a UI
-- pause signal would close that gap if one is ever found.
local PAUSE_AFTER = 0.5
-- a sprint's speed against his run (the author, 2026-10-16: "if no charge animation, add a 20% boost to speed", then
-- "20% boost even with charge animation")
local SPRINT_SPEED = 1.2

return function(E)
	local F, P = E.F, E.P
	local cam = bm:camera()
	local M = {}
	local ready_by = {} -- unique_ui_id -> model time he can shoot again, kept across sessions

	-- what the game says is selected (CcoBattleUnit.IsSelected, by unique_ui_id; measured 2026-10-15: true for the one
	-- selected unit, false for the rest). A set kept from selection callbacks went stale (the author, 2026-10-15: "the
	-- camera jumps one unit to another"; log: card 1010 clicked, F2 took 1012, the unit before): CA's helper runs them
	-- all from one selection handler, which another script can take over
	local function selected(u)
		local ok, s = pcall(common.get_context_value, "CcoBattleUnit", tostring(u:unique_ui_id()), "IsSelected")
		return ok and s == true
	end
	-- the one selected unit, else the general
	local function pick_unit()
		local units, one, general = bm:get_player_army():units(), bm:num_units_selected() == 1, nil
		for i = 1, units:count() do
			local u = units:item(i)
			if one and selected(u) then return u end
			if u:is_commanding_unit() then general = u end
		end
		return general
	end

	-- one man shoots only when he can shoot alone: otherwise the shot is the regiment's, and its fire order walked
	-- the whole regiment into range and pulled him back into his place (seen in game 2026-10-14). Such a man is still
	-- played, in melee, with no ranged mode (F.cannot_shoot): handing the shot to his regiment whole moved the camera off
	-- him and threw with all of them (the author, 2026-10-15: "it happens when switching to ranged", "it also triggers
	-- the whole battalion to shoot or throw")
	function E.can_shoot() return not F.cannot_shoot and F.unit:missile_range() > 0 and F.unit:ammo_left() > 0 end

	-- the clip a man shoots with alone: FIRE_LEVEL, or GRENADIER for a thrower with none (measured 2026-10-15: Exalted
	-- Plaguebearers' Death's Head, 25 units of 827 - third_person_fires.py); nil, none
	local function fire_clip(m) if P.has_slot(m, 1557) then return 1557 elseif P.has_slot(m, 949) then return 949 end end

	local function capabilities(m)
		m = m and (P.mount(m) or m)
		local function any(a)
			if m then for s = a, a + 4 do if P.has_slot(m, s) then return true end end end
			return false
		end
		F.can_charge, F.can_jump = any(484), any(489)
		F.can_cheer = any(1094) or any(1099) or any(1104) or any(1109)
	end

	-- a shot data.lua lacks - every modded unit (measured 2026-10-15: 15 of 16 ranged units in a modded army) - from the
	-- unit's own context, kept with data.lua's: {projectile, base reload s, projectiles a shot}
	local function learn_shot(unit)
		local t = unit:type()
		if E.D.shots[t] or unit:missile_range() <= 0 then return end -- a known unit's spawns are in data.lua's fires
		local card = find_uicomponent(core:get_ui_root(), "cards_panel", tostring(unit:unique_ui_id()))
		local id = card and card:GetContextObjectId("CcoBattleUnit")
		if not id then return end
		local function get(f) return common.get_context_value("CcoBattleUnit", id, "ActiveProjectileContext." .. f) end
		-- a thrown bomb leaves late in its clip (the author, 2026-10-15: the ironbreakers' charge left at the throw's start)
		local ok, kind = pcall(get, "ShotTypeKey")
		F.thrown = ok and kind == "explosives"
		local ok, key, reload, n = pcall(function() return get("Key"), get("BaseReloadTimeContext.Value"), get("NumProjectiles") end)
		if ok and type(key) == "string" and type(reload) == "number" and type(n) == "number" and n > 0 then
			E.D.shots[t] = {key, reload, n}
		end
	end

	-- a platform check that throws is a failed check, never an error: that feature goes off, the rest stay
	local function check(group, fn, ...)
		local ok, res, why = pcall(fn, ...)
		if ok then return res, why end
		P.features[group] = false
		return false, res
	end

	-- called every frame, switched on change only. Cinematic UI hides the cursor and CA's whole interface,
	-- selection markers, flags and panels with it (the author's choice, 2026-10-14); the pack draws its own.
	local function cursor(show)
		show = show and true or false
		if F.cursor_shown == show then return end
		F.cursor_shown = show
		-- the interface hidden (S.keys.hide_ui), the freed mouse brings the cursor back and CA's interface stays off
		if show and not F.ui_off then bm:enable_cinematic_ui(false, true, false) else bm:enable_cinematic_ui(true, show, false) end
		-- the flags over every unit: the switch brings them back. enable_unit_ids would write it into the replay
		bm.battle:set_banners_enabled(false)
	end

	-- everything the pack draws off, and CA's interface kept off (the author, 2026-10-15: "hide all ui"): the HUD here,
	-- the crosshair and the cursor from F.ui_off
	local function hide_ui(off)
		F.ui_off = off
		E.hud.show(not off)
		F.cursor_shown = nil -- cursor() applies CA's interface again, hidden or not
	end

	-- Store visibility by id, not UI handles: selection and HUD redraws can replace components.
	-- CA's porthole_mask also draws the cup the camera and info buttons sit in (state images 2 and 3, the
	-- cup and its side strip): with the buttons hidden it shows as two empty sockets, so it fades too.
	local CUP = {2, 3}
	local function hud(show)
		local root = core:get_ui_root()
		local saved = F.hidden_ui
		local mask = find_uicomponent(root, "porthole_parent", "porthole_mask")
		if show then
			if not saved then return end
			for group, ids in pairs(saved) do
				local parent = group == "root" and root or find_uicomponent(root, group)
				if parent then for id, visible in pairs(ids) do local c = find_uicomponent(parent, id) if c then c:SetVisible(visible == true) end end end
			end
			if mask and F.cup then for _, i in ipairs(CUP) do mask:SetCurrentStateImageOpacity(i, F.cup[i]) end end
			F.hidden_ui, F.cup = nil, nil
			return
		end
		if mask then
			F.cup = F.cup or {}
			for _, i in ipairs(CUP) do
				if F.cup[i] == nil then F.cup[i] = mask:GetCurrentStateImageOpacity(i) end
				mask:SetCurrentStateImageOpacity(i, 0)
			end
		end
		saved = saved or {hud_battle = {}, porthole_parent = {}, root = {}}
		F.hidden_ui = saved
		local function hide(c, group)
			local id = c:Id()
			if saved[group][id] == nil then saved[group][id] = c:Visible() end
			c:SetVisible(false)
		end
		local h = find_uicomponent(root, "hud_battle")
		if h then for i = 0, h:ChildCount() - 1 do local c = UIComponent(h:Find(i)) if c:Id() ~= "porthole_parent" then hide(c, "hud_battle") end end end
		local port = find_uicomponent(root, "porthole_parent")
		local keep = {model_parent = true, porthole_mask = true, ability_parent = true, ability_page_parent = true}
		if port then for i = 0, port:ChildCount() - 1 do local c = UIComponent(port:Find(i)) if not keep[c:Id()] then hide(c, "porthole_parent") end end end
		for _, id in ipairs({"unit_id_holder", "capture_point_visibility_parent", "building_icon_holder", "menu_bar", "under_advisor_docker", "df_launcher_button", "df_fountain_1_layer", "watermark_square", "ursun_mouse_follower"}) do
			local c = find_uicomponent(root, id)
			if c then hide(c, "root") end
		end
	end

	-- flying units: the game's own Toggle flying button lands and lifts them; no script call does
	local function toggle_flying()
		local b = find_uicomponent(core:get_ui_root(), "button_toggle_flying")
		if b then b:SimulateLClick() else E.once("fly", "no Toggle flying button for " .. F.utype) end
	end

	local function look()
		if P.held(E.S.keys.look_free) then F.dragging = false return end
		if not F.dragging then P.look_begin() F.dragging = true return end
		local dx, dy = P.look_delta()
		if dx ~= 0 or dy ~= 0 then E.rig.look(dx, dy) end
	end

	local function zoom(dt)
		local S = E.S
		local zin = P.held(S.keys.zoom_in) and 1 or 0
		local zout = P.held(S.keys.zoom_out) and 1 or 0
		local notches = P.wheel and P.wheel() or 0
		if zin ~= zout or notches ~= 0 then
			E.rig.zoom_by((zout - zin) * S.zoom_rate * dt - notches * ZOOM_NOTCH)
			E.zoom_by_type[F.utype] = E.rig.zoom
		end
	end

	-- now, dt: real time for the camera; gnow: model time for what acts; paused: nothing acts
	local function tick(now, dt, gnow, paused)
		local S, unit = E.S, F.unit
		F.dt = dt -- real time: the model clock steps in 100 ms ticks (move.lua's turn)
		hud(false)
		if unit:number_of_men_alive() == 0 or unit:is_routing() then M.stop("unit lost") return end
		local single = not F.model and unit:number_of_men_alive() == 1 and P.models(unit)[1]
		if single and P.model_hp(single) <= 0 then M.stop("unit lost") return end
		-- orders are off, selection is not: a click on another unit or on the ground would take the portrait
		if bm:num_units_selected() ~= 1 or not selected(unit) then bm:clear_selection() unit:select_in_ui() end
		if F.model and (unit:number_of_men_alive() < 2 or not P.alive(unit, F.model)) then
			-- he died, or he is the last man: the next front-centre man, or the whole unit
			F.model, F.man_hold, F.shot, F.lock, F.swung = E.move.front_man(unit), nil, nil, nil, nil
			F.reload_slot = F.model and P.reload_slot(F.model)
			-- played whole from here; it keeps holding its fire until third person ends (no shot he did not ask for)
			F.fire_slot = F.model and fire_clip(F.model)
			F.solo = F.model ~= nil and E.D.shots[F.utype] ~= nil and P.features.anim and F.fire_slot ~= nil
			capabilities(F.model or P.models(unit)[1])
			-- a next man who cannot shoot alone is played in melee, as at the start
			F.cannot_shoot = F.model ~= nil and not F.solo and unit:missile_range() > 0
			if F.cannot_shoot then F.ranged = false end
		end
		-- the game's melee mode follows his: the melee weapon drawn in melee, the missile weapon in ranged (the author,
		-- 2026-10-15: "should walk and idle with melee weapons if melee mode, and vice versa for ranged"). It is the whole
		-- unit's, so only for a unit played whole: one man of a regiment gives it no orders (the design, section 3; the
		-- author, 21:46: "why does switching melee and range of one units affects the entire battalion")
		local melee = unit:missile_range() > 0 and not F.arty and not F.ranged and not F.model
		if melee ~= F.melee_on then
			F.melee_on = melee
			F.uc:melee(melee)
			F.uc:release_control()
		end
		local x, y, z
		if F.model then x, y, z = P.model_pos(F.model) else local q = unit:position() x, y, z = q:get_x(), q:get_y(), q:get_z() end
		local kf, kr = 0, 0
		if P.focused() then
			look()
			if P.pressed(S.keys.hide_ui) then hide_ui(not F.ui_off) end -- paused too: a still to take a picture of
			if P.pressed(S.keys.minimap) then F.map = E.hud.map(not F.map) end
			cursor(not F.dragging)
			kf = (P.held(S.keys.forward) and 1 or 0) - (P.held(S.keys.back) and 1 or 0)
			kr = (P.held(S.keys.right) and 1 or 0) - (P.held(S.keys.left) and 1 or 0)
			if not paused then
				-- toggled, or held (the author, 2026-10-15: "make shift be a long press or a toggable in the mct"; 2026-10-16:
				-- "make z as the toggable walk"): he runs unless it has him walk
				if S.walk_hold then F.walking = P.held(S.keys.walk) elseif P.pressed(S.keys.walk) then F.walking = not F.walking end
				local clicked, held = P.pressed(S.keys.attack), P.held(S.keys.attack)
				-- an armed ability takes the mode key (it disarms) and the left click (it casts) from fighting
				if P.pressed(S.keys.mode) and F.dragging then
					if F.armed then E.abilities.cancel() else E.combat.mode(gnow) end
				end
				if not F.on then return end -- the mode key can hand artillery to Manual fire, which ends this session
				-- held on the move (the author, 2026-10-16: "shift button as the charge or sprint button"): the charge, at the run
				E.combat.sprint(gnow, P.held(S.keys.sprint) and F.dragging and not F.armed and (kf ~= 0 or kr ~= 0))
				F.running = F.sprinting or not F.walking
				if P.pressed(S.keys.jump) and F.dragging and not F.armed then E.combat.jump(gnow) end
				if P.pressed(S.keys.cheer) and F.dragging and not F.armed then E.combat.cheer(gnow) end
				if F.armed then
					if F.dragging and clicked then E.abilities.fire() F.swallow = true end
				elseif F.swallow then
					F.swallow = held or nil -- the click that cast is no shot: fighting waits for the button to come up
				else
					E.combat.attack(gnow, F.dragging and clicked, F.dragging and held)
				end
				for n = 1, 10 do
					if P.pressed(S.keys["ability_" .. n]) and F.dragging then
						local why = E.abilities.press(n, gnow)
						if why then E.log(why) end
					end
				end
				if P.pressed(S.keys.fly) and F.dragging then toggle_flying() end
			end
			zoom(dt)
		else
			F.dragging = false
			cursor(true)
			if not paused then E.combat.sprint(gnow, false) E.combat.attack(gnow, false, false) end
		end
		E.abilities.update(now) -- real time: the label and arrow follow the camera, which turns while paused
		if not paused then
			-- the engine's own orders on him go (the author, 2026-10-16: "battalion actions also affect the unit which
			-- shouldnt be"; 2026-10-14: "absolute control and no auto attack")
			if F.model then P.guard(F.model)
			elseif single and not F.native_attack and not F.driving and not F.firing then P.guard(single) end
			-- and none of its swings start on him (P.disarm): his own, and an attack order on a unit of one, only
			-- a swing held back past its lock (combat.lua C.locked) stays armed until it has played
			local pd = F.pending
			if pd then
				local c = P.anim_slot(pd.m)
				if c == pd.slot then pd.seen = true end
				if pd.seen and c ~= pd.slot or not pd.seen and gnow >= pd.till then F.pending = nil end
			end
			local man = F.model or single
			if man then
				if F.lock or F.swung or F.native_attack or F.pending then P.arm(man) else P.disarm(man) end
				F.disarmed = man
			end
			if F.shot and (kf ~= 0 or kr ~= 0) then E.combat.drop(gnow, true) end
			if F.shot then P.face(F.model, E.rig.yaw)
			elseif E.combat.locked(gnow) and not F.lock.runs then
				-- a swing or cheer: until the engine reports its clip (0.19-0.31 s), as a clip under way still turns him; then the
				-- clip turns him (round 25)
				if F.model and not (F.lock.turns and F.lock.seen) then P.face(F.model, F.lock.yaw) end
			elseif not F.firing then E.move.drive(gnow, kf, kr, F.running, F.sprinting and SPRINT_SPEED or 1) end
		end
		-- the author, 2026-10-16: "UNRESPONSIVE UNITS WHEN IN COMBAT INCL BATTALION STILL NOT FIXED", not reproduced off the
		-- game: with the debug log on, a second of a move key held with him under half a metre from where it began logs what
		-- held him, once a stall
		if E.S.debug and not paused then
			local s = F.stall
			if kf == 0 and kr == 0 then F.stall = nil
			elseif not s or (x - s.x) ^ 2 + (z - s.z) ^ 2 > 0.25 then F.stall = {t = gnow, x = x, z = z}
			elseif not s.told and gnow - s.t >= 1 then
				s.told = true
				local o = not F.model and unit:ordered_position()
				E.log("stalled 1 s with a move key held: in melee " .. tostring(unit:is_in_melee()) .. ", his clip "
					.. tostring(F.model and P.anim_slot(F.model)) .. ", his command " .. tostring(F.model and P.command(F.model))
					.. ", action " .. tostring(F.lock and F.lock.slot) .. ", shot " .. tostring(F.shot and F.shot.phase)
					.. ", firing " .. tostring(F.firing) .. ", sprint " .. tostring(F.sprinting) .. ", s since an order "
					.. math.floor((gnow - (F.last_order or 0)) * 10) / 10
					.. (o and (", ordered " .. math.floor(o:get_x() - x) .. "," .. math.floor(o:get_z() - z) .. " m off") or ""))
			end
		end
		E.combat.crosshair((F.ranged or F.armed ~= nil) and F.dragging and not F.ui_off)
		E.hud.update(gnow)
		local ex, ey, ez, lx, ly, lz = E.rig.update(now, dt, x, y, z, F.ranged, unit:is_in_melee(),
			cam:position():get_y())
		cam:move_to(v(ex, ey, ez), v(lx, ly, lz), 0, false, -1, false)
		F.frames = F.frames + 1
	end

	function M.start(unit)
		if E.disabled or F.on then return end
		E.S = E.settings(get_mct and get_mct(), E.K) -- loaded once by the entry: no file is read here
		local S = E.S
		for _, c in ipairs(S.conflicts) do
			E.once("conflict_" .. c.action, "key " .. c.key .. " for " .. c.action .. " is already used by " .. c.taken_by
				.. (c.now and ("; it uses " .. c.now .. " instead") or "; it is unbound"))
		end
		if not E.checked then
			E.checked = true
			local ok, why = check("anim", P.check_anim)
			if not ok then E.once("anim", "swings become attack orders: " .. tostring(why)) end
			ok, why = check("wheel", P.open_wheel)
			if not ok then E.once("wheel", "zoom is on the keys only: " .. tostring(why)) end
			E.log("build " .. tostring(P.build) .. " via " .. tostring(P.source) .. ": anim " .. tostring(P.features.anim)
				.. ", wheel " .. tostring(P.features.wheel))
		end
		unit = unit or pick_unit()
		if not unit or unit:number_of_men_alive() == 0 then return end
		F.unit, F.uc, F.utype, F.arty = unit, create_unitcontroller(unit), unit:type(), unit:is_artillery()
		local men_ok, why = check("men", P.check_men, unit)
		F.men_ok = men_ok
		E.log("men check on " .. F.utype .. ": " .. tostring(men_ok))
		if not men_ok then E.once("men", "regiments are played whole: " .. tostring(why)) end
		if S.one_man and not P.features.steer then E.once("steer", "regiments are played whole: walking command types unknown for build " .. tostring(P.build)) end
		-- one man of a regiment, never of a flying machine (measured 2026-10-15: a gyro gunship's crew steered nothing)
		F.model = S.one_man and men_ok and P.features.steer and not F.arty and not unit:is_war_machine() and not unit:can_fly()
			and E.move.front_man(unit) or nil
		F.reload_slot = F.model and P.reload_slot(F.model)
		F.thrown = false
		learn_shot(unit)
		-- no reload clip is no bar (measured 2026-10-15: a rocket team's men have FIRE_LEVEL only): the reload runs on the clock
		F.fire_slot = F.model and fire_clip(F.model)
		F.solo = F.model ~= nil and E.D.shots[F.utype] ~= nil and P.features.anim and F.fire_slot ~= nil
		-- a man who cannot shoot alone is played all the same (the author, 2026-10-15: "pressing f2 will still move the
		-- entire battalion"), in melee with no ranged mode - E.can_shoot
		F.cannot_shoot = F.model ~= nil and not F.solo and unit:missile_range() > 0
		-- the charge and jump keys need their clips (MOVING_ATTACK_1 484, JUMPING_ATTACK_1 489; measured 2026-10-15)
		-- any of the five: an engineer's one jump is JUMPING_ATTACK_2 (measured 2026-10-15)
		-- cheer: any CELEBRATE_1-10 or TAUNT_1-10 (1094-1113, combat.lua C.cheer); none, no cheer (the author, 2026-10-15:
		-- "only show cheer and fly if its applicable")
		capabilities(F.model or P.models(unit)[1])
		F.lock, F.next_charge, F.next_jump, F.charging, F.charge_at = nil, 0, 0, false, nil
		F.native_attack = nil
		F.ranged = E.can_shoot() and not F.arty
		-- a reload under way when he was last let go still counts (ready_by, by unit)
		F.firing, F.want_shot, F.shot, F.next_swing, F.swings, F.shot_n = false, false, nil, 0, 0, 0
		F.ready_at = ready_by[unit:unique_ui_id()] or 0
		F.driving, F.dragging, F.running, F.cursor_shown, F.held_fire = false, false, true, nil, false
		F.walking, F.sprinting, F.stamina, F.stamina_t, F.map = false, false, 1, nil, false
		F.man_hold, F.frames, F.swallow, F.ui_off, F.melee_on, F.face_yaw, F.queued = nil, 0, nil, false, false, nil, nil
		F.fire_was = unit:is_behaviour_active("fire_at_will") -- the player's own setting, given back at the end
		local x, y, z
		if F.model then x, y, z = P.model_pos(F.model) else local q = unit:position() x, y, z = q:get_x(), q:get_y(), q:get_z() end
		local zoom_now = E.zoom_by_type[F.utype] or (unit:is_infantry() and 1 or ZOOM_LARGE)
		-- on from here: whatever below changes the battle, M.stop puts back, even if a later line throws
		F.on = true
		-- the author: "absolute control of the unit and no auto attack". It shoots when clicked, never at will, and
		-- keeps its ground (defend: no pursuit) - both given back as the player had them
		if unit:missile_range() > 0 then F.held_fire = true F.uc:fire_at_will(false) end
		F.defend_was = unit:is_behaviour_active("defend")
		if not F.defend_was and unit:can_use_behaviour("defend") then F.uc:change_behaviour_active("defend", true, false) end
		F.uc:halt()
		F.uc:release_control()
		-- his clicks beat the order his regiment gives him each tick of a melee (platform.lua P.gate)
		if F.model then
			F.gated = P.gate(true)
			if not F.gated then E.once("gate", "a swing in a melee waits for a tick without an order: no gate on build " .. tostring(P.build)) end
		end
		F.last_order = bm:time_elapsed_ms() / 1000 -- an order: the first click or step waits STEER_GAP from it (round 25)
		E.rig.start(os.clock(), x, y, z, math.rad(unit:bearing()), zoom_now, F.ranged)
		if F.model then E.move.halt() end
		if P.wheel then P.wheel() end -- drop what the wheel did while third person was off
		bm:disable_orders(true)
		-- the game's shortcut on a key an action has is off while on (keys.lua K.game: P paused the game as it hid the
		-- interface); a key moved in MCT leaves the game's own alone
		F.shortcuts = {}
		for _, name in pairs(S.names) do
			local sc = E.K.game[name]
			if sc then bm:disable_shortcut(sc, true) F.shortcuts[#F.shortcuts + 1] = sc end
		end
		bm.battle:enable_tooltips(false) -- the unit hover panel (SpecialTooltip) follows the parked cursor
		bm.battle:suppress_unit_voices(true) -- each start and stop of his walk is a state the game voices, as in CA's cutscenes
		cam:enable_functionality("CAMERA_ALL_FUNCTIONS", false)
		cam:change_height_range(0, 100) -- as CA's cutscenes: the default floor lifts him out of shot with the terrain
		unit:select_in_ui()
		hud(false)
		E.hud.show(true)
		E.log("on: " .. F.utype .. (F.model and ", one man" or "") .. (F.solo and ", shooting alone" or ""))
	end

	-- each step on its own: one that throws must not keep the rest from being put back
	local function try(step, ...)
		local ok, err = pcall(step, ...)
		if not ok then out("derpy_tp: putting back: " .. tostring(err)) end
	end

	function M.stop(why)
		if not F.on then return end
		F.on = false
		try(function()
			E.combat.drop(bm:time_elapsed_ms() / 1000)
			ready_by[F.unit:unique_ui_id()] = F.ready_at
		end)
		F.shot, F.want_shot = nil, false
		-- his swings back; nothing written to a dead man, whose model may be gone
		if F.disarmed then try(function() if P.alive(F.unit, F.disarmed) then P.arm(F.disarmed) end end) F.disarmed = nil end
		if F.gated then F.gated = nil try(function() P.gate(false) end) end
		try(function() E.move.halt() end)
		if F.firing then try(function() E.combat.stop_fire() end) end
		try(function() E.abilities.cancel() end)
		try(function() E.combat.crosshair(false) end)
		try(hud, true)
		F.map = false
		try(function() E.hud.map(false) end) -- CA's radar back in its holder before the panel goes
		try(function() E.hud.show(false) end)
		if F.defend_was == false then try(function() F.uc:change_behaviour_active("defend", false, false) end) end
		if F.held_fire then
			F.held_fire = false
			try(function() F.uc:fire_at_will(F.fire_was) F.uc:release_control() end)
		end
		if F.melee_on then F.melee_on = false try(function() F.uc:melee(false) F.uc:release_control() end) end
		for _, sc in ipairs(F.shortcuts or {}) do try(function() bm:disable_shortcut(sc, false) end) end
		F.shortcuts = nil
		F.ui_off, F.cursor_shown = false, nil -- hidden at the stop: CA's interface comes back all the same
		try(cursor, true)
		F.dragging = false
		try(function() bm:disable_orders(false) end)
		try(function() bm.battle:enable_tooltips(true) end)
		try(function() bm.battle:set_banners_enabled(true) end)
		try(function() bm.battle:suppress_unit_voices(false) end)
		try(function() cam:enable_functionality("CAMERA_ALL_FUNCTIONS", true) end)
		try(function() cam:change_height_range(-1, -1) end)
		E.log("off: " .. tostring(why))
	end

	function E.fail(err)
		out("derpy_tp: error: " .. tostring(err))
		pcall(M.stop, "error")
		E.strikes = E.strikes + 1
		if E.strikes >= MAX_ERRORS and not E.disabled then
			E.disabled = true
			E.say("derpy_tp_switched_off")
		end
	end

	local function frame()
		-- an error inside a one-shot timer is handed over here: E.fail registers a timer, and one registered
		-- from inside a one-shot never runs (memory: wh3-real-callback-one-shot-id-reuse)
		if E.pending then local err = E.pending E.pending = nil E.fail(err) end
		local ok, err = xpcall(function()
			local now = os.clock()
			local dt = now - (F.t or now)
			F.t = now
			if dt <= 0 or dt > 0.25 then dt = 0.016 end
			local gnow = bm:time_elapsed_ms() / 1000
			if gnow ~= F.gt then F.gt, F.gt_real = gnow, now end
			local paused = now - F.gt_real > PAUSE_AFTER
			if P.focused() and P.pressed(E.S.keys.toggle) then
				if E.fp then E.combat.manual_exit()
				elseif F.on then M.stop("key")
				else M.start() end
			elseif F.on then
				tick(now, dt, gnow, paused)
			end
		end, debug.traceback)
		if not ok then E.fail(err) end
	end

	bm:register_phase_change_callback("Complete", function() pcall(M.stop, "battle over") E.disabled = true end)
	bm:repeat_real_callback(frame, 1, "derpy_tp")
	return M
end
