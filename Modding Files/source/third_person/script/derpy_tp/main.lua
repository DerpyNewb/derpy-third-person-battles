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
-- a sprint's speed against his run, the charge's too (the author, 2026-10-16: "if no charge animation, add a 20% boost
-- to speed", then "20% boost even with charge animation"; 2026-10-17: "add 50% speed boost when charging/sprinting")
local SPRINT_SPEED = 1.5
-- s the lock-on key may be held and still be its click: longer is the free mouse's hold when they share a key (keys.lua)
local LOCK_CLICK = 0.3

return function(E)
	local F, P = E.F, E.P
	local cam = bm:camera()
	local M = {}
	local ready_by = {} -- unique_ui_id -> model time he can shoot again, kept across sessions
	local swap -- a transformation under way (M.follow): the army's ui ids at the cast, and the battle time it is waited for

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
	-- Plaguebearers' Death's Head, 25 units of 827 - third_person_fires.py), or RIDER_FIRE_FORWARD_LEVEL for a rider with
	-- neither (measured 2026-10-17: 165 mounted missile units, Kislev's Horse Archers among them; the author: "are mounted
	-- archers not supported? they are missing their ranged option"); nil, none
	local function fire_clip(m)
		for _, s in ipairs({1557, 949, 2105}) do if P.has_slot(m, s) then return s end end
	end

	-- a crew on one body (the author, 2026-10-18: "cannot fire range mode using necrofex"): the Necrofex Colossus's five men
	-- are his crew, all riding the one colossus (read live). One of them is no man to play alone: his rider clips went to
	-- the crew's first man (sent to the front man 15 times, seen only on the first), and the colossus is what walks. Such a
	-- unit is played as a unit of one, on its first man; platform.lua steers, holds, guards and faces his mount
	local function crewed(unit)
		local ms = P.models(unit)
		local body = #ms > 1 and P.mount(ms[1])
		if not body then return false end
		for i = 2, #ms do
			local b = P.mount(ms[i])
			if not (b and P.same(b, body)) then return false end
		end
		return true
	end

	-- a chariot (the author, 2026-10-20: "chariots can be played alone or regiment depending on the mod settings"): every
	-- chariot in CA's data is a war machine, drawn by beasts (data.lua chariots, off db.pack and the installed mods); its
	-- crewman is played and his chariot steered (platform.lua P.mount). Other war machines stay whole: a lord in a tank
	-- steered as a crewman moved nothing (2026-10-14), and a war machine of one is unmeasured on the mailbox.
	-- ponytail: a chariot whose crew shoot (Tiranoc, wolf chariots) is played whole with the guns, so the Tilean tank
	-- and the Knellgun stay as they were; a unit of a mod installed after --gen is played whole
	local function chariot(unit) return E.D.chariots ~= nil and E.D.chariots[unit:type()] == true end

	local function capabilities(m)
		m = m and (P.mount(m) or m)
		-- a slot whose every clip is an empty file is none (data.lua blanks): the Great Unclean One's jump is in his
		-- fragment, and "clip 489 never played" four times in the author's log, 2026-10-18
		local blank = {}
		for _, s in ipairs(E.D.blanks and E.D.blanks[F.utype] or {}) do blank[s] = true end
		local function any(a)
			if m then for s = a, a + 4 do if P.has_slot(m, s) and not blank[s] then return true end end end
			return false
		end
		-- an artillery crew has no melee of its own here: the gun is what is played (the author, 2026-10-18)
		F.can_charge, F.can_jump = not F.arty and any(484), not F.arty and any(489)
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
	-- the author, 2026-10-21: "using the space bar is inconsistent when flying off and on". The button drops a click while
	-- the unit cannot toggle (CA's CanToggleFlying: its cooldown, a take-off or landing under way), so a press is what he
	-- asked for, up or down, kept until the button can take it or FLY_WAIT s pass. A press while one waits takes it back.
	-- CA's IsFlying is the order (the button's selected state), is_currently_flying where he is: ordered there already,
	-- he is on his way, and a click would turn him back
	-- s a press waits: a landing (3 s) then the toggle's cooldown (10 s), measured 2026-10-21 on a Disc Sorcerer; s
	-- between two clicks for it
	local FLY_WAIT, FLY_GAP = 20, 1
	local function fly_press(now)
		local up = F.fly_want and F.fly_want.up
		if up == nil then up = F.unit:is_currently_flying() end
		F.fly_want = {up = not up, till = now + FLY_WAIT}
		if E.hud.value("CanToggleFlying") == nil then toggle_flying() F.fly_want = nil end -- no context: the click alone
	end
	local function fly(now)
		local w = F.fly_want
		if not w then return end
		if F.unit:is_currently_flying() == w.up or now >= w.till then F.fly_want = nil return end
		if now < (w.next or 0) or E.hud.value("CanToggleFlying") ~= true or E.hud.value("IsFlying") == w.up then return end
		toggle_flying()
		w.next = now + FLY_GAP
	end

	-- no shot he did not ask for (the author, 2026-10-14: "absolute control of the unit and no auto attack"): a unit
	-- played whole holds its fire, given back at the end. One man of a regiment leaves it alone - his regiment shoots
	-- as the player set it (the author, 2026-10-19: "controlling a ranged unit disables the rest of the battalions
	-- ranged option too"; 2026-10-15: one man gives it no orders)
	local function hold_fire(unit)
		if F.held_fire or F.model or unit:missile_range() <= 0 then return end
		F.held_fire = true
		F.uc:fire_at_will(false)
		F.uc:release_control()
	end

	local function look(now)
		local S = E.S
		-- on the lock-on's key, only a press past its click frees the mouse: freed at once, every click showed the cursor
		-- and CA's interface faded in and out (the author, 2026-10-21: "the cursor keep popping off")
		local click = S.keys.lock == S.keys.look_free and F.lock_key and now - F.lock_key <= LOCK_CLICK
		if P.held(S.keys.look_free) and not click then F.dragging = false return end
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
			local step = (zout - zin) * S.zoom_rate * dt - notches * ZOOM_NOTCH
			local closest = E.rig.zoom_by(step)
			E.zoom_by_type[F.utype] = E.rig.zoom
			-- zoomed in all the way, or to where the ground would bring the eye in to his head, first person; zoomed out to
			-- where it fits behind him, third (the author, 2026-10-17: "the first person mode should work if the player
			-- scrolled to the lowest"; the ground did that from zoom 0.9 on a slope, probes/zz_tp_zoomsweep.lua)
			local fits = E.rig.fits(E.rig.zoom)
			if step < 0 and (closest or not fits) then E.first_person = true
			elseif step > 0 and fits then E.first_person = false end
		end
	end

	-- now, dt: real time for the camera; gnow: model time for what acts; paused: nothing acts
	local function tick(now, dt, gnow, paused)
		local S, unit = E.S, F.unit
		F.dt = dt -- real time: the model clock steps in 100 ms ticks (move.lua's turn)
		hud(false)
		if unit:number_of_men_alive() == 0 or unit:is_routing() then M.stop("unit lost") return end
		local single = not F.model and (unit:number_of_men_alive() == 1 or F.crew) and P.models(unit)[1]
		if single and P.model_hp(single) <= 0 then M.stop("unit lost") return end
		F.single = F.single_steer and single or nil
		-- orders are off, selection is not: a click on another unit or on the ground would take the portrait
		if bm:num_units_selected() ~= 1 or not selected(unit) then bm:clear_selection() unit:select_in_ui() end
		if F.model and (unit:number_of_men_alive() < 2 or not P.alive(unit, F.model)) then
			-- he died, or he is the last man: the next front-centre man, or the whole unit; a crewman's mate on the same
			-- chariot first, so the camera stays on the chariot played (F.body: read while he lived, not off a dead man)
			F.model, F.man_hold, F.shot, F.lock, F.swung = E.move.front_man(unit, F.body), nil, nil, nil, nil
			F.body = F.model and P.mount(F.model)
			F.reload_slot = F.model and P.reload_slot(F.model)
			-- played whole from here: it holds its fire until third person ends
			hold_fire(unit)
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
		-- first person (the author, 2026-10-17: "first person camera"): out of the man he plays, or a unit of one; a regiment
		-- played whole has no head to look out of. The rig takes his height
		local head = E.first_person and (F.model or single) or nil
		local body = head and E.D.bodies and E.D.bodies[F.utype]
		local height = head and (body and body[2] or 1.8)
		local x, y, z
		if head or F.model then x, y, z = P.model_pos(head or F.model)
		else local q = unit:position() x, y, z = q:get_x(), q:get_y(), q:get_z() end
		local kf, kr = 0, 0
		if P.focused() then
			-- the lock-on: a click, on its release (combat.lua C.target); read before the look, which it holds off
			local lk = P.held(S.keys.lock)
			if lk and not F.lock_key then F.lock_key = now
			elseif not lk and F.lock_key then
				if now - F.lock_key <= LOCK_CLICK then E.combat.target() end
				F.lock_key = nil
			end
			look(now)
			if P.pressed(S.keys.hide_ui) then hide_ui(not F.ui_off) end -- paused too: a still to take a picture of
			if P.pressed(S.keys.minimap) then F.map = E.hud.map(not F.map) end
			if P.pressed(S.keys.view) then E.first_person = not E.first_person end -- kept for the battle
			-- the markers under enemies and allies (the author, 2026-10-19: "show the ally/enemy guide while holding/ toggle
			-- Alt, configurable using mct"): while held, or a press switches them; paused too
			if S.guide_hold then F.guide = P.held(S.keys.guide) elseif P.pressed(S.keys.guide) then F.guide = not F.guide end
			cursor(not F.dragging)
			if F.dragging then P.hide_cursor() end -- every frame: the game's middle-button release shows it (platform.lua)
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
					-- a move key ends a clicked ground-fire shot, as it drops one man's: it holds his walk, and waits out a reload
					if F.firing and not held and (kf ~= 0 or kr ~= 0) then E.combat.stop_fire() end
					E.combat.attack(gnow, F.dragging and clicked, F.dragging and held)
				end
				-- the next page of the ability bar (the author, 2026-10-20: "pressing t will switch the hotbar to spells");
				-- an armed ability's slot goes with its page, so it is disarmed
				if P.pressed(S.keys.page) and F.dragging then E.abilities.cancel() E.hud.next_page() end
				for n = 1, 10 do
					if P.pressed(S.keys["ability_" .. n]) and F.dragging then
						local why = E.abilities.press(n, gnow)
						if why then E.log(why) end
						if not F.on then return end -- a transformation ends this session: nothing more on the old unit
					end
				end
				if P.pressed(S.keys.fly) and F.dragging then fly_press(gnow) end
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
			-- shouldnt be"; 2026-10-14: "absolute control and no auto attack"). In multiplayer the guard is a state on every
			-- machine: P.guard sends it once, P.unguard takes it off by the id it went with, alive or dead: here when the
			-- body changes (he died and the next man is played) or goes (a unit of one's own attack orders), and at the stop
			local guard = F.model or single and not F.native_attack and not F.driving and not F.firing and single or nil
			if F.guarded and P.features.net and not (guard and P.same(guard, F.guarded)) then P.unguard() F.guarded = nil end
			if guard then P.guard(guard) F.guarded = guard end
			-- and none of its swings start on him (P.disarm): his own, and an attack order on a unit of one, only
			-- a swing held back past its lock (combat.lua C.locked) stays armed until it has played
			-- multiplayer: a clip of his once seen lets his steps and turns go again (platform.lua R.watch; a no-op alone)
			P.watch(F.model or single or nil)
			local pd = F.pending
			if pd then
				local c = P.anim_slot(pd.m)
				if c == pd.slot then pd.seen = true end
				if pd.seen and c ~= pd.slot or not pd.seen and gnow >= pd.till then F.pending = nil end
			end
			-- one man of a regiment: none of its volleys either, armed only for his own shot (F.shot); a unit of one keeps his
			-- shot clips, the engine's own order fires him (combat.lua C.ground)
			local man = F.model or single
			if man then
				if F.lock or F.swung or F.native_attack or F.pending or F.shot then P.arm(man)
				else P.disarm(man, F.model ~= nil, single and F.sprinting and F.charge_order ~= nil) end
				F.disarmed = man
			end
			-- through his jump, charge attack and a blow standing idle (his defend): a unit of one only
			E.combat.invincible(single, gnow, kf == 0 and kr == 0)
			fly(gnow)
			if F.shot and (kf ~= 0 or kr ~= 0) then E.combat.drop(gnow, true) end
			if F.shot then P.face(F.model, E.move.turn(F.model, E.rig.yaw, E.move.ACTION_TURN))
			elseif E.combat.locked(gnow) and not F.lock.runs then
				-- a swing or cheer: until the engine reports its clip (0.19-0.31 s) and he has turned to the crosshair, as a clip
				-- under way still turns him; then the clip turns him (round 25)
				local m = F.model or F.single
				if m and not (F.lock.turns and F.lock.seen and F.lock.faced) then
					local yaw = E.move.turn(m, F.lock.yaw, E.move.ACTION_TURN)
					P.face(m, yaw)
					F.lock.faced = yaw == F.lock.yaw
				end
			elseif not F.firing and (not F.charge_order or F.single) then E.move.drive(gnow, kf, kr, F.running, F.sprinting and SPRINT_SPEED or 1) end
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
		E.combat.track(dt)
		E.combat.crosshair((F.ranged or F.armed ~= nil) and F.dragging and not F.ui_off)
		E.hud.update(gnow)
		-- melee mode centres on him; an ability armed looks ahead, where its crosshair aims (combat.lua C.aim_point)
		local ex, ey, ez, lx, ly, lz = E.rig.update(now, dt, x, y, z, F.ranged, unit:is_in_melee(),
			cam:position():get_y(), height, not F.ranged and not F.armed)
		cam:move_to(v(ex, ey, ez), v(lx, ly, lz), 0, false, -1, false)
		F.frames = F.frames + 1
	end

	-- a transformation replaces the unit (abilities.lua ends third person before it goes off): the unit that was not in
	-- the army at the cast is its new form, played on as soon as it is there (the author, 2026-10-17: "seems to
	-- deactivate f2 when changing ammo"; measured: Deithland's mortar was back 0.2 s after the cast, under a ui id of
	-- its own). Waited for in battle time, a wind-up included (CA's dragon forms wind up 5 s), and for its unit card: it
	-- came a frame after the unit, and taken over before it the HUD had no context (portrait and slots off for good)
	local SWAP_WAIT = 10
	function M.follow()
		local army, before = bm:get_player_army(), {}
		for i = 1, army:units():count() do before[army:units():item(i):unique_ui_id()] = true end
		swap = {before = before, till = bm:time_elapsed_ms() / 1000 + SWAP_WAIT}
	end
	local function follow_swap(gnow)
		if gnow > swap.till then swap = nil return end
		local army = bm:get_player_army()
		for i = 1, army:units():count() do
			local u = army:units():item(i)
			if not swap.before[u:unique_ui_id()] and u:number_of_men_alive() > 0
				and find_uicomponent(core:get_ui_root(), "cards_panel", tostring(u:unique_ui_id())) then M.start(u) return end
		end
	end

	-- a press before every player's HELLO (Ruling 26) is kept, F.asked its model s: third person starts by itself once the
	-- handshake completes (M.start forgets the press as it starts), and the player is told when the platform says it is
	-- late (P.net_late). A press is dropped after NET_DROP model s: the handshake has missed its 5 s three times over, and
	-- a camera taken over that long after the key would land on a player who has gone back to commanding the battle. Once
	-- complete, a new press starts at once
	local NET_DROP = 15
	local function waiting(gnow)
		if P.net_play then M.start() return end
		if gnow - F.asked >= NET_DROP then F.asked = nil return end
		if P.net_late and not F.told then F.told = true E.say("derpy_tp_mp_needs_everyone") end
	end

	-- multiplayer waits for "Deployed", where every machine builds the fragment table its disarm reads; a build that threw
	-- leaves it waiting for the battle (platform.lua P.net_ready; MP_FEASIBILITY_20261021_THIRD_PERSON.md, Ruling 20).
	-- Nothing said or logged: it simply waits. Then for every player's HELLO (platform.lua M.handshake, Rulings 25, 26 and
	-- 29): the first press asks this machine to say HELLO and is kept; a press while it waits is ignored, sending nothing
	-- and restarting nothing, and the kept press still starts it on completion. A spectator plays no army: CA does not say
	-- what local_army() names on one, and a player's would be driven from the spectator's client. It is refused here, not
	-- at the build, since its handshake still puts its gate in at the players' tick
	function M.start(unit)
		if E.disabled or F.on or P.features.net and not P.net_ready then return end
		if P.features.net then
			local ok, watching = pcall(function() return bm:is_spectator() end)
			if not ok or watching then E.once("spectator", "multiplayer: a spectator plays no army, so third person stays off") return end
		end
		if P.features.net and not P.net_play then
			if not F.asked then F.asked, F.told, P.net_asked = bm:time_elapsed_ms() / 1000, false, true end
			return
		end
		-- the key, or the new form: either way nothing more is waited for, and a kept press is spent
		swap, F.asked = nil, nil
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
		-- one man is steered, held and guarded only on the battle thread (platform.lua's mailbox); a cave refused because a
		-- thread was in his update goes in at a later start
		if P.features.steer and not P.features.mailbox then
			local ok, why = check("mailbox", P.check_mailbox)
			if not ok then E.once("mailbox", "regiments are played whole: " .. tostring(why)) end
		end
		-- one man of a regiment, flyers too (the author, 2026-10-17: "flying units still controls the whole battalion as well
		-- when moving"; measured that day, probes/zz_tp_fly_one.lua: a Birdman steered alone in the air and landed. On
		-- 2026-10-15's steering a gyro gunship's crew steered nothing, and flyers were played whole)
		F.crew = men_ok and P.features.steer and crewed(unit)
		F.model = S.one_man and men_ok and P.features.steer and P.features.mailbox and not F.arty
			and (not unit:is_war_machine() or chariot(unit)) and not F.crew and E.move.front_man(unit) or nil
		F.body = F.model and P.mount(F.model)
		-- a unit of one walks steered alone too, his sprint in the steer (the author, 2026-10-18; CA's walk speed scalar
		-- leaves a single entity's speed alone, measured that day): main.lua's frame keeps F.single, his model
		F.single_steer = not F.model and men_ok and P.features.steer and P.features.mailbox and not F.arty
			and (not unit:is_war_machine() or chariot(unit))
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
		F.native_attack, F.charge_order = nil, nil
		-- artillery too: its click is the gun's attack (combat.lua C.attack), the mode key CA's Manual fire (the author, 2026-10-18: "I am
		-- only controlling the gunners, not the artillery piece itself")
		F.ranged = E.can_shoot()
		-- a reload under way when he was last let go still counts (ready_by, by unit)
		F.firing, F.want_shot, F.shot, F.next_swing, F.swings, F.shot_n = false, false, nil, 0, 0, 0
		F.ready_at = ready_by[unit:unique_ui_id()] or 0
		F.driving, F.dragging, F.running, F.cursor_shown, F.held_fire = false, false, true, nil, false
		F.walking, F.sprinting, F.stamina, F.stamina_t, F.map = false, false, 1, nil, false
		F.man_hold, F.frames, F.swallow, F.ui_off, F.melee_on, F.face_yaw, F.queued = nil, 0, nil, false, false, nil, nil
		F.lead = nil -- his steering point at its full distance (move.lua)
		F.fly_want = nil
		F.target, F.lock_key = nil, nil
		F.hit_hp, F.next_react = nil, 0 -- a blow is his hit points falling from one frame to the next (combat.lua C.invincible)
		F.fire_was = unit:is_behaviour_active("fire_at_will") -- the player's own setting, given back at the end
		local x, y, z
		if F.model then x, y, z = P.model_pos(F.model) else local q = unit:position() x, y, z = q:get_x(), q:get_y(), q:get_z() end
		local zoom_now = E.zoom_by_type[F.utype] or (unit:is_infantry() and 1 or ZOOM_LARGE)
		-- on from here: whatever below changes the battle, M.stop puts back, even if a later line throws
		F.on = true
		-- the author: "absolute control of the unit and no auto attack". It shoots when clicked, never at will, and
		-- keeps its ground (defend: no pursuit) - both given back as the player had them
		hold_fire(unit)
		-- one man of a regiment gives it neither: CA's halt turns its fire at will off, and it stayed off past the end
		-- (the author, 2026-10-19: "controlling a ranged unit disables the rest of the battalions ranged option too";
		-- measured that day). He is halted alone (E.move.halt below)
		F.defend_was = nil
		if not F.model then
			F.defend_was = unit:is_behaviour_active("defend")
			if not F.defend_was and unit:can_use_behaviour("defend") then F.uc:change_behaviour_active("defend", true, false) end
			F.uc:halt()
			F.uc:release_control()
		end
		-- his clicks beat the order his regiment gives him each tick of a melee (platform.lua P.gate); a unit of one steered
		-- alone too, whose melee attack the engine orders again every tick (measured 2026-10-18: none of 5 played, gated 6 of 6).
		-- Multiplayer: the gate changes the simulation, so every machine has it from the handshake (platform.lua M.handshake) to
		-- the battle's end, and here it is left alone: a toggle at a key press is a desync, and F.gated stays nil for the stop
		if (F.model or F.single_steer) and not P.features.net then
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
			-- Alt the guide key: Alt held with an action's key is the game's Alt shortcut too (Alt+M its music)
			sc = S.names.guide == "Alt" and E.K.game_alt[name]
			if sc then bm:disable_shortcut(sc, true) F.shortcuts[#F.shortcuts + 1] = sc end
		end
		bm.battle:enable_tooltips(false) -- the unit hover panel (SpecialTooltip) follows the parked cursor
		bm.battle:suppress_unit_voices(true) -- each start and stop of his walk is a state the game voices, as in CA's cutscenes
		cam:enable_functionality("CAMERA_ALL_FUNCTIONS", false)
		cam:change_height_range(0, 100) -- as CA's cutscenes: the default floor lifts him out of shot with the terrain
		-- and the floor counts the terrain alone: a roof or a gatehouse lifted the eye 18-24 m (platform.lua P.terrain_floor)
		F.floored = P.terrain_floor(true)
		if not F.floored then E.once("floor", "the camera rises over buildings: no terrain floor on build " .. tostring(P.build)) end
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
		if F.guarded and P.features.net then try(P.unguard) end -- by its id: nothing read off a dead man
		F.guarded = nil
		if F.gated then F.gated = nil try(function() P.gate(false) end) end
		if F.invincible then F.invincible = nil try(function() F.uc:set_invincible(false) F.uc:release_control() end) end
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
		if F.floored then F.floored = nil try(function() P.terrain_floor(false) end) end
		try(function() P.net_reset() end) -- multiplayer: the next session's first hold stops him anew
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
			elseif F.asked then
				waiting(gnow)
			elseif swap then
				follow_swap(gnow)
			end
		end, debug.traceback)
		if not ok then E.fail(err) end
	end

	bm:register_phase_change_callback("Complete", function() pcall(M.stop, "battle over") E.disabled = true end)
	bm:repeat_real_callback(frame, 1, "derpy_tp")
	return M
end
