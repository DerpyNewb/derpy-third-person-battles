-- Test scaffolding (2026-10-29), never shipped. Does BCQ_ENTITY_USER_OVERRIDE_ORDER_ATTACK, forged on the one man third
-- person plays against the nearest enemy man, deal the damage a no-splash clip played by the pack does not
-- (docs/sessions/THIRD_PERSON_VERIFY_20261029.md section 2)? Needs TPO (zz_tp_mp_override.lua) and TPV (the input stubs
-- over P.held / P.pressed). Bridge-only: local f = loadfile("<this path>") setfenv(f, core:get_env()) f()
-- TPA.run(sub_uid, enemy_uid, tag, mode): the regiment 45 m back from the enemy, F2 on it (one man), the man put 1.3 m
-- off the enemy's front man, then four 4.4 s ticks. mode "click": a left click each tick (the baseline); "idle": nothing;
-- "attack": the guard, hold and disarm lifted for the run and an ATTACK forged on the nearest enemy man each tick;
-- "attack_click": the forge, then a click 0.3 s on. TPA[tag]: hit points before and after, his slots, the forges' results,
-- how far he moved off his spot. No string library calls.
local E = _G.DERPY_TP
local F, P = E.F, E.P
local T, TPO = _G.TPV, _G.TPO
local TPA = _G.TPA or {}
_G.TPA = TPA

local mr = _G.memreader_plus
-- no_guard: the guard lifted whole (his regiment's order takes him back, measured: 287 m in a tick); free: the hold too;
-- armed: his attack clips kept. "attack_melee" keeps guard and hold and blanks the mailbox's melee vtable (MB.melee,
-- +0x20, compared by the cave and never called), so the engine's melee runs on him and its walks and moves do not
if not TPA.wrapped then
	local guard, hold, disarm = P.guard, P.hold, P.disarm
	P.guard = function(m) if TPA.no_guard then return true end return guard(m) end
	P.hold = function(m, ...) if TPA.free then return end return hold(m, ...) end
	P.disarm = function(m, ...) if TPA.armed then return P.arm(m) end return disarm(m, ...) end
	TPA.wrapped = true
end
local function lift(mode)
	TPA.armed = mode ~= nil and mode ~= "click" and mode ~= "idle" and mode ~= "click_arm"
	TPA.no_guard = mode == "attack" or mode == "attack_click" or mode == "attack_free"
	TPA.free = mode == "attack_free"
	if mode == "attack_melee" then
		TPA.melee_vt = TPA.melee_vt or mr.read_pointer(P.mailbox, 0x20)
		mr.write(P.mailbox, 0x20, mr.uint32(1)) mr.write(P.mailbox, 0x24, mr.uint32(0))
	elseif TPA.melee_vt then
		mr.write(P.mailbox, 0x20, TPA.melee_vt)
		TPA.melee_vt = nil
	end
end
TPA.lift_mode = lift

local function r2(x) return math.floor(x * 100 + 0.5) / 100 end

