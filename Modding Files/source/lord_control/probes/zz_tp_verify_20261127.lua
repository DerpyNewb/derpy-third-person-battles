-- 2026-11-27 verification (docs/sessions/THIRD_PERSON_BUGS_20261024.md): the enemy ignoring the lord played with F2 at
-- the start of a battle (comments 11-26 10:41 and 12:08, and 11-22 16:04), and whether matched combat (sync kills) still
-- happens while a unit is played (comments 11-26 14:46 and 11-27 04:17). Loaded after zz_tp_live_20261108.lua (_G.TPT,
-- T.stub) and zz_tp_verify_20261125.lua (_G.TPY, Y.swing). No string library calls and no s:method(); every per-frame
-- read is in a pcall. Times are battle time.
--
-- Z.layout(): once, before the first arm. The lord 30 m ahead of his army's centre towards the enemy, my other units 35 m
--   behind him, the enemy 90 m ahead of him in a line. One kept controller per unit (a controller made inside a probe
--   call dies with it).
-- Z.ai{arm = "none" | "f2", secs = s}: every unit put back on its spot, healed, fearless, the enemy handed to the AI;
--   then each enemy unit's current_target() every 0.25 s for s seconds. f2: the lord is played (E.main.start), no key
--   held. Z.ai_read() afterwards.
-- Z.mc_start(me_type, k) / Z.mc_stop() / Z.mc_read(): every animation slot each man of my unit `me_type` and of the
--   held enemy unit T.enemy[k] enters, counted, with the slot each enemy man died in. Z.chance(me_type, c) sets the
--   unit's matched combat chance (c < 0: CA's default).
local T = _G.TPT
if not (T and T.E) then return "load TPT first" end
local E = T.E
local P, F = E.P, E.F
local Z = _G.TPZ or {}
_G.TPZ = Z

local function now() return bm:time_elapsed_ms() / 1000 end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
local function pos(u) local q = u:position() return q:get_x(), q:get_z() end
local function dist(a, b)
	local ax, az = pos(a)
	local bx, bz = pos(b)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

local function mine_of(ty)
	local us = bm:get_player_army():units()
	for i = 1, us:count() do
		local u = us:item(i)
		if u:type() == ty then return u end
	end
end

