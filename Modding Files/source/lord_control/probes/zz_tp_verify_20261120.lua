-- 2026-11-20 verification of the 11-19 and 11-20 Workshop reports (docs/sessions/THIRD_PERSON_BUGS_20261024.md):
-- collision kills while W is held (bugs thread #82), movement stuck on hills (a comment, 11-19 19:16) and the markers key
-- showing enemies (a comment, 11-20 22:15). The lock-on in a crowd (#83) runs zz_tp_crowd_focus.lua. Loaded after
-- zz_tp_live_20261108.lua (_G.TPT, T.stub and T.static first). No string library calls and no s:method(); every
-- per-frame read is in a pcall. Times are battle time (bm:time_elapsed_ms), since a background game runs slow.
local T = _G.TPT
if not (T and T.E) then return "load TPT first" end
local E = T.E
local P, F = E.P, E.F
local X = _G.TPX or {}
_G.TPX = X

local function now() return bm:time_elapsed_ms() / 1000 end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
local function r2(x) return math.floor(x * 100 + 0.5) / 100 end

function X.find(alliance, ty, nth)
	local k = 0
	local armies = alliance:armies()
	for a = 1, armies:count() do
		local us = armies:item(a):units()
		for i = 1, us:count() do
			local u = us:item(i)
			if u:type() == ty then
				k = k + 1
				if k == (nth or 1) then return u, armies:item(a) end
			end
		end
	end
end

local function hp(u)
	local h = -1
	pcall(function() h = u:unit_health() end)
	return h
end

-- where the man third person plays stands, else the unit's centre
local function body(me)
	local m = F.on and (F.model or F.single)
	if m then
		local x, y, z = P.model_pos(P.mount(m) or m)
		return x, y, z
	end
	local q = me:position()
	return q:get_x(), q:get_y(), q:get_z()
end

-- my unit placed at (x, z) facing bearing b (degrees), held still, then released to the player
local function place(me, army, x, z, b)
	local mc = army:create_unit_controller()
	mc:add_units(me)
	mc:take_control()
	mc:halt()
	mc:teleport_to_location(v(x, bm:get_terrain_height(x, z), z), b % 360, 2)
	mc:release_control()
end

local function halt(me, army)
	local mc = army:create_unit_controller()
	mc:add_units(me)
	mc:take_control()
	mc:halt()
	mc:release_control()
end

-- one driven pass, shared by the collision and hill tests. P: {me, army, mode, secs, to = {x, z}, start = {x, z, b},
-- each = function(rec, t) extra sample fields}. mode "run" / "walk" / "sprint" hold W under third person (W and Shift
-- for "sprint", the walk switch on for "walk"); "ca_run" / "ca_walk" give CA's move order to `to` with third person off
local function pass(p, rec)
	place(p.me, p.army, p.start.x, p.start.z, p.start.b)
	rec.samples, rec.done, rec.strikes = {}, false, 0
	local t0, step, next_sample, next_goto = now(), "settle", 0, 0
	-- "run_goto": third person at the run, and CA's move order on the unit to the same point every 0.6 s (a unit-level
	-- move state under the pack's own walk of the man)
	local tp = p.mode == "run" or p.mode == "walk" or p.mode == "sprint" or p.mode == "run_goto"
	local strike_was = P.strike
	local function finish(why)
		rec.why = why
		for k in pairs(T.keys or {}) do T.keys[k] = nil end
		if F.on then pcall(E.main.stop, "verify pass") end
		P.strike = strike_was
		pcall(halt, p.me, p.army)
		rec.done = true
		pcall(function() bm:remove_real_callback("tpx_pass") end)
	end
	bm:repeat_real_callback(function()
		local ok, err = pcall(function()
			if rec.done then return end
			if _G.TPX_STOP then finish("stopped") return end
			local t = now() - t0
			if step == "settle" and t >= 1 then
				if tp then
					local s_ok, s_err = pcall(E.main.start, p.me)
					if not s_ok then rec.start_err = tostring(s_err) end
					P.strike = function(...) rec.strikes = rec.strikes + 1 return strike_was(...) end
					step = "keys"
				else
					local mc = p.army:create_unit_controller()
					mc:add_units(p.me)
					mc:take_control()
					mc:goto_location(v(p.to.x, bm:get_terrain_height(p.to.x, p.to.z), p.to.z), p.mode == "ca_run")
					mc:release_control()
					rec.go, step = t, "go"
				end
			elseif step == "keys" and t >= 1.6 then
				if not F.on then finish("third person did not start") return end
				rec.swings0 = F.swings or 0
				if p.mode == "walk" then F.walking = true end
				T.key("forward", true)
				if p.mode == "sprint" then T.key("sprint", true) end
				rec.go, step = t, "go"
			elseif step == "go" then
				local x, y, z = body(p.me)
				if tp then
					local yaw = math.atan2(p.to.x - x, p.to.z - z)
					E.rig.yaw, E.rig.want_yaw = yaw, yaw
				end
				if p.mode == "run_goto" and t >= next_goto and F.uc then
					next_goto = t + 0.6
					F.uc:goto_location(v(p.to.x, bm:get_terrain_height(p.to.x, p.to.z), p.to.z), true)
					F.uc:release_control()
					rec.gotos = (rec.gotos or 0) + 1
				end
				if p.watch then p.watch(t - rec.go, x, z) end
				-- the fix's move order (move.lua single_order): each new F.order is one order sent
				if F.order ~= rec.order_was then
					rec.order_was = F.order
					if F.order then rec.orders = (rec.orders or 0) + 1 end
				end
				if t >= next_sample then
					next_sample = t + 0.1
					local s = {t = r1(t - rec.go), x = r1(x), z = r1(z), y = r1(y), melee = p.me:is_in_melee() == true}
					if tp then s.walking, s.running, s.sprinting = F.walking == true, F.running == true, F.sprinting == true end
					if p.each then p.each(s) end
					rec.samples[#rec.samples + 1] = s
				end
				if t - rec.go >= p.secs then
					if tp then rec.swings = (F.swings or 0) - rec.swings0 end
					finish("time")
				end
			end
		end)
		if not ok then rec.err = tostring(err) finish("probe error") end
	end, 1, "tpx_pass")
end

-- COLLISION: my unit `ty` starts `back` m in front of enemy unit k (T.enemy, held, NOT invincible for the pass) and
-- is driven at a point 20 m behind its centre for secs s. Men and health of that enemy sampled every 0.1 s
function X.collide(ty, k, mode, secs, back)
	if X.c and not X.c.done then return "a pass is running" end
	local me, army = X.find(bm:get_player_alliance(), ty)
	local e = T.enemy and T.enemy[k]
	if not (me and e) then return "missing: me " .. tostring(me ~= nil) .. ", enemy " .. tostring(e ~= nil) end
	local q = e.u:position()
	local ex, ez = q:get_x(), q:get_z()
	local eb = math.rad(e.u:bearing())
	local fx, fz = math.sin(eb), math.cos(eb)
	back = back or 25
	e.uc:set_invincible(false)
	local rec = {kind = "collide", mode = mode, unit = ty, enemy = e.u:type(), k = k,
		men0 = e.u:number_of_men_alive(), hp0 = hp(e.u)}
	X.c = rec
	-- every enemy man of k each frame: a hit point drop or a death, with the clip he played then (and in the second
	-- before a death), the played man's clip, and his speed over the last 0.5 s
	local men, trail = {}, {}
	rec.drops, rec.deaths = {}, {}
	for _, m in ipairs(P.models(e.u)) do local h = P.model_hp(m) men[tostring(m)] = {hp = h, slots = {}} end
	local function watch(t, x, z)
		trail[#trail + 1] = {t, x, z}
		while #trail > 1 and t - trail[1][1] > 0.5 do table.remove(trail, 1) end
		local a = trail[1]
		local sp = (t - a[1]) > 0.05 and math.sqrt((x - a[2]) ^ 2 + (z - a[3]) ^ 2) / (t - a[1]) or 0
		local mine = F.single or F.model
		local my_slot = mine and P.anim_slot(P.mount(mine) or mine) or nil
		local seen = {}
		for _, m in ipairs(P.models(e.u)) do
			local key = tostring(m)
			seen[key] = true
			local w = men[key]
			if not w then w = {hp = P.model_hp(m), slots = {}} men[key] = w end
			local h = P.model_hp(m)
			local s = P.anim_slot(m)
			if s then w.slots[#w.slots + 1] = {t, s} end
			while #w.slots > 0 and t - w.slots[1][1] > 1 do table.remove(w.slots, 1) end
			if h < w.hp then
				rec.drops[#rec.drops + 1] = {t = r1(t), drop = w.hp - h, hp = h, slot = s, my_slot = my_slot, speed = r1(sp)}
				w.hp = h
			end
			w.last_slot = s
		end
		for key, w in pairs(men) do
			if not seen[key] and not w.dead then
				w.dead = true
				local ss = {}
				for _, q in ipairs(w.slots) do ss[#ss + 1] = q[2] end
				rec.deaths[#rec.deaths + 1] = {t = r1(t), hp_before = w.hp, slots = table.concat(ss, ","), my_slot = my_slot, speed = r1(sp)}
			end
		end
	end
	pass({me = me, army = army, mode = mode, secs = secs or 8,
		start = {x = ex + fx * back, z = ez + fz * back, b = e.u:bearing() + 180},
		to = {x = ex - fx * 20, z = ez - fz * 20}, watch = watch,
		each = function(s) s.men, s.hp = e.u:number_of_men_alive(), hp(e.u) end}, rec)
	return "pass: " .. mode .. ", " .. ty .. " into " .. rec.enemy .. " (" .. rec.men0 .. " men)"
end

function X.collide_read()
	local rec = X.c
	if not rec then return "not run" end
	local S = rec.samples or {}
	local last = S[#S]
	local out = {mode = rec.mode, done = rec.done, why = rec.why, err = rec.err, start_err = rec.start_err,
		enemy = rec.enemy, men0 = rec.men0, hp0 = rec.hp0, pack_blows = rec.strikes, pack_swings = rec.swings}
	if last then
		out.men_end, out.hp_end, out.killed = last.men, last.hp, rec.men0 - last.men
		local first_loss, first_melee, melee_n = nil, nil, 0
		for _, s in ipairs(S) do
			if not first_loss and s.men < rec.men0 then first_loss = s.t end
			if s.melee then melee_n = melee_n + 1 if not first_melee then first_melee = s.t end end
		end
		out.first_loss_t, out.first_melee_t, out.melee_share = first_loss, first_melee, r2(melee_n / #S)
		local a = S[1]
		out.metres = r1(math.sqrt((last.x - a.x) ^ 2 + (last.z - a.z) ^ 2))
		-- the kills second by second
		local per = {}
		local sec, base = 1, rec.men0
		for _, s in ipairs(S) do
			if s.t >= sec then per[#per + 1] = base - s.men base = s.men sec = sec + 1 end
		end
		out.kills_per_s = table.concat(per, " ")
		if S[1] and S[1].walking ~= nil then
			local w, r, sp = 0, 0, 0
			for _, s in ipairs(S) do if s.walking then w = w + 1 end if s.running then r = r + 1 end if s.sprinting then sp = sp + 1 end end
			out.walking_share, out.running_share, out.sprinting_share = r2(w / #S), r2(r / #S), r2(sp / #S)
		end
	end
	return out
end

-- the watched drops and deaths of the last collide pass, tallied: how many by the victim's clip at the drop, the played
-- man's clip, and the played man's speed band
function X.watch_read()
	local rec = X.c
	if not (rec and rec.drops) then return "not run" end
	local by_slot, by_mine, by_speed, dmg = {}, {}, {}, {}
	for _, d in ipairs(rec.drops) do
		local k = tostring(d.slot)
		by_slot[k] = (by_slot[k] or 0) + 1
		local km = tostring(d.my_slot)
		by_mine[km] = (by_mine[km] or 0) + 1
		local band = d.speed < 1 and "<1" or d.speed < 3 and "1-3" or d.speed < 4 and "3-4" or ">=4"
		by_speed[band] = (by_speed[band] or 0) + 1
		dmg[#dmg + 1] = d.drop
	end
	local function flat(t) local o = {} for k, n in pairs(t) do o[#o + 1] = k .. ":" .. n end table.sort(o) return table.concat(o, " ") end
	local deaths = {}
	for _, d in ipairs(rec.deaths) do deaths[#deaths + 1] = d.t .. "s hp" .. d.hp_before .. " v" .. d.speed .. " [" .. d.slots .. "] mine " .. tostring(d.my_slot) end
	table.sort(dmg)
	return {drops = #rec.drops, deaths = #rec.deaths, gotos = rec.gotos, orders = rec.orders, drop_by_victim_slot = flat(by_slot),
		drop_by_my_slot = flat(by_mine), drop_by_speed = flat(by_speed), damages = table.concat(dmg, " "), death_list = deaths}
end

-- HILLS: the steepest ground within r m of (cx, cz): the rise over 10 m in 16 directions on a `grid` m grid, kept
-- where the next 10 m keep at least half that rise (a slope, not a step). Top n, at least 25 m apart
function X.slopes(cx, cz, r, n, grid)
	grid = grid or 8
	local list = {}
	for gx = -r, r, grid do
		for gz = -r, r, grid do
			local x, z = cx + gx, cz + gz
			local h0 = bm:get_terrain_height(x, z)
			local best, best_a = 0, 0
			for d = 0, 15 do
				local a = d * math.pi / 8
				local sx, sz = math.sin(a), math.cos(a)
				local h1 = bm:get_terrain_height(x + sx * 10, z + sz * 10)
				local h2 = bm:get_terrain_height(x + sx * 20, z + sz * 20)
				local s = (h1 - h0) / 10
				if s > best and (h2 - h1) / 10 >= s / 2 then best, best_a = s, a end
			end
			if best > 0 then list[#list + 1] = {x = x, z = z, s = best, b = math.deg(best_a)} end
		end
	end
	table.sort(list, function(a, b) return a.s > b.s end)
	local out = {}
	for _, c in ipairs(list) do
		local far = true
		for _, o in ipairs(out) do if (o.x - c.x) ^ 2 + (o.z - c.z) ^ 2 < 625 then far = false break end end
		if far then
			out[#out + 1] = {x = r1(c.x), z = r1(c.z), bearing = r1(c.b), deg = r1(math.deg(math.atan(c.s))), rise_10m = r1(c.s * 10)}
			if #out >= (n or 8) then break end
		end
	end
	return out
end

-- my unit `ty` at (x, z) facing bearing b (degrees), driven `dist` m straight up it for secs s
function X.climb(ty, x, z, b, mode, secs, dist)
	if X.h and not X.h.done then return "a pass is running" end
	local me, army = X.find(bm:get_player_alliance(), ty)
	if not me then return "missing " .. ty end
	local a = math.rad(b)
	dist = dist or 30
	local rec = {kind = "climb", mode = mode, unit = ty, at = {x = x, z = z, b = b}}
	X.h = rec
	pass({me = me, army = army, mode = mode, secs = secs or 8, start = {x = x, z = z, b = b},
		to = {x = x + math.sin(a) * dist, z = z + math.cos(a) * dist}}, rec)
	return "climb: " .. mode .. ", " .. ty .. " at bearing " .. b
end

function X.climb_read()
	local rec = X.h
	if not rec then return "not run" end
	local S = rec.samples or {}
	local out = {mode = rec.mode, done = rec.done, why = rec.why, err = rec.err, start_err = rec.start_err, n = #S}
	if #S < 2 then return out end
	local a, last = S[1], S[#S]
	out.metres = r1(math.sqrt((last.x - a.x) ^ 2 + (last.z - a.z) ^ 2))
	out.climbed = r1(last.y - a.y)
	out.secs = r1(last.t - a.t)
	out.speed = r2(out.metres / math.max(out.secs, 0.1))
	-- metres covered in each second, and the longest span under 0.3 m/s
	local per, sec, bx, bz = {}, 1, a.x, a.z
	local still, still_from, longest = false, 0, 0
	for i, s in ipairs(S) do
		if s.t >= sec then
			per[#per + 1] = r1(math.sqrt((s.x - bx) ^ 2 + (s.z - bz) ^ 2))
			bx, bz, sec = s.x, s.z, sec + 1
		end
		if i > 1 then
			local p = S[i - 1]
			local sp = math.sqrt((s.x - p.x) ^ 2 + (s.z - p.z) ^ 2) / math.max(s.t - p.t, 0.05)
			if sp < 0.3 then
				if not still then still, still_from = true, p.t end
				longest = math.max(longest, s.t - still_from)
			else still = false end
		end
	end
	out.m_per_s = table.concat(per, " ")
	out.longest_still = r1(longest)
	return out
end

-- MARKERS KEY: hold it (stubbed) for hold s while third person plays `ty`; F.guide and F.banners sampled each frame,
-- and which enemy units the game counts as visible to the player
function X.guide(ty, hold)
	local me = X.find(bm:get_player_alliance(), ty)
	if not me then return "missing " .. ty end
	local rec = {frames = 0, guide = 0, banners = 0, done = false}
	X.g = rec
	local t0, step = now(), "start"
	bm:repeat_real_callback(function()
		local ok, err = pcall(function()
			if rec.done then return end
			local t = now() - t0
			if step == "start" then
				pcall(E.main.start, me)
				step = "wait"
			elseif step == "wait" and t >= 0.8 then
				rec.on = F.on == true
				T.key("guide", true)
				step, rec.t1 = "hold", t
			elseif step == "hold" then
				rec.frames = rec.frames + 1
				if F.guide then rec.guide = rec.guide + 1 end
				if F.banners then rec.banners = rec.banners + 1 end
				if t >= rec.t1 + hold then
					T.key("guide", false)
					step, rec.t2 = "after", t
				end
			elseif step == "after" and t >= rec.t2 + 0.5 then
				rec.guide_after, rec.banners_after = F.guide == true, F.banners == true
				pcall(E.main.stop, "verify guide")
				rec.done = true
				bm:remove_real_callback("tpx_guide")
			end
		end)
		if not ok then rec.err = tostring(err) rec.done = true pcall(function() bm:remove_real_callback("tpx_guide") end) end
	end, 1, "tpx_guide")
	return "holding the markers key"
end

function X.visible()
	local out, n = {}, 0
	local armies = bm:get_non_player_alliance():armies()
	for a = 1, armies:count() do
		local us = armies:item(a):units()
		for i = 1, us:count() do
			local u = us:item(i)
			n = n + 1
			local seen = "?"
			pcall(function() seen = u:is_valid_target() == true end)
			out[#out + 1] = u:type() .. " " .. tostring(seen)
		end
	end
	return out
end
return "TPX loaded"
