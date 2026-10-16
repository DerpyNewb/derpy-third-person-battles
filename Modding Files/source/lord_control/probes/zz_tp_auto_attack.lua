-- No auto attack under a sustained attack (the author, 2026-10-16: "check again when the regiment is under attack and near
-- enemies"). Per subject: the pack plays him, no key is pressed, up to three enemy units attack his regiment for 30 s, both
-- sides invincible. Every frame on his physical body: any attack clip (he asked for none), the command it ran under, the
-- engine orders the guard stopped, the nearest enemy man and how far he was carried. Test scaffolding, not shipped.
-- Read with zz_tp_auto_attack_read.lua; _G.TP_AA_TYPES limits subjects; _G.TP_AA_STOP=true cancels. No string library calls.
local ok, result = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.main and mr) then return "load the pack in a battle first" end
	if _G.TP_AA and not _G.TP_AA.done then return "already running" end
	local P, F = E.P, E.F
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel", "guard"}) do saved[k] = P[k] end
	local T = {units = {}, controllers = {}, done = false, i = 0}
	_G.TP_AA, _G.TP_AA_STOP = T, false
	P.held = function() return false end
	P.pressed = function() return false end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	local clip_cmd = mr.add(mr.add(mr.base, 0x3910000), 0x1fb0)
	local R
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function bump(t, k) t[k] = (t[k] or 0) + 1 end
	P.guard = function(m)
		local before = R and R.phase == "fight" and mr.tostring(mr.read_pointer(P.mount(m) or m, 0x330))
		local slot_then = before and P.anim_slot(P.mount(m) or m)
		local stopped = saved.guard(m)
		if before and stopped then
			bump(R.stops, before) R.stopped = R.stopped + 1
			R.last_stop = now()
			bump(R.stop_slots, tostring(slot_then)) -- the clip on him as the guard stopped the order
		end
		return stopped
	end
	local function controller(army, u, hold)
		local c = army:create_unit_controller()
		c:add_units(u)
		c:set_invincible(true)
		if hold then c:halt() else c:release_control() end
		T.controllers[#T.controllers + 1] = c
		return c
	end
	local function place(uc, x, z, bearing)
		uc:halt()
		uc:teleport_to_location(v(x, bm:get_terrain_height(x, z), z), bearing, 30)
	end
	local enemies = {}
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local ar = all:item(a)
		for i = 1, ar:units():count() do
			local u = ar:units():item(i)
			if u:number_of_men_alive() > 0 and not u:is_artillery() then enemies[#enemies + 1] = {u = u, uc = controller(ar, u, true)} end
		end
	end
	local army = bm:get_player_army()
	local want = _G.TP_AA_TYPES or {"hef_calith_gatekeepers", "wh2_dlc10_hef_inf_everqueens_court_guards_ror_0",
		"wh2_main_hef_cha_tyrion_1", "wh2_main_hef_cav_dragon_princes", "wh2_dlc10_hef_cav_the_fireborn_ror_0",
		"wh2_dlc10_hef_inf_keepers_of_the_flame_ror_0"}
	for _, ty in ipairs(want) do
		for i = 1, army:units():count() do
			local u = army:units():item(i)
			if u:type() == ty and u:number_of_men_alive() > 0 then
				T.units[#T.units + 1] = {type = ty, u = u, uc = controller(army, u), checks = {}, stops = {}, by = {}, cmds = {},
					starts = {}, stop_slots = {},
					stopped = 0, frames = 0, auto_frames = 0, auto_starts = 0, contact = 0, melee_frames = 0, drift = 0}
				break
			end
		end
	end
	local function body()
		local m = F.model or P.models(R.u)[1]
		return m and (P.mount(m) or m)
	end
	local function finish()
		if F.on then pcall(E.main.stop, "auto attack test") end
		for k, f in pairs(saved) do P[k] = f end
		for _, c in ipairs(T.controllers) do pcall(function() c:set_invincible(false) c:release_control() end) end
		T.done = true
		bm:remove_real_callback("tp_auto_attack")
	end
	T.finish = finish
	local function enter(p) R.phase, R.began = p, now() end
	local function next_unit()
		if F.on then E.main.stop("auto attack next") end
		if R then
			place(R.uc, -300, -300 + T.i * 30, 0) R.uc:release_control()
			for k, e in ipairs(R.foes or {}) do place(e.uc, 250, -300 + T.i * 60 + k * 15, 0) end
		end
		T.i = T.i + 1 R = T.units[T.i]
		if not R then finish() return end
		place(R.uc, -100, -350, 0) R.uc:release_control()
		local taken, foes = {}, {}
		for k = 1, 3 do
			local best, bd
			for j, e in ipairs(enemies) do
				if not taken[j] and e.u:number_of_men_alive() > 0 then
					local d = R.u:position():distance_xz(e.u:position())
					if not bd or d < bd then best, bd = j, d end
				end
			end
			if best then taken[best] = true foes[#foes + 1] = enemies[best] end
		end
		R.foes = foes
		for k, e in ipairs(foes) do place(e.uc, -160 + k * 30, -150, 180) end
		enter("prepare")
	end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if _G.TP_AA_STOP or E.disabled then finish() return end
			if not R then next_unit() return end
			local elapsed = now() - R.began
			if R.phase == "prepare" then
				if elapsed > 1.5 then
					for _, m in ipairs(P.models(R.u)) do
						local x, _, z = P.model_pos(P.mount(m) or m)
						P.hold(m, x, z) -- teleport setup: discard destination copies
					end
					E.main.start(R.u)
					if not F.on then R.checks.start = "FAIL could not start" next_unit() return end
					R.one_man = F.model ~= nil
					enter("settle")
				end
				return
			end
			if not F.on then R.checks.control = "FAIL ended in " .. R.phase next_unit() return end
			local b = body()
			if not b then return end
			local x, _, z = P.model_pos(b)
			if R.phase == "settle" and elapsed > 3 then
				R.x0, R.z0 = x, z
				local offs = {{0, 14, 180}, {14, 0, 270}, {-14, 0, 90}}
				for k, e in ipairs(R.foes) do
					local o = offs[k]
					e.uc:teleport_to_location(v(x + o[1], bm:get_terrain_height(x + o[1], z + o[2]), z + o[2]), o[3], 20)
					e.uc:attack_unit(R.u, true, true)
				end
				enter("close")
			elseif R.phase == "close" then
				if R.u:is_in_melee() then enter("fight")
				elseif elapsed > 25 then R.checks.melee = "FAIL not in melee in 25 s" next_unit() end
			elseif R.phase == "fight" then
				R.frames = R.frames + 1
				local cl = P.anim_slot(b)
				local cmd = mr.read_pointer(b, 0x330)
				local cs = mr.tostring(cmd)
				bump(R.cmds, cs)
				if R.u:is_in_melee() then R.melee_frames = R.melee_frames + 1 end
				local attack = cl and (cl >= 454 and cl <= 463 or cl >= 484 and cl <= 500)
				if attack then
					R.auto_frames = R.auto_frames + 1
					bump(R.by, cs .. ":" .. cl)
					if not R.was_attack then
						R.auto_starts = R.auto_starts + 1
						-- what he was under the frame before, and how long since the guard last stopped an order
						if #R.starts < 20 then
							R.starts[#R.starts + 1] = "clip " .. cl .. " under " .. cs .. " after " .. tostring(R.prev_cmd) .. ":"
								.. tostring(R.prev_clip) .. ", " .. tostring(R.last_stop and math.floor((now() - R.last_stop) * 1000)) .. " ms after a stop"
						end
					end
				end
				R.was_attack = attack
				R.prev_cmd, R.prev_clip = cs, cl
				-- a rider's own sword: RIDER_ATTACK_1-10 and their flying forms on the rider model, not his horse
				local rm = F.model or P.models(R.u)[1]
				if rm and not P.same(rm, b) then
					local rc = P.anim_slot(rm)
					if rc and rc >= 1901 and rc <= 1950 then
						R.rider_frames = (R.rider_frames or 0) + 1
						bump(R.by, "rider:" .. rc)
					end
				end
				local d = math.sqrt((x - R.x0) ^ 2 + (z - R.z0) ^ 2)
				if d > R.drift then R.drift = d end
				if R.frames % 5 == 0 then
					local near
					for _, e in ipairs(R.foes) do
						for _, em in ipairs(P.models(e.u)) do
							local ex, _, ez = P.model_pos(em)
							local dd = math.sqrt((ex - x) ^ 2 + (ez - z) ^ 2)
							if not near or dd < near then near = dd end
						end
					end
					if near then
						if not R.nearest or near < R.nearest then R.nearest = near end
						if near < 3 then R.contact = R.contact + 1 end
					end
				end
				if elapsed > 30 then
					R.checks.no_auto_attack = (R.auto_frames == 0 and (R.rider_frames or 0) == 0 and "PASS " or "FAIL ") .. R.auto_starts
						.. " attack clips started, " .. R.auto_frames .. "/" .. R.frames .. " frames; rider attack frames "
						.. (R.rider_frames or 0) .. "; guard stopped " .. R.stopped .. " engine orders"
					R.checks.in_contact = (R.contact > 0 and "PASS " or "FAIL ") .. "nearest enemy " .. tostring(R.nearest)
						.. " m; " .. R.contact .. " samples under 3 m; in melee " .. R.melee_frames .. "/" .. R.frames .. " frames"
					R.checks.carried = "INFO carried up to " .. R.drift .. " m with no key held"
					next_unit()
				end
			end
		end)
		if not worked then T.err = tostring(err) pcall(finish) end
	end, 1, "tp_auto_attack")
	return "auto attack test on " .. #T.units .. " units against " .. #enemies .. " enemy units"
end)
return ok and result or "ERR " .. tostring(result)