function Z.layout()
	local army = bm:get_player_army()
	local us = army:units()
	local L = {lord = nil, others = {}, enemy = {}}
	for i = 1, us:count() do
		local u = us:item(i)
		local c = army:create_unit_controller()
		c:add_units(u)
		local w = {u = u, uc = c, army = army}
		if u:is_commanding_unit() and not L.lord then L.lord = w else L.others[#L.others + 1] = w end
	end
	if not L.lord then return "no lord" end
	local ea = bm:get_non_player_alliance():armies()
	for a = 1, ea:count() do
		local ar = ea:item(a)
		local eu = ar:units()
		for i = 1, eu:count() do
			local u = eu:item(i)
			local c = ar:create_unit_controller()
			c:add_units(u)
			L.enemy[#L.enemy + 1] = {u = u, uc = c, army = ar}
		end
	end
	local function centre(list)
		local sx, sz = 0, 0
		for _, w in ipairs(list) do local x, z = pos(w.u) sx, sz = sx + x, sz + z end
		return sx / #list, sz / #list
	end
	local all = {L.lord}
	for _, w in ipairs(L.others) do all[#all + 1] = w end
	local mx, mz = centre(all)
	local ex, ez = centre(L.enemy)
	local d = math.sqrt((ex - mx) ^ 2 + (ez - mz) ^ 2)
	local fx, fz = (ex - mx) / d, (ez - mz) / d
	local face = math.deg(math.atan2(fx, fz))
	local lx, lz = mx + fx * 30, mz + fz * 30
	L.lord.spot = {lx, lz, face, 2}
	local function line(list, ahead, b)
		for k, w in ipairs(list) do
			local off = (k - (#list + 1) / 2) * 30
			w.spot = {lx + fx * ahead + fz * off, lz + fz * ahead - fx * off, b, 24}
		end
	end
	line(L.others, -35, face)
	line(L.enemy, 90, face + 180)
	L.lord_id = L.lord.u:unique_ui_id()
	Z.L = L
	return {lord = L.lord.u:type(), others = #L.others, enemy = #L.enemy, start_gap = r1(d)}
end

local function put(w, to_ai)
	local s = w.spot
	w.uc:take_control()
	w.uc:halt()
	w.uc:teleport_to_location(v(s[1], bm:get_terrain_height(s[1], s[2]), s[2]), s[3] % 360, s[4])
	w.uc:set_invincible(false)
	w.uc:morale_behavior_fearless()
	if to_ai ~= false then w.uc:release_control() end
end

local function each(f)
	local L = Z.L
	f(L.lord)
	for _, w in ipairs(L.others) do f(w) end
	for _, w in ipairs(L.enemy) do f(w) end
end

-- everyone back on their spot and healed; the enemy is kept halted until `go`
function Z.reset()
	local L = Z.L
	if not L then return "no layout" end
	if F.on then pcall(E.main.stop, "verify reset") end
	local errs = {}
	each(function(w)
		local ok, err = pcall(function()
			if not Z.no_heal then w.u:heal_hitpoints_unary(1, true) end
			put(w, false)
		end)
		if not ok then errs[#errs + 1] = tostring(err) end
	end)
	-- mine go back to the player at once
	pcall(function() L.lord.uc:release_control() end)
	for _, w in ipairs(L.others) do pcall(function() w.uc:release_control() end) end
	return #errs == 0 and "reset" or errs
end

function Z.ai(o)
	local L = Z.L
	if not L then return "no layout" end
	if Z.r and not Z.r.done then return "an arm is running" end
	local rec = {arm = o.arm, done = false, n = 0, counts = {}, first_lord = {}, first_any = {}, first_kind = {},
		at_first = {}, lord_melee = 0, lord_invalid = 0, lord_script = 0, lord_hidden = 0, others_melee = 0}
	Z.r = rec
	local res = Z.reset()
	rec.reset = res
	for k = 1, #L.enemy do rec.counts[k] = {lord = 0, other = 0, none = 0} end
	local t0, step = now(), "settle"
	local function finish(why)
		rec.why, rec.done = why, true
		if o.at_end then pcall(o.at_end) end
		if F.on then pcall(E.main.stop, "verify ai") end
		for _, w in ipairs(L.enemy) do pcall(function() w.uc:take_control() w.uc:halt() end) end
		pcall(function() rec.lord_hp = r1(L.lord.u:unary_hitpoints() * 100) end)
		-- a halted enemy in melee keeps fighting, and heal_hitpoints_unary does not raise a dead unit of one (2026-11-27)
		pcall(function() L.lord.uc:take_control() L.lord.uc:halt() L.lord.uc:set_invincible(true) L.lord.uc:release_control() end)
		for _, w in ipairs(L.others) do pcall(function() w.uc:take_control() w.uc:halt() w.uc:release_control() end) end
		pcall(function() rec.lord_hp = r1(L.lord.u:unary_hitpoints() * 100) end)
		pcall(function() bm:remove_real_callback("tpz_ai") end)
	end
	bm:repeat_real_callback(function()
		local ok, err = pcall(function()
			if rec.done then return end
			local t = now() - t0
			if t > (o.secs or 40) + 10 then finish("timeout") return end
			if step == "settle" and t >= 1 then
				if rec.arm == "f2" then
					local s_ok, s_err = pcall(E.main.start, L.lord.u)
					if not s_ok then rec.start_err = tostring(s_err) end
					rec.played = F.on and (F.model and "one entity" or F.single and "unit of one" or "regiment") or "off"
				end
				if o.at_go then local g_ok, g_err = pcall(o.at_go) if not g_ok then rec.go_err = tostring(g_err) end end
				for _, w in ipairs(L.enemy) do pcall(function() w.uc:release_control() end) end
				rec.go, step = t, "go"
			elseif step == "go" then
				local tt = t - rec.go
				if tt >= (o.secs or 40) then finish("time") return end
				rec.n = rec.n + 1
				for k, w in ipairs(L.enemy) do
					local tgt
					pcall(function() tgt = w.u:current_target() end)
					local c = "none"
					if tgt then
						local id
						pcall(function() id = tgt:unique_ui_id() end)
						c = (id == L.lord_id) and "lord" or "other"
					end
					rec.counts[k][c] = rec.counts[k][c] + 1
					if c == "lord" and not rec.first_lord[k] then rec.first_lord[k] = r1(tt) end
					if c ~= "none" and not rec.first_any[k] then
						rec.first_any[k], rec.first_kind[k] = r1(tt), c
						local dl = r1(dist(w.u, L.lord.u))
						local dn
						for _, m in ipairs(L.others) do local dd = dist(w.u, m.u) if not dn or dd < dn then dn = dd end end
						rec.at_first[k] = {lord_m = dl, other_m = dn and r1(dn) or nil}
					end
				end
				local lu = L.lord.u
				pcall(function() if lu:is_in_melee() then rec.lord_melee = rec.lord_melee + 1 end end)
				pcall(function() if not lu:is_valid_target() then rec.lord_invalid = rec.lord_invalid + 1 end end)
				pcall(function() if lu:is_script_controlled() then rec.lord_script = rec.lord_script + 1 end end)
				pcall(function() if lu:is_hidden() then rec.lord_hidden = rec.lord_hidden + 1 end end)
				for _, m in ipairs(L.others) do pcall(function() if m.u:is_in_melee() then rec.others_melee = rec.others_melee + 1 end end) end
				if F.on == false and rec.arm == "f2" and not rec.f2_lost then rec.f2_lost = r1(tt) end
			end
		end)
		if not ok then rec.err = tostring(err) finish("probe error") end
	end, 250, "tpz_ai")
	return "arm " .. tostring(o.arm) .. " running"
end

function Z.ai_read()
	local r = Z.r
	if not r then return "not run" end
	local out = {arm = r.arm, done = r.done, why = r.why, err = r.err, start_err = r.start_err, played = r.played, reset = r.reset,
		samples = r.n, lord_hp = r.lord_hp, lord_melee = r.lord_melee, lord_invalid = r.lord_invalid,
		lord_script = r.lord_script, lord_hidden = r.lord_hidden, others_melee = r.others_melee, f2_lost = r.f2_lost}
	local per = {}
	local tl, to, tn = 0, 0, 0
	for k, c in ipairs(r.counts) do
		local a = r.at_first[k]
		per[#per + 1] = k .. ":" .. Z.L.enemy[k].u:type() .. " lord " .. c.lord .. " other " .. c.other .. " none " .. c.none
			.. " first " .. tostring(r.first_kind[k]) .. "@" .. tostring(r.first_any[k]) .. " lord@" .. tostring(r.first_lord[k])
			.. (a and (" d_lord " .. a.lord_m .. " d_other " .. tostring(a.other_m)) or "")
		tl, to, tn = tl + c.lord, to + c.other, tn + c.none
	end
	out.per_enemy = per
	out.total = {lord = tl, other = to, none = tn}
	return out
end

-- Z.engage{mode = "ca" | "tp", k = enemy index, secs = s}: the lord put 12 m in front of enemy unit k, every other enemy
-- held on its spot, unit k left to the AI. ca: CA's attack order on unit k. tp: played, walking at the nearest man of k
-- and clicking every 1.5 s. Each 0.25 s: does unit k target the lord, is the lord in melee, his hit points.
function Z.engage(o)
	local L = Z.L
	if not L then return "no layout" end
	if Z.r and not Z.r.done then return "an arm is running" end
	local rec = {arm = "engage_" .. tostring(o.mode), done = false, n = 0, k_on_lord = 0, k_other = 0, lord_melee = 0, clicks = 0}
	Z.r = rec
	rec.reset = Z.reset()
	local A = L.lord
	if o.me then for _, w in ipairs(L.others) do if w.u:type() == o.me then A = w end end end
	local A_id = A.u:unique_ui_id()
	local e = L.enemy[o.k or 2]
	local es = e.spot
	local b = math.rad(es[3])
	local fx, fz = math.sin(b), math.cos(b)
	local lx, lz = es[1] + fx * 12, es[2] + fz * 12
	pcall(function()
		A.uc:take_control()
		A.uc:halt()
		A.uc:teleport_to_location(v(lx, bm:get_terrain_height(lx, lz), lz), (es[3] + 180) % 360, math.max(A.u:ordered_width(), 2))
		A.uc:release_control()
	end)
	rec.men0 = e.u:number_of_men_alive()
	local t0, step, next_click = now(), "settle", 0
	local function finish(why)
		rec.why, rec.done = why, true
		for kk in pairs(T.keys or {}) do T.keys[kk] = nil end
		if F.on then pcall(E.main.stop, "verify engage") end
		pcall(function() e.uc:take_control() e.uc:halt() end)
		pcall(function() rec.lord_hp = r1(A.u:unary_hitpoints() * 100) end)
		pcall(function() A.uc:take_control() A.uc:halt() A.uc:set_invincible(true) A.uc:release_control() end)
		rec.killed = rec.men0 - e.u:number_of_men_alive()
		pcall(function() bm:remove_real_callback("tpz_engage") end)
	end
	bm:repeat_real_callback(function()
		local ok, err = pcall(function()
			if rec.done then return end
			local t = now() - t0
			if t > (o.secs or 20) + 10 then finish("timeout") return end
			if step == "settle" and t >= 1 then
				if o.mode == "tp" then
					local s_ok, s_err = pcall(E.main.start, A.u)
					if not s_ok then rec.start_err = tostring(s_err) end
				else
					pcall(function() A.uc:take_control() A.uc:attack_unit(e.u, true, true) A.uc:release_control() end)
				end
				pcall(function() e.uc:release_control() end)
				rec.go, step = t, "go"
			elseif step == "go" then
				local tt = t - rec.go
				if tt >= (o.secs or 20) then finish("time") return end
				rec.n = rec.n + 1
				local tgt
				pcall(function() tgt = e.u:current_target() end)
				if tgt then
					local id
					pcall(function() id = tgt:unique_ui_id() end)
					if id == A_id then rec.k_on_lord = rec.k_on_lord + 1
						if not rec.first_on_lord then rec.first_on_lord = r1(tt) end
					else rec.k_other = rec.k_other + 1 end
				end
				pcall(function() if A.u:is_in_melee() then rec.lord_melee = rec.lord_melee + 1
					if not rec.first_melee then rec.first_melee = r1(tt) end end end)
				if o.mode == "tp" and F.on then
					local man = F.model or F.single
					if man then
						local x, _, z = P.model_pos(P.mount(man) or man)
						local best, bd
						for _, m in ipairs(P.models(e.u)) do
							if P.model_hp(m) > 0 then
								local mx, _, mz = P.model_pos(m)
								local d = (mx - x) ^ 2 + (mz - z) ^ 2
								if not bd or d < bd then best, bd = m, d end
							end
						end
						if best then
							local tx, _, tz = P.model_pos(best)
							local yaw = math.atan2(tx - x, tz - z)
							E.rig.yaw, E.rig.want_yaw = yaw, yaw
							T.key("forward", math.sqrt(bd) > 2.2)
						end
						if tt >= 2 and tt >= next_click then T.tap("attack", 120) rec.clicks = rec.clicks + 1 next_click = tt + 1.5 end
					end
				end
			end
		end)
		if not ok then rec.err = tostring(err) finish("probe error") end
	end, 250, "tpz_engage")
	return "engage " .. tostring(o.mode) .. " on " .. e.u:type()
end

function Z.engage_read()
	local r = Z.r
	if not r then return "not run" end
	return {arm = r.arm, done = r.done, why = r.why, err = r.err, start_err = r.start_err, samples = r.n, k_on_lord = r.k_on_lord,
		k_other = r.k_other, first_on_lord = r.first_on_lord, lord_melee = r.lord_melee, first_melee = r.first_melee,
		lord_hp = r.lord_hp, killed = r.killed, clicks = r.clicks}
end

-- matched combat: my unit's controller kept here so the chance outlives the call
function Z.chance(ty, c)
	local u = mine_of(ty)
	if not u then return "no " .. tostring(ty) end
	Z.mc_uc = Z.mc_uc or {}
	local uc = Z.mc_uc[ty]
	if not uc then uc = bm:get_player_army():create_unit_controller() uc:add_units(u) Z.mc_uc[ty] = uc end
	uc:set_matched_combat_chance(c)
	uc:release_control()
	return "chance " .. c
end

function Z.mc_start(ty, k)
	local me = mine_of(ty)
	local e = T.enemy and T.enemy[k or 1]
	if not (me and e) then return "missing" end
	pcall(function() bm:remove_real_callback("tpz_mc") end)
	local rec = {mine = {}, theirs = {}, died_in = {}, near = {}, t0 = now(), frames = 0, gaps = {}}
	-- a stretch with no ordinary clip on my man (P.anim_slot nil): how long, the nearest enemy man then, and whether he died in it
	local gap
	Z.m = rec
	local last, hp = {}, {}
	local function note(tab, s)
		local key = tostring(s)
		tab[key] = (tab[key] or 0) + 1
	end
	bm:repeat_real_callback(function()
		pcall(function()
			rec.frames = rec.frames + 1
			local t = now() - rec.t0
			local mx, mz
			for _, m in ipairs(P.models(me)) do
				local body = P.mount(m) or m
				for _, b in ipairs(body ~= m and {m, body} or {m}) do
					local key = tostring(b)
					local s = P.anim_slot(b)
					if s ~= last[key] then
						last[key] = s
						note(rec.mine, s)
					end
				end
				if not mx then local x0, y0, z0 = P.model_pos(body) mx, mz = x0, z0 end
			end
			local my = (F.on and (F.model or F.single)) or P.models(me)[1]
			local ms = my and P.anim_slot(my)
			-- each man's command vtable (+0x330, as platform.lua reads it) and running action's vtable (+0x4a8, has
			-- +0x5c0), counted on each change; the played man apart from the rest
			local mr = _G.memreader_plus
			rec.sigs = rec.sigs or {}
			rec.sig_last = rec.sig_last or {}
			for _, man in ipairs(P.models(me)) do
				pcall(function()
					local kind = mr.tostring(mr.read_pointer(man, 0x330))
					local act = "none"
					if mr.read_uint8(man, 0x5c0) ~= 0 then
						local obj = mr.read_pointer(man, 0x4a8)
						if not mr.is_null(obj) then act = mr.tostring(mr.read_pointer(obj, 0)) end
					end
					local who = (F.on and ((F.model and mr.eq(man, F.model)) or (F.single and mr.eq(man, F.single)))) and "played" or "other"
					local key = mr.tostring(man)
					local sig = who .. " " .. tostring(kind) .. "/" .. act
					if sig ~= rec.sig_last[key] then
						rec.sig_last[key] = sig
						rec.sigs[sig] = (rec.sigs[sig] or 0) + 1
					end
				end)
			end
			if my and ms == nil and not gap then
				local best, bd
				for _, m in ipairs(P.models(e.u)) do
					if P.model_hp(m) > 0 then
						local x, _, z = P.model_pos(m)
						local d = (x - mx) ^ 2 + (z - mz) ^ 2
						if not bd or d < bd then best, bd = m, d end
					end
				end
				gap = {from = t, near = best and _G.memreader_plus.tostring(best), d = bd and r1(math.sqrt(bd)) or nil}
			elseif gap and ms ~= nil then
				gap.len = r1(t - gap.from)
				gap.next = ms
				if #rec.gaps < 60 then rec.gaps[#rec.gaps + 1] = gap end
				gap = nil
			end
			local seen = {}
			for _, m in ipairs(P.models(e.u)) do
				pcall(function()
					local kind = mr.tostring(mr.read_pointer(m, 0x330))
					local act = "none"
					if mr.read_uint8(m, 0x5c0) ~= 0 then
						local obj = mr.read_pointer(m, 0x4a8)
						if not mr.is_null(obj) then act = mr.tostring(mr.read_pointer(obj, 0)) end
					end
					local k2 = "e" .. mr.tostring(m)
					local sig = "enemy " .. kind .. "/" .. act
					if sig ~= rec.sig_last[k2] then
						rec.sig_last[k2] = sig
						rec.sigs[sig] = (rec.sigs[sig] or 0) + 1
					end
				end)
				local key = mr.tostring(m)
				seen[key] = true
				local s = P.anim_slot(m)
				local h = P.model_hp(m)
				if s ~= last[key] then
					last[key] = s
					note(rec.theirs, s)
					if mx then
						local x, _, z = P.model_pos(m)
						if (x - mx) ^ 2 + (z - mz) ^ 2 < 16 and #rec.near < 400 then rec.near[#rec.near + 1] = r1(t) .. ":" .. tostring(s) end
					end
				end
				if h <= 0 and (hp[key] or 1) > 0 then note(rec.died_in, s) if gap and gap.near == key then gap.died = r1(t - gap.from) end end
				hp[key] = h
			end
			for key, h in pairs(hp) do
				if not seen[key] and h > 0 then note(rec.died_in, "gone:" .. tostring(last[key])) hp[key] = 0 if gap and gap.near == key then gap.died = r1(t - gap.from) end end
			end
		end)
	end, 1, "tpz_mc")
	return "recording " .. ty .. " vs " .. e.u:type()
end

function Z.mc_stop()
	pcall(function() bm:remove_real_callback("tpz_mc") end)
	return Z.mc_read()
end

function Z.mc_read()
	local r = Z.m
	if not r then return "not run" end
	local gs = {}
	for _, g in ipairs(r.gaps or {}) do gs[#gs + 1] = r1(g.from) .. "+" .. tostring(g.len) .. "s d" .. tostring(g.d) .. (g.died and (" died@" .. g.died) or "") .. ">" .. tostring(g.next) end
	return {frames = r.frames, mine = r.mine, theirs = r.theirs, died_in = r.died_in, gaps = table.concat(gs, " | "), sigs = r.sigs}
end

-- Z.lock_start(me_type, k, played_only) / Z.lock_read(): a matched combat pins two men face to face at a fixed distance
-- for the length of its clip; ordinary melee does not hold that. Each frame, every man of mine (or only the played one)
-- with his nearest live enemy man of T.enemy[k]: locked while within 2.2 m, headings opposite within 3 degrees and the
-- distance moving under 3 cm a frame. Episodes of 0.6 s or more are kept, with whether the enemy man died in them.
function Z.lock_start(ty, k, played_only)
	local me = mine_of(ty)
	local e = T.enemy and T.enemy[k or 1]
	if not (me and e) then return "missing" end
	local mr = _G.memreader_plus
	pcall(function() bm:remove_real_callback("tpz_lock") end)
	local rec = {eps = {}, frames = 0, t0 = now(), open = {}}
	Z.k = rec
	local TWO_PI = 2 * math.pi
	bm:repeat_real_callback(function()
		pcall(function()
			rec.frames = rec.frames + 1
			local t = now() - rec.t0
			local foes = {}
			for _, m in ipairs(P.models(e.u)) do
				if P.model_hp(m) > 0 then
					local x, _, z = P.model_pos(m)
					foes[#foes + 1] = {m = m, x = x, z = z, key = mr.tostring(m)}
				end
			end
			local alive = {}
			for _, f in ipairs(foes) do alive[f.key] = true end
			local mine = {}
			if played_only then
				local pm = F.on and (F.model or F.single)
				if pm then mine[1] = pm end
			else mine = P.models(me) end
			for _, m in ipairs(mine) do
				local key = mr.tostring(m)
				local x, _, z = P.model_pos(m)
				local best, bd
				for _, f in ipairs(foes) do
					local d = (f.x - x) ^ 2 + (f.z - z) ^ 2
					if not bd or d < bd then best, bd = f, d end
				end
				local o = rec.open[key]
				local locked = false
				if best and bd < 2.2 * 2.2 then
					local ok, h1 = pcall(P.heading, m)
					local ok2, h2 = pcall(P.heading, best.m)
					if ok and ok2 and h1 and h2 then
						local diff = math.abs(((h1 - h2) % TWO_PI) - math.pi)
						local d = math.sqrt(bd)
						locked = diff < math.rad(3) and (not o or o.partner ~= best.key or math.abs(d - o.d) < 0.03)
						if locked then
							if o and o.partner == best.key then o.d, o.till = d, t
							else
								if o and o.till - o.from >= 0.6 and #rec.eps < 200 then rec.eps[#rec.eps + 1] = o end
								rec.open[key] = {partner = best.key, from = t, till = t, d = d}
							end
						end
					end
				end
				if not locked and o then
					if o.till - o.from >= 0.6 and #rec.eps < 200 then rec.eps[#rec.eps + 1] = o end
					rec.open[key] = nil
				end
			end
			-- a partner gone from the live list inside or just after its episode died in it
			for _, ep in ipairs(rec.eps) do
				if ep.died == nil and not alive[ep.partner] and t - ep.till < 0.5 then ep.died = true end
			end
			for _, o in pairs(rec.open) do if not alive[o.partner] then o.died = true end end
		end)
	end, 1, "tpz_lock")
	return "lock watch on " .. ty .. (played_only and " (played man only)" or "")
end

function Z.lock_read(stop)
	if stop then pcall(function() bm:remove_real_callback("tpz_lock") end) end
	local r = Z.k
	if not r then return "not run" end
	local n, died, long, total = 0, 0, 0, 0
	local lens = {}
	for _, ep in ipairs(r.eps) do
		local len = ep.till - ep.from
		n = n + 1
		total = total + len
		if ep.died then died = died + 1 end
		if len >= 1.5 then long = long + 1 end
		if #lens < 40 then lens[#lens + 1] = r1(len) .. (ep.died and "x" or "") end
	end
	return {frames = r.frames, episodes = n, died_in = died, over_1_5s = long, secs = r1(total), lens = table.concat(lens, " ")}
end

-- heal a unit (mine by type, or the enemy T.enemy[k])
function Z.heal(ty, k)
	local u = ty and mine_of(ty) or (T.enemy and T.enemy[k] and T.enemy[k].u)
	if not u then return "none" end
	u:heal_hitpoints_unary(1, true)
	return u:number_of_men_alive()
end
return "TPZ loaded"
