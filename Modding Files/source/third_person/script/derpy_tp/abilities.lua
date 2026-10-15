-- Ability keys 1-0 (spec section 6): key N casts the unit's Nth non-passive ability, aimed by its kind - the
-- crosshair's ground point, the enemy or ally nearest the crosshair ray, itself, or nothing at all. The kind is the
-- ability record's own (measured 2026-10-14: the unit context carries its target flags, modded abilities included);
-- without a context, data.lua's from db.pack. return function(E) -> A.
local RANGE = 300 -- m: farthest ground point or unit an ability is aimed at
-- a unit is on the crosshair inside 12 deg of it, as the eye sees it: half a 20 m regiment front seen from 50 m
local CONE = math.tan(math.rad(12))

return function(E)
	local F = E.F
	local A = {}

	-- the record's flags in data.lua's order (tools/build_third_person.py ability_kind): ground before a unit
	local FLAGS = {{"TargetGround", "ground"}, {"TargetGroundUnderEnemies", "ground"}, {"TargetGroundUnderAllies", "ground"},
		{"TargetEnemies", "enemy"}, {"TargetFriends", "friend"}, {"TargetSelf", "self"}}
	local function kind_of(n, key)
		local ok, kind = pcall(function()
			for _, f in ipairs(FLAGS) do
				if E.hud.ability(n, "UnitSpecialAbilityRecordContext." .. f[1]) == true then return f[2] end
			end
			return "none"
		end)
		if ok then return kind end
		return E.D.abilities[key] or "self"
	end

	-- how far slot n's ability reaches: its own TargetRange (CcoUnitAbility: "the maximum range of a target an ability
	-- can be used on"); RANGE without a context or a range
	local function reach(n)
		local ok, r = pcall(E.hud.ability, n, "TargetRange")
		return ok and type(r) == "number" and r > 0 and r or RANGE
	end

	-- the unit, enemy or friendly, nearest the camera's ray by angle, inside CONE and in front of the camera; never the
	-- caster. By metres off the ray, a far unit in a screen corner won when nothing was near (seen in game 2026-10-14).
	-- Past range m from the caster it is no target; far says one on the crosshair was (the author: "no enemy in range")
	local function nearest_to_ray(enemy, range)
		local R = E.rig
		if not R.ex then return nil end -- before the camera's first frame
		local ox, oz
		if F.model then local x, _, z = E.P.model_pos(F.model) ox, oz = x, z else local q = F.unit:position() ox, oz = q:get_x(), q:get_z() end
		local far = false
		local dx, dy, dz = R.lx - R.ex, R.ly - R.ey, R.lz - R.ez
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		dx, dy, dz = dx / len, dy / len, dz / len
		local alliance = enemy and bm:get_non_player_alliance() or bm:get_player_alliance()
		local best, best_d
		local armies = alliance:armies()
		for a = 1, armies:count() do
			local units = armies:item(a):units()
			for i = 1, units:count() do
				local u = units:item(i)
				-- an enemy the game will not let be attacked (hidden, arriving, leaving) is no target either
				if u:unique_ui_id() ~= F.unit:unique_ui_id() and u:number_of_men_alive() > 0 and not u:is_routing()
					and (not enemy or u:is_valid_target()) then
					local p = u:position()
					local px, py, pz = p:get_x() - R.ex, p:get_y() - R.ey, p:get_z() - R.ez
					local t = px * dx + py * dy + pz * dz
					if t > 0 and t < RANGE then
						local cx, cy, cz = px - dx * t, py - dy * t, pz - dz * t
						local d = math.sqrt(cx * cx + cy * cy + cz * cz) / t
						if d < CONE and (p:get_x() - ox) ^ 2 + (p:get_z() - oz) ^ 2 > range * range then far = true
						elseif d < CONE and (not best_d or d < best_d) then best, best_d = u, d end
					end
				end
			end
		end
		return best, far
	end

	-- slot n's ability key when it can go off now; nil and why when not
	local function ready(n)
		local list = F.unit:owned_non_passive_special_abilities()
		local key = list and list[n]
		if not key then return nil, "no ability in slot " .. n end
		if not F.unit:can_perform_special_ability(key) then return nil, key .. " cannot be cast now" end
		-- can_perform stays true through a cooldown (measured): the order went out anyway
		if E.hud.cooling(n) then return nil, key .. " is cooling down" end
		return key
	end

	function A.cast(n)
		local key, why = ready(n)
		if not key then return why end
		local kind = kind_of(n, key)
		local ok, err, via_context
		if kind == "ground" then
			local x, y, z = E.combat.aim_point(reach(n))
			if not x then return "no aim yet" end
			ok, err = pcall(F.uc.perform_special_ability_ground, F.uc, key, v(x, y, z))
		elseif kind == "enemy" then
			local target, far = nearest_to_ray(true, reach(n))
			if not target then return (far and "out of range" or "no enemy near the crosshair") .. " for " .. key end
			ok, err = pcall(F.uc.perform_special_ability, F.uc, key, target)
		elseif kind == "friend" then -- no ally on the crosshair: himself (the engine refuses it if he cannot be)
			ok, err = pcall(F.uc.perform_special_ability, F.uc, key, nearest_to_ray(false, reach(n)) or F.unit)
		elseif kind == "none" then -- no target at all: any unit order is refused, so activate it as CA's button does
			ok, err = pcall(E.hud.ability_command, n, "PerformAbilityForOwner")
			via_context = ok
			if not ok then ok, err = pcall(F.uc.perform_special_ability, F.uc, key, F.unit) end -- no context: the old cast
		else
			ok, err = pcall(F.uc.perform_special_ability, F.uc, key, F.unit)
		end
		-- the engine refusing an order is not a fault in this mod: name the ability once, never count it as an error
		if not ok then
			E.once("cast_" .. key, "the game refused " .. key .. " (" .. kind .. "): " .. tostring(err))
			return nil
		end
		-- a context activation gave the controller no order: releasing it let the unit resume its last move (seen in
		-- game 2026-10-14), so only a unit order is handed back
		if not via_context then
			F.uc:release_control()
			F.driving = false
		end
		E.log("cast " .. key .. " (" .. kind .. ")")
		return nil
	end

	-- Arming (the author, 2026-10-14): an aimed ability arms on its key - its slot shows CA's selected ring, the
	-- crosshair comes up in any mode and a label names the target - and goes off on the left click. The key again or
	-- the mode key disarms. An ability with nothing to aim at goes off on its key.
	local AIMED = {ground = true, enemy = true, friend = true}
	local LABEL_EVERY = 0.2 -- s between label updates: a unit name is a context read
	function A.cancel()
		if not F.armed then return end
		F.armed = nil
		E.hud.armed(nil)
		E.hud.target(nil)
		E.hud.mark(nil)
	end
	function A.press(n, now)
		if F.armed and F.armed.n == n then A.cancel() return nil end
		local key, why = ready(n)
		if not key then return why end
		local kind = kind_of(n, key)
		if not AIMED[kind] then A.cancel() return A.cast(n) end
		E.combat.stand_down(now) -- the author: "stop melee or shooting"
		F.armed = {n = n, kind = kind, label_at = -1e9, range = reach(n)}
		E.hud.armed(n)
		return nil
	end
	function A.fire()
		local n = F.armed and F.armed.n
		A.cancel()
		if n then return A.cast(n) end
	end
	-- the label and the unit it names are picked every LABEL_EVERY; the arrow over him follows the view every frame
	function A.update(now)
		local a = F.armed
		if not a then return end
		if now - a.label_at >= LABEL_EVERY then
			a.label_at = now
			a.unit = nil
			local s
			if a.kind == "ground" then
				local x, _, z = E.combat.aim_point(a.range)
				local q = F.unit:position()
				s = x and ("Ground, " .. math.floor(math.sqrt((x - q:get_x()) ^ 2 + (z - q:get_z()) ^ 2) + 0.5) .. " m")
					or "No ground in sight"
			else
				local far
				a.unit, far = nearest_to_ray(a.kind == "enemy", a.range)
				s = a.unit and E.hud.unit_name(a.unit)
					or (a.kind ~= "enemy" and "On himself") or (far and "Out of range") or "No enemy in sight"
			end
			E.hud.target(s)
		end
		E.hud.mark(a.unit)
	end

	return A
end
