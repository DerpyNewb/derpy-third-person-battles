-- Test scaffolding (2026-10-21, multiplayer plan Task 2 step 1), never shipped. Watches, never drives: runs in the
-- battle and again in its replay, keyed by model time, so the two script logs line up tick for tick.
-- Bridge-only, loaded from disk: local f = loadfile("<this path>") setfenv(f, core:get_env()) f()
-- Every 100 ms of MODEL time (bm:repeat_callback), for every unit of both sides, one field list:
--   tag (alliance.army.unit) = unique_ui_id, x dm, z dm, fire_at_will, defend, men alive, ammo, invulnerable,
--   script controlled, moving, first man's command (low 16 bits of its vtable) and his +0x278 clip slot
-- written to the script log as "TPW <ms> K|D ..." - K a keyframe (every unit, every 5 s), D only the units whose list
-- changed. For each man in _G.TPW_MEN ({name, tag, id = "hi.lo" of his +0x258}) a "TPM <ms> <name> ..." line every
-- tick: x z dm, heading (u16 at the body's +0xb0), P.anim_slot or -1, command low 16, +0x340 done, +0x890 set,
-- +0x324 order kind, queued holder has/started (+0x6f8/+0x6f9), hit points. Keyframes also carry the gates
-- +0x3b0/+0x3b1 and the RELOAD_TIME global exe+3d10794. Stops after _G.TPW_SECS (200) s or on _G.TPW_STOP.
-- Works with the pack idle (a replay): needs only memreader Plus and _G.DERPY_TP.P. No string library calls.
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local E = _G.DERPY_TP
	local P = E and E.P
	if not (mr and P and P.models) then return "no platform" end
	if _G.TPW and _G.TPW.on then return "already watching" end
	local W = {on = true, ticks = 0, men = _G.TPW_MEN or {}}
	_G.TPW = W
	local base = mr.base
	local function A(hi, lo) return mr.add(mr.add(base, hi), lo) end
	local reload_g, battle_g = A(0x3d10000, 0x0794), A(0x4480000, 0x0da0)
	local function r(x) return math.floor(x * 10 + 0.5) end
	local function b(x) if x then return 1 end return 0 end
	local function id_of(m) return tostring(mr.read_uint16(m, 0x25a)) .. "." .. tostring(mr.read_uint16(m, 0x258)) end
	local units, by_tag = {}, {}
	for a, al in ipairs({bm:get_player_alliance(), bm:get_non_player_alliance()}) do
		local armies = al:armies()
		for k = 1, armies:count() do
			local us = armies:item(k):units()
			for i = 1, us:count() do
				local e = {u = us:item(i), tag = a .. "." .. k .. "." .. i}
				units[#units + 1] = e
				by_tag[e.tag] = e
			end
		end
	end
	W.units = units
	local last = {}
	local function fields(u)
		local p = u:position()
		local s = tostring(u:unique_ui_id()) .. "," .. r(p:get_x()) .. "," .. r(p:get_z())
		local okb, beh = pcall(function() return b(u:is_behaviour_active("fire_at_will")) .. "," .. b(u:is_behaviour_active("defend")) end)
		s = s .. "," .. (okb and beh or "?,?") .. "," .. u:number_of_men_alive() .. "," .. u:ammo_left() .. "," .. b(u:is_invulnerable())
			.. "," .. b(u:is_script_controlled()) .. "," .. b(u:is_moving())
		local ms = P.models(u)
		local m = ms[1]
		if m then s = s .. "," .. mr.read_uint16(m, 0x330) .. "," .. mr.read_uint16(m, 0x278) else s = s .. ",-,-" end
		local ab = _G.TPW_AB -- {id = unique_ui_id, keys = {...}}: can_perform_special_ability per key, appended as 0/1
		if ab and ab.id == u:unique_ui_id() then for _, k in ipairs(ab.keys) do s = s .. "," .. b(u:can_perform_special_ability(k)) end end
		return s
	end
	local function man(w)
		local e = by_tag[w.tag]
		if not e then return nil end
		for _, m in ipairs(P.models(e.u)) do -- every tick: a cached pointer could outlive a dead man
			if id_of(m) == w.id then return m end
		end
		return nil
	end
	local function men_line(t, w)
		local m = man(w)
		if not m then return "TPM " .. t .. " " .. w.name .. " gone" end
		local body = P.mount(m) or m
		local x, _, z = P.model_pos(body)
		local hp = mr.read_int32(body, 0xb1c)
		return "TPM " .. t .. " " .. w.name .. " " .. r(x) .. " " .. r(z) .. " hd " .. mr.read_uint16(body, 0xb0)
			.. " clip " .. tostring(P.anim_slot(m) or -1) .. (body ~= m and P.mount(m) and (" mclip " .. tostring(P.anim_slot(body) or -1)) or "") .. " cmd " .. mr.read_uint16(body, 0x330)
			.. " done " .. mr.read_uint8(body, 0x340) .. " p890 " .. b(not mr.is_null(mr.read_pointer(body, 0x890)))
			.. " ok " .. mr.read_int32(body, 0x324) .. " q " .. mr.read_uint8(body, 0x6f8) .. mr.read_uint8(body, 0x6f9)
			.. " hp " .. hp
	end
	local t0 = bm:time_elapsed_ms()
	out("TPW start " .. t0 .. " base " .. mr.tostring(base) .. " units " .. #units .. " men " .. #W.men .. " replay " .. tostring(bm:is_replay()))
	local function tick()
		local t = bm:time_elapsed_ms()
		if _G.TPW_STOP or t - t0 > (_G.TPW_SECS or 200) * 1000 then
			W.on = false
			bm:remove_process("tp_mp_watch")
			out("TPW stop " .. t)
			return
		end
		local key = W.ticks % 50 == 0
		W.ticks = W.ticks + 1
		local parts = {"TPW", tostring(t), key and "K" or "D"}
		if key then
			local g = mr.read_pointer(battle_g, 0)
			local bt = not mr.is_null(g) and mr.read_pointer(g, 0x468)
			if bt and not mr.is_null(bt) then parts[#parts + 1] = "gates=" .. mr.read_uint8(bt, 0x3b0) .. "," .. mr.read_uint8(bt, 0x3b1) end
			parts[#parts + 1] = "rg=" .. tostring(mr.read_float(reload_g, 0))
		end
		for _, e in ipairs(units) do
			local okf, s = pcall(fields, e.u)
			if not okf then s = "err" end
			if key or s ~= last[e.tag] then parts[#parts + 1] = e.tag .. "=" .. s end
			last[e.tag] = s
		end
		out(table.concat(parts, " "))
		for _, w in ipairs(W.men) do
			local okm, line = pcall(men_line, t, w)
			out(okm and line or ("TPM " .. t .. " " .. w.name .. " err"))
		end
	end
	bm:repeat_callback(function()
		local worked, err = pcall(tick)
		if not worked then W.err = tostring(err) end
	end, 100, "tp_mp_watch")
	return "watching from " .. t0 .. ", " .. #units .. " units, " .. #W.men .. " men"
end)
return ok and res or "ERR " .. tostring(res)
