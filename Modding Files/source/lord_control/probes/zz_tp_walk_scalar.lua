-- Test scaffolding (2026-10-18): what CA's change_current_walk_speed does to a move order, measured on its own - no
-- third person. Each unit of _G.TP_WS_TYPES (default Harald, the Mutalith, Chaos Marauders) is teleported to the same
-- start, halfway between the armies, and given one goto_location 150 m along the line between their fronts, at the run or
-- the walk, then the scalar (none, 1.5, its run over its walk, 3). Speed over 1.5-4.5 s after the order. The direction
-- is whichever way along that line keeps furthest from every other unit. Enemies held, everyone invincible. Read with
-- zz_tp_walk_scalar_read.lua; _G.TP_WS_STOP = true cancels. No string library calls.
local ok, res = pcall(function()
	if _G.TP_WS and not _G.TP_WS.done then return "already running" end
	local E = _G.DERPY_TP
	if E and E.F and E.F.on then pcall(E.main.stop, "walk scalar test") end
	local T = {cases = {}, done = false}
	_G.TP_WS, _G.TP_WS_STOP = T, false
	local types = _G.TP_WS_TYPES or {"wh3_pro11_chs_cha_harald_hammerstorm", "wh3_dlc24_tze_mon_mutalith_vortex_beast_ror",
		"wh_main_chs_inf_chaos_marauders_1"}
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function r1(x) return math.floor(x * 100 + 0.5) / 100 end
	local ucs, uc_of, others = {}, {}, {}
	local function hold(army, u, keep)
		local c = army:create_unit_controller()
		c:add_units(u)
		c:set_invincible(true)
		if keep then c:halt() end
		ucs[#ucs + 1] = c
		uc_of[u:unique_ui_id()] = c
	end
	local ex, ez, en, px, pz, pn = 0, 0, 0, 0, 0, 0
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local u = ar:units():item(i)
			if u:number_of_men_alive() > 0 then
				hold(ar, u, true)
				local q = u:position()
				ex, ez, en = ex + q:get_x(), ez + q:get_z(), en + 1
				others[#others + 1] = u
			end
		end
	end
	local army = bm:get_player_army()
	local picked = {}
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		if u:number_of_men_alive() > 0 then
			hold(army, u, true)
			local q = u:position()
			px, pz, pn = px + q:get_x(), pz + q:get_z(), pn + 1
			local want
			for _, ty in ipairs(types) do if ty == u:type() then want = true end end
			if want then picked[#picked + 1] = u else others[#others + 1] = u end
		end
	end
	if en == 0 or pn == 0 then return "no armies" end
	ex, ez, px, pz = ex / en, ez / en, px / pn, pz / pn
	local dx, dz = ex - px, ez - pz
	local dn = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / dn, dz / dn
	local mx, mz = (px + ex) / 2, (pz + ez) / 2
	-- the nearest other unit to the 150 m segment from (ax, az) along (lx, lz)
	local function room(ax, az, lx, lz)
		local best = 1e9
		for _, o in ipairs(others) do
			local q = o:position()
			local rx, rz = q:get_x() - ax, q:get_z() - az
			local t = math.max(0, math.min(150, rx * lx + rz * lz))
			local d = math.sqrt((rx - lx * t) ^ 2 + (rz - lz * t) ^ 2)
			if d < best then best = d end
		end
		return best
	end
	-- the clearest of: starts 0-100 m either side of halfway, toward either army, each way along the fronts
	local sx, sz, lx, lz, best
	for k = -4, 4 do
		for side = -2, 2 do
			for dir = -1, 1, 2 do
				local ax, az = mx + dx * k * 25 + dz * side * 50, mz + dz * k * 25 - dx * side * 50
				local r = room(ax, az, dz * dir, -dx * dir)
				if not best or r > best then sx, sz, lx, lz, best = ax, az, dz * dir, -dx * dir, r end
			end
		end
	end
	T.lane = "start " .. r1(sx) .. "," .. r1(sz) .. ", room " .. r1(best) .. " m"
	local queue = {}
	for _, u in ipairs(picked) do
		local ratio = u:fast_speed() / u:slow_speed()
		for _, c in ipairs({{true, nil}, {true, 1.5}, {true, ratio}, {true, 3}, {false, nil}, {false, 1.5}, {false, ratio}}) do
			queue[#queue + 1] = {u = u, run = c[1], s = c[2]}
		end
	end
	local function finish(why)
		T.done, T.why = true, why
		for _, c in ipairs(ucs) do pcall(function() c:set_invincible(false) c:release_control() end) end
		pcall(function() bm:remove_real_callback("tp_ws") end)
	end
	local idx, rec, t0, step = 0, nil, nil, nil
	local function pos() local q = rec.u:position() return q:get_x(), q:get_z() end
	local function next_case()
		idx = idx + 1
		local e = queue[idx]
		if not e then finish("all done") return end
		rec = {type = e.u:type(), u = e.u, run = e.run, s = e.s and r1(e.s), slow = r1(e.u:slow_speed()), fast = r1(e.u:fast_speed())}
		T.cases[#T.cases + 1] = rec
		local c = uc_of[e.u:unique_ui_id()]
		c:teleport_to_location(v(sx, bm:get_terrain_height(sx, sz), sz), math.deg(math.atan2(lx, lz)) % 360, 30)
		t0, step = now(), "teleported"
	end
	next_case()
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if _G.TP_WS_STOP then finish("stopped") return end
			local t = now() - t0
			local c = uc_of[rec.u:unique_ui_id()]
			if step == "teleported" and t >= 1.5 then
				local gx, gz = sx + lx * 150, sz + lz * 150
				c:goto_location(v(gx, bm:get_terrain_height(gx, gz), gz), rec.run)
				if rec.s then c:change_current_walk_speed(rec.s) end
				step, rec.t_order = "moving", t
			elseif step == "moving" then
				local tm = t - rec.t_order
				if tm >= 1.5 and not rec.p0 then rec.p0 = {pos()} rec.p0[3] = t end
				if tm >= 4.5 then
					local x, z = pos()
					rec.speed = r1(math.sqrt((x - rec.p0[1]) ^ 2 + (z - rec.p0[2]) ^ 2) / (t - rec.p0[3]))
					rec.melee = rec.u:is_in_melee()
					c:halt()
					step = "done"
					rec.t_done = t
				end
			elseif step == "done" and t >= rec.t_done + 0.5 then
				rec.u = nil
				next_case()
			end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_ws")
	return "testing " .. #queue .. " cases on " .. #picked .. " units, " .. T.lane
end)
return ok and res or "ERR " .. tostring(res)