-- park: {x, z} his regiment is teleported to, far from every enemy (45 m along the enemy's facing put it in a melee);
-- mode "attack_free" lifts the hold as well, so the engine walks him
-- walk: he walks in on W, steered at the nearest enemy man, instead of P.place (a placed man was put back with his
-- regiment, 287 m, the moment an engine command ran on him)
function TPA.run(sub_uid, enemy_uid, tag, mode, park, walk)
	local army = E.army()
	local sub, enemy
	for i = 1, army:units():count() do local u = army:units():item(i) if u:unique_ui_id() == sub_uid then sub = u end end
	local en = bm:get_non_player_alliance():armies():item(1):units()
	for i = 1, en:count() do local u = en:item(i) if u:unique_ui_id() == enemy_uid then enemy = u end end
	if not sub or not enemy then return "no unit " .. tostring(sub) .. " " .. tostring(enemy) end
	local res = {tag = tag, mode = mode, log = {}, slots = {}, forged = {}, hits = 0}
	TPA[tag] = res
	local function hp() return common.get_context_value("CcoBattleUnit", tostring(enemy_uid), "HealthValue") end
	local b = enemy:bearing()
	local fx, fz = math.sin(math.rad(b)), math.cos(math.rad(b))
	local function front()
		local best, bx, bz
		for _, em in ipairs(P.models(enemy)) do
			local x, _, z = P.model_pos(em)
			local d = x * fx + z * fz
			if not best or d > best then best, bx, bz = d, x, z end
		end
		return bx, bz
	end
	local function nearest(m)
		local mx, _, mz = P.model_pos(m)
		local best, bm_
		for _, em in ipairs(P.models(enemy)) do
			local ex, _, ez = P.model_pos(em)
			local d = math.sqrt((ex - mx) ^ 2 + (ez - mz) ^ 2)
			if P.model_hp(em) > 0 and (not best or d < best) then best, bm_ = d, em end
		end
		return bm_, best or 99
	end
	for _, c in ipairs(T.ucs or {}) do c:halt() end
	local uc = army:create_unit_controller()
	uc:add_units(sub)
	uc:set_invincible(true)
	-- no park: he stays where he is (a teleport leaves each man's steering copy behind, and F2 then refuses one man)
	if park then uc:teleport_to_location(v(park[1], bm:get_terrain_height(park[1], park[2]), park[2]), (b + 180) % 360, 20) end
	uc:halt()
	uc:release_control()
	TPA.uc = uc
	local stage, t_stage, ticks, sx, sz = "wait", os.clock(), 0, nil, nil
	local function click()
		T.pressed[0x01] = true T.held[0x01] = true
		bm:real_callback(function() T.held[0x01] = nil end, 120, "tpa_rel_" .. tag .. ticks)
	end
	local function forge()
		local target, d = nearest(F.model)
		local ok, why = TPO.attack(F.model, target)
		res.forged[#res.forged + 1] = tostring(ok) .. ":" .. tostring(why) .. "@" .. r2(d)
	end
	-- "click_arm": a click, then the moment his slot changes (the swing's clip started) the pending hit is written on
	-- him the way exe+3251af8 writes it for a man in the engine's melee: type, damage, slot, victim, pending last.
	-- TPA.arm_type / TPA.arm_dmg (default 1 / 35, the Dragon Guard's measured blows were 27-44). Each arm is then
	-- followed until pending drops: how long, +0x898 / +0x284 / +0x27c as it went, the enemy's hit points either side
	local function arm(slot)
		local target, d = nearest(F.model)
		local m = F.model
		mr.write(m, 0xaf0, mr.int32(TPA.arm_type or 1)) mr.write(m, 0xaf4, mr.int32(TPA.arm_dmg or 35))
		mr.write(m, 0xaf8, mr.uint16(slot)) mr.write(m, 0xb00, target) mr.write(m, 0xb08, mr.int32(1))
		res.watch = {t = os.clock(), slot = slot, d = r2(d), hp = hp(), trace = {}}
	end
	bm:remove_real_callback("tpa_run")
	bm:repeat_real_callback(function()
		local ok, err = pcall(function()
			local now = os.clock()
			if stage == "wait" and now - t_stage > 3 then
				if F.on then E.main.stop("reset") end
				local card = find_uicomponent(core:get_ui_root(), "cards_panel", tostring(sub_uid))
				bm:clear_selection() card:SimulateLClick()
				T.pressed[0x71] = true
				stage, t_stage = "start", now
			elseif stage == "start" and now - t_stage > 0.8 then
				res.log[#res.log + 1] = "on " .. tostring(F.on) .. " " .. tostring(F.utype) .. " one_man " .. tostring(F.model ~= nil)
				if not F.model then error("not one man") end
				if walk then
					T.held[0x57] = true
					stage, t_stage = "walk", now
				else
					local bx, bz = front()
					sx, sz = bx + fx * 1.3, bz + fz * 1.3
					P.place(F.model, sx, sz)
					local yaw = math.rad((b + 180) % 360)
					E.rig.yaw, E.rig.want_yaw = yaw, yaw
					P.face(F.model, yaw)
					stage, t_stage = "settle", now
				end
			elseif stage == "walk" then
				local target, d = nearest(F.model)
				local mx, _, mz = P.model_pos(F.model)
				local tx, _, tz = P.model_pos(target)
				local yaw = math.atan2(tx - mx, tz - mz)
				E.rig.yaw, E.rig.want_yaw = yaw, yaw
				if d < 1.5 or now - t_stage > 25 then
					T.held[0x57] = nil
					sx, sz = mx, mz
					res.log[#res.log + 1] = "walked " .. r2(now - t_stage) .. " s"
					stage, t_stage = "settle", now
				end
			elseif stage == "settle" and now - t_stage > 1.0 then
				res.hp0, res.men0, res.t0 = hp(), enemy:number_of_men_alive(), now
				local _, d = nearest(F.model)
				res.log[#res.log + 1] = "placed d=" .. r2(d)
				lift(mode)
				res.reg0 = r2(sub:position():distance_xz(enemy:position()))
				stage, t_stage = "run", now - 5
			elseif stage == "run" then
				-- TPA.tgt: offsets on him written with the nearest enemy man every frame (the fields a man in the engine's
				-- melee holds his opponent in, read live: +0x298, +0x2c0, +0xb00 during a blow)
				if TPA.tgt then
					local target = nearest(F.model)
					if target then for _, o in ipairs(TPA.tgt) do mr.write(F.model, o, target) end end
				end
				local s = P.anim_slot(F.model)
				if s and res.slots[#res.slots] ~= s then res.slots[#res.slots + 1] = s end
				if res.arm_wait and s and s ~= res.arm_wait.s0 then res.arm_wait = nil arm(s)
				elseif res.arm_wait and now - res.arm_wait.t > 2 then res.log[#res.log + 1] = "no swing" res.arm_wait = nil end
				local w = res.watch
				if w then
					local m = F.model
					local pend = mr.read_int32(m, 0xb08)
					if #w.trace < 40 then
						w.trace[#w.trace + 1] = (mr.is_null(mr.read_pointer(m, 0x898)) and "0" or "P") .. mr.read_int32(m, 0x284)
							.. ":" .. mr.read_int32(m, 0x27c) .. ":" .. tostring(P.anim_slot(m))
					end
					if pend == 0 or now - w.t > 3 then
						res.arms = res.arms or {}
						res.arms[#res.arms + 1] = "slot " .. w.slot .. " d=" .. w.d .. " " .. r2(now - w.t) .. " s pend=" .. pend
							.. " hp " .. tostring(w.hp) .. ">" .. tostring(hp()) .. " [" .. table.concat(w.trace, " ") .. "]"
						res.watch = nil
					end
				end
				local mx, _, mz = P.model_pos(F.model)
				local moved = math.sqrt((mx - sx) ^ 2 + (mz - sz) ^ 2)
				if not res.moved or moved > res.moved then res.moved = moved end
				if ticks < 4 and now - t_stage > 4.4 then
					ticks, t_stage = ticks + 1, now
					if mode == "click" then click()
					elseif mode == "click_arm" then click() res.arm_wait = {t = now, s0 = P.anim_slot(F.model)}
					elseif mode == "attack" or mode == "attack_free" or mode == "attack_melee" then forge()
					elseif mode == "attack_click" then
						forge()
						bm:real_callback(function() pcall(click) end, 300, "tpa_click_" .. tag .. ticks)
					end
					local _, d = nearest(F.model)
					res.log[#res.log + 1] = "tick " .. ticks .. " d=" .. r2(d) .. " hp=" .. tostring(hp())
				elseif ticks >= 4 and now - t_stage > 4.4 then
					res.hp1, res.men1, res.dt = hp(), enemy:number_of_men_alive(), now - res.t0
					res.moved = r2(res.moved)
					res.reg1 = r2(sub:position():distance_xz(enemy:position()))
					res.reg_melee = sub:is_in_melee()
					res.done = true
					lift(nil)
					if TPA.tgt then for _, o in ipairs(TPA.tgt) do mr.write(F.model, o, mr.uint32(0)) mr.write(F.model, o + 4, mr.uint32(0)) end end
					TPA.tgt = nil
					if F.on then E.main.stop("test done") end
					bm:remove_real_callback("tpa_run")
				end
			end
		end)
		if not ok then res.err = tostring(err) pcall(lift, nil) TPA.tgt = nil bm:remove_real_callback("tpa_run") end
	end, 1, "tpa_run")
	return "running " .. tag
end

function TPA.report(tag)
	local r = TPA[tag]
	if not r then return "no run " .. tostring(tag) end
	local s = {}
	for _, x in ipairs(r.slots) do s[#s + 1] = tostring(x) end
	return tag .. " " .. r.mode .. " done=" .. tostring(r.done) .. " err=" .. tostring(r.err) .. " hp " .. tostring(r.hp0) .. ">"
		.. tostring(r.hp1) .. " men " .. tostring(r.men0) .. ">" .. tostring(r.men1) .. " moved=" .. tostring(r.moved)
		.. " regiment " .. tostring(r.reg0) .. ">" .. tostring(r.reg1) .. " m off, melee " .. tostring(r.reg_melee)
		.. " slots=" .. table.concat(s, ",") .. " forged=" .. table.concat(r.forged, ",") .. " | " .. table.concat(r.log, "; ")
		.. (r.arms and (" || arms: " .. table.concat(r.arms, " || ")) or "")
end
return "TPA loaded"
