-- 2026-11-25 verification of the 11-21 to 11-25 Workshop reports (docs/sessions/THIRD_PERSON_BUGS_20261024.md):
-- a common soldier's swings hitting several men and knocking them (a comment, 11-25 04:38), swings cancelled with no
-- damage, worst on a moving enemy (a comment, 11-23 01:29). The hills report uses zz_tp_verify_20261120.lua X.climb.
-- Loaded after zz_tp_live_20261108.lua (_G.TPT, T.stub and T.static first). No string library calls and no
-- s:method(); every per-frame read is in a pcall. Times are battle time.
--
-- Y.swing{me = type, k = enemy index in T.enemy, swings = n, gap = s, moving = bool, vanilla = bool, secs = s, back = m}
--   third person: my unit `me` stands `back` m behind the enemy's front (the enemy held, fearless, NOT invincible for
--   the pass), is played (E.main.start; MCT's default plays one entity), walks to the nearest enemy man and clicks every
--   `gap` s. vanilla: third person off, CA's attack order on the enemy unit for `secs` s.
--   moving: the enemy unit walks 25 m along its front and back again for the whole pass.
-- Y.read(): enemy men hit per swing, knocks (KNOCKBACK/KNOCKDOWN 143-197 entered), the blow lines, short swings.
local T = _G.TPT
if not (T and T.E) then return "load TPT first" end
local E = T.E
local P, F = E.P, E.F
local Y = _G.TPY or {}
_G.TPY = Y

local function now() return bm:time_elapsed_ms() / 1000 end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
local function knock(s) return s ~= nil and s >= 143 and s <= 197 end
-- ATTACK_1-10, FLY_ATTACK_1-10, RIDER_ATTACK_1-10, RIDER_FLY_ATTACK_1-10 (9.0 ids, combat.lua IMPACTS)
local function attack(s) return s ~= nil and (s >= 454 and s <= 463 or s >= 494 and s <= 503 or s >= 1901 and s <= 1910 or s >= 1941 and s <= 1950) end

local function find(alliance, ty)
	local armies = alliance:armies()
	for a = 1, armies:count() do
		local us = armies:item(a):units()
		for i = 1, us:count() do
			local u = us:item(i)
			if u:type() == ty then return u, armies:item(a) end
		end
	end
end

local function nearest(unit, x, z)
	local best, bd
	for _, m in ipairs(P.models(unit)) do
		if P.model_hp(m) > 0 then
			local mx, _, mz = P.model_pos(m)
			local d = (mx - x) ^ 2 + (mz - z) ^ 2
			if not bd or d < bd then best, bd = m, d end
		end
	end
	return best, bd and math.sqrt(bd) or nil
end

function Y.swing(o)
	if Y.r and not Y.r.done then return "a pass is running" end
	local me, army = find(bm:get_player_alliance(), o.me)
	local e = T.enemy and T.enemy[o.k or 1]
	if not (me and e) then return "missing: me " .. tostring(me ~= nil) .. ", enemy " .. tostring(e ~= nil) end
	local rec = {me = o.me, enemy = e.u:type(), vanilla = o.vanilla == true, moving = o.moving == true, done = false,
		drops = {}, knocks = {}, segs = {}, logs = {}, strikes = 0, men0 = e.u:number_of_men_alive()}
	Y.r = rec
	-- place: my unit's centre `back` m in front of the enemy's front man, facing it
	local q = e.u:position()
	local ex, ez = q:get_x(), q:get_z()
	local eb = math.rad(e.u:bearing())
	local fx, fz = math.sin(eb), math.cos(eb)
	local front = 0
	for _, m in ipairs(P.models(e.u)) do
		local mx, _, mz = P.model_pos(m)
		local d = (mx - ex) * fx + (mz - ez) * fz
		if d > front then front = d end
	end
	local back = o.back or 10
	local sx, sz = ex + fx * (front + back), ez + fz * (front + back)
	local mc = army:create_unit_controller()
	mc:add_units(me)
	mc:take_control()
	mc:halt()
	mc:teleport_to_location(v(sx, bm:get_terrain_height(sx, sz), sz), (e.u:bearing() + 180) % 360, math.max(me:ordered_width(), 2))
	mc:release_control()
	e.uc:set_invincible(false)
	e.uc:morale_behavior_fearless()
	-- every enemy man: hit point drops, knocks entered
	local men = {}
	for _, m in ipairs(P.models(e.u)) do men[tostring(m)] = {hp = P.model_hp(m), slot = P.anim_slot(m)} end
	-- my men's attack clips: one segment per clip played (the played man's alone under third person)
	local mine = {}
	local strike_was, log_was = P.strike, E.log
	local t0, step, n, next_click, leg = now(), "settle", 0, 0, 0
	local function finish(why)
		rec.why, rec.done = why, true
		for k in pairs(T.keys or {}) do T.keys[k] = nil end
		if F.on then pcall(E.main.stop, "verify swing") end
		P.strike, E.log = strike_was, log_was
		pcall(function() e.uc:halt() e.uc:set_invincible(true) end)
		pcall(function()
			local c = army:create_unit_controller()
			c:add_units(me) c:take_control() c:halt() c:release_control()
		end)
		rec.men_end = e.u:number_of_men_alive()
		pcall(function() bm:remove_real_callback("tpy_swing") end)
	end
	rec.deaths = {}
	local function watch(t)
		local seen = {}
		for _, m in ipairs(P.models(e.u)) do seen[tostring(m)] = true end
		for key, w in pairs(men) do
			if not seen[key] and not w.dead then w.dead = true rec.deaths[#rec.deaths + 1] = {t = t, hp = w.hp} end
		end
		for _, m in ipairs(P.models(e.u)) do
			local key = tostring(m)
			local w = men[key]
			if not w then w = {hp = P.model_hp(m)} men[key] = w end
			local h, s = P.model_hp(m), P.anim_slot(m)
			if h < w.hp then rec.drops[#rec.drops + 1] = {t = t, man = key, drop = w.hp - h, slot = s} w.hp = h end
			if knock(s) and not knock(w.slot) then rec.knocks[#rec.knocks + 1] = {t = t, man = key, slot = s} end
			w.slot = s
		end
		local ms
		if rec.vanilla then ms = P.models(me) else
			local b = F.model or F.single
			ms = b and {b} or {}
		end
		for _, m in ipairs(ms) do
			local body = P.mount(m) or m
			for _, b in ipairs(body ~= m and {m, body} or {m}) do
				local key = tostring(b)
				local s = P.anim_slot(b)
				local w = mine[key]
				if not w then w = {} mine[key] = w end
				if s ~= w.slot then
					if w.seg then w.seg.till, w.seg.next = t, s w.seg = nil end
					if attack(s) then w.seg = {from = t, slot = s, man = key} rec.segs[#rec.segs + 1] = w.seg end
					w.slot = s
				end
			end
		end
	end
	bm:repeat_real_callback(function()
		local ok, err = pcall(function()
			if rec.done then return end
			if _G.TPY_STOP then finish("stopped") return end
			local t = now() - t0
			-- the enemy walks along its front and back (moving)
			if rec.moving and step ~= "settle" and t >= leg then
				leg = t + 6
				rec.legs = (rec.legs or 0) + 1
				local side = (rec.legs % 2 == 1) and 1 or -1
				local tx, tz = ex + fz * 12 * side, ez - fx * 12 * side
				e.uc:goto_location(v(tx, bm:get_terrain_height(tx, tz), tz), false)
			end
			if step == "settle" and t >= 1 then
				if rec.vanilla then
					local c = army:create_unit_controller()
					c:add_units(me)
					c:take_control()
					c:attack_unit(e.u, true, true)
					c:release_control()
					rec.go, step = t, "go"
				else
					local s_ok, s_err = pcall(E.main.start, me)
					if not s_ok then rec.start_err = tostring(s_err) end
					P.strike = function(...) rec.strikes = rec.strikes + 1 return strike_was(...) end
					E.log = function(s) rec.logs[#rec.logs + 1] = {r1(now() - t0 - (rec.go or 0)), s} return log_was(s) end
					step = "aim"
				end
			elseif step == "aim" and t >= 1.8 then
				if not F.on then finish("third person did not start") return end
				rec.played = F.model and "one entity" or F.single and "unit of one" or "regiment"
				rec.go, step = t, "go"
			elseif step == "go" then
				local tt = t - rec.go
				watch(tt)
				if not rec.vanilla then
					local b = F.model or F.single
					if not b then finish("no played man") return end
					local x, _, z = P.model_pos(P.mount(b) or b)
					local target, d = nearest(e.u, x, z)
					if target then
						local tx, _, tz = P.model_pos(target)
						local yaw = math.atan2(tx - x, tz - z)
						E.rig.yaw, E.rig.want_yaw = yaw, yaw
						T.key("forward", d > (o.reach or 2.2))
						rec.d_min = math.min(rec.d_min or 99, r1(d))
					end
					if n < (o.swings or 12) and tt >= next_click and tt >= (o.first or 3) then
						T.tap("attack", 120)
						n, next_click = n + 1, tt + (o.gap or 2)
						rec.clicks = rec.clicks or {}
						rec.clicks[#rec.clicks + 1] = r1(tt)
					end
					if n >= (o.swings or 12) and tt >= next_click + 1 then finish("time") end
				elseif tt >= (o.secs or 20) then finish("time") end
			end
		end)
		if not ok then rec.err = tostring(err) finish("probe error") end
	end, 1, "tpy_swing")
	return "swing pass: " .. o.me .. " vs " .. rec.enemy .. (rec.vanilla and " (CA's melee)" or " (third person)") .. (rec.moving and ", enemy moving" or "")
end

function Y.read()
	local r = Y.r
	if not r then return "not run" end
	local out = {done = r.done, why = r.why, err = r.err, start_err = r.start_err, played = r.played, me = r.me, enemy = r.enemy,
		vanilla = r.vanilla, moving = r.moving, killed = (r.men_end or r.men0) - r.men0, strikes = r.strikes, d_min = r.d_min,
		drops = #r.drops, knocks = #r.knocks}
	-- distinct enemy men hit, and knocks that came within 0.6 s of a drop on the same man
	local hit = {}
	for _, d in ipairs(r.drops) do hit[d.man] = true end
	local nh = 0 for _ in pairs(hit) do nh = nh + 1 end
	out.men_hit = nh
	-- per swing segment: enemy men hit and knocked from its start to the next segment's start (third person: one man)
	local segs = r.segs
	table.sort(segs, function(a, b) return a.from < b.from end)
	out.swings = #segs
	if not r.vanilla then
		local per, kper, short = {}, {}, {}
		for i, s in ipairs(segs) do
			local till = segs[i + 1] and segs[i + 1].from or 1e9
			local victims, kn = {}, 0
			for _, d in ipairs(r.drops) do if d.t >= s.from and d.t < till then victims[d.man] = true end end
			for _, k in ipairs(r.knocks) do if k.t >= s.from and k.t < till then kn = kn + 1 end end
			local c = 0 for _ in pairs(victims) do c = c + 1 end
			per[#per + 1] = s.slot .. ":" .. c
			kper[#kper + 1] = kn
			local len = s.till and r1(s.till - s.from) or "open"
			short[#short + 1] = s.slot .. " " .. len .. "s>" .. tostring(s.next)
		end
		out.victims_per_swing = table.concat(per, " ")
		out.knocks_per_swing = table.concat(kper, " ")
		out.swing_clips = table.concat(short, " | ")
		out.clicks = r.clicks and table.concat(r.clicks, " ") or nil
		local bl = {}
		for _, l in ipairs(r.logs) do
			local s = l[2]
			-- the blow lines and the refusals only: "blow ..." starts with b, plus anything naming a swing
			if type(s) == "string" and #s < 140 then bl[#bl + 1] = l[1] .. " " .. s end
		end
		out.log = bl
	else
		-- CA's melee: my men's swings against enemy hits; knocks per hit
		out.knocks_per_drop = #r.drops > 0 and math.floor(#r.knocks / #r.drops * 100 + 0.5) / 100 or 0
	end
	local ks = {}
	for _, k in ipairs(r.knocks) do ks[#ks + 1] = r1(k.t) .. "s/" .. k.slot end
	out.knock_list = table.concat(ks, " ")
	local ds = {}
	for _, d in ipairs(r.drops) do if #ds < 60 then ds[#ds + 1] = r1(d.t) .. "s-" .. d.drop end end
	out.drop_list = table.concat(ds, " ")
	local dl = {}
	for _, d in ipairs(r.deaths or {}) do dl[#dl + 1] = r1(d.t) .. "s(hp" .. d.hp .. ")" end
	out.death_list = table.concat(dl, " ")
	return out
end
return "TPY loaded"
