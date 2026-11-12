-- 2026-11-12 verification of the 11-11/11-12 bugs-thread reports. Loaded after zz_tp_live_20261108.lua (_G.TPT); results in docs/sessions/WORKSHOP_REPORTS_20261112_THIRD_PERSON.md.
-- No string library calls and no s:method(). Every per-frame read is inside pcall.
local T = _G.TPT
if not T then return "load TPT first" end
local E = T.E
local P, F = E.P, E.F
local V = _G.TPV or {}
_G.TPV = V

local function ms(r) return math.floor((os.clock() - r.t0) * 1000) end

-- the man watched: the one played, else the first model of V.unit (third person off)
local function watched()
	if F.on then return F.model or F.single end
	if V.unit then return P.models(V.unit)[1] end
end

-- record every slot change on him and his mount, every clip the pack sends, ammo, firing state, and his position
-- every 100 ms. Events: {ms, what, a, b}
function V.rec_start(unit)
	V.unit = unit
	local R = {t0 = os.clock(), ev = {}, pos = {}, on = true, last = {}}
	V.R = R
	local function add(e) if #R.ev < 900 then R.ev[#R.ev + 1] = e end end
	R.add = add
	if not V.play0 then
		V.play0 = P.play
		P.play = function(m, slot, mask, a, b)
			local ok = V.play0(m, slot, mask, a, b)
			local r = V.R
			if r and r.on then r.add({ms(r), "send", slot, ok and 1 or 0}) end
			return ok
		end
	end
	if not V.stop0 then
		V.stop0 = E.combat.stop_fire
		E.combat.stop_fire = function(a, b)
			local r = V.R
			if r and r.on then r.add({ms(r), "stop_fire"}) end
			return V.stop0(a, b)
		end
	end
	local nextpos = 0
	bm:repeat_real_callback(function()
		pcall(function()
			local r = V.R
			if not (r and r.on) then return end
			local man = watched()
			if not man then return end
			local L = r.last
			local s = P.anim_slot(man)
			if s ~= L.s then add({ms(r), "slot", s or -1}) L.s = s end
			local mt = P.mount(man)
			local s2 = mt and P.anim_slot(mt)
			if s2 ~= L.s2 then add({ms(r), "mslot", s2 or -1}) L.s2 = s2 end
			local u = F.on and F.unit or V.unit
			if u then
				local a = u:ammo_left()
				if a ~= L.a then add({ms(r), "ammo", a}) L.a = a end
			end
			local fs = (F.firing and 1 or 0) + (F.move_fire and 2 or 0) + (F.sprinting and 4 or 0) + (F.charging and 8 or 0)
			if fs ~= L.fs then add({ms(r), "flags", fs}) L.fs = fs end
			local t = ms(r)
			if t >= nextpos then
				nextpos = t + 100
				local x, _, z = P.model_pos(man)
				r.pos[#r.pos + 1] = {t, x, z}
			end
		end)
	end, 1, "tpv_rec")
	return "recording"
end

-- speed over each half second, m/s
local function speeds(pos)
	local out = {}
	for i = 6, #pos, 5 do
		local a, b = pos[i - 5], pos[i]
		local d = math.sqrt((b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
		out[#out + 1] = math.floor(d / ((b[1] - a[1]) / 1000) * 100 + 0.5) / 100
	end
	return out
end

function V.rec_stop()
	bm:remove_real_callback("tpv_rec")
	local r = V.R
	if not r then return "nothing" end
	r.on = false
	return {ev = r.ev, speeds = speeds(r.pos), n_ev = #r.ev}
end

-- CHARGE (135) episodes: how long the engine reported each, and the gap from each send to the next
function V.charges(slot)
	slot = slot or 135
	local r = V.R
	local runs, sends, open = {}, {}, nil
	local man = watched()
	local which = man and P.mount(man) and "mslot" or "slot"
	for _, e in ipairs(r.ev) do
		if e[2] == which then
			if e[3] == slot and not open then open = e[1]
			elseif e[3] ~= slot and open then runs[#runs + 1] = e[1] - open open = nil end
		end
		if e[2] == "send" and e[3] == slot then sends[#sends + 1] = e[1] end
	end
	local gaps = {}
	for i = 2, #sends do gaps[#gaps + 1] = sends[i] - sends[i - 1] end
	return {runs_ms = runs, send_gaps_ms = gaps, sends = #sends}
end

-- the length the pack resends CHARGE at, per unit type; nil restores
function V.charge_len(len)
	local k = F.utype
	V.saved_charge = V.saved_charge or {}
	if V.saved_charge[k] == nil then V.saved_charge[k] = E.D.charges[k] or false end
	if len then E.D.charges[k] = {len, 0} else E.D.charges[k] = V.saved_charge[k] or nil end
	return {unit = k, now = E.D.charges[k] and E.D.charges[k][1] or "none"}
end

-- the enemy: routed, and let go
function V.rout()
	for _, e in ipairs(T.enemy or {}) do
		pcall(function() e.uc:set_invincible(false) end)
		pcall(function() e.uc:morale_behavior_rout() end)
		pcall(function() e.uc:release_control() end)
	end
	return V.phase()
end
function V.phase()
	local p = "?"
	pcall(function() p = bm:get_current_phase_name() end)
	local out = {phase = p, enemy = {}}
	for _, e in ipairs(T.enemy or {}) do
		out.enemy[#out.enemy + 1] = {men = e.u:number_of_men_alive(), routing = e.u:is_routing() == true, valid = e.u:is_valid_target() == true}
	end
	return out
end

-- the ability bar the pack shows: key and the pack's own can/cooling per slot, on every page
function V.bar()
	local out = {}
	for pg = 1, 4 do
		local name = E.hud.page_name(0)
		for n = 1, 10 do
			local k = E.hud.key(n)
			if k then
				local can, cool = false, false
				pcall(function() can = E.hud.can(n) == true end)
				pcall(function() cool = E.hud.cooling(n) == true end)
				out[#out + 1] = {page = name, n = n, key = k, can = can, cooling = cool}
			end
		end
		E.hud.next_page()
		if E.hud.page_name(0) == (out[1] and out[1].page) then break end
	end
	return out
end

-- the engine's answer for a unit's abilities, third person on or off
function V.can(unit, keys)
	local out = {}
	for _, k in ipairs(keys) do
		local ok, v = pcall(function() return unit:can_perform_special_ability(k) end)
		out[k] = ok and v == true or (ok and "false" or "err")
	end
	return out
end

-- the nearest enemy unit, any state
function V.nearest(u)
	local q = u:position()
	local best, bd
	for _, e in ipairs(T.enemy or {}) do
		if e.u:number_of_men_alive() > 0 then
			local d = q:distance_xz(e.u:position())
			if not bd or d < bd then best, bd = e.u, d end
		end
	end
	return best, bd
end

-- CA's own order, third person off: attack the nearest enemy unit with unit i (a fire order for a shooter)
function V.vanilla_attack(i)
	local u = T.unit(i)
	local t, d = V.nearest(u)
	if not t then return "no enemy" end
	local uc = bm:get_player_army():create_unit_controller()
	uc:add_units(u)
	uc:fire_at_will(true)
	uc:attack_unit(t, true, true)
	uc:release_control()
	V.vuc = uc
	return {target = t:type(), dist = math.floor(d), routing = t:is_routing() == true}
end
function V.vanilla_halt(i)
	local u = T.unit(i)
	local uc = bm:get_player_army():create_unit_controller()
	uc:add_units(u)
	uc:halt()
	uc:release_control()
	return "halted"
end
-- CA's own cast, third person off: ability key at the nearest enemy (target) or its position (ground)
function V.vanilla_cast(i, key, how)
	local u = T.unit(i)
	local t = V.nearest(u)
	local uc = bm:get_player_army():create_unit_controller()
	uc:add_units(u)
	local ok, err
	if how == "ground" and t then ok, err = pcall(function() uc:perform_special_ability_ground(key, t:position()) end)
	elseif how == "self" then ok, err = pcall(function() uc:perform_special_ability(key, u) end)
	elseif t then ok, err = pcall(function() uc:perform_special_ability(key, t) end) end
	uc:release_control()
	return {ok = ok, err = err ~= nil and tostring(err) or nil}
end

-- the played unit faces the nearest enemy: a turn order on the spot
function V.face_enemy(i)
	local u = T.unit(i)
	local t = V.nearest(u)
	if not t then return "no enemy" end
	local q, p = u:position(), t:position()
	local b = math.deg(math.atan2(p:get_x() - q:get_x(), p:get_z() - q:get_z())) % 360
	local uc = bm:get_player_army():create_unit_controller()
	uc:add_units(u)
	uc:goto_location_angle_width(q, b, 1, false)
	uc:release_control()
	return b
end
-- put the enemy line dist m ahead of unit i (TPT.gather without moving my other units)
function V.enemy_ahead(i, dist)
	local c = T.unit(i)
	local q = c:position()
	local b = math.rad(c:bearing())
	local fx, fz = math.sin(b), math.cos(b)
	for k, e in ipairs(T.enemy) do
		local off = (k - (#T.enemy + 1) / 2) * 28
		local x, z = q:get_x() + fx * dist + fz * off, q:get_z() + fz * dist - fx * off
		e.uc:teleport_to_location(v(x, bm:get_terrain_height(x, z), z), (c:bearing() + 180) % 360, 24)
	end
	return #T.enemy .. " placed"
end
-- the camera: the yaw the pack's view looks along, set to the unit's bearing (the stubbed mouse never turns it)
function V.yaw_to(i)
	local u = T.unit(i)
	E.rig.yaw = math.rad(u:bearing())
	return u:bearing()
end
return "TPV loaded"
