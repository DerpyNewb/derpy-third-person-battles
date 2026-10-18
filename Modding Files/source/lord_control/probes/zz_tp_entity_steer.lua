-- Test scaffolding (2026-10-18): a single entity's sprint. CA's change_current_walk_speed leaves a single entity's speed
-- alone (zz_tp_walk_scalar.lua), so: does the mailbox's steer, which sets the speed in his own walk command, move one,
-- and at its scale? Each single entity of _G.TP_ES_TYPES (default Harald, the Mutalith, Be'lakor) is teleported to the
-- clearest 150 m of ground between the armies, then steered each frame by P.steer at the run toward a point LEAD m ahead
-- along it, for each lead (3 m, a man's; 15 m, a mount's) and scale (1, 1.5), 4.5 s each, P.hold between. Speed over the
-- last 3 s of each. No third person: the pack's own P is called. Enemies held, everyone invincible. Read with
-- zz_tp_entity_steer_read.lua; _G.TP_ES_STOP = true cancels. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.P) then return "no pack" end
	if _G.TP_ES and not _G.TP_ES.done then return "already running" end
	local P = E.P
	if not P.mailbox and P.check_mailbox then pcall(P.check_mailbox) end
	if not P.mailbox then return "no mailbox" end
	if E.F and E.F.on then pcall(E.main.stop, "entity steer test") end
	local T = {cases = {}, done = false}
	_G.TP_ES, _G.TP_ES_STOP = T, false
	local types = _G.TP_ES_TYPES or {"wh3_pro11_chs_cha_harald_hammerstorm", "wh3_dlc24_tze_mon_mutalith_vortex_beast_ror",
		"wh3_main_dae_cha_be_lakor_0"}
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function r1(x) return math.floor(x * 100 + 0.5) / 100 end
	-- ours are given back at the end; the enemy stays held, or its AI ends the battle (2026-10-18)
	local ucs, uc_of, others = {}, {}, {}
	local function hold(army, u, ours)
		local c = army:create_unit_controller()
		c:add_units(u)
		c:set_invincible(true)
		c:halt()
		if ours then ucs[#ucs + 1] = c end
		uc_of[u:unique_ui_id()] = c
	end
	local ex, ez, en, px, pz, pn = 0, 0, 0, 0, 0, 0
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local u = ar:units():item(i)
			if u:number_of_men_alive() > 0 then
				hold(ar, u)
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
	local yaw = math.atan2(lx, lz)
	T.lane = "start " .. r1(sx) .. "," .. r1(sz) .. ", room " .. r1(best) .. " m"
	local queue = {}
	for _, u in ipairs(picked) do
		for _, c in ipairs({{3, 1}, {3, 1.5}, {15, 1}, {15, 1.5}}) do queue[#queue + 1] = {u = u, lead = c[1], scale = c[2]} end
	end
	local idx, rec, t0, step, m = 0, nil, nil, nil, nil
	local function finish(why)
		T.done, T.why = true, why
		if m and rec and rec.u then pcall(function() local x, _, z = P.model_pos(m) P.hold(m, x, z, yaw) end) end
		for _, c in ipairs(ucs) do pcall(function() c:set_invincible(false) c:release_control() end) end
		pcall(function() bm:remove_real_callback("tp_es") end)
	end
	local function next_case()
		idx = idx + 1
		local e = queue[idx]
		if not e then finish("all done") return end
		rec = {type = e.u:type(), u = e.u, lead = e.lead, scale = e.scale, fast = r1(e.u:fast_speed()), flying = e.u:is_currently_flying()}
		T.cases[#T.cases + 1] = rec
		m = P.models(e.u)[1]
		local c = uc_of[e.u:unique_ui_id()]
		c:teleport_to_location(v(sx, bm:get_terrain_height(sx, sz), sz), math.deg(yaw) % 360, 30)
		c:release_control()
		t0, step = now(), "teleported"
	end
	next_case()
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if _G.TP_ES_STOP then finish("stopped") return end
			local t = now() - t0
			if step == "teleported" and t >= 1.5 then step, rec.t_go = "steering", t end
			if step == "steering" then
				local x, _, z = P.model_pos(m)
				if _G.TP_ES_GUARD then P.guard(m) end -- the unit's own orders on him stopped, as for one man (main.lua)
				P.steer(m, x + lx * rec.lead, z + lz * rec.lead, true, yaw, rec.scale)
				local tg = t - rec.t_go
				if tg >= 1.5 and not rec.p0 then rec.p0 = {x, z, t} end
				if tg >= 4.5 then
					rec.speed = r1(math.sqrt((x - rec.p0[1]) ^ 2 + (z - rec.p0[2]) ^ 2) / (t - rec.p0[3]))
					rec.cmd_speed = r1(_G.memreader_plus.read_float(P.mount(m) or m, 0x394))
					rec.flying_after = rec.u:is_currently_flying()
					P.hold(m, x, z, yaw)
					step, rec.t_held = "held", t
				end
			elseif step == "held" then
				if t < rec.t_held + 0.2 then local x, _, z = P.model_pos(m) P.hold(m, x, z, yaw) end
				if t >= rec.t_held + 1 then
					local x, _, z = P.model_pos(m)
					rec.after_hold = r1(math.sqrt((x - (rec.hx or x)) ^ 2 + (z - (rec.hz or z)) ^ 2))
					rec.u = nil
					next_case()
				end
			end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_es")
	return "testing " .. #queue .. " cases on " .. #picked .. " units, " .. T.lane
end)
return ok and res or "ERR " .. tostring(res)
