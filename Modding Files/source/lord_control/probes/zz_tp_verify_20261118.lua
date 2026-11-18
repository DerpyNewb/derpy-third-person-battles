-- 2026-11-18 verification of the 11-12 to 11-18 Workshop reports (docs/sessions/THIRD_PERSON_BUGS_20261024.md, "Status on
-- 2026-11-18"): Skarbrand's Bellow of Endless Fury, Tyrion's missed attacks, a large lord stuck in a crowd, and the
-- ability bar beside Single Combat! (3831075966). Loaded after zz_tp_live_20261108.lua (_G.TPT) and
-- zz_tp_verify_20261112.lua (_G.TPV). No string library calls and no s:method(); every per-frame read is in a pcall.
local T, V = _G.TPT, _G.TPV
if not (T and V) then return "load TPT and TPV first" end
local E = T.E
local P, F = E.P, E.F
local W = _G.TPW or {}
_G.TPW = W

local function ms(t0) return math.floor((os.clock() - t0) * 1000) end

-- every line the pack logs, whatever its debug setting (E.log writes only with debug on)
function W.cap_start()
	W.lines, W.t0 = {}, os.clock()
	if not W.log0 then
		W.log0, W.once0 = E.log, E.once
		E.log = function(msg)
			local L = W.lines
			if L and #L < 3000 then L[#L + 1] = {ms(W.t0), tostring(msg)} end
			return W.log0(msg)
		end
		E.once = function(tag, msg)
			local L = W.lines
			if L and #L < 3000 and not E.logged[tag] then L[#L + 1] = {ms(W.t0), "once: " .. tostring(msg)} end
			return W.once0(tag, msg)
		end
	end
	return "capturing"
end
function W.cap(from)
	local out = {}
	for i = from or 1, #(W.lines or {}) do out[#out + 1] = W.lines[i] end
	return out
end
function W.cap_n() return #(W.lines or {}) end

-- the army's winds now
function W.winds()
	local a = bm:get_player_army()
	local ok, cur = pcall(function() return a:winds_of_magic_current() end)
	return ok and cur or "?"
end

-- the pack's own arming and click: what a number key and a left click call (main.lua 487 and 501)
function W.arm(n) return E.abilities.press(n, bm:time_elapsed_ms() / 1000) or "armed" end
function W.fire()
	if not F.armed then return "not armed" end
	E.abilities.fire()
	return "fired"
end
function W.armed()
	local a = F.armed
	if not a then return "none" end
	local label = "?"
	pcall(function() label = E.hud.label_text and E.hud.label_text() or "?" end)
	local target = nil
	if a.unit then target = a.unit:type() end
	return {key = a.key, kind = a.kind, range = a.range, unit = target, label = label}
end

-- every unit's men and, for a unit of one, its hit points
function W.hp()
	local out = {}
	local function one(u) local hp = "?" pcall(function() hp = u:unit_health() end) return {type = u:type(), men = u:number_of_men_alive(), hp = hp} end
	for k, e in ipairs(T.enemy or {}) do out[k] = one(e.u) end
	return out
end

-- n attack clicks gap_ms apart, through the stubbed keys (P.pressed sees the edge): per click, the swing cooldown left
-- when it was clicked, whether a clip was still locked, and whether F.swings moved by the next click
function W.clicks(n, gap_ms, action)
	W.cr = {done = false}
	local t0, k, next_at = os.clock(), 0, 0
	bm:repeat_real_callback(function()
		pcall(function()
			local el = ms(t0)
			if k < n and el >= next_at then
				if k > 0 then W.cr[k].swung = F.swings > W.cr[k].sw0 end
				k = k + 1
				next_at = next_at + gap_ms
				local now = os.clock()
				local L = F.lock
				local melee = false
				if F.unit then melee = F.unit:is_in_melee() == true end
				W.cr[k] = {t = el, cd = math.floor(((F.next_swing or 0) - now) * 100 + 0.5) / 100, lock = L ~= nil,
					lock_slot = L and L.slot or nil, lock_seen = L and L.seen or nil, sw0 = F.swings, melee = melee}
				T.tap(action or "attack", 120)
			elseif k >= n and el >= next_at then
				W.cr[k].swung = F.swings > W.cr[k].sw0
				W.cr.done = true
				bm:remove_real_callback("tpw_clicks")
			end
		end)
	end, 1, "tpw_clicks")
	return "clicking " .. n .. " every " .. gap_ms .. " ms"
end
function W.click_summary()
	local sent, refused_cd, refused_lock, other = 0, 0, 0, 0
	for i = 1, #W.cr do
		local c = W.cr[i]
		if c.swung then sent = sent + 1
		elseif c.cd > 0 then refused_cd = refused_cd + 1
		elseif c.lock then refused_lock = refused_lock + 1
		else other = other + 1 end
	end
	return {done = W.cr.done, clicks = #W.cr, swings = sent, in_cooldown = refused_cd, in_lock = refused_lock, neither = other}
end

-- where the played man is, and how far he went over a held direction: keys held for hold_ms, positions every 100 ms
function W.pos()
	local man = F.model or F.single
	if not man then return nil end
	local x, _, z = P.model_pos(man)
	return {x = x, z = z}
end
function W.walk(action, hold_ms)
	W.wk = {done = false, pos = {}, action = action}
	local t0 = os.clock()
	T.key(action, true)
	local nextp = 0
	bm:repeat_real_callback(function()
		pcall(function()
			local el = ms(t0)
			if el >= nextp then
				nextp = nextp + 100
				local p = W.pos()
				if p then W.wk.pos[#W.wk.pos + 1] = {el, p.x, p.z, F.unit:is_in_melee() == true} end
			end
			if el >= hold_ms then
				T.key(action, false)
				W.wk.done = true
				bm:remove_real_callback("tpw_walk")
			end
		end)
	end, 1, "tpw_walk")
	return "holding " .. action
end
function W.walk_summary()
	local p = W.wk.pos
	if #p < 2 then return {done = W.wk.done, n = #p} end
	local a, b = p[1], p[#p]
	local d = math.sqrt((b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
	local melee = 0
	for _, q in ipairs(p) do if q[4] then melee = melee + 1 end end
	return {done = W.wk.done, metres = math.floor(d * 10) / 10, secs = (b[1] - a[1]) / 1000,
		speed = math.floor(d / ((b[1] - a[1]) / 1000) * 100) / 100, in_melee_samples = melee, samples = #p}
end

-- CA's move order with third person off: unit i walks dist m back from its facing; returns where it was
function W.vanilla_back(i, dist)
	local u = T.unit(i)
	local q = u:position()
	local b = math.rad(u:bearing())
	local x, z = q:get_x() - math.sin(b) * dist, q:get_z() - math.cos(b) * dist
	local uc = bm:get_player_army():create_unit_controller()
	uc:add_units(u)
	uc:goto_location(v(x, bm:get_terrain_height(x, z), z), true)
	uc:release_control()
	W.vb = {x = q:get_x(), z = q:get_z(), t0 = os.clock()}
	return "ordered"
end
function W.moved(i)
	local q = T.unit(i):position()
	local d = math.sqrt((q:get_x() - W.vb.x) ^ 2 + (q:get_z() - W.vb.z) ^ 2)
	return {metres = math.floor(d * 10) / 10, secs = math.floor((os.clock() - W.vb.t0) * 10) / 10, in_melee = T.unit(i):is_in_melee() == true}
end

-- the enemy unit k: teleported onto unit i (a crowd round him) or dist m ahead
function W.enemy_onto(k, i, ahead)
	local c = T.unit(i)
	local q = c:position()
	local b = math.rad(c:bearing())
	local x, z = q:get_x() + math.sin(b) * (ahead or 0), q:get_z() + math.cos(b) * (ahead or 0)
	T.enemy[k].uc:teleport_to_location(v(x, bm:get_terrain_height(x, z), z), (c:bearing() + 180) % 360, 24)
	return T.enemy[k].u:type()
end

-- CA's army ability bar and what the pack's bar makes of it: every holder, shown or not, and the pack's pages
function W.army_bar()
	local out = {holders = {}, pack = {}}
	pcall(function()
		local p = find_uicomponent(core:get_ui_root(), "hud_battle", "army_ability_parent")
		if not p then out.holders = "no army_ability_parent" return end
		for i = 0, p:ChildCount() - 1 do
			local c = UIComponent(p:Find(i))
			out.holders[#out.holders + 1] = {id = c:Id(), visible = c:Visible() == true}
		end
	end)
	pcall(function() out.own = common.get_context_value("CcoBattleRoot", "", "PlayerArmyContext.ArmyAbilitiesList(false).Size") end)
	local ok, bar = pcall(V.bar)
	out.pack = ok and bar or tostring(bar)
	return out
end
return "TPW loaded"
