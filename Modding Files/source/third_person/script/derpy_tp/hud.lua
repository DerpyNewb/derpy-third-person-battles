-- The third-person HUD (docs/superpowers/specs/2026-10-14-third-person-hud-design.md): our own panel at the root,
-- filled from the tick. Positions and sizes come from hud_layout.lua, generated with the panel from one dict
-- (tools/gen_third_person_hud.py). Every write goes through put(), which skips a value already on screen.
-- A part that throws hides alone and logs once; three in a battle turn the HUD off, never third person.
-- return function(E) -> H.
local CCO_EVERY, MAX_ERRORS = 0.2, 3 -- s between unit-context reads (each is an expression the engine parses)
local RELOAD_SCALE = 1 -- ReloadPercentMax is 0..1 (plan 2 Task 1 measures)
-- CA's bottom band under hud_battle, its parts' tops measured 2026-10-23 (porthole highest): command mode's Vanilla style
-- stands the panel on them
local CA_BAND = {"porthole_parent", "battle_orders", "winds_of_magic"}
-- CA's words for a morale state (ui_unit_statuses, CA's banner status tooltips): MoraleState 4 and 5
local MORALE_WORDS = {[4] = "ui_unit_statuses_tooltip_shaken", [5] = "ui_unit_statuses_tooltip_wavering"}
local BACK = {"back_plate", "back", "back_keyplate", "back_key"}
-- CA's context constructor: in the script environment this file runs in, not in _G (measured 2026-10-19: _G.cco nil,
-- the bare name a callable table, as CA's lib_battle_script_unit.lua uses it); taken before cco() below hides it
local context = cco

