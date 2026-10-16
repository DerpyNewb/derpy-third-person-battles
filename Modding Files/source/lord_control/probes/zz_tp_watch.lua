-- Why the pack differs by unit, 2026-10-16 (the author: "still auto attacking", "headless but still controlling the
-- character", "no attack being triggered as tyrion", "why is this mod very inconsistent across units"). Read only,
-- 10 minutes, every 0.1 s real time, across third person going off and on. Per unit played: its kind, his model
-- class (+0), which swing / rider / mount attack rows his bin has; then every command put on him (+0x330 as hex)
-- with the clips seen under it; his hit points and whether he is still in the unit's list each time either changes;
-- for a unit played whole, its first model's command and clip and how far the unit moved each second. No orders, no
-- writes. No string library calls. Read back: zz_tp_watch_read.lua.
local E = _G.DERPY_TP
if not (E and E.P and E.S) then return "load the pack first" end
local mr = _G.memreader_plus
if not mr then return "no memreader_plus" end
if _G.TP_WATCH and not _G.TP_WATCH.done then return "already running" end
local P, F = E.P, E.F
local T = {base = mr.tostring(mr.base), events = {}, cmds = {}, done = false, ticks = 0}
_G.TP_WATCH = T
local t0 = os.clock()
local function note(s)
	if #T.events < 500 then T.events[#T.events + 1] = math.floor((os.clock() - t0) * 10) / 10 .. "s " .. s end
end
local ROWS = {454, 455, 456, 457, 458, 459, 460, 484, 485, 489, 1901, 1902, 1903, 1904, 1941}
local function rows(m)
	if not m then return "none" end
	local s = ""
	for _, r in ipairs(ROWS) do if P.has_slot(m, r) then s = s .. r .. " " end end
	return s == "" and "none" or s
end
local last_u, last_m, last_vt, last_hp, last_in, win
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		T.ticks = T.ticks + 1
		if os.clock() - t0 > 600 then T.done = true return end
		if not F.on then last_u, last_m, last_vt, last_hp, last_in, win = nil, nil, nil, nil, nil, nil return end
		local u = F.unit
		local m = F.model or P.models(u)[1]
		if not m then return end
		if u ~= last_u then
			last_u = u
			note("ON " .. tostring(F.utype) .. (F.model and " one man" or " whole") .. ", men " .. u:number_of_men_alive()
				.. ", infantry " .. tostring(u:is_infantry()) .. ", cavalry " .. tostring(u:is_cavalry())
				.. ", single " .. tostring(u:number_of_men_alive() == 1))
		end
		if not (last_m and mr.eq(last_m, m)) then
			local mount = P.mount(m)
			note("model " .. mr.tostring(m) .. " class " .. mr.tostring(mr.read_pointer(m, 0)) .. " rows " .. rows(m)
				.. "| mount " .. tostring(mount and mr.tostring(mount)) .. " rows " .. rows(mount))
			last_m, last_vt, last_hp, last_in = m, nil, nil, nil
		end
		local vt = mr.tostring(mr.read_pointer(m, 0x330))
		local c = T.cmds[vt]
		if not c then c = {n = 0, clips = {}, nclips = 0} T.cmds[vt] = c end
		local clip = P.anim_slot(m)
		if vt ~= last_vt then
			c.n = c.n + 1
			last_vt = vt
			if c.n <= 2 then note("command " .. vt .. " clip " .. tostring(clip) .. (F.model and "" or " (whole)") .. ", in melee " .. tostring(u:is_in_melee())) end
		end
		if clip and not c.clips[clip] and c.nclips < 12 then c.clips[clip] = true c.nclips = c.nclips + 1 end
		local hp = P.model_hp(m)
		local inl = P.alive(u, m)
		if hp ~= last_hp and (hp <= 0 or (last_hp and last_hp > 0 and hp <= 0)) or inl ~= last_in then
			note("hp " .. tostring(hp) .. " in list " .. tostring(inl) .. " clip " .. tostring(clip) .. " command " .. vt
				.. " still played " .. tostring(F.model ~= nil and mr.eq(F.model, m)))
		end
		last_hp, last_in = hp, inl
		if not F.model then
			local q = u:position()
			if not win then win = {t = os.clock(), x = q:get_x(), z = q:get_z(), o = F.last_order}
			elseif os.clock() - win.t >= 1 then
				local d = math.sqrt((q:get_x() - win.x) ^ 2 + (q:get_z() - win.z) ^ 2)
				if F.last_order ~= win.o or d > 0.5 then
					note("whole: moved " .. math.floor(d * 10) / 10 .. " m in 1 s, order sent " .. tostring(F.last_order ~= win.o)
						.. ", in melee " .. tostring(u:is_in_melee()) .. ", clip " .. tostring(clip) .. ", command " .. vt)
				end
				win = {t = os.clock(), x = q:get_x(), z = q:get_z(), o = F.last_order}
			end
		end
	end)
	if not ok then T.err = tostring(err) T.done = true end
	if T.done then bm:remove_real_callback("tp_watch") end
end, 100, "tp_watch")
return "watching 10 minutes; base " .. T.base
