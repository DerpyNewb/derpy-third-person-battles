-- Fighting from third person (spec section 6): swings, ranged fire by unit kind, the crosshair, and the
-- artillery hand-over to the game's Manual fire mode. return function(E) -> C.
local SLOTS_LMB, SLOTS_RMB = {454, 455, 456, 457}, {458, 459, 460} -- ATTACK_1-4 and ATTACK_5-7
local SLOTS_JUMP, SLOTS_RUN = {489, 490, 491, 492, 493}, {484, 485, 486, 487, 488} -- JUMPING_ and MOVING_ATTACK_1-5
local SLOTS_CHEER = {1094, 1095, 1096, 1097, 1098, 1099, 1100, 1101, 1102, 1103} -- CELEBRATE_1-10
local SLOTS_TAUNT = {1104, 1105, 1106, 1107, 1108, 1109, 1110, 1111, 1112, 1113} -- TAUNT_1-10
-- s an action clip holds him at most; s it may take to report (measured 2026-10-15: the jump runs ~2 s, the charge
-- attack ~1.8; reported 0.1 s after being sent in a small battle, 0.19-0.31 s in a busy one)
local LOCK_MAX, LOCK_WAIT = 3, 1
local TURN_DEG, TURN_WAIT_MS, MAX_MODELS = 25, 350, 160
local AIM_COS, AIM_RANGE, AIM_CLOSE = 0.707, 150, 8 -- a melee target: inside 45 deg and 150 m, or 8 m any way
local AIM_STEP, FIRE_REAIM, FIRE_ARC, FIRE_COMMIT, STEER_GAP = 2, 5, 20, 4, 0.5 -- AIM_STEP: m a march step of the view
-- s a ground-fire shot's clip may run on past the shot leaving before it is halted anyway: a fire clip runs to 9.5 s
-- (the Necrofex Colossus's flame, 6.8 s of it after the flame leaves; Ku'gath's throw 5.7)
local FIRE_TAIL = 10
-- the clips a shot plays (9.0 ids): AIM_ to KNEEL_ (1547-1599: raise, aim, fire, reload, moving fire, a pilum, the crenels),
-- GRENADIER and the throws (949-952), RIDER_FIRE_ and RIDER_THROW_PILUM (2104-2116). An idle is none of them: one on his
-- body as the shot leaves must not hold the order for its 9 s
local function shooting(s) return s and (s >= 1547 and s <= 1599 or s >= 949 and s <= 952 or s >= 2104 and s <= 2116) or nil end
-- m from a regiment's centre its men can stand: a wide line of 160 is ~40 m across
local SPREAD = 30
-- 9.0 ids (AssetEditor's dlc24 list + 2): SHOOT_READY_TO_AIM_LEVEL, FIRE_LEVEL; the reload slot comes from the
-- unit's animation fragment, and a crossbow's is the raise to aim itself
local SLOT_AIM = 1554 -- the fire clip is F.fire_slot (main.lua): FIRE_LEVEL 1557, or a thrower's GRENADIER 949
-- one pair per shot, by the angle it leaves at (the author, 2026-10-15: "fire level high, level, low not fitting to the
-- precursor fire of aim high, level and low"): SHOOT_READY_TO_AIM_ and FIRE_ LOW, LEVEL, HIGH. Past BAND up or down, the
-- high or low pair (their poses sit near 45 deg); G: gravity for the projectile's low arc, m/s2. Third: the pair's AIM_
-- LOW, LEVEL, HIGH, CA's hold between raise and fire: a raise ends past its aim (seen 2026-10-16, the Streltsi's level
-- one ~20 deg up, probes/zz_tp_shot_side2.lua) and the fire snapped it back; the aim clip sets it (zz_tp_aim_seq.lua)
local PAIRS, BAND, G = {low = {1553, 1556, 1547}, level = {1554, 1557, 1548}, high = {1555, 1558, 1549}}, math.rad(22.5), 9.81
-- s the aim clip plays, from its report, before the fire: past its 0.3 s blend in (the bin's), the gun was level at the
-- report already (seen); CA's own gap between raise and fire is 0.1-0.2 s with no clip reported (zz_tp_vanilla_fire.lua)
local AIM_HOLD = 0.2
local SHOT_DELAY_MS, SHOT_H, SHOT_FWD = 300, 1.5, 1.5 -- anim to release; m up; m forward (the jitter is S.spread)
-- m ahead of him a spawn must be: a scripted launch has no owner, and one inside him hits him (the author, 2026-10-16:
-- "aiming up the projectile hits the controlled unit"; measured: Akshina's Ambushers' high muzzle 0.45 m ahead, 2 m up,
-- 77 to 48 hp 0.2 s after). No level or low muzzle, 1.12 m out and further, ever hit him
local SHOT_CLEAR = 1.1
-- a thrown bomb's release (measured 2026-10-15 in anim2.pack: both blasting-charge throws carry FIRE_POS at 2.2 and 2.3 s)
local THROW_MS = 2200
-- the charge run: CHARGE at mask 6 (measured 2026-10-15: he keeps his speed under it), sent again CHARGE_LEAD s before
-- its own end - a model tick, so the next starts as it ends (ponytail: a guess until measured in game)
local CHARGE, CHARGE_LEAD, WALK_1 = 135, 0.1, 42
local FLY_CHARGE = 102 -- FLY_CHARGE_AIR_TO_AIR
-- the exe's body-mask enum (exe+3926238, read 2026-10-16): 0 NONE (the clip's own metadata), 1 TORSO_AND_ARMS,
-- 2 SPINE_AND_CHILDREN, 3 NECK_AND_CHILDREN, 4 LEFT_ARM, 5 RIGHT_ARM, 6 FULL_BODY
local TORSO_AND_ARMS = 1
-- a clip starts a model tick or two after it is sent (reported 0.1-0.31 s late, measured 2026-10-15)
local CLIP_START = 0.2
-- stamina, model time: a sprint empties it in STAMINA_DRAIN s and it fills in STAMINA_FILL s off it; empty, no sprint
-- until STAMINA_AGAIN of it is back. ponytail: constants; an MCT slider each when asked for
local STAMINA_DRAIN, STAMINA_FILL, STAMINA_AGAIN = 8, 12, 0.25
-- s before the raise to aim ends that fire is sent: one model-time step (100-200 ms) so the command lands in time.
-- ponytail: a guess until measured in game; too long cuts the raise visibly short
local AIM_LEAD = 0.15

return function(E)
	local F, P = E.F, E.P
	local C = {}
	local aim_len = {} -- unit type and raise slot -> s the raise runs, measured on the first whole one
	local turn = {} -- slot list -> the next in its rotation

	-- his models: the one man, a unit of one's (a crew's first man: the rest ride the same body), or every man of the
	-- unit up to MAX_MODELS
	local function each(fn)
		local one = F.model or F.single
		local ms = one and {one} or P.models(F.unit)
		for i = 1, math.min(#ms, MAX_MODELS) do fn(ms[i]) end
	end

	-- the aiming dot: our own instance of the first-person layout with everything but its crosshair hidden
	function C.crosshair(show)
		show = show and true or false -- SetVisible(nil) corrupts the game's strings
		if F.xhair == show then return end
		F.xhair = show
		local root = core:get_ui_root()
		local ui = find_uicomponent(root, "derpy_tp_crosshair")
		if not ui then
			if not show then return end
			ui = UIComponent(root:CreateComponent("derpy_tp_crosshair", "ui/battle ui/first_person_ui"))
			for i = 0, ui:ChildCount() - 1 do local c = UIComponent(ui:Find(i)) c:SetVisible(c:Id() == "crosshair") end
			local x = find_uicomponent(ui, "crosshair")
			local sw, sh = core:get_screen_resolution()
			local w, h = x:Dimensions()
			x:MoveTo(math.floor(sw / 2 - w / 2), math.floor(sh / 2 - h / 2))
		end
		ui:SetVisible(show)
	end

	-- the point under the screen centre: last frame's camera ray where it meets the ground; looking level or up, or past
	-- reach, the ray's point at reach from him (in the air: an order or a cast wants the ground under it). nil before the
	-- first frame. (the author, 2026-10-15: "far off from the crosshair" - it met a flat plane at his height, 1 m under
	-- where the shot went)
	-- The first enemy man the view passes through before t_max, as its t (the author, 2026-10-16: "it shoots above, so its
	-- aiming at the terrain not the cursor target" - the view ran through the Ogre under the crosshair to the ground
	-- behind him, and the arc to that far point passed over him). Each man a standing cylinder of his entity's radius and
	-- height (data.lua bodies; a man's 0.5 by 1.8 m where it has none), tested where the view passes closest to his axis;
	-- only the regiments whose centre the view passes within SPREAD of are read
	local function first_enemy(ex, ey, ez, dx, dy, dz, t_max)
		local hh = dx * dx + dz * dz
		if hh < 1e-6 then return nil end
		local best = t_max
		local armies = bm:get_non_player_alliance():armies()
		for a = 1, armies:count() do
			local list = armies:item(a):units()
			for i = 1, list:count() do
				local u = list:item(i)
				local q = u:position()
				local t = ((q:get_x() - ex) * dx + (q:get_z() - ez) * dz) / hh
				local ox, oz = ex + dx * t - q:get_x(), ez + dz * t - q:get_z()
				if t > -SPREAD and t < best + SPREAD and ox * ox + oz * oz < SPREAD * SPREAD and u:number_of_men_alive() > 0 then
					local body = E.D.bodies and E.D.bodies[u:type()]
					local r, h = body and body[1] or 0.5, body and body[2] or 1.8
					for _, m in ipairs(P.models(u)) do
						local mx, my, mz = P.model_pos(m)
						local s = ((mx - ex) * dx + (mz - ez) * dz) / hh
						local cx, cz, y = ex + dx * s - mx, ez + dz * s - mz, ey + dy * s
						if s > 0 and s < best and cx * cx + cz * cz <= r * r and y >= my and y <= my + h then best = s end
					end
				end
			end
		end
		return best < t_max and best or nil
	end

	function C.aim_point(reach)
		local R = E.rig
		if not R.ex then return nil end
		local ux, uz
		if F.model then local x, _, z = P.model_pos(F.model) ux, uz = x, z else local q = F.unit:position() ux, uz = q:get_x(), q:get_z() end
		local dx, dy, dz = R.lx - R.ex, R.ly - R.ey, R.lz - R.ez
		local n = math.sqrt(dx * dx + dy * dy + dz * dz)
		dx, dy, dz = dx / n, dy / n, dz / n
		local function at(t) return R.ex + dx * t, R.ey + dy * t, R.ez + dz * t end
		local function stop(t) local x, y, z = at(t) return y <= bm:get_terrain_height(x, z) or (x - ux) ^ 2 + (z - uz) ^ 2 > reach * reach end
		-- the view marched until it meets the ground (a slope included) or passes his reach, then halved down to 6 cm
		local t, cap = 0, (reach + 50) / AIM_STEP
		repeat t = t + AIM_STEP cap = cap - 1 until stop(t) or cap <= 0
		local lo = t - AIM_STEP
		for _ = 1, 5 do local mid = (lo + t) / 2 if stop(mid) then t = mid else lo = mid end end
		return at(first_enemy(R.ex, R.ey, R.ez, dx, dy, dz, t) or t)
	end

	-- the enemy nearest the aim: inside AIM_COS of the camera's forward and reach (AIM_RANGE, a gun's its range), or
	-- AIM_CLOSE any way; distance weighted by how far off the aim it is
	local function pick_target(reach)
		reach = reach or AIM_RANGE
		local q = F.unit:position()
		local qx, qz = q:get_x(), q:get_z()
		local fx, fz = math.sin(E.rig.yaw), math.cos(E.rig.yaw)
		local best, best_score
		local armies = bm:get_non_player_alliance():armies()
		for a = 1, armies:count() do
			local list = armies:item(a):units()
			for i = 1, list:count() do
				local e = list:item(i)
				if e:is_valid_target() and not e:is_routing() and e:number_of_men_alive() > 0 then
					local p = e:position()
					local dx, dz = p:get_x() - qx, p:get_z() - qz
					local d = math.sqrt(dx * dx + dz * dz)
					local c = (dx * fx + dz * fz) / math.max(d, 0.01)
					if d < AIM_CLOSE or (c > AIM_COS and d < reach) then
						local score = d * (2 - c)
						if not best_score or score < best_score then best, best_score = e, score end
					end
				end
			end
		end
		return best
	end

	-- an order inside STEER_GAP of the last is dropped by the engine (a click just after the walk's halt attacked nothing):
	-- it waits, sent from the tick (C.attack), never from a timer - a timer set inside a timer never runs (round 25)
	function C.flush(now)
		if not F.queued or now - (F.last_order or -1e9) < STEER_GAP then return end
		local fn = F.queued
		F.queued = nil
		fn()
		F.uc:release_control()
		F.driving, F.last_order = false, now
	end

	local function send(fn)
		F.queued = fn
		C.flush(bm:time_elapsed_ms() / 1000)
	end

	-- CA's attack order on the enemy nearest the aim: a unit played whole with no clip to swing charges it. Never for one
	-- man of a regiment: it is his regiment's order (the author, 2026-10-15: one man gives it no orders)
	local function order(primary, reach)
		if F.model then return end
		local target = pick_target(reach)
		if not target then return end
		send(function()
			F.uc:attack_unit(target, primary, F.running)
			F.native_attack = true
			E.log("attack order on " .. target:type())
		end)
	end

	-- the next attack animation of the list, on the one man or every model that has it (measured 2026-10-15: the
	-- Greybeard tank's crew have ATTACK_1-5, a landship's none); no model with it, the attack order. A whole unit
	-- more than TURN_DEG off the camera is turned first
	-- now: the swing is an action (jump, charge attack) that nothing may cut until its clip ends - see C.locked - or hold s
	-- pass (a swing's clip runs 2.1-7.1 s, median 3.5, measured 2026-10-15 over 37 ATTACK_1-7 clips of 6 units)
	-- an action starts (a swing, jump, charge attack, cheer): a shot under way is dropped, or it fired after the action
	-- (round 25); he faces the crosshair before the clip plays (main.lua's lock writes nothing once the engine reports it).
	-- A charge's run ends through the sprint, which the lock ends, and charge_run sends no clip over the action's
	local function act(now)
		C.drop(now)
		F.native_attack = nil
		F.face_yaw = nil
		if F.model then P.face(F.model, E.rig.yaw) end
	end

	local function swing(slots, primary, now, hold, mask)
		-- only the clips his men have (the author, 2026-10-15: "rng on activating the animation" - measured, a list that
		-- rotated past them played nothing), each list on its own count
		local first, has = F.model or P.models(F.unit)[1], {}
		local mount = first and P.mount(first)
		-- what flies: his mount, or he on his own wings (the author, 2026-10-18: "flying units when using melee uses ground
		-- melee attacks e.g belakor"; Be'lakor has no mount, ATTACK_1-5 and FLY_ATTACK_1-4, read live)
		local flyer = mount or first
		local air = flyer and F.unit:is_currently_flying() and (slots == SLOTS_LMB or slots == SLOTS_RMB)
		for _, s in ipairs(slots) do
			if air then
				if P.has_slot(flyer, s + 40) then has[#has + 1] = s end
			elseif first and (P.has_slot(first, s) or mount and P.has_slot(mount, s)) then has[#has + 1] = s end
		end
		if air and #has == 0 then for s = 454, 460 do if P.has_slot(flyer, s + 40) then has[#has + 1] = s end end end
		if #has == 0 then has = slots end -- a rider's fallback clip, or the attack order
		local k = turn[slots] or 0
		local slot = has[k % #has + 1]
		turn[slots], F.swings = k + 1, F.swings + 1
		act(now)
		-- an action faces the camera as it starts and keeps that facing to its end (main.lua): left alone, the engine played
		-- jump and charge attacks along the regiment's facing (the author, 2026-10-15). A swing's only until its clip plays:
		-- the clip turns him (measured 2026-10-15, Chosen ATTACK_2: 21 deg right, then 28-46 deg left through the blow, then
		-- back), and a facing held over it put the blow 30-45 deg right of the crosshair ("WHY IS IT SWINGING TO THE RIGHT")
		-- (the click's swing is the one held to a cooldown; jump and charge attacks, not measured, keep the camera's facing)
		if now then F.lock = {from = now, till = now + (hold or LOCK_MAX), yaw = E.rig.yaw, turns = hold ~= nil} end
		-- the model that carries the clip, and its slot; nil when he has none
		local function play(m)
			local mount = P.mount(m)
			if mount then
				local chosen = slot
				if F.unit:is_currently_flying() and slot >= 454 and slot <= 460 then
					chosen = P.has_slot(mount, slot + 40) and slot + 40 or 494
				end
				if chosen == slot and slot >= 454 and slot <= 460 and not P.has_slot(mount, chosen) then chosen = 454 end
				if P.has_slot(mount, chosen) then P.play(mount, chosen, mask) return mount, chosen end
				if P.has_slot(m, slot) then P.play(m, slot, mask) return m, slot end -- an artillery crewman's parent is his gun
				return
			end
			if F.unit:is_currently_flying() and slot >= 454 and slot <= 460 and P.has_slot(m, slot + 40) then
				P.play(m, slot + 40, mask) return m, slot + 40 -- FLY_ATTACK_n, as a mount's
			end
			local rider = slot + 1447 -- ATTACK_1 -> RIDER_ATTACK_1
			local chosen = slot
			if F.unit:is_currently_flying() and P.has_slot(m, 1941) then chosen = P.has_slot(m, rider + 40) and rider + 40 or 1941
			elseif P.has_slot(m, 1901) then chosen = P.has_slot(m, rider) and rider or 1901 end
			if chosen ~= slot then
				P.play(m, chosen, 6)
				return m, chosen
			elseif P.has_slot(m, slot) then P.play(m, slot, mask) return m, slot end
		end
		local function go()
			local any = false
			each(function(m)
				local carrier, played = play(m)
				if carrier and not any and F.lock and not F.lock.m then
					F.lock.m, F.lock.slot = carrier, played
					-- a swing's clip outlives its hold (2.6-3.5 s against 1.5): it turns him itself to its end (move.lua)
					if F.lock.turns then F.swung = {carrier, played} end
				end
				any = any or carrier ~= nil
			end)
			if not any then F.lock = nil order(primary) end -- no clip: nothing to wait for
		end
		local want = math.deg(E.rig.yaw) % 360
		local off = math.abs((want - F.unit:bearing() + 540) % 360 - 180)
		-- a unit of one steered alone is faced as one man is (act): the turn order lost his swing (measured 2026-10-18)
		if off > TURN_DEG and not (F.model or F.single) then
			send(function()
				local q = F.unit:position()
				F.uc:goto_location_angle_width(v(q:get_x(), q:get_y(), q:get_z()), want, math.max(F.unit:ordered_width(), 1), false)
				bm:real_callback(function()
					local ok, err = xpcall(function() if F.on then go() end end, debug.traceback)
					if not ok then E.pending = err end -- E.fail registers a timer: not from in here
				end, TURN_WAIT_MS, "derpy_tp_swing_" .. F.swings)
			end)
		else
			go()
		end
	end

	function C.melee(now, primary)
		if C.locked(now) or now < F.next_swing then return end -- the mode key's swing too (round 25)
		F.next_swing = now + E.S.swing_cooldown
		-- held like an action, to the next swing at most: the walk waits (the author, 2026-10-15: "spamming left button while
		-- walking does nothing, melee should be prioritized" - the walk and its unlatch's WALK_1 cut the swing off)
		if P.features.anim and F.men_ok then swing(primary and SLOTS_LMB or SLOTS_RMB, primary, now, E.S.swing_cooldown) return end
		order(primary)
	end

	-- ground fire at the aim (single entities and regiments without a one-man shot): turned first when
	-- the aim is outside FIRE_ARC; re-aimed when the point moves FIRE_REAIM, no faster than STEER_GAP
	-- a shooting clip on him or on his body
	local function in_shot()
		local first = F.model or P.models(F.unit)[1]
		local body = first and P.mount(first)
		return shooting(first and P.anim_slot(first)) or shooting(body and P.anim_slot(body))
	end

	local function fire(now)
		local ax, ay, az = C.aim_point(F.unit:missile_range())
		if not ax then return end
		-- a shot under way is not re-aimed or turned: a new order starts the engine's aim again (the author, 2026-10-18:
		-- "moving the mouse and aiming for fire, it keeps repeating the aim animation and never firing" - the Necrofex
		-- Colossus, 13 orders in 14 s, his FIRE_LEVEL letting the shot go 2.66 s into 9.5)
		if F.fire_at and in_shot() then return end
		local q = F.unit:position()
		local want = math.deg(math.atan2(ax - q:get_x(), az - q:get_z())) % 360
		if math.abs((want - F.unit:bearing() + 540) % 360 - 180) > FIRE_ARC then
			local turned = F.turn_to and math.abs((want - F.turn_to + 540) % 360 - 180) <= FIRE_ARC / 2
			if not turned and now - (F.last_order or -1e9) >= STEER_GAP then
				F.uc:goto_location_angle_width(v(q:get_x(), q:get_y(), q:get_z()), want, math.max(F.unit:ordered_width(), 1), false)
				F.uc:release_control()
				F.turn_to, F.fire_at, F.last_order, F.driving = want, nil, now, false
			end
			return
		end
		F.turn_to = nil
		-- the gap from any order, the first fire too: the walk's halt just before it (round 25)
		if now - (F.last_order or -1e9) < STEER_GAP
			or F.fire_at and (ax - F.fire_at[1]) ^ 2 + (az - F.fire_at[2]) ^ 2 < FIRE_REAIM * FIRE_REAIM then return end
		-- a ground-fire order with fire at will off looses nothing (measured 2026-10-15): it is on while he shoots, from
		-- the order and not the click - on through the turn, the unit swung back to the enemy it could already shoot and
		-- never faced the aim (the author, 2026-10-17: "check artillery still bugging"; the Tilean tank, zz_tp_tank_fire.lua)
		F.uc:fire_at_will(true)
		F.uc:attack_location(v(ax, bm:get_terrain_height(ax, az), az), false)
		F.uc:release_control()
		F.fire_at, F.last_order, F.driving = {ax, az}, now, false
		E.log("ground fire at " .. math.floor(ax) .. "," .. math.floor(az))
	end

	function C.stop_fire()
		F.firing, F.fire_at, F.turn_to, F.fire_order_t = false, nil, nil, nil
		if F.held_fire then F.uc:fire_at_will(false) end -- shooting over: no shot he did not ask for
		F.uc:halt()
		F.uc:release_control()
		F.last_order = bm:time_elapsed_ms() / 1000 -- an order: the next click's fire waits STEER_GAP (round 25)
	end

	-- a click commits to one shot: the order stays until the shot is out and the clip it left in is over, or until
	-- FIRE_COMMIT past a whole reload and the time his fire clip lets it go (data.lua shots and fires); held, it stays;
	-- a move key ends it (main.lua). The author, 2026-10-18: "Kugath cant use his ranged attack ... why cant the full
	-- animation play" - measured: the throw started 7 s after the order (his reload; base 10 s) and the nurgling left
	-- 3.8 s into its 5.8 s clip, and a halt 4 s from the click stopped every one before it began
	function C.ground(now, clicked, held)
		if clicked and not F.firing and E.can_shoot() then
			-- the commit counts from the click: a turn that never ends does not keep him firing (round 25)
			F.firing, F.fire_ammo, F.fire_order_t, F.fire_clip = true, F.unit:ammo_left(), now, nil
		end
		if not F.firing then return end
		-- his clip and his body's: Ku'gath's throw is his own (a rider's 2105); the Necrofex Colossus's shot is the colossus's
		-- FIRE_LEVEL, 9.5 s, and his crewman's RIDER_FIRE beside it ended 6 s sooner (read live 2026-10-18)
		local first = F.model or P.models(F.unit)[1]
		local body = first and P.mount(first)
		local mine, its = first and P.anim_slot(first), body and P.anim_slot(body)
		local ammo = F.unit:ammo_left()
		-- a shot out, and the shooting clips it left in
		if ammo < F.fire_ammo then F.fire_ammo, F.fire_clip = ammo, {shooting(mine) and mine, shooting(its) and its, now} end
		local can, last = E.can_shoot(), F.fire_clip
		if last then
			local over = (not last[1] or mine ~= last[1]) and (not last[2] or its ~= last[2]) or now - last[3] > FIRE_TAIL
			if (not held or not can) and over then C.stop_fire() elseif held and can then fire(now) end
			return
		end
		local fires, shot = E.D.fires[F.utype], E.D.shots[F.utype]
		local wait = FIRE_COMMIT + (fires and fires[1] and fires[1][1] or 0) + (shot and shot[2] or 0)
		if not can or (not held and now - F.fire_order_t > wait) then C.stop_fire() else fire(now) end
	end

	-- A queued request is not an animation start; idle and hit reactions cannot complete a reload. Aim and
	-- reload hold the full body (mask 6); fire keeps mask 0 for its animation events.
	local function play_phase(shot, phase, slot, now)
		if not P.play(shot.model, slot, phase == "fire" and 0 or 6) then return false end
		shot.phase, shot.slot, shot.started, shot.sent = phase, slot, false, now
		return true
	end

	-- the angle a shot from (x, y, z) leaves at to reach the aim: the low arc of its projectile's speed (data.lua speeds),
	-- its steepest past that arc's reach; the straight line for a unit data.lua does not know
	local function launch_angle(x, y, z, ax, ay, az)
		local d = math.max(math.sqrt((ax - x) ^ 2 + (az - z) ^ 2), 0.01)
		local h = ay - (y + SHOT_H)
		local v = E.D.speeds[F.utype]
		if not v then return math.atan2(h, d) end
		return math.atan((v * v - math.sqrt(math.max(0, v ^ 4 - G * (G * d * d + h * v * v * 2)))) / (G * d))
	end

	-- the shot's pair: low or high only when he has both its clips (or neither aim, as for level) and data.lua its muzzle
	local function pair_of(x, y, z, ax, ay, az)
		local a = launch_angle(x, y, z, ax, ay, az)
		local want = a >= BAND and "high" or a <= -BAND and "low" or "level"
		local p, fires = PAIRS[want], E.D["fires_" .. want]
		if want == "level" or not (fires and fires[F.utype]) or not P.has_slot(F.model, p[2])
			or P.has_slot(F.model, p[1]) ~= P.has_slot(F.model, SLOT_AIM) then return "level", a, want end
		return want, a, want
	end

	local function r1(n) return math.floor(n * 10 + 0.5) / 10 end

	local function man_shot(now)
		local ax, ay, az = C.aim_point(F.unit:missile_range())
		if not ax then return end
		local shot = {model = F.model, unit = F.unit, aim = {ax, ay, az}}
		-- nothing drives him while a shot runs, so a walk under way would carry him along under the aim clip
		local x, y, z = P.model_pos(F.model)
		local pair, angle, want = pair_of(x, y, z, ax, ay, az)
		shot.pair, shot.aim_slot = pair, PAIRS[pair][1]
		shot.fire_slot = pair == "level" and F.fire_slot or PAIRS[pair][2]
		shot.hold_slot = P.has_slot(F.model, PAIRS[pair][3]) and PAIRS[pair][3] or nil
		local aims = P.has_slot(F.model, shot.aim_slot)
		-- the author, 2026-10-16: "aim high -then shoot level" and "aiming up the projectile hits the controlled unit",
		-- neither reproduced off the game: each shot, its clips as the engine reports them, its spawn and his hit points
		E.log("shot " .. pair .. " (" .. r1(math.deg(angle)) .. " deg, wanted " .. want .. "): aim " .. r1(math.sqrt((ax - x) ^ 2
			+ (az - z) ^ 2)) .. " m out, " .. r1(ay - y) .. " m up; raise " .. tostring(aims and shot.aim_slot) .. ", fire "
			.. tostring(shot.fire_slot))
		F.face_yaw = nil -- he shoots along the crosshair
		P.hold(F.model, x, z, E.rig.yaw)
		if not play_phase(shot, aims and "aim" or "fire", aims and shot.aim_slot or shot.fire_slot, now) then return end
		F.shot, F.man_hold = shot, nil
		F.shot_n = F.shot_n + 1
	end

	-- at: the spawn, {s, x, y, z}; first: the shot's first spawn, which alone spends the shot's ammo
	local function launch(shot, first, at)
		if not P.alive(shot.unit, shot.model) then return end
		local s = E.D.shots[F.utype]
		-- the crosshair as this spawn leaves: a burst follows the camera (the author, 2026-10-15: "shooting then moving
		-- the cameras has the same bullet spawn and placement as the first shot")
		local ax, ay, az = C.aim_point(shot.unit:missile_range())
		if not ax then ax, ay, az = unpack(shot.aim) end
		local x, y, z = P.model_pos(shot.model)
		local from
		if at[2] then
			-- FIRE_POS's position: metres from his animroot, x right, y up, z ahead, turned with him (he faces the
			-- camera through the shot; the author, 2026-10-15: "the projectile spawn is mismatched to the model")
			local c, sn = math.cos(E.rig.yaw), math.sin(E.rig.yaw)
			from = v(x + at[2] * c + at[4] * sn, y + at[3], z - at[2] * sn + at[4] * c)
			-- a muzzle inside him (a raised gun's, over his head) moves out along the line to the aim until SHOT_CLEAR from
			-- him: k solves |p + k d| = SHOT_CLEAR across the ground, p the muzzle from him, d the line
			local fx, fy, fz = from:get_x(), from:get_y(), from:get_z()
			local px, pz, dx, dy, dz = fx - x, fz - z, ax - fx, ay - fy, az - fz
			local a, b, c2 = dx * dx + dz * dz, px * dx + pz * dz, px * px + pz * pz - SHOT_CLEAR * SHOT_CLEAR
			if c2 < 0 and a > 1e-4 then
				local k = (-b + math.sqrt(b * b - a * c2)) / a
				from = v(fx + dx * k, fy + dy * k, fz + dz * k)
			end
		else
			local dx, dz = ax - x, az - z
			local d = math.max(math.sqrt(dx * dx + dz * dz), 0.01)
			from = v(x + dx / d * SHOT_FWD, y + SHOT_H, z + dz / d * SHOT_FWD)
		end
		for k = 1, s[3] do
			local jx, jz = 0, 0
			if k > 1 then jx, jz = (math.random() * 2 - 1) * E.S.spread, (math.random() * 2 - 1) * E.S.spread end
			bm:trigger_projectile_launch(s[1], from, v(ax + jx, ay, az + jz))
		end
		-- the launch plays the projectile's sounds only; the bang is the weapon's, once a spawn (each is a discharge)
		if s[4] then play_sound(from, new_sfx(s[4], false, false)) end
		local hp = P.model_hp(shot.model)
		F.hp_watch = {model = shot.model, hp = hp, t = bm:time_elapsed_ms() / 1000}
		E.log("launch from " .. r1(from:get_x() - x) .. "," .. r1(from:get_y() - y) .. "," .. r1(from:get_z() - z) .. " to "
			.. r1(ax - x) .. "," .. r1(ay - y) .. "," .. r1(az - z) .. " (his position), his hp " .. tostring(hp))
		if not first then return end
		local ammo, full = shot.unit:ammo_left(), shot.unit:starting_ammo()
		if full > 0 then shot.unit:set_current_ammo_unary(math.max(0, ammo - 1) / full) end
		shot.launched = true
		E.log("shot " .. s[1])
	end

	-- Ends the shot early: a step does once he reloads (the author, 2026-10-14: the 14 s reload held him in place),
	-- the mode key at any point. The reload still counts: after a shot has left, the next waits the projectile's
	-- base_reload_time from the reload's start.
	function C.drop(now, step)
		local shot = F.shot
		if not shot or (step and shot.phase ~= "reload") then return end
		if shot.launched then F.ready_at = (shot.reload_at or now) + E.D.shots[F.utype][2] * E.S.reload_factor end
		F.shot = nil
	end

	-- a click always fires one shot, kept through a reload; held, he fires again each time he has reloaded
	function C.solo(now, clicked, held)
		if clicked then F.want_shot = true end
		local w = F.hp_watch
		if w and now - w.t > 3 then F.hp_watch = nil
		elseif w and not P.same(w.model, F.model) then E.log("the man who shot is gone, " .. r1(now - w.t) .. " s after") F.hp_watch = nil
		elseif w then
			local hp = P.model_hp(w.model)
			if hp < w.hp then E.log("hit " .. r1(now - w.t) .. " s after his shot: hp " .. w.hp .. " to " .. hp) w.hp = hp end
		end
		local shot = F.shot
		if shot and not P.same(shot.model, F.model) then F.shot, shot = nil, nil end
		-- the reload setting (the author, 2026-10-15): a share of the game's reload time; shorter ends the clip there,
		-- longer holds the next shot past its end
		if shot and shot.phase == "reload" and E.S.reload_factor < 1 and now >= F.ready_at then F.shot, shot = nil, nil end
		-- a clip sent and never started (replaced before it played) gives up after LOCK_WAIT: he is not rooted (round 25)
		if shot and not shot.started and now >= shot.sent + LOCK_WAIT then C.drop(now) shot = nil end
		if shot then
			local clip = P.anim_slot(shot.model)
			if clip ~= shot.seen then shot.seen = clip E.log("shot clip " .. tostring(clip) .. " in " .. shot.phase) end
			if clip == shot.slot and not shot.started then
				shot.started, shot.at = true, now
				-- sent early, the fire clip reports at once but plays from the raise's end (the author, 2026-10-15: the
				-- shot left before the clip): the release counts from there
				-- One shot per spawn the clip carries: data.lua's fires, read off its FIRE_POS events (the author,
				-- 2026-10-15: a rocket barrage spawns 18). A unit not there gets one, at SHOT_DELAY_MS or a throw's THROW_MS
				if shot.phase == "fire" then
					shot.from, shot.spawned = math.max(now, shot.raise_end or now), 0
					local fires = E.D[shot.pair == "level" and "fires" or "fires_" .. shot.pair]
					shot.times = fires and fires[F.utype] or {{(F.thrown and THROW_MS or SHOT_DELAY_MS) / 1000}}
				end
			end
			-- before the phase moves on: a spawn due in the clip's last model tick reads as due with the clip already over
			if shot.phase == "fire" and shot.times then
				while shot.spawned < #shot.times and now >= shot.from + shot.times[shot.spawned + 1][1] do
					shot.spawned = shot.spawned + 1
					launch(shot, shot.spawned == 1, shot.times[shot.spawned])
				end
			end
			-- the raise is a transition clip: past its end the engine settles him in its shooting idle and the fire clip
			-- starts from there, the weapon jumping (the author, 2026-10-14). Its length sends fire AIM_LEAD before the end,
			-- so the engine goes from the raise into the fire clip: its .anim's (data.lua raises; learned on the first
			-- shot, the first high shot stood him in his idle, gun level, for a model tick - the author, 2026-10-16:
			-- "twitching when aiming high"), else the one learned on the first whole raise. Timed from the raise's send: its
			-- report comes 0.2-0.31 s after it starts, and timed from there the next clip went after the raise had ended (measured
			-- 2026-10-16, Hochland Long Rifles: raise reported 92.0 s, no clip at 92.8, hold 93.0 - "reverts to idle for 1 frame")
			local r = E.D.raises and E.D.raises[F.utype]
			local len = r and r[shot.aim_slot - 1552]
			if not len or len <= 0 then len = aim_len[F.utype .. shot.aim_slot] end
			if shot.phase == "aim" and shot.started and clip == shot.slot and len and now >= shot.sent + len - AIM_LEAD then
				shot.raise_end = shot.at + len
				if shot.hold_slot then play_phase(shot, "hold", shot.hold_slot, now) else play_phase(shot, "fire", shot.fire_slot, now) end
				return
			end
			if shot.phase == "hold" and shot.started and clip == shot.slot and now >= shot.at + AIM_HOLD then
				play_phase(shot, "fire", shot.fire_slot, now) return
			end
			if not shot.started or clip == shot.slot then return end
			if shot.phase == "aim" then
				aim_len[F.utype .. shot.aim_slot] = aim_len[F.utype .. shot.aim_slot] or now - shot.at
				if shot.hold_slot then play_phase(shot, "hold", shot.hold_slot, now) else play_phase(shot, "fire", shot.fire_slot, now) end
				return
			end
			if shot.phase == "hold" then play_phase(shot, "fire", shot.fire_slot, now) return end
			-- no reload clip (a weapon team, a crossbow): the projectile's reload time on the clock from the fire clip's end
			if shot.phase == "fire" and not F.reload_slot then
				F.ready_at, F.shot = now + E.D.shots[F.utype][2] * E.S.reload_factor, nil
				return
			end
			if shot.phase == "fire" then
				shot.reload_at = now
				-- the game's reload time, the setting's share of it, whatever the clip's length: a clip shorter than it
				-- freed the next shot (the author, 2026-10-16: "reload time not being followed, I can click fire button when
				-- the reloading animation is finished")
				F.ready_at = now + E.D.shots[F.utype][2] * E.S.reload_factor
				play_phase(shot, "reload", F.reload_slot, now) return
			end
			F.shot = nil
		end
		if not (F.want_shot or held) then return end
		if not E.can_shoot() then F.want_shot = false return end
		if now < F.ready_at then return end
		man_shot(now)
		if F.shot then F.want_shot = false end
	end

	-- artillery: the game's own Manual fire mode (Insert), its first-person gun view (handoff 9h). Only
	-- units whose engine is in first_person_engines have it. Control stops, the unit is selected so the
	-- HUD carries its button, the button is clicked, and a watcher gives control back when the
	-- first-person UI closes (the game's own way out) or the mode key or F2 asks - those click the button
	-- again 0.25 s later, only if the mode is still open. The watcher is a repeat registered straight from
	-- the key, never inside a one-shot: CA frees a one-shot's id before running it.
	-- The click waits SETTLE s from the key: what the stop puts back (CA's cinematic interface fading out, the camera's floor)
	-- takes a moment, and a click 0.1-0.3 s after it lost the view again within 1.2 s, or never opened it; 0.5, 1 and 2 s
	-- after, it held (measured 2026-10-17, probes/zz_tp_manual.lua: a Culverin)
	local SETTLE = 1
	local function manual_button() return find_uicomponent(core:get_ui_root(), "hud_battle", "porthole_parent", "button_unit_manual_fire") end
	local function manual_open() local fp = find_uicomponent(core:get_ui_root(), "first_person_ui") return fp and fp:Visible() or false end

	local function watch()
		local ok, err = xpcall(function()
			local fp = E.fp
			if not fp then bm:remove_real_callback("derpy_tp_fp") return end
			local now, open = os.clock(), manual_open()
			if not fp.clicked then
				if now - fp.t < SETTLE then return end
				local b = manual_button()
				if b and b:Visible() then b:SimulateLClick() fp.clicked, fp.t = true, now return end
				if now - fp.t < 2 then return end
				fp.clicked = true
				E.once("fp_button_" .. fp.unit:type(), "no Manual fire button for " .. fp.unit:type())
			end
			if open then fp.seen = true end
			if open and P.pressed(E.S.keys.mode) and not fp.exit_at then fp.exit_at = now + 0.25 end
			local timed_out = not fp.seen and now - fp.t > 3
			local asked = fp.exit_at and now >= fp.exit_at
			if timed_out or asked or (fp.seen and not open) then
				bm:remove_real_callback("derpy_tp_fp")
				if open and asked then local b = manual_button() if b then b:SimulateLClick() end end
				E.fp = nil
				E.main.start(fp.unit)
			end
		end, debug.traceback)
		if not ok then bm:remove_real_callback("derpy_tp_fp") E.fp = nil E.fail(err) end
	end

	function C.manual()
		local u = F.unit
		E.main.stop("manual fire")
		u:select_in_ui()
		E.fp = {unit = u, seen = false, clicked = false, t = os.clock()}
		bm:repeat_real_callback(watch, 100, "derpy_tp_fp")
	end

	function C.manual_exit()
		if E.fp and not E.fp.exit_at then E.fp.exit_at = os.clock() + 0.25 end
	end

	-- the shot or fire order under way stops, the reload still counting: the mode key, and arming an ability
	function C.stand_down(now)
		F.native_attack = nil
		if F.firing then C.stop_fire() end
		C.drop(now)
		F.want_shot = false
	end

	function C.mode(now)
		if F.arty then C.manual() return end
		if F.ranged or E.can_shoot() then -- out of ammo, the key still leaves ranged mode
			F.ranged = not F.ranged
			C.stand_down(now)
		else
			C.melee(now, false)
		end
	end

	-- an action clip runs: nothing is sent to him until it ends, as the engine reports it, or LOCK_MAX passes (the author,
	-- 2026-10-15: "it should let its animation play without being overrided with different buttons")
	function C.locked(now)
		local L = F.lock
		if not L then return false end
		-- over once the engine has reported the clip and then something else; never reported, after LOCK_WAIT
		local slot = L.m and P.anim_slot(L.m)
		-- no clip sent yet (a turn order's wait) is nothing reported: read as seen, the lock ended as the clip was sent
		if L.m and slot == L.slot then L.seen = true end
		local over = now >= L.till or L.m and (L.seen and slot ~= L.slot or not L.seen and now >= L.from + LOCK_WAIT)
		if not over then return true end
		-- a charge attack thrown on the run stays latched under the walk (measured 2026-10-16): freed here, or by the charge
		-- (charge_run) when he sprints on
		if L.runs and not F.sprinting then each(function(m) m = P.mount(m) or m if P.has_slot(m, WALK_1) then P.play(m, WALK_1, 0) end end) end
		-- for the in-combat stall (main.lua): a clip sent and never reported
		if L.m and not L.seen then
			E.log("clip " .. tostring(L.slot) .. " never played: in melee " .. tostring(F.unit:is_in_melee()) .. ", his clip "
				.. tostring(slot))
			-- still his: a block (DEFEND, 474-483) holds a queued clip back until it ends, which ran past LOCK_WAIT 3 times in
			-- 10 (measured 2026-10-16, probes/zz_tp_melee_spam.lua); main.lua keeps him armed for it, LOCK_MAX from its send
			F.pending = {m = L.m, slot = L.slot, till = L.from + LOCK_MAX}
		end
		F.lock, F.man_hold = nil, nil -- he stands where the clip left him (the jump carries him ~4.5 m)
		return false
	end

	function C.attack(now, clicked, held)
		C.flush(now)
		if C.locked(now) then return end
		if clicked and F.charging and F.can_charge and now >= F.next_charge and not F.unit:is_currently_flying() then C.charge_attack(now) return end
		if F.ranged then
			-- a gun's click is its attack on the enemy nearest the crosshair, out to its range: ground fire drove a flame
			-- cannon toward the point and fired nothing (measured 2026-10-18, probes/zz_tp_arty_order.lua)
			if F.arty then if clicked then order(true, F.unit:missile_range()) end
			elseif F.solo then C.solo(now, clicked, held) else C.ground(now, clicked, held) end
		elseif clicked and not F.arty then -- a gun out of shot is nothing: its crew never swing (the author, 2026-10-18)
			C.melee(now, true)
		end
	end

	-- the cheer (the author, 2026-10-15: "add button for cheer"): a CELEBRATE clip his men have, else a TAUNT one, in turn,
	-- held like an action. Measured 2026-10-15: about half of all land units' men have CELEBRATE (1.5-7.1 s, median 2.9,
	-- each with its own sound); Plaguebearers, Blightkings and Tamurkhan have neither, and have no cheer (F.can_cheer)
	function C.cheer(now)
		if C.locked(now) then return end
		local first = F.model or P.models(F.unit)[1]
		first = first and (P.mount(first) or first)
		local function has(list)
			local out = {}
			if first and P.features.anim and F.men_ok then for _, s in ipairs(list) do if P.has_slot(first, s) then out[#out + 1] = s end end end
			return out
		end
		local clips = has(SLOTS_CHEER)
		if #clips == 0 then clips = has(SLOTS_TAUNT) end
		if #clips == 0 then return end -- neither (F.can_cheer false, the HUD shows no button), or animation off
		local k = turn[SLOTS_CHEER] or 0
		turn[SLOTS_CHEER] = k + 1
		local slot = clips[k % #clips + 1]
		act(now)
		F.lock = {from = now, till = now + LOCK_MAX, yaw = E.rig.yaw, turns = true} -- its clip turns him, as a swing's
		each(function(m)
			m = P.mount(m) or m
			if P.has_slot(m, slot) then
				P.play(m, slot)
				if not F.lock.m then F.lock.m, F.lock.slot, F.swung = m, slot, {m, slot} end
			end
		end)
		E.log("cheer " .. slot)
	end

	-- the jump attack (the author, 2026-10-15: E): JUMPING_ATTACK_1-5 as a swing, on its own cooldown. A unit whose men
	-- have none does nothing - no attack order in its place (F.can_jump, read off his men at the start). None in the air:
	-- a ground clip, as the charge attack's
	function C.jump(now)
		if C.locked(now) or not F.can_jump or now < F.next_jump or not (P.features.anim and F.men_ok)
			or F.unit:is_currently_flying() then return end
		F.next_jump = now + E.S.jump_cooldown
		E.log("jump attack")
		swing(SLOTS_JUMP, true, now)
	end

	-- the charge (the author, 2026-10-15: "charging running should be triggered with q as a continuious press"): the
	-- sprint plays CHARGE for as long as it lasts; over, WALK_1 at mask 0 ends it (move.lua's unlatch). In the air, his
	-- FLY_CHARGE_AIR_TO_AIR, else none (the author, 2026-10-18: "charging belakors triggers his land charge run"; 86 of the
	-- 123 skeletons that fly have one, read 2026-10-18), and no charge attack: that is a ground clip.
	-- The clip does not loop: it goes again at its own end - its length off its .anim (data.lua charges), and at once if
	-- the engine reports it over first; a length unknown, only then (LOCK_MAX at most). A fixed 0.6 s cut every one
	-- mid-stride (the author, 2026-10-18: "looks like its not looping but being cut off mid animation"; Harald's is 0.8 s,
	-- the Great Unclean One's 1.9)
	function C.charge_run(now, want)
		local first = F.model or P.models(F.unit)[1]
		first = first and (P.mount(first) or first)
		local air = F.unit:is_currently_flying()
		local clip = air and FLY_CHARGE or CHARGE
		local on = want and first and not F.arty and P.has_slot(first, clip) and P.features.anim and F.men_ok
		local playing = on and P.anim_slot(first) == clip
		if playing then F.charge_seen = true end
		if F.lock then -- the charge attack, thrown on the run: neither clip over it
		elseif on and (now >= (F.charge_at or 0) or F.charge_seen and not playing) then
			each(function(m) m = P.mount(m) or m if P.has_slot(m, clip) then P.play(m, clip, 6) end end)
			local len = E.D.charges and E.D.charges[F.utype]
			len = len and len[air and 2 or 1] or 0
			F.charge_at, F.charge_seen = now + (len > CHARGE_LEAD and len - CHARGE_LEAD or LOCK_MAX), false
		elseif not on and F.charging then
			each(function(m) m = P.mount(m) or m if P.has_slot(m, WALK_1) then P.play(m, WALK_1, 0) end end)
		end
		if not on then F.charge_at, F.charge_seen = nil, nil end
		F.charging = on
	end

	-- the sprint (the author, 2026-10-16: "shift button as the charge or sprint button, add stamina bar"): held on the move,
	-- on stamina; the charge clip plays under it, and main.lua runs him. Never over an action clip
	function C.sprint(now, want)
		local dt = math.max(0, now - (F.stamina_t or now))
		F.stamina_t = now
		F.stamina = math.max(0, math.min(1, F.stamina + dt * (F.sprinting and -1 / STAMINA_DRAIN or 1 / STAMINA_FILL)))
		F.sprinting = want and (not C.locked(now) or F.lock.runs) and F.stamina > 0 and (F.sprinting or F.stamina >= STAMINA_AGAIN)
		C.charge_run(now, F.sprinting)
	end
	function C.can_sprint() return F.sprinting or F.stamina >= STAMINA_AGAIN end

	-- a click in the charge throws the charge attack: MOVING_ATTACK_1-2 (the only two any unit has, measured 2026-10-15)
	-- as a swing, on its own cooldown, and he runs on through it (the author, 2026-10-16: "charge attack while sprinting
	-- comepletely stops the player and stops its legs"). At the default mask the clip took his whole body and he stopped
	-- for ~1.8 s (measured, standing); a step cuts a default-mask clip (the jump, measured) and a walk under a masked one
	-- latches it (probes/zz_tp_unclip.lua). Over his torso and arms, his legs are the run's. Not measured on the run:
	-- probes/zz_tp_charge_run.lua tries each mask
	function C.charge_attack(now)
		F.next_charge = now + E.S.charge_cooldown
		E.log("charge attack")
		swing(SLOTS_RUN, true, now, nil, TORSO_AND_ARMS)
		-- steered, the clip never reports its end (latched, measured 2026-10-16): the lock ends at its length, data.lua's
		-- longest MOVING_ATTACK off the .anim; a unit with none, at LOCK_MAX
		local len = E.D.runs and E.D.runs[F.utype]
		if F.lock then
			F.lock.runs = true
			if len then F.lock.till = math.min(F.lock.till, now + len + CLIP_START) end
		end
	end

	return C
end
