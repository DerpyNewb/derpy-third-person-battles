-- The third-person HUD (docs/superpowers/specs/2026-10-14-third-person-hud-design.md): our own panel at the root,
-- filled from the tick. Positions and sizes come from hud_layout.lua, generated with the panel from one dict
-- (tools/gen_third_person_hud.py). Every write goes through put(), which skips a value already on screen.
-- A part that throws hides alone and logs once; three in a battle turn the HUD off, never third person.
-- return function(E) -> H.
local CCO_EVERY, MAX_ERRORS = 0.2, 3 -- s between unit-context reads (each is an expression the engine parses)
local RELOAD_SCALE = 1 -- ReloadPercentMax is 0..1 (plan 2 Task 1 measures)

return function(E)
	local F, L = E.F, E.load("hud_layout")
	local H = {}
	local ui, last, dead, errors, off = nil, {}, {}, 0, false
	local cco_id, cco_at, keys, slot_of, reload_cco = nil, 0, {}, {}, nil
	local acts, act_at = {}, {} -- the action buttons this unit shows, in order, and each one's place in that order
	local ACT_PARTS = {"frame", "icon", "active_l", "active_r", "dim", "coolplate", "cool", "keyplate", "key"}

	local function part(id) return ui and find_uicomponent(ui, id) end

	-- one write, only when the value differs from the last one written
	local function put(c, key, value, write)
		if not c or last[key] == value then return end
		last[key] = value
		write(c, value)
	end
	local function vis(id, b) put(part(id), id .. ".vis", b == true, function(c, x) c:SetVisible(x) end) end
	local function text(id, s) put(part(id), id .. ".text", s, function(c, x) c:SetStateText(x, "derpy_tp_hud") end) end
	local function img(id, path) put(part(id), id .. ".img", path, function(c, x) c:SetImagePath(x, 0) end) end

	-- the parts a failure hides together
	local GROUPS = {portrait = {"portrait", "name"}, health = {"health_back", "health_fill", "health_frame"},
		men = {"men"}, ammo = {"ammo", "ammo_back", "ammo_fill", "ammo_frame"}, mode = {"mode"}, slots = {}, reload = {},
		target = {"target_plate", "target"}, mark = {"target_arrow"}, actions = {}}
	for _, a in ipairs(L.actions) do
		for _, s in ipairs(ACT_PARTS) do GROUPS.actions[#GROUPS.actions + 1] = "act_" .. a .. "_" .. s end
	end
	for n = 1, L.slots do
		for _, s in ipairs({"frame", "icon", "active_l", "active_r", "windup_l", "windup_r", "dim", "armed", "coolplate",
			"cool", "keyplate", "key"}) do
			GROUPS.slots[#GROUPS.slots + 1] = "slot_" .. n .. "_" .. s
		end
	end

	local function fail(name, err)
		dead[name] = true
		for _, id in ipairs(GROUPS[name] or {}) do vis(id, false) end
		E.once("hud_" .. name, "HUD part " .. name .. " is off: " .. tostring(err))
		errors = errors + 1
		if errors >= MAX_ERRORS then
			off = true
			if ui then ui:SetVisible(false) end
			E.once("hud_off", "the HUD is off until this battle ends")
		end
	end
	local function guard(name, fn, ...)
		if dead[name] or off then return end
		local ok, err = pcall(fn, ...)
		if not ok then fail(name, err) end
	end

	local function cco(expr)
		if not cco_id then error("no unit context for this unit") end
		local val = common.get_context_value("CcoBattleUnit", cco_id, expr)
		if val == nil then error("the unit context gave nothing for " .. expr) end
		return val
	end

	-- every part from its group's corner; the scale is what the engine drew the probe part at against its design size
	function H.place()
		local sw, sh = core:get_screen_resolution()
		local probe = part(L.probe)
		local s = probe and select(1, probe:Dimensions()) / L.size[L.probe][1] or 1
		local m = L.margin * s
		local g = L.groups
		-- the bar centres on the slots it shows, not on all ten: its full width less a pitch per empty slot
		local shown = math.max(1, math.min(#keys, L.slots))
		local bar_w = g.bar[1] - (L.slots - shown) * (L.at.slot_2_frame[2] - L.at.slot_1_frame[2])
		local o = {left = {m, sh - m - g.left[2] * s}, bar = {(sw - bar_w * s) / 2, sh - m - g.bar[2] * s},
			right = {sw - m - g.right[1] * s, sh - m - g.right[2] * s},
			centre = {(sw - g.centre[1] * s) / 2, sh / 2 + L.target_y * s}}
		-- the shown action buttons packed against the right edge, over the right plate
		local aw = math.max(0, #acts * L.action_pitch - (L.action_pitch - L.size.act_attack_frame[1]))
		o.actions = {sw - m - aw * s, sh - m - (g.right[2] + L.stack + g.actions[2]) * s}
		for id, at in pairs(L.at) do
			local c = part(id)
			local dx = at[2]
			if at[1] == "actions" then dx = dx + ((act_at[id:match("^act_(%a+)_")] or 1) - 1) * L.action_pitch end
			if c then c:MoveTo(math.floor(o[at[1]][1] + dx * s), math.floor(o[at[1]][2] + at[3] * s)) end
		end
		H.s = s
	end

	-- the unit at the start of a session: its card's context, its portrait, and the hotbar in cast order. The
	-- context and the slots' places in it are read even with the HUD off: abilities.lua casts through them
	function H.unit()
		local card = find_uicomponent(core:get_ui_root(), "cards_panel", tostring(F.unit:unique_ui_id()))
		cco_id = card and card:GetContextObjectId("CcoBattleUnit") or nil
		keys = F.unit:owned_non_passive_special_abilities() or {}
		slot_of = {}
		local indexed, why = pcall(function()
			local index = {}
			for i = 0, cco("BattleAbilityList.Size") - 1 do
				index[cco("BattleAbilityList.At(" .. i .. ").SetupAbilityContext.RecordKey")] = i
			end
			for n = 1, math.min(#keys, L.slots) do slot_of[n] = index[keys[n]] end
		end)
		if off then return end
		guard("portrait", function()
			img("portrait", cco("IconPath"))
			text("name", cco("Name"))
			vis("portrait", true) vis("name", true)
		end)
		for n = 1, L.slots do
			local on = keys[n] ~= nil
			for _, s in ipairs({"frame", "icon", "keyplate", "key", "cool"}) do vis("slot_" .. n .. "_" .. s, on) end
			for _, s in ipairs({"dim", "coolplate", "armed", "active_l", "active_r", "windup_l", "windup_r"}) do
				vis("slot_" .. n .. "_" .. s, false)
			end
			if on then text("slot_" .. n .. "_key", E.S.names["ability_" .. n] or "") end
		end
		-- the action buttons: attack always, fire for a shooter (artillery aims in Manual fire), charge and jump when his
		-- men have the clips; each with its key
		local can = {run = true, attack = true, fire = F.unit:missile_range() > 0 and not F.arty, charge = F.can_charge,
			jump = F.can_jump}
		local key_of = {run = "run", attack = "attack", fire = "attack", charge = "charge", jump = "jump"}
		acts, act_at = {}, {}
		for _, a in ipairs(L.actions) do
			if can[a] then acts[#acts + 1] = a act_at[a] = #acts end
			for _, s in ipairs({"frame", "icon", "keyplate", "key"}) do vis("act_" .. a .. "_" .. s, can[a] == true) end
			for _, s in ipairs({"dim", "coolplate", "cool", "active_l", "active_r"}) do vis("act_" .. a .. "_" .. s, false) end
			if can[a] then text("act_" .. a .. "_key", E.S.names[key_of[a]] or "") end
		end
		guard("slots", function()
			if not indexed then error(why, 0) end
			for n, i in pairs(slot_of) do
				img("slot_" .. n .. "_icon", cco("BattleAbilityList.At(" .. i .. ").SetupAbilityContext.IconPath"))
			end
		end)
	end

	-- hotbar slot n's ability in the unit's context: a field of its record, or a command run on it. Both throw when the
	-- slot has no matched ability or the context gave nothing, so a caller can fall back
	local function ability_at(n)
		local i = slot_of[n]
		if not i or not cco_id then error("no context for ability slot " .. n) end
		return "BattleAbilityList.At(" .. i .. ")."
	end
	function H.ability(n, field) return cco(ability_at(n) .. "SetupAbilityContext." .. field) end
	-- on the battle ability itself: PerformAbilityForOwner on its SetupAbilityContext does nothing (measured 2026-10-14)
	function H.ability_command(n, fn) common.call_context_command("CcoBattleUnit", cco_id, ability_at(n) .. fn) end
	-- slot n's ability is recharging; no context, no answer: false (-1 is no cooldown, measured)
	function H.cooling(n)
		local ok, secs = pcall(function() return cco(ability_at(n) .. "RechargeTimeRemainingSecs") end)
		return ok and secs > 0
	end

	-- the armed ability (abilities.lua): its slot shows CA's selected ring; nil clears every slot
	function H.armed(n) for k = 1, L.slots do vis("slot_" .. k .. "_armed", k == n) end end
	-- the label under the crosshair naming what an armed ability would hit; nil hides it
	function H.target(s)
		vis("target_plate", s ~= nil) vis("target", s ~= nil)
		if s then text("target", s) end
	end
	-- the arrow over the unit an armed ability would hit, tip on his position lifted L.arrow_lift m; nil hides it.
	-- CA's WorldSpaceToScreenSpace answers screen px; 0 < z < 1 is in front of the camera, anything else projects
	-- to nonsense (measured 2026-10-14 against a screenshot)
	local function cm2(n) return math.floor(n * 100 + 0.5) / 100 end
	function H.mark(u)
		guard("mark", function()
			local c = part("target_arrow")
			if not u or not c then vis("target_arrow", false) return end
			local p = u:position()
			local at = "WorldSpaceToScreenSpace(ToVector4(" .. cm2(p:get_x()) .. "," .. cm2(p:get_y() + L.arrow_lift) .. ","
				.. cm2(p:get_z()) .. ",1), false, false)."
			local z = common.get_context_value(at .. "z")
			if z == nil then error("the engine gave no projection") end
			local front = z > 0 and z < 1
			vis("target_arrow", front)
			if not front then return end
			local s = H.s or 1
			local x = math.floor(common.get_context_value(at .. "x") - L.size.target_arrow[1] * s / 2)
			local y = math.floor(common.get_context_value(at .. "y") - L.size.target_arrow[2] * s)
			put(c, "target_arrow.at", x * 10000 + y, function() c:MoveTo(x, y) end)
		end)
	end
	-- any unit's display name, from its own context (measured 2026-10-14: enemies answer by their ui id too)
	function H.unit_name(u)
		local ok, name = pcall(common.get_context_value, "CcoBattleUnit", tostring(u:unique_ui_id()), "Name")
		return ok and name or u:type()
	end

	function H.show(on)
		if on and off then H.unit() return end -- no panel, but this unit's abilities still need its context
		if off then return end
		if not on then if ui then ui:SetVisible(false) end return end
		local root = core:get_ui_root()
		ui = find_uicomponent(root, "derpy_tp_hud")
		if not ui then
			-- a layout the engine cannot build answers nil (measured): say so once, and third person goes on without
			local made = root:CreateComponent("derpy_tp_hud", L.file)
			if not made then
				off = true
				E.once("hud_layout", "the HUD's layout did not load: " .. L.file)
				return
			end
			ui = UIComponent(made)
			for _, id in ipairs({"health_fill", "ammo_fill"}) do
				local c = part(id)
				if c then c:SetCanResizeWidth(true) c:SetCanResizeHeight(true) end
			end
		end
		last, dead, cco_at = {}, {}, 0
		ui:SetVisible(true)
		H.target(nil) H.mark(nil)
		H.unit() -- first: the bar centres on how many abilities he has
		H.place()
	end

	local function width(id, frac)
		local c = part(id)
		if not c then return end
		local w = math.max(1, math.floor(L.fill[id] * math.max(0, math.min(1, frac)) * (H.s or 1) + 0.5))
		put(c, id .. ".w", w, function(x, val) x:Resize(val, math.floor(L.size[id][2] * (H.s or 1) + 0.5)) end)
	end

	-- CA's first-person reload ring (plan 2 Task 1: script can show it and turn its two half rings). nil hides; past 1
	-- is full.
	local function ring(frac)
		local x = find_uicomponent(core:get_ui_root(), "derpy_tp_crosshair", "reload_ring")
		if not x then return end
		local on = frac ~= nil and frac > 0
		put(x, "ring.vis", on, function(c, b) c:SetVisible(b) end)
		if not on then return end
		frac = math.min(frac, 1) -- the clip can outlast the reload time: full until he can fire
		for half = 1, 2 do
			-- the halves turn opposite ways (measured): L1, the right, runs 0 to +pi; L2, the left, 0 to -pi
			local from, to = L.ring[half][1], L.ring[half][2]
			local f = half == 1 and math.min(frac, 0.5) * 2 or math.max(frac - 0.5, 0) * 2
			local c = find_uicomponent(x, "loading_ring_L" .. half)
			put(c, "ring." .. half, math.floor((from + f * (to - from)) * 1000 + 0.5) / 1000,
				function(r, a) r:SetImageRotation(0, a) end)
		end
	end

	-- how far through his reload the shooter is: one man shooting alone runs on our own clock (the shot is ours,
	-- not the engine's); a regiment firing as a whole reports the engine's own
	local function reload_frac(now)
		local base = E.D.shots[F.utype] and E.D.shots[F.utype][2] * E.S.reload_factor
		if F.solo and base then
			local shot = F.shot
			if shot and shot.phase == "reload" and shot.reload_at then return (now - shot.reload_at) / base end
			if now < F.ready_at then return 1 - (F.ready_at - now) / base end
			return nil
		end
		-- the engine reports 1 for a loaded regiment (measured), so 1 shows no ring
		if F.ranged and reload_cco ~= nil and reload_cco < 1 then return reload_cco end
		return nil
	end

	function H.update(now)
		if off or not ui then return end
		local u = F.unit
		guard("health", function() width("health_fill", u:unary_hitpoints()) end)
		guard("men", function()
			local n0 = u:initial_number_of_men()
			vis("men", n0 > 1)
			if n0 > 1 then text("men", u:number_of_men_alive() .. " / " .. n0) end
		end)
		guard("ammo", function()
			local has = u:missile_range() > 0
			for _, id in ipairs(GROUPS.ammo) do vis(id, has) end
			if has then
				local left, start = u:ammo_left(), u:starting_ammo()
				text("ammo", tostring(left))
				width("ammo_fill", start > 0 and left / start or 0)
			end
		end)
		guard("mode", function() img("mode", F.ranged and L.art.ranged or L.art.melee) vis("mode", true) end)
		guard("slots", function()
			for n = 1, math.min(#keys, L.slots) do
				vis("slot_" .. n .. "_dim", not u:can_perform_special_ability(keys[n]))
			end
		end)
		if now >= cco_at then
			cco_at = now + CCO_EVERY
			guard("slots", function()
				-- CA's timer ring states: winding up (the cast before it takes effect; -1 when not) the plain ring, running
				-- the green one, each with its seconds left; then the cooldown's seconds
				for n, i in pairs(slot_of) do
					local at = "BattleAbilityList.At(" .. i .. ")."
					local windup = cco(at .. "WindUpTimeRemainingSecs")
					local winding = windup > 0
					local active = cco(at .. "IsActive") == true -- false through a wind-up (measured)
					local secs = winding and windup or cco(at .. (active and "ActiveTimeRemainingSecs" or "RechargeTimeRemainingSecs"))
					text("slot_" .. n .. "_cool", secs > 0 and tostring(math.ceil(secs)) or "")
					vis("slot_" .. n .. "_coolplate", secs > 0)
					vis("slot_" .. n .. "_active_l", active) vis("slot_" .. n .. "_active_r", active)
					vis("slot_" .. n .. "_windup_l", winding) vis("slot_" .. n .. "_windup_r", winding)
				end
			end)
			if F.ranged and not F.solo then
				guard("reload", function() reload_cco = cco("ReloadPercentMax") / RELOAD_SCALE end)
			end
		end
		guard("reload", function() ring(reload_frac(now)) end)
		guard("actions", function()
			-- each action's cooldown seconds, dimmed as CA dims a button that cannot be used yet
			local function show(a, secs, empty)
				if not act_at[a] then return end
				local p = "act_" .. a .. "_"
				local wait = secs ~= nil and secs > 0
				text(p .. "cool", wait and tostring(math.ceil(secs)) or "")
				vis(p .. "cool", wait) vis(p .. "coolplate", wait)
				vis(p .. "dim", empty or wait)
			end
			show("attack", F.next_swing - now)
			show("jump", F.next_jump - now)
			show("charge", F.next_charge - now)
			-- lit while on: the run, and the charge (CA's green ring, as an ability's active time)
			local function lit(a, on) if act_at[a] then vis("act_" .. a .. "_active_l", on) vis("act_" .. a .. "_active_r", on) end end
			lit("run", F.running) lit("charge", F.charging)
			local frac = reload_frac(now)
			local base = E.D.shots[F.utype] and E.D.shots[F.utype][2] * E.S.reload_factor
			local secs = frac and frac < 1 and (base and (1 - frac) * base or 0.5) or nil
			local empty = u:ammo_left() <= 0 -- out of ammo: dim, no seconds
			show("fire", not empty and secs or nil, empty)
		end)
	end

	return H
end
