-- Fighting from third person (spec section 6): swings, ranged fire by unit kind, the crosshair, and the
-- artillery hand-over to the game's Manual fire mode. return function(E) -> C.
local SLOTS_LMB, SLOTS_RMB = {454, 455, 456, 457}, {458, 459, 460} -- ATTACK_1-4 and ATTACK_5-7
local SLOTS_JUMP, SLOTS_RUN = {489, 490, 491, 492, 493}, {484, 485, 486, 487, 488} -- JUMPING_ and MOVING_ATTACK_1-5
-- s an action clip holds him at most; s before its slot is read (measured 2026-10-15: the jump runs ~2 s, the charge
-- attack ~1.8, each reported within 0.1 s of being sent)
local LOCK_MAX, LOCK_START = 3, 0.25
local TURN_DEG, TURN_WAIT_MS, MAX_MODELS = 25, 350, 160
local AIM_COS, AIM_RANGE, AIM_CLOSE = 0.707, 150, 8 -- a melee target: inside 45 deg and 150 m, or 8 m any way
local AIM_MIN, FIRE_REAIM, FIRE_ARC, FIRE_COMMIT, STEER_GAP = 10, 5, 20, 4, 0.5
-- 9.0 ids (AssetEditor's dlc24 list + 2): SHOOT_READY_TO_AIM_LEVEL, FIRE_LEVEL; the reload slot comes from the
-- unit's animation fragment, and a crossbow's is the raise to aim itself
local SLOT_AIM, SLOT_FIRE = 1554, 1557
local SHOT_DELAY_MS, SHOT_H, SHOT_FWD = 300, 1.5, 1.5 -- anim to release; m up; m forward (the jitter is S.spread)
-- a thrown bomb's release (measured 2026-10-15 in anim2.pack: both blasting-charge throws carry FIRE_POS at 2.2 and 2.3 s)
local THROW_MS = 2200
-- the charge run: CHARGE, sent again inside its cycle (measured 2026-10-15: under 1 s, mask 6 only, he keeps his speed)
local CHARGE, CHARGE_GAP, WALK_1 = 135, 0.6, 42
-- s before the raise to aim ends that fire is sent: one model-time step (100-200 ms) so the command lands in time.
-- ponytail: a guess until measured in game; too long cuts the raise visibly short
local AIM_LEAD = 0.15

return function(E)
	local F, P = E.F, E.P
	local C = {}
	local aim_len, reload_len = {}, {} -- unit type -> s its raise to aim and its reload clip run, measured on the first whole one
	local turn = {} -- slot list -> the next in its rotation

	-- his models: the one man, or every man of the unit up to MAX_MODELS
	local function each(fn)
		local ms = F.model and {F.model} or P.models(F.unit)
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

	-- the ground under the screen centre: last frame's camera ray meets the ground at the shooter's height;
	-- looking level or up, or past reach, clamps to reach along the view. nil before the first frame.
	function C.aim_point(reach)
		local R = E.rig
		if not R.ex then return nil end
		local ux, gy, uz
		if F.model then ux, gy, uz = P.model_pos(F.model) else local q = F.unit:position() ux, gy, uz = q:get_x(), q:get_y(), q:get_z() end
		local dx, dy, dz = R.lx - R.ex, R.ly - R.ey, R.lz - R.ez
		local hx, hz, want = dx, dz, reach
		if dy < 0 then
			local t = (R.ey - gy) / -dy
			hx, hz = R.ex + dx * t - ux, R.ez + dz * t - uz
			want = math.max(AIM_MIN, math.min(reach, math.sqrt(hx * hx + hz * hz)))
		end
		local d = math.sqrt(hx * hx + hz * hz)
		if d < 0.01 then hx, hz, d = math.sin(R.yaw), math.cos(R.yaw), 1 end
		return ux + hx / d * want, gy, uz + hz / d * want
	end

	-- the enemy nearest the aim: inside AIM_COS of the camera's forward and AIM_RANGE, or AIM_CLOSE any
	-- way; distance weighted by how far off the aim it is
	local function pick_target()
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
					if d < AIM_CLOSE or (c > AIM_COS and d < AIM_RANGE) then
						local score = d * (2 - c)
						if not best_score or score < best_score then best, best_score = e, score end
					end
				end
			end
		end
		return best
	end

	-- CA's attack order on the enemy nearest the aim: a unit with no clip to swing charges it
	local function order(primary)
		local target = pick_target()
		if not target then return end
		F.uc:attack_unit(target, primary, F.running)
		F.uc:release_control()
		F.driving = false
		E.log("attack order on " .. target:type())
	end

	-- the next attack animation of the list, on the one man or every model that has it (measured 2026-10-15: the
	-- Greybeard tank's crew have ATTACK_1-5, a landship's none); no model with it, the attack order. A whole unit
	-- more than TURN_DEG off the camera is turned first
	-- now: the swing is an action (jump, charge attack) that nothing may cut until its clip ends - see C.locked
	local function swing(slots, primary, now)
		-- only the clips his men have (the author, 2026-10-15: "rng on activating the animation" - measured, a list that
		-- rotated past them played nothing), each list on its own count
		local first, has = F.model or P.models(F.unit)[1], {}
		local mount = first and P.mount(first)
		for _, s in ipairs(slots) do
			if first and (P.has_slot(first, s) or mount and P.has_slot(mount, s)) then has[#has + 1] = s end
		end
		if #has == 0 then has = slots end -- a rider's fallback clip, or the attack order
		local k = turn[slots] or 0
		local slot = has[k % #has + 1]
		turn[slots], F.swings = k + 1, F.swings + 1
		F.face_yaw = nil -- he swings at the crosshair
		if now then F.lock = {from = now, till = now + LOCK_MAX} end
		-- the model that carries the clip, and its slot; nil when he has none
		local function play(m)
			local rider = slot + 1447 -- ATTACK_1 -> RIDER_ATTACK_1
			local chosen = slot
			if F.unit:is_currently_flying() and P.has_slot(m, 1941) then chosen = P.has_slot(m, rider + 40) and rider + 40 or 1941
			elseif P.has_slot(m, 1901) then chosen = P.has_slot(m, rider) and rider or 1901 end
			if chosen ~= slot then
				local mount = P.mount(m)
				-- The rider fragment inherits the mount's playback; a second command cancels the first.
				if mount and P.has_slot(mount, chosen - 1447) then P.play(mount, chosen - 1447) return mount, chosen - 1447 end
				P.play(m, chosen, 6)
				return m, chosen
			elseif P.has_slot(m, slot) then P.play(m, slot) return m, slot end
		end
		local function go()
			local any = false
			each(function(m)
				local carrier, played = play(m)
				if carrier and not any and F.lock and not F.lock.m then F.lock.m, F.lock.slot = carrier, played end
				any = any or carrier ~= nil
			end)
			if not any then order(primary) end
		end
		local want = math.deg(E.rig.yaw) % 360
		local off = math.abs((want - F.unit:bearing() + 540) % 360 - 180)
		if off > TURN_DEG and not F.model then
			local q = F.unit:position()
			F.uc:goto_location_angle_width(v(q:get_x(), q:get_y(), q:get_z()), want, math.max(F.unit:ordered_width(), 1), false)
			F.uc:release_control()
			F.driving = false
			bm:real_callback(function()
				local ok, err = xpcall(function() if F.on then go() end end, debug.traceback)
				if not ok then E.pending = err end -- E.fail registers a timer: not from in here
			end, TURN_WAIT_MS, "derpy_tp_swing_" .. F.swings)
		else
			go()
		end
	end

	function C.melee(now, primary)
		if now < F.next_swing then return end
		F.next_swing = now + E.S.swing_cooldown
		if P.features.anim and F.men_ok then swing(primary and SLOTS_LMB or SLOTS_RMB, primary) return end
		order(primary)
	end

	-- ground fire at the aim (single entities and regiments without a one-man shot): turned first when
	-- the aim is outside FIRE_ARC; re-aimed when the point moves FIRE_REAIM, no faster than STEER_GAP
	local function fire(now)
		local ax, ay, az = C.aim_point(F.unit:missile_range())
		if not ax then return end
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
		if F.fire_at and ((ax - F.fire_at[1]) ^ 2 + (az - F.fire_at[2]) ^ 2 < FIRE_REAIM * FIRE_REAIM or now - F.last_order < STEER_GAP) then return end
		F.uc:attack_location(v(ax, ay, az), false)
		F.uc:release_control()
		F.fire_at, F.last_order, F.driving = {ax, az}, now, false
		F.fire_order_t = F.fire_order_t or now
		E.log("ground fire at " .. math.floor(ax) .. "," .. math.floor(az))
	end

	function C.stop_fire()
		F.firing, F.fire_at, F.turn_to, F.fire_order_t = false, nil, nil, nil
		if F.held_fire then F.uc:fire_at_will(false) end -- shooting over: no shot he did not ask for
		F.uc:halt()
		F.uc:release_control()
	end

	-- a click commits to one shot: the order stays until ammo drops or FIRE_COMMIT passes; held, it stays
	function C.ground(now, clicked, held)
		if clicked and not F.firing and E.can_shoot() then
			F.firing, F.fire_ammo = true, F.unit:ammo_left()
			-- a ground-fire order with fire at will off looses nothing (measured 2026-10-15): it is on while he shoots
			F.uc:fire_at_will(true)
		end
		if not F.firing then return end
		local shot = F.unit:ammo_left() < F.fire_ammo
		local expired = F.fire_order_t and now - F.fire_order_t > FIRE_COMMIT
		if not E.can_shoot() or (not held and (shot or expired)) then C.stop_fire() else fire(now) end
	end

	-- A queued request is not an animation start; idle and hit reactions cannot complete a reload. Aim and
	-- reload hold the full body (mask 6); fire keeps mask 0 for its animation events.
	local function play_phase(shot, phase, slot)
		if not P.play(shot.model, slot, phase == "fire" and 0 or 6) then return false end
		shot.phase, shot.slot, shot.started = phase, slot, false
		return true
	end

	local function man_shot(now)
		local ax, ay, az = C.aim_point(F.unit:missile_range())
		if not ax then return end
		local shot = {model = F.model, unit = F.unit, aim = {ax, ay, az}}
		local aims = P.has_slot(F.model, SLOT_AIM)
		-- nothing drives him while a shot runs, so a walk under way would carry him along under the aim clip
		local x, _, z = P.model_pos(F.model)
		F.face_yaw = nil -- he shoots along the crosshair
		P.hold(F.model, x, z, E.rig.yaw)
		if not play_phase(shot, aims and "aim" or "fire", aims and SLOT_AIM or SLOT_FIRE) then return end
		F.shot, F.man_hold = shot, nil
		F.shot_n = F.shot_n + 1
	end

	local function launch(shot)
		if not P.alive(shot.unit, shot.model) then return end
		local s = E.D.shots[F.utype]
		local ax, ay, az = unpack(shot.aim)
		local x, y, z = P.model_pos(shot.model)
		local dx, dz = ax - x, az - z
		local d = math.max(math.sqrt(dx * dx + dz * dz), 0.01)
		local from = v(x + dx / d * SHOT_FWD, y + SHOT_H, z + dz / d * SHOT_FWD)
		for k = 1, s[3] do
			local jx, jz = 0, 0
			if k > 1 then jx, jz = (math.random() * 2 - 1) * E.S.spread, (math.random() * 2 - 1) * E.S.spread end
			bm:trigger_projectile_launch(s[1], from, v(ax + jx, ay + 1, az + jz))
		end
		-- the launch plays the projectile's sounds only; the bang is the weapon's, once a shot
		if s[4] then play_sound(from, new_sfx(s[4], false, false)) end
		local ammo, full = shot.unit:ammo_left(), shot.unit:starting_ammo()
		if full > 0 then shot.unit:set_current_ammo_unary(math.max(0, ammo - 1) / full) end
		shot.launched = true
		E.log("shot " .. s[1])
	end

	-- Ends the shot early: a step does once he reloads (the author, 2026-10-14: the 14 s reload held him in place),
	-- the mode key at any point. The reload still counts: after a shot has left, the next waits the projectile's
	-- base_reload_time from the reload's start; a crossbow's reload is its next raise to aim.
	function C.drop(now, step)
		local shot = F.shot
		if not shot or (step and shot.phase ~= "reload") then return end
		if shot.launched and F.reload_slot ~= SLOT_AIM then F.ready_at = (shot.reload_at or now) + E.D.shots[F.utype][2] * E.S.reload_factor end
		F.shot = nil
	end

	-- a click always fires one shot, kept through a reload; held, he fires again each time he has reloaded
	function C.solo(now, clicked, held)
		if clicked then F.want_shot = true end
		local shot = F.shot
		if shot and not P.same(shot.model, F.model) then F.shot, shot = nil, nil end
		-- the reload setting (the author, 2026-10-15): at 100% the clip alone decides; shorter ends the clip at that share
		-- of its length, longer holds the next shot past its end
		if shot and shot.phase == "reload" and E.S.reload_factor < 1 and now >= F.ready_at then F.shot, shot = nil, nil end
		if shot then
			local clip = P.anim_slot(shot.model)
			if clip == shot.slot and not shot.started then
				shot.started, shot.at = true, now
				-- sent early, the fire clip reports at once but plays from the raise's end (the author, 2026-10-15: the
				-- shot left before the clip): the release counts from there
				if shot.phase == "fire" then shot.release_at = math.max(now, shot.raise_end or now) + (F.thrown and THROW_MS or SHOT_DELAY_MS) / 1000 end
			end
			if shot.phase == "fire" and clip == shot.slot and shot.release_at and now >= shot.release_at and not shot.launched then launch(shot) end
			-- the raise is a transition clip: past its end the engine settles him in its shooting idle and the fire clip
			-- starts from there, the weapon jumping (the author, 2026-10-14). Its length, learned on the first shot,
			-- sends fire AIM_LEAD before the end, so the engine goes from the raise into the fire clip
			local len = aim_len[F.utype]
			if shot.phase == "aim" and shot.started and clip == shot.slot and len and now >= shot.at + len - AIM_LEAD then
				shot.raise_end = shot.at + len
				play_phase(shot, "fire", SLOT_FIRE) return
			end
			if not shot.started or clip == shot.slot then return end
			if shot.phase == "aim" then
				aim_len[F.utype] = aim_len[F.utype] or now - shot.at
				play_phase(shot, "fire", SLOT_FIRE) return
			end
			if shot.phase == "reload" then reload_len[F.utype] = reload_len[F.utype] or now - shot.reload_at end
			-- no reload clip (a weapon team): the projectile's reload time on the clock from the fire clip's end
			if shot.phase == "fire" and not F.reload_slot then
				F.ready_at, F.shot = now + E.D.shots[F.utype][2] * E.S.reload_factor, nil
				return
			end
			if shot.phase == "fire" and F.reload_slot ~= SLOT_AIM then
				shot.reload_at = now
				-- the clip's length, learned on a whole one; until then the projectile's reload time, which the clip runs
				-- close to (the author, 2026-10-14: the 14 s reload)
				local f = E.S.reload_factor
				if f ~= 1 then F.ready_at = now + (reload_len[F.utype] or E.D.shots[F.utype][2]) * f end
				play_phase(shot, "reload", F.reload_slot) return
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
	local function manual_button() return find_uicomponent(core:get_ui_root(), "hud_battle", "porthole_parent", "button_unit_manual_fire") end
	local function manual_open() local fp = find_uicomponent(core:get_ui_root(), "first_person_ui") return fp and fp:Visible() or false end

	local function watch()
		local ok, err = xpcall(function()
			local fp = E.fp
			if not fp then bm:remove_real_callback("derpy_tp_fp") return end
			local now, open = os.clock(), manual_open()
			if not fp.clicked then
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
		local over = now >= L.till or L.m and now >= L.from + LOCK_START and P.anim_slot(L.m) ~= L.slot
		if not over then return true end
		F.lock, F.man_hold = nil, nil -- he stands where the clip left him (the jump carries him ~4.5 m)
		return false
	end

	function C.attack(now, clicked, held)
		if C.locked(now) then return end
		if clicked and F.charging and now >= F.next_charge then C.charge_attack(now) return end
		if F.ranged then
			if F.solo then C.solo(now, clicked, held) else C.ground(now, clicked, held) end
		elseif clicked then -- an artillery crew swings too (the author, 2026-10-15: a mortar team had no melee)
			C.melee(now, true)
		end
	end

	-- the jump attack (the author, 2026-10-15: E): JUMPING_ATTACK_1-5 as a swing, on its own cooldown. A unit whose men
	-- have none does nothing - no attack order in its place (F.can_jump, read off his men at the start)
	function C.jump(now)
		if C.locked(now) or not F.can_jump or now < F.next_jump or not (P.features.anim and F.men_ok) then return end
		F.next_jump = now + E.S.jump_cooldown
		E.log("jump attack")
		swing(SLOTS_JUMP, true, now)
	end

	-- the charge (the author, 2026-10-15: "charging running should be triggered with q as a continuious press"): Q held
	-- on the run plays CHARGE for as long as it is held; let go, WALK_1 at mask 0 ends it (move.lua's unlatch)
	function C.charge_run(now, want)
		local on = want and F.can_charge and P.features.anim and F.men_ok and not C.locked(now)
		if on and now >= (F.charge_at or 0) then
			each(function(m) if P.has_slot(m, CHARGE) then P.play(m, CHARGE, 6) end end)
			F.charge_at = now + CHARGE_GAP
		elseif not on and F.charging then
			each(function(m) if P.has_slot(m, WALK_1) then P.play(m, WALK_1, 0) end end)
		end
		if not on then F.charge_at = nil end
		F.charging = on
	end

	-- a click in the charge throws the charge attack: MOVING_ATTACK_1-2 (the only two any unit has, measured 2026-10-15)
	-- as a swing, on its own cooldown. It plays at the default mask for ~1.8 s and he stops to throw it
	function C.charge_attack(now)
		F.next_charge = now + E.S.charge_cooldown
		F.charging, F.charge_at = false, nil -- the attack clip replaces the charge's
		E.log("charge attack")
		swing(SLOTS_RUN, true, now)
	end

	return C
end