return function(E)
	local F, L = E.F, E.load("hud_layout")
	local H = {}
	local ui, last, dead, errors, off = nil, {}, {}, 0, false
	local cco_id, cco_at, keys, on_page, reload_cco = nil, 0, {}, {}, nil -- on_page: the shown page's entries (build)
	local cooling = {} -- slot n's ability is recharging, as the last context read found it
	local able = {} -- slot n's army ability can go off, as the last read of CA's button found it
	local army_n = 0 -- CA's army ability buttons the pages came from
	local acts, act_at = {}, {} -- the action buttons this unit shows, in order, and each one's place in that order
	local caster = false -- an ability of his spends winds: his army's pool and its bar show
	local home -- CA's radar's holder and place while the radar is in this panel (H.map): {holder, x, y}
	local pages, page, list_n = {}, 1, nil -- the bar's pages (build below), the one shown, CA's list's size they came from
	local tab_text -- the page tab's words while it shows (show_page); H.place sizes the tab to them
	local hint, cost -- why an overcast was refused {n, why, till}; the winds an armed spell would spend
	local HINT_SECS = 2
	local function clock() return bm:time_elapsed_ms() / 1000 end
	local ACT_PARTS = {"frame", "icon", "active_l", "active_r", "dim", "coolplate", "cool", "keyplate", "key"}

	local function part(id) return ui and find_uicomponent(ui, id) end

	-- one write, only when the value differs from the last one written
	local function put(c, key, value, write)
		if not c or last[key] == value then return end
		last[key] = value
		write(c, value)
	end
	-- the parts command mode's Vanilla style sets aside (H.back; the author, 2026-10-23, from the live frames): his plate,
	-- which CA's unit information panel covers, the action buttons, and the bar's keys and page tab, whose keys the mode
	-- gives to other things (the number keys pick units, E pages, Shift slows). away holds them while set aside, and vis
	-- shows none of them; asked is what each part was last asked to show, what H.back gives back
	local AWAY, away, asked = {}, {}, {}
	for id, at in pairs(L.at) do
		if at[1] == "left" or at[1] == "actions" or id:match("^slot_%d+_key") or id:match("^tab") then AWAY[id] = true end
	end
	local function vis(id, b)
		asked[id] = b == true
		put(part(id), id .. ".vis", asked[id] and not away[id], function(c, x) c:SetVisible(x) end)
	end
	local function text(id, s) put(part(id), id .. ".text", s, function(c, x) c:SetStateText(x, "derpy_tp_hud") end) end
	local function img(id, path) put(part(id), id .. ".img", path, function(c, x) c:SetImagePath(x, 0) end) end

	-- the parts a failure hides together
	local GROUPS = {portrait = {"portrait", "name"}, health = {"health_back", "health_fill", "health_frame"},
		hp = {"hp", "hp_icon"}, winds = {"winds", "winds_icon", "winds_back", "winds_fill", "winds_frame", "winds_cost"},
		stamina = {"stamina", "stamina_icon", "stamina_back", "stamina_fill", "stamina_frame"},
		men = {"men", "men_icon"}, ammo = {"ammo", "ammo_back", "ammo_fill", "ammo_frame"}, mode = {"mode"}, slots = {}, reload = {},
		target = {"target_plate", "target"}, mark = {"target_arrow"}, actions = {}, bars = {"bars"}, men_bars = {"men_bars"},
		morale = {"morale_icon", "morale_back", "morale_fill", "morale_alarm", "morale_frame", "morale_text"}, kills = {"kills_icon", "kills"},
		hidden = {"hidden_plate", "hidden_icon", "hidden"}}
	for _, a in ipairs(L.actions) do
		for _, s in ipairs(ACT_PARTS) do GROUPS.actions[#GROUPS.actions + 1] = "act_" .. a .. "_" .. s end
	end
	for n = 1, L.slots do
		for _, s in ipairs({"frame", "icon", "active_l", "active_r", "windup_l", "windup_r", "dim", "armed", "over", "coolplate",
			"cool", "usesplate", "uses", "manaplate", "mana", "keyplate", "key"}) do
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
			H.map(false) -- CA's radar back in its holder: this panel is going
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

	-- a value off his unit's context; nil with none
	function H.value(expr)
		local ok, v = pcall(cco, expr)
		if ok then return v end
	end

	-- command mode's Vanilla style brings CA's whole HUD back (command.lua): the panel stands a margin over CA's bottom
	-- band, the corner buttons a margin under its radar (the author, 2026-10-23, picked the pack's panel with CA's HUD),
	-- and his skills on CA's portrait, from its left edge (later that day: "move back the skills to the character
	-- portrait"). floor, top, left: the screen's floor, the margin and nil with none
	local placed, band_at = {}, 0 -- what H.place last stood the panel on; H.update places again when it moves
	local function band(sh, m)
		local floor, top, left = sh, m, nil
		if E.command and E.command.vanilla() then
			local h = find_uicomponent(core:get_ui_root(), "hud_battle")
			-- only the parts CA shows: one CA hides may be parked anywhere (the final review). While third person hides
			-- CA's HUD, CA's own visibility is what main.lua kept (F.hidden_ui)
			local kept = F.hidden_ui and F.hidden_ui.hud_battle or {}
			for _, id in ipairs(CA_BAND) do
				local c = h and find_uicomponent(h, id)
				local ca_shows = kept[id]
				if ca_shows == nil then ca_shows = c and c:Visible() end
				if c and ca_shows then local _, y = c:Position() floor = math.min(floor, y) end
			end
			local r = h and find_uicomponent(h, "radar_holder")
			if r then local _, y = r:Position() local _, rh = r:Dimensions() top = math.max(top, y + rh + m) end
			local p = h and find_uicomponent(h, "porthole_parent")
			if p then left = p:Position() end
		end
		return floor, top, left
	end

	-- what the engine drew the probe part at against its design size
	local function scale()
		local probe = part(L.probe)
		return probe and select(1, probe:Dimensions()) / L.size[L.probe][1] or 1
	end
	-- every part from its group's corner, at scale()
	function H.place()
		local sw, sh = core:get_screen_resolution()
		local s = scale()
		local m = L.margin * s
		local g = L.groups
		-- the bar centres on the slots it shows, not on all ten: its full width less a pitch per empty slot
		local shown = math.max(1, math.min(#keys, L.slots))
		local bar_w = g.bar[1] - (L.slots - shown) * (L.at.slot_2_frame[2] - L.at.slot_1_frame[2])
		-- and the page tab hanging off its left end with it (a 200px tab beside ten slots met the portrait's plate), its
		-- text and the padding wide (the author, 2026-10-20, in game: "too long"), a slot's gap left of slot 1
		local gap = -L.at.tab_plate[2] - L.size.tab_plate[1]
		local tab_w, tab_dw = 0, nil
		local tp, tt = part("tab_plate"), part("tab")
		if tab_text and tp and tt and not away.tab then
			tab_dw = math.ceil(tt:TextDimensionsForText(tab_text) / s) + 2 * L.pad
			for c, w in pairs({[tp] = tab_dw, [tt] = tab_dw - 2 * L.pad}) do
				local _, h = c:Dimensions()
				c:SetCanResizeWidth(true) c:SetCanResizeHeight(true)
				c:Resize(math.floor(w * s + 0.5), h)
			end
			tab_w = tab_dw + gap
		end
		local floor, top, left = band(sh, m)
		placed[1], placed[2] = floor, top
		local bar_x = left and left + tab_w * s or (sw - (bar_w + tab_w) * s) / 2 + tab_w * s
		local o = {left = {m, floor - m - g.left[2] * s}, bar = {bar_x, floor - m - g.bar[2] * s},
			right = {sw - m - g.right[1] * s, floor - m - g.right[2] * s},
			centre = {(sw - g.centre[1] * s) / 2, sh / 2 + L.target_y * s}, toggle = {sw - m - g.toggle[1] * s, top},
			screen = {0, 0}}
		-- the shown action buttons packed against the right edge, over the right plate
		local aw = math.max(0, #acts * L.action_pitch - (L.action_pitch - L.size.act_attack_frame[1]))
		o.actions = {sw - m - aw * s, floor - m - (g.right[2] + L.stack + g.actions[2]) * s}
		-- the way back out of command mode over the bar, from its left edge
		o.back = {o.bar[1], o.bar[2] - (L.stack + g.back[2]) * s}
		-- reaching over the ability bar (all eight beside ten abilities; seven left 22 px at 1600 in the preview,
		-- 2026-10-15), the buttons go up a row, clear of it
		if #keys > 0 and o.actions[1] < o.bar[1] + bar_w * s and o.actions[2] + g.actions[2] * s > o.bar[2] then
			o.actions[2] = o.bar[2] - (L.stack + g.actions[2]) * s
		end
		-- CA's radar while shown (H.map): under the corner buttons, on the right margin, at its own drawn size
		local r = home and find_uicomponent(ui, "radar_group")
		if r then
			local w = r:Dimensions()
			r:MoveTo(math.floor(sw - m - w), math.floor(o.toggle[2] + (g.toggle[2] + L.stack) * s))
		end
		for id, at in pairs(L.at) do
			local c = part(id)
			local dx, dy = at[2], at[3]
			if not caster and L.lifted[id] then dy = dy + L.lift end -- no winds row: the rows above it drop into its place
			if at[1] == "actions" then dx = dx + ((act_at[id:match("^act_(%a+)_")] or 1) - 1) * L.action_pitch end
			if tab_dw and id == "tab_plate" then dx = -tab_w elseif tab_dw and id == "tab" then dx = -tab_w + L.pad end
			if c then c:MoveTo(math.floor(o[at[1]][1] + dx * s), math.floor(o[at[1]][2] + dy * s)) end
		end
		H.s = s
	end

	-- his army's abilities (a player, 2026-10-29: "faction spell to be use when on third person mode"): CA's own buttons
	-- under hud_battle's army_ability_parent, in CA's order, those his unit's army owns. Their live record is reachable
	-- there only (a CcoBattleArmy by its id answers nothing, measured 2026-10-29), and CA leaves the hidden ones out, the
	-- pack's 40 stat abilities among them. Also how many buttons CA has, for the update to see one come. ponytail: a
	-- player with two armies in one battle - whose buttons CA shows is unmeasured
	local function army_parent() return find_uicomponent(core:get_ui_root(), "hud_battle", "army_ability_parent") end
	local function army_entries()
		local p, out = army_parent(), {}
		local own = H.value('ArmyContext.ArmyAbilitiesList(false).JoinString(RecordKey, ",")')
		if not p then return out, 0 end
		for i = 0, p:ChildCount() - 1 do
			-- keys are [a-z0-9_]: no pattern character, so a plain match (find with a pattern finds nothing in game)
			local key = UIComponent(p:Find(i)):Id():match("^button_holder_(.+)$")
			if key and type(own) == "string" and ("," .. own .. ","):match("," .. key .. ",") then
				out[#out + 1] = {key = key, army = true}
			end
		end
		return out, p:ChildCount()
	end

	-- the bar's pages (the 2026-10-20 design, Part 2): CA's own list in its order, each ability once - the owned list
	-- holds every spell twice, its key and its overcast's (measured 2026-10-20) - abilities first, then spells (they cost
	-- winds, CcoBattleAbility.ManaUsed), then his army's, L.slots a page. No context: the owned list, its overcast copies
	-- dropped, one kind. Each slot {key, i: its place in CA's list, up: the spell's overcast key} or {key, army = true}
	local function build()
		local owned, has = F.unit:owned_non_passive_special_abilities() or {}, {}
		for _, k in ipairs(owned) do has[k] = true end
		local entries = {}
		local indexed, why = pcall(function()
			local n = cco("BattleAbilityList.Size")
			list_n = n
			for i = 0, n - 1 do
				local at = "BattleAbilityList.At(" .. i .. ")."
				-- the passives lead CA's list (8 of the Exalted Keeper of Secrets' 22, measured 2026-10-20): nothing to cast
				local okp, passive = pcall(cco, at .. "SetupAbilityContext.IsPassive")
				-- an entry that cannot be read costs itself only, not the entries after it (the final review)
				local okk, key = pcall(cco, at .. "SetupAbilityContext.RecordKey")
				if not (okp and passive == true) and okk then
					local ok, mana = pcall(cco, at .. "ManaUsed") -- an ability without the field costs none
					entries[#entries + 1] = {key = key, i = i, spell = ok and mana > 0}
				elseif not okk then E.once("hud_entry_" .. i, "HUD: ability " .. i .. " of CA's list unreadable: " .. tostring(key)) end
			end
		end)
		-- no context, or CA's list holds none of what he owns: the owned list
		if not indexed then list_n = nil end
		if #entries == 0 then
			for _, k in ipairs(owned) do entries[#entries + 1] = {key = k} end
		end
		local listed, kinds = {}, {{}, {}}
		for _, e in ipairs(entries) do listed[e.key] = true end
		for _, e in ipairs(entries) do
			local base = e.key:match("^(.+)_upgraded$")
			if not (base and listed[base]) then
				-- only a spell overcasts: an ability's skill upgrade has the same suffix (data.lua overcasts)
				local over = e.spell or E.D.overcasts and E.D.overcasts[e.key] ~= nil
				e.up = over and has[e.key .. "_upgraded"] and e.key .. "_upgraded" or nil
				table.insert(kinds[e.spell and 2 or 1], e)
			end
		end
		kinds[3], army_n = army_entries()
		pages = {}
		for k, name in ipairs({"Abilities", "Spells", "Army abilities"}) do
			for p = 1, math.ceil(#kinds[k] / L.slots) do
				local slots = {}
				for j = (p - 1) * L.slots + 1, math.min(p * L.slots, #kinds[k]) do slots[#slots + 1] = kinds[k][j] end
				pages[#pages + 1] = {name = p == 1 and name or name .. " " .. p, slots = slots}
			end
		end
		caster = #kinds[2] > 0
		return indexed, why
	end

	-- a caster's tall plate and winds rows, a non-caster's short plate; again after a rebuild, which can make him either
	local function show_caster()
		if off then return end
		vis("plate_left", caster) vis("plate_left_short", not caster)
		if not dead.winds then for _, id in ipairs(GROUPS.winds) do vis(id, caster) end end
	end

	-- hotbar slot n's ability, a field of its live record: his unit's own at its place in his context's list, his army's
	-- on CA's button for it (army_entries). Throws when the slot has none or the context gave nothing, so a caller can
	-- fall back
	local function ability_at(n)
		local i = on_page[n] and on_page[n].i
		if not i or not cco_id then error("no context for ability slot " .. n) end
		return "BattleAbilityList.At(" .. i .. ")."
	end
	local function read(n, field)
		local e = on_page[n]
		if not (e and e.army) then return cco(ability_at(n) .. field) end
		local p = army_parent()
		local b = p and find_uicomponent(p, "button_ability_" .. e.key)
		local c = b and b:GetContextObject("CcoBattleAbility")
		local val = c and c:Call(field)
		if val == nil then error("CA's army ability button gave nothing for " .. e.key .. " " .. field) end
		return val
	end
	-- a slot read now: his unit's with a place in his context's list, an army's always (CA's button, not his context)
	local function live(n) return on_page[n] ~= nil and (on_page[n].i ~= nil or on_page[n].army == true) end

	-- the shown page into the slots: each one's key, place in CA's list, icon and key label
	local function show_page(indexed, why)
		keys, on_page = {}, pages[page] and pages[page].slots or {}
		for n, e in ipairs(on_page) do keys[n] = e.key end
		if off then return end
		for n = 1, L.slots do
			local on = keys[n] ~= nil
			for _, s in ipairs({"frame", "icon", "keyplate", "key", "cool"}) do vis("slot_" .. n .. "_" .. s, on) end
			for _, s in ipairs({"dim", "coolplate", "armed", "over", "active_l", "active_r", "windup_l", "windup_r", "usesplate",
				"uses", "manaplate", "mana"}) do
				vis("slot_" .. n .. "_" .. s, false)
			end
			cooling[n], able[n] = nil, nil
			if on then text("slot_" .. n .. "_key", E.S.names["ability_" .. n] or "") end
			text("slot_" .. n .. "_cool", "") -- the page before's seconds; this page's come at the next read
		end
		-- the tab names the page its key goes to next, the key in brackets (the author, 2026-10-20: mockup A, "(T)");
		-- none with one page, or with the key unbound
		local tab = #pages > 1 and E.S.names.page
		vis("tab_plate", tab ~= nil and tab ~= false) vis("tab", tab ~= nil and tab ~= false)
		tab_text = tab and "(" .. tab .. ") " .. H.page_name(1) or nil
		if tab then text("tab", tab_text) end
		guard("slots", function()
			-- an army's page is read off CA's buttons: no context of his is wanted for it
			if not indexed and not (on_page[1] and on_page[1].army) then error(why, 0) end
			for n in ipairs(on_page) do
				if live(n) then img("slot_" .. n .. "_icon", read(n, "SetupAbilityContext.IconPath")) end
			end
		end)
	end

	function H.key(n) return keys[n] end
	function H.upgraded(n) local e = pages[page] and pages[page].slots[n] return e and e.up end
	-- the shown page's name (offset 0) or the next one's (1); nil with no abilities
	function H.page_name(offset) return #pages > 0 and pages[(page - 1 + offset) % #pages + 1].name or nil end
	-- the next page, round to the first; false with one page
	function H.next_page()
		if #pages < 2 then return false end
		page = page % #pages + 1
		show_page(list_n ~= nil, "no unit context for this unit")
		H.place()
		return true
	end

	-- the unit at the start of a session: its card's context, its portrait, and the bar's first page. The context and
	-- the slots' places in it are read even with the HUD off: abilities.lua casts through them
	function H.unit()
		local card = find_uicomponent(core:get_ui_root(), "cards_panel", tostring(F.unit:unique_ui_id()))
		cco_id = card and card:GetContextObjectId("CcoBattleUnit") or nil
		page = 1
		if F.armed then E.abilities.cancel() end -- the pages are built again below: page 1, other slots
		local indexed, why = build()
		show_page(indexed, why)
		if off then return end
		for _, id in ipairs(GROUPS.hidden) do vis(id, false) end -- till the first read says so
		show_caster()
		guard("portrait", function()
			img("portrait", cco("IconPath"))
			text("name", cco("Name"))
			vis("portrait", true) vis("name", true)
		end)
		-- the action buttons: walk and sprint always, attack but for a gun, fire for a shooter, artillery too (its click
		-- fires the gun), jump when his men have the clips; each with its key
		local can = {walk = true, sprint = true, attack = not F.arty, fire = F.unit:missile_range() > 0
			and not F.cannot_shoot, jump = F.can_jump, fly = F.unit:can_fly(), cheer = F.can_cheer}
		local key_of = {walk = "walk", sprint = "sprint", attack = "attack", fire = "attack", jump = "jump", fly = "fly",
			cheer = "cheer"}
		acts, act_at = {}, {}
		for _, a in ipairs(L.actions) do
			if can[a] then acts[#acts + 1] = a act_at[a] = #acts end
			for _, s in ipairs({"frame", "icon", "keyplate", "key"}) do vis("act_" .. a .. "_" .. s, can[a] == true) end
			for _, s in ipairs({"dim", "coolplate", "cool", "active_l", "active_r"}) do vis("act_" .. a .. "_" .. s, false) end
			if can[a] then text("act_" .. a .. "_key", E.S.names[key_of[a]] or "") end
		end
		-- hide and the minimap in their own corner
		for _, s in ipairs({"frame", "icon", "keyplate", "key"}) do vis("hide_" .. s, true) vis("map_" .. s, true) end
		text("hide_key", E.S.names.hide_ui or "")
		text("map_key", E.S.names.minimap or "")
	end

	-- hotbar slot n's ability: a field of its record, or a command run on it in the unit's context (none for an army's).
	-- Both throw when the slot has no matched ability or the context gave nothing, so a caller can fall back
	function H.ability(n, field) return read(n, "SetupAbilityContext." .. field) end
	-- on the battle ability itself: PerformAbilityForOwner on its SetupAbilityContext does nothing (measured 2026-10-14)
	function H.ability_command(n, fn) common.call_context_command("CcoBattleUnit", cco_id, ability_at(n) .. fn) end
	-- slot n's ability is recharging; no context, no answer: false (-1 is no cooldown, measured)
	function H.cooling(n)
		local ok, secs = pcall(read, n, "RechargeTimeRemainingSecs")
		return ok and secs > 0
	end
	-- slot n holds his army's ability (abilities.lua casts it through his army)
	function H.army(n) return on_page[n] ~= nil and on_page[n].army == true end
	-- slot n's ability can go off now: his unit's by the engine's own test, his army's by CA's button's (CanCurrentlyPerform,
	-- false through its recharge too)
	function H.can(n)
		local e = on_page[n]
		if not e then return false end
		if not e.army then return F.unit:can_perform_special_ability(e.key) end
		local ok, can = pcall(read, n, "CanCurrentlyPerform")
		return ok and can == true
	end

	-- the armed ability (abilities.lua): its slot shows CA's selected ring; nil clears every slot
	function H.armed(n) for k = 1, L.slots do vis("slot_" .. k .. "_armed", k == n) end end
	-- an armed spell overcast: CA's glow over its slot (hud_battle.twui.xml overcast_effect); off, every slot's
	function H.overcast(n, on) for k = 1, L.slots do vis("slot_" .. k .. "_over", on == true and k == n) end end
	-- why the overcast cannot go off, as CA's bar says it: the slot's invalid overlay and a line in the target label, for
	-- HINT_SECS (the author, 2026-10-20: "should show UI hints as possible as the CA Vanilla design"); c: the overcast's
	-- winds when they are the reason, previewed on the winds bar as long as the line shows
	function H.refuse(n, why, c)
		hint = {n = n, why = why, till = clock() + HINT_SECS, cost = c}
		cco_at = 0
		vis("slot_" .. n .. "_dim", true)
		H.target(why)
	end
	-- the winds an armed spell would spend, previewed on the winds bar (CA's SpellPreviewRemainingMana); nil, none
	function H.cost(c)
		cost = c and c > 0 and c or nil
		cco_at = 0 -- shown at the next frame, not the next read
	end
	-- slot n's winds cost (CcoBattleAbility.ManaUsed), 0 without one; the army's winds now, nil without a context
	function H.mana(n)
		local ok, c = pcall(read, n, "ManaUsed")
		return ok and type(c) == "number" and c or 0
	end
	function H.winds()
		local ok, w = pcall(cco, "ArmyContext.WindsOfMagicPoolContext.CurrentWind")
		if ok and type(w) == "number" then return w end
		-- no context on his card: his army's own figure (CA's battle_army doc)
		ok, w = pcall(function() return F.unit:army():winds_of_magic_current() end)
		return ok and type(w) == "number" and w or nil
	end
	-- the label under the crosshair naming what an armed ability would hit; nil hides it
	function H.target(s)
		if s == nil then hint = nil -- disarmed: no refusal left to tell
		elseif hint and clock() < hint.till then s = hint.why end
		vis("target_plate", s ~= nil) vis("target", s ~= nil)
		if s then text("target", s) end
	end
	-- a world point in screen px, by CA's WorldSpaceToScreenSpace: x, y, z, z first and nil with no answer. 0 < z < 1 is
	-- in front of the camera, anything else projects to nonsense (measured 2026-10-14 against a screenshot)
	local function cm2(n) return math.floor(n * 100 + 0.5) / 100 end
	local function w2s(x, y, z)
		local at = "WorldSpaceToScreenSpace(ToVector4(" .. cm2(x) .. "," .. cm2(y) .. "," .. cm2(z) .. ",1), false, false)."
		local sz = common.get_context_value(at .. "z")
		if sz == nil then return nil end
		return common.get_context_value(at .. "x"), common.get_context_value(at .. "y"), sz
	end
	-- the arrow over the unit an armed ability would hit, tip on his position lifted L.arrow_lift m; nil hides it
	function H.mark(u)
		guard("mark", function()
			local c = part("target_arrow")
			if not u or not c then vis("target_arrow", false) return end
			local p = u:position()
			local sx, sy, z = w2s(p:get_x(), p:get_y() + L.arrow_lift, p:get_z())
			if z == nil then error("the engine gave no projection") end
			local front = z > 0 and z < 1
			vis("target_arrow", front)
			if not front then return end
			local s = H.s or 1
			local x = math.floor(sx - L.size.target_arrow[1] * s / 2)
			local y = math.floor(sy - L.size.target_arrow[2] * s)
			put(c, "target_arrow.at", x * 10000 + y, function() c:MoveTo(x, y) end)
		end)
	end
	-- any unit's display name, from its own context (measured 2026-10-14: enemies answer by their ui id too)
	function H.unit_name(u)
		local ok, name = pcall(common.get_context_value, "CcoBattleUnit", tostring(u:unique_ui_id()), "Name")
		return ok and name or u:type()
	end

	-- CA's minimap (the author, 2026-10-16: "pressing M should show mini map"). The cinematic UI hides CA's whole HUD, its
	-- radar with it, and not this panel (measured 2026-10-14): the radar moves into the panel while shown, and back into
	-- its holder, first, where it was. Answers whether it shows. ponytail: whether the radar draws in its new parent is
	-- unmeasured in game; the log says what was done
	local function map(on)
		if on == (home ~= nil) then return on end
		if not on then
			local r = ui and find_uicomponent(ui, "radar_group")
			if r then home[1]:Adopt(r:Address(), 0) r:MoveTo(home[2], home[3]) end
			home = nil
			return false
		end
		if off or not ui then return false end
		local holder = find_uicomponent(core:get_ui_root(), "hud_battle", "radar_holder")
		local r = holder and find_uicomponent(holder, "radar_group")
		if not r then E.once("map", "no minimap in this battle's interface") return false end
		local x, y = r:Position()
		home = {holder, x, y}
		ui:Adopt(r:Address())
		H.place()
		E.log("minimap at " .. table.concat({r:Position()}, ",") .. ", " .. table.concat({r:Dimensions()}, "x"))
		return true
	end
	function H.map(on)
		local ok, res = pcall(map, on)
		if ok then return res end
		E.once("map_failed", "the minimap is off: " .. tostring(res))
		return false
	end

	-- every unit in the battle, and whether it is an enemy
	local function each_unit(fn)
		for _, side in ipairs({{bm:get_player_alliance(), false}, {bm:get_non_player_alliance(), true}}) do
			local armies = side[1]:armies()
			for a = 1, armies:count() do
				local units = armies:item(a):units()
				for i = 1, units:count() do fn(units:item(i), side[2]) end
			end
		end
	end

	-- a health bar over every other unit, in its side's colour (players, 2026-10-19: "a health bar each unit and a ally or
	-- enemy highlight"). The engine pins, fills, colours and hides each one (ui/derpy_tp/bar_*: CA's own callbacks, and
	-- none while the player cannot see the unit); here one is made per unit at the lift over his men, and the played
	-- unit's (the panel shows his) and a dead unit's are hidden. A few made a refresh, then kept for the battle
	local BARS_EVERY, BARS_MADE = 0.5, 8
	local pins, bars_at = {}, 0
	local function lift(u)
		local body = E.D.bodies and E.D.bodies[u:type()]
		local want = (body and body[2] or 1.8) + L.bar.clear
		for n, m in ipairs(L.bar.lifts) do if m >= want then return n end end
		return #L.bar.lifts
	end

	-- CA's tracker chevrons under the men of every unit the player does not command (unitcontroller:highlight; measured
	-- 2026-10-19: red under an enemy, green under ours, kept after release_control, each back to its own control and
	-- moving), an enemy only while the player can see it, and only while F.guide (the guide key, main.lua). None under
	-- his own, but the one an armed ability would hit (a player, 2026-10-22: "maybe show the outline of the targeted
	-- unit"; no script call draws an outline, and the author ruled his own in that day)
	local marked = {} -- unique_ui_id -> {uc, on}
	local function mark(u, on)
		local m = marked[u:unique_ui_id()]
		if (m and m.on or false) == on then return end
		if not m then m = {uc = create_unitcontroller(u)} marked[u:unique_ui_id()] = m end
		m.on = on
		m.uc:highlight(on)
		m.uc:release_control()
	end
	local function unmark() for _, m in pairs(marked) do if m.on then m.on = false m.uc:highlight(false) m.uc:release_control() end end end

	local guide_was, target_was, aimed_was, pick_was = false, nil, nil, nil
	local function bars(now)
		-- the guide key, the lock-on, an armed ability's target and a command mode pick answer at once, not at the next
		-- refresh; the locked enemy, the target and the picked units are marked with the guide off too (combat.lua
		-- C.target, abilities.lua A.update, command.lua). CA's banners change with the guide key, or with the interface
		-- hidden, and H.show starts the refresh over
		local target = F.target and F.target:unique_ui_id()
		local aimed = F.armed and F.armed.unit and F.armed.unit:unique_ui_id()
		local picked, pick = F.command and F.command.picked or {}, F.command and F.command.v
		if now < bars_at and (F.guide or false) == guide_was and target == target_was and aimed == aimed_was
			and pick == pick_was then return end
		bars_at, guide_was, target_was, aimed_was, pick_was = now + BARS_EVERY, F.guide or false, target, aimed, pick
		local holder = E.S.bars and part("bars")
		if E.S.bars and not holder then error("no unit bar holder in the panel") end
		local made, seen = 0, {}
		-- near the unit he plays (the author, 2026-10-19: "currently is clogging the scene ... by default only near the
		-- character"), always or with the markers key (MCT); 1000 m is every unit on the field. None while CA's banners
		-- show (main.lua banners): they carry a health bar of their own
		local show = (E.S.bars == "always" or E.S.bars == "guide" and guide_was) and not F.banners
		local mx, mz
		if F.model then local x, _, z = E.P.model_pos(F.model) mx, mz = x, z else local q = F.unit:position() mx, mz = q:get_x(), q:get_z() end
		local reach = E.S.bars_range >= 1000 and math.huge or E.S.bars_range * E.S.bars_range
		each_unit(function(u, enemy)
			local alive = u:number_of_men_alive() > 0
			local uid = u:unique_ui_id()
			-- a unit of his never marked makes no controller here (mark answers an unchanged state first)
			mark(u, (uid == aimed or picked[uid] or not u:is_player_controlled() and (guide_was or uid == target)) and alive
				and (not enemy or u:is_valid_target()))
			if not holder then return end
			local id = tostring(u:unique_ui_id())
			seen[id] = true
			local pin = pins[id]
			if not pin and made < BARS_MADE then
				made = made + 1
				local file = L.bar.file .. lift(u)
				local c = holder:CreateComponent("derpy_tp_bar_" .. id, file)
				if not c then error("the unit bar's layout did not load: " .. file) end
				pin = UIComponent(c)
				pin:SetContextObject(context("CcoBattleUnit", id))
				pins[id] = pin
			end
			if pin then
				local p = u:position()
				local near = (p:get_x() - mx) ^ 2 + (p:get_z() - mz) ^ 2 <= reach
				put(pin, "bar." .. id, show and near and u ~= F.unit and alive, function(c, b) c:SetVisible(b) end)
			end
		end)
		-- a unit gone from its army's list (a summoning that ended) keeps no bar where it was
		for id, pin in pairs(pins) do if not seen[id] then put(pin, "bar." .. id, false, function(c, b) c:SetVisible(b) end) end end
	end

	-- a bar over every man of each regiment near him (a player, 2026-10-29: "kill count and Healthbar to all entity"),
	-- beside its unit's own; a lord, hero or monster alone has that one already. No context holds a man's health
	-- (CcoBattleEntity: IsAlive, Position, reload only), so his hit points are read off him as the man played is
	-- (P.model_hp), and he is put on screen through this frame's view - rig's eye and look point, after the camera moved
	-- (main.lua) - by a pinhole whose centre and scale CA's own projection gives (w2s of three points CAL_D m out, CAL_A m
	-- apart, while the view holds still, as CA projects through the view it is drawing). Each bar wears its unit's context:
	-- the engine colours it by side and hides it while the player cannot see the unit (ui/derpy_tp/man_bar). MEN_MAX at
	-- most, the nearest units first; MEN_MADE made a frame at most, each kept for its man's place in his unit's list.
	-- ponytail: a man's place in that list moves as men die, so a bar can change men; it reads the new man's health
	local MEN_MAX, MEN_MADE, CAL_EVERY, NEAR, CAL_D, CAL_A = 160, 24, 1, 0.5, 20, 4
	local men_pool, men_on, cal, cal_at, view_was = {}, {}, nil, -1e9, nil
	local function view()
		local R = E.rig
		if not (R.ex and R.lx) then return nil end
		local fx, fy, fz = R.lx - R.ex, R.ly - R.ey, R.lz - R.ez
		local n, flat = math.sqrt(fx * fx + fy * fy + fz * fz), math.sqrt(fx * fx + fz * fz)
		if n < 1e-6 or flat < 1e-6 then return nil end
		fx, fy, fz = fx / n, fy / n, fz / n
		local rx, rz = fz * n / flat, -fx * n / flat -- level, to his right (rig.lua's shoulder)
		return {x = R.ex, y = R.ey, z = R.ez, fx = fx, fy = fy, fz = fz, rx = rx, rz = rz,
			ux = fy * rz, uy = fz * rx - fx * rz, uz = -fy * rx}
	end
	local function still(V, W)
		return W ~= nil and (V.x - W.x) ^ 2 + (V.y - W.y) ^ 2 + (V.z - W.z) ^ 2 < 1e-4
			and V.fx * W.fx + V.fy * W.fy + V.fz * W.fz > 0.999999
	end
	local function calibrate(V)
		local px, py, pz = V.x + V.fx * CAL_D, V.y + V.fy * CAL_D, V.z + V.fz * CAL_D
		local cx, cy, cz = w2s(px, py, pz)
		local x1 = w2s(px + V.rx * CAL_A, py, pz + V.rz * CAL_A)
		local _, y2 = w2s(px + V.ux * CAL_A, py + V.uy * CAL_A, pz + V.uz * CAL_A)
		if not (cx and cy and x1 and y2) or cz <= 0 or cz >= 1 then return end
		local kx, ky = (x1 - cx) * CAL_D / CAL_A, (y2 - cy) * CAL_D / CAL_A
		-- square pixels both ways, or one of the three went through another view
		if math.abs(kx) < 100 or ky == 0 or math.abs(math.abs(kx / ky) - 1) > 0.05 then return end
		cal = {cx = cx, cy = cy, kx = kx, ky = ky}
	end
	local function project(V, x, y, z)
		local dx, dy, dz = x - V.x, y - V.y, z - V.z
		local d = dx * V.fx + dy * V.fy + dz * V.fz
		if d < NEAR then return nil end
		return cal.cx + cal.kx * (dx * V.rx + dz * V.rz) / d, cal.cy + cal.ky * (dx * V.ux + dy * V.uy + dz * V.uz) / d
	end
	local function new_bar(holder, uid, k)
		local made = holder:CreateComponent("derpy_tp_man_" .. uid .. "_" .. k, L.man.file)
		if not made then error("the man bar's layout did not load: " .. L.man.file) end
		local c = UIComponent(made)
		c:SetContextObject(context("CcoBattleUnit", uid))
		local fill = find_uicomponent(c, "fill")
		if fill then fill:SetCanResizeWidth(true) fill:SetCanResizeHeight(true) end
		c:SetVisible(false)
		return {c = c, fill = fill}
	end
	local function place(b, sx, sy, frac)
		local w, h = L.man.size[1], L.man.size[2]
		local x, y = math.floor(sx - w / 2 + 0.5), math.floor(sy - h + 0.5)
		if b.x ~= x or b.y ~= y then b.x, b.y = x, y b.c:MoveTo(x, y) end
		local fw = math.max(1, math.floor(w * math.max(0, math.min(1, frac)) + 0.5))
		if b.fill and b.w ~= fw then b.w = fw b.fill:Resize(fw, h) end
		if not men_on[b] then men_on[b] = true b.c:SetVisible(true) end
	end
	function H.men()
		guard("men_bars", function()
			local holder, V, now = part("men_bars"), view(), os.clock()
			if V and still(V, view_was) and now - cal_at >= CAL_EVERY then cal_at = now calibrate(V) end
			view_was = V
			local S, shown = E.S, {}
			if holder and V and cal and S.man_bars and (S.bars == "always" or S.bars == "guide" and guide_was) and not F.banners
				and E.P.features.men then
				local sw, sh = core:get_screen_resolution()
				local w, h = L.man.size[1], L.man.size[2]
				local mx, mz
				if F.model then local x, _, z = E.P.model_pos(F.model) mx, mz = x, z else local q = F.unit:position() mx, mz = q:get_x(), q:get_z() end
				local reach = S.bars_range >= 1000 and math.huge or S.bars_range * S.bars_range
				-- a unit's men stand around its centre: one whose centre is past the distance by a deep block may still have
				-- men inside it
				local pre = reach == math.huge and reach or (S.bars_range + 30) ^ 2
				local mine, units = F.unit:unique_ui_id(), {}
				each_unit(function(u)
					if u:unique_ui_id() == mine or u:initial_number_of_men() < 2 or u:number_of_men_alive() < 1 then return end
					local p = u:position()
					local d = (p:get_x() - mx) ^ 2 + (p:get_z() - mz) ^ 2
					if d <= pre then units[#units + 1] = {u = u, d = d} end
				end)
				table.sort(units, function(a, b) return a.d < b.d end)
				local made, n = 0, 0
				for _, e in ipairs(units) do
					local u = e.u
					local ms = E.P.models(u)
					-- the count the man check asks for (platform.lua P.check_men): a list that reads otherwise is not read
					if #ms == u:number_of_men_alive() then
						local uid = tostring(u:unique_ui_id())
						local pool = men_pool[uid] or {}
						men_pool[uid] = pool
						local body = E.D.bodies and E.D.bodies[u:type()]
						local up = (body and body[2] or 1.8) + L.man.lift
						for k, m in ipairs(ms) do
							if n >= MEN_MAX then break end
							local x, y, z = E.P.model_pos(m)
							if (x - mx) ^ 2 + (z - mz) ^ 2 <= reach then
								local cur, max = E.P.model_hp(m)
								local sx, sy = project(V, x, y + up, z)
								if sx and max > 0 and cur > 0 and sx > -w and sx < sw + w and sy > 0 and sy < sh + h then
									local b = pool[k]
									if not b and made < MEN_MADE then made = made + 1 b = new_bar(holder, uid, k) pool[k] = b end
									if b then n = n + 1 shown[b] = true place(b, sx, sy, cur / max) end
								end
							end
						end
					end
					if n >= MEN_MAX then break end
				end
			end
			for b in pairs(men_on) do if not shown[b] then men_on[b] = nil b.c:SetVisible(false) end end
		end)
	end

	function H.show(on)
		-- a session starts whole: three part errors turned it off until the battle ended (a player, 2026-10-19: "the HUD
		-- stayed off for the rest of the match", after a transformation)
		if on then off, errors = false, 0 end
		if not on then pcall(unmark) H.back(false) end
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
				H.unit() -- no panel, but this unit's abilities still need its context
				return
			end
			ui = UIComponent(made)
			for id in pairs(L.fill) do
				local c = part(id)
				if c then c:SetCanResizeWidth(true) c:SetCanResizeHeight(true) end
			end
		end
		last, dead, cco_at, bars_at = {}, {}, 0, 0
		ui:SetVisible(true)
		vis("bars", E.S.bars ~= false)
		vis("men_bars", E.S.bars ~= false and E.S.man_bars == true)
		H.target(nil) H.mark(nil)
		H.back(E.command ~= nil and E.command.vanilla()) -- before the parts it sets aside are shown
		H.unit() -- then: the bar centres on how many abilities he has
		H.place()
	end

	-- the way back out of command mode's Vanilla style, its key beside it (the author, 2026-10-23: "theres also no buttons
	-- or custom hud to be found for the unit and to switch back to 3rd person mode"). The plate takes the freed cursor's
	-- click (the listener below); the parked cursor sits at the screen's centre, never on it
	function H.back(on)
		local was = away
		away = on and AWAY or {}
		-- set aside, or given back as each was last asked to show (the final review: not by drawing the HUD over). A part
		-- no update asks about (the health and stamina bars, which are only sized) is given back as it stood: given back
		-- hidden, it stayed so (the author, 2026-10-24: "healthbar is gone")
		if on or was == AWAY then
			for id in pairs(AWAY) do
				local c = asked[id] == nil and part(id)
				if c then asked[id] = c:Visible() end
				vis(id, asked[id])
			end
		end
		for _, id in ipairs(BACK) do vis(id, on) end
		-- hidden, it takes no click either: a hidden interactive component is a dead zone where it last stood, over CA's
		-- cards once the mode is left (the final review, 2026-10-23; seen live at y 755 of 900)
		put(part("back_plate"), "back_plate.click", on == true, function(c, x) c:SetInteractive(x) end)
		if on then text("back", "Back to third person") text("back_key", E.S.names.command or "") end
	end
	-- CA runs a listener unguarded in the released game (lib_core.lua event_unprotected_callback): the click only asks,
	-- and the tick leaves the mode inside its guard (main.lua)
	core:add_listener("derpy_tp_back", "ComponentLClickUp", function(ctx) return ctx.string == "back_plate" end,
		function() if F.command then F.back_click = true end end, true)

	-- one man played: his own hit points (the author, 2026-10-15: "should be health of the individual unit not the whole
	-- battalion"); nil when played whole, or when what the model holds is not a health
	local function own_hp()
		if not F.model then return nil end
		local cur, max = E.P.model_hp(F.model)
		if max > 0 and cur >= 0 and cur <= max then return cur, max end
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

	local card_try = 0
	function H.update(now)
		-- taken over before his unit card was there (F2 on a new form in the gap of a transformation): no context, so the
		-- portrait and slots went off; the card is looked for again, and the HUD starts over whole when it comes
		if not cco_id and ui and now - card_try >= CCO_EVERY then
			card_try = now
			local card = find_uicomponent(core:get_ui_root(), "cards_panel", tostring(F.unit:unique_ui_id()))
			if card and card:GetContextObjectId("CcoBattleUnit") then H.show(true) end
		end
		if off or not ui then return end
		-- CA's band moves under the panel: placed once at Q, as the mode turned CA's interface on, it stood where third person
		-- puts it, on CA's unit cards (the author's picture, 2026-10-23: "even conflicting ui"). Read again every CCO_EVERY
		-- real s: the mode's quarter speed stretches model time four times, and its pause stops it
		if E.command and E.command.vanilla() and os.clock() >= band_at then
			band_at = os.clock() + CCO_EVERY
			local _, sh = core:get_screen_resolution()
			local floor, top = band(sh, L.margin * scale())
			if floor ~= placed[1] or top ~= placed[2] then H.place() end
		end
		local u = F.unit
		guard("bars", bars, now)
		guard("health", function()
			local cur, max = own_hp()
			width("health_fill", cur and cur / max or u:unary_hitpoints())
		end)
		guard("men", function()
			local n0 = u:initial_number_of_men()
			vis("men", n0 > 1) vis("men_icon", n0 > 1)
			if n0 > 1 then text("men", u:number_of_men_alive() .. " / " .. n0) end
		end)
		guard("stamina", function()
			width("stamina_fill", F.stamina)
			text("stamina", math.floor(F.stamina * 100 + 0.5) .. "%")
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
				-- recharging too: can_perform_special_ability stays true through a cooldown (measured 2026-10-21), and CA's
				-- button greys out through it. An army's: what CA's button said at the last read
				local can = on_page[n].army and able[n] or not on_page[n].army and u:can_perform_special_ability(keys[n])
				vis("slot_" .. n .. "_dim", not can or cooling[n] or hint ~= nil and hint.n == n and now < hint.till)
			end
		end)
		if now >= cco_at then
			cco_at = now + CCO_EVERY
			-- an ability granted or spent mid-battle, his or his army's: the pages again, on the page of the same name if it
			-- is still there
			local okn, n = pcall(cco, "BattleAbilityList.Size")
			local p = army_parent()
			if okn and list_n and n ~= list_n or (p and p:ChildCount() or 0) ~= army_n then
				if F.armed then E.abilities.cancel() end -- an armed slot may hold another ability after (the final review)
				local name = H.page_name(0)
				local indexed, why = build()
				page = 1
				for k, pg in ipairs(pages) do if pg.name == name then page = k end end
				show_page(indexed, why)
				show_caster()
				H.place()
			end
			guard("slots", function()
				-- CA's timer ring states: winding up (the cast before it takes effect; -1 when not) the plain ring, running
				-- the green one, each with its seconds left; then the cooldown's seconds
				for n in ipairs(on_page) do if live(n) then
					local function at(field) return read(n, field) end
					local windup = at("WindUpTimeRemainingSecs")
					local winding = windup > 0
					local active = at("IsActive") == true -- false through a wind-up (measured)
					local secs = winding and windup or at(active and "ActiveTimeRemainingSecs" or "RechargeTimeRemainingSecs")
					text("slot_" .. n .. "_cool", secs > 0 and tostring(math.ceil(secs)) or "")
					vis("slot_" .. n .. "_coolplate", secs > 0)
					cooling[n] = secs > 0 and not active and not winding
					if on_page[n].army then able[n] = at("CanCurrentlyPerform") == true end
					-- its uses left, of an ability that has a count (RemainingUses, -1 without one)
					local okl, limited = pcall(at, "HasLimitedUses")
					local left = okl and limited == true and at("RemainingUses")
					text("slot_" .. n .. "_uses", left and tostring(left) or "")
					vis("slot_" .. n .. "_uses", left ~= false) vis("slot_" .. n .. "_usesplate", left ~= false)
					-- a spell's winds (ManaUsed; CA shows them in its tooltip only), the overcast's while it is armed
					-- overcast (data.lua overcasts, as abilities.lua prices it); an ability that costs none shows nothing
					local mana, a = H.mana(n), F.armed
					local over = a and a.n == n and a.over and E.D.overcasts and E.D.overcasts[keys[n]]
					local winds = mana > 0 and (over or mana)
					text("slot_" .. n .. "_mana", winds and tostring(winds) or "")
					vis("slot_" .. n .. "_mana", winds ~= false) vis("slot_" .. n .. "_manaplate", winds ~= false)
					vis("slot_" .. n .. "_active_l", active) vis("slot_" .. n .. "_active_r", active)
					vis("slot_" .. n .. "_windup_l", winding) vis("slot_" .. n .. "_windup_r", winding)
				end end
			end)
			-- hidden (the 2026-10-20 design, Part 4: third person turns off CA's banners, which show it): unspottable is the
			-- unit's own trait and CA shows it always; hidden is his cover, the context's IsHidden or "hidden in tall
			-- grass/trees" (unit:is_hidden). Out of the enemy's sight is neither, and CA's banner shows it no more than this
			guard("hidden", function()
				local unspottable = cco("IsUnspottable") == true
				local hidden = unspottable or cco("IsHidden") == true or u:is_hidden()
				for _, id in ipairs(GROUPS.hidden) do vis(id, hidden) end
				if hidden then
					text("hidden", unspottable and "Unspottable" or "Hidden")
					img("hidden_icon", unspottable and L.art.unspottable or L.art.hidden)
				end
			end)
			-- the figures: his hit points, and a caster's army's winds (CcoBattleWindsOfMagicPool) with their bar
			guard("hp", function()
				local cur, max = own_hp()
				if not cur then cur, max = cco("HealthValue"), cco("HealthMax") end
				text("hp", math.floor(cur) .. " / " .. math.floor(max))
				vis("hp", true) vis("hp_icon", true)
			end)
			-- his morale (a player, 2026-10-29, in Russian: undead and daemons crumble "and it is not noticed at once").
			-- MoralePercent on the bar, which runs past 1 at its best (measured 1.06-1.57 at deploy), so it reads full
			-- until he is hurt; the figure that percent, CA's own word for MoraleState 4 and 5, and from 6 "Crumbling": a
			-- unit that routs is let go at once (tick, "unit lost"), so one still played there is one that cannot rout.
			-- From 4 the fill is CA's shaken red. 4 shaken and 5 wavering is the order of CA's morale colours in ui_colours
			-- (impetuous, eager, confident, steady, shaken, wavering, broken, shattered)
			guard("morale", function()
				local p, st = cco("MoralePercent"), cco("MoraleState")
				width("morale_fill", p)
				width("morale_alarm", p)
				local word = st >= 6 and "Crumbling" or MORALE_WORDS[st] and common.get_localised_string(MORALE_WORDS[st])
				text("morale_text", word and word ~= "" and word or math.floor(math.min(p, 1) * 100 + 0.5) .. "%")
				for _, id in ipairs(GROUPS.morale) do vis(id, id ~= "morale_alarm" or st >= 4) end
			end)
			-- his unit's kills in this battle (a player, 2026-10-29: "add kill count"): CA's count for the unit, so for one
			-- man of a regiment it is the regiment's, as the men figure beside it is
			guard("kills", function()
				text("kills", tostring(u:number_of_enemies_killed()))
				vis("kills", true) vis("kills_icon", true)
			end)
			if caster then
				guard("winds", function()
					local p = "ArmyContext.WindsOfMagicPoolContext."
					local cur, max = cco(p .. "CurrentWind"), cco(p .. "MaxWind")
					text("winds", math.floor(cur) .. " / " .. math.floor(max))
					-- an armed spell: the fill is what the cast would leave, its cost shown up to the winds there are
					local c = math.min((hint and now < hint.till and hint.cost) or cost or 0, cur)
					width("winds_fill", max > 0 and (cur - c) / max or 0)
					vis("winds_cost", c > 0)
					if c > 0 then width("winds_cost", cur / max) end
				end)
			end
			if F.ranged and not F.solo then
				guard("reload", function() reload_cco = cco("ReloadPercentMax") / RELOAD_SCALE end)
			end
		end
		guard("reload", function() ring(reload_frac(now)) end)
		guard("actions", function()
			-- each action's cooldown seconds, dimmed as CA dims a button that cannot be used yet; still: it can, the
			-- seconds are another thing's
			local function show(a, secs, empty, still)
				if not act_at[a] then return end
				local p = "act_" .. a .. "_"
				local wait = secs ~= nil and secs > 0
				text(p .. "cool", wait and tostring(math.ceil(secs)) or "")
				vis(p .. "cool", wait) vis(p .. "coolplate", wait)
				vis(p .. "dim", empty or wait and not still)
			end
			show("attack", F.next_swing - now)
			-- a unit that cannot shoot swings on the mode key too (combat.lua swing): both named, "mouse" said once (the
			-- author, 2026-10-24: "no right button mention"); a shooter's is its mode, out of ammo it swings again
			if act_at.attack then
				local n = E.S.names
				local a, m = n.attack or "", n.mode or ""
				local both = (a:match("^(.-) mouse$") and m:match("^(.-) mouse$")) and a:gsub(" mouse$", "") .. " / "
					.. m:gsub(" mouse$", "") or a .. " / " .. m
				text("act_attack_key", E.can_shoot() and a or both)
			end
			show("jump", F.next_jump - now)
			-- the sprint: its charge attack's seconds; dim only with too little stamina to start one
			show("sprint", F.next_charge - now, not E.combat.can_sprint(), true)
			-- lit while on: the walk, the sprint, flight, the minimap (CA's green ring, as an ability's active time)
			local function lit(a, on) if act_at[a] then vis("act_" .. a .. "_active_l", on) vis("act_" .. a .. "_active_r", on) end end
			lit("walk", F.walking) lit("sprint", F.sprinting) lit("fly", u:is_currently_flying())
			-- flight's toggle: CA's own seconds and test (hud_battle.twui.xml button_toggle_flying)
			if act_at.fly then show("fly", H.value("ToggleFlyingCooldownTimer"), H.value("CanToggleFlying") == false) end
			vis("map_active_l", home ~= nil) vis("map_active_r", home ~= nil)
			local frac = reload_frac(now)
			local base = E.D.shots[F.utype] and E.D.shots[F.utype][2] * E.S.reload_factor
			local secs = frac and frac < 1 and (base and (1 - frac) * base or 0.5) or nil
			local empty = u:ammo_left() <= 0 -- out of ammo: dim, no seconds
			show("fire", not empty and secs or nil, empty)
		end)
	end

	return H
end
