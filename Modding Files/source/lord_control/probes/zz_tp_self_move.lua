-- The regiment moving the man third person plays, 2026-10-16 (the author: "battalion actions also affect the unit which
-- shouldnt be and its moving itself the unit whenever the battalion is affected"). Read only, 10 minutes, every 0.1 s
-- real time, across third person going off and on: each time his command is replaced (+0x330's vtable, as memreader's
-- hex), and each second he covers more than half a metre with no move key down and no shot or action of ours, with what
-- his regiment was doing then. No string library calls. Read back: zz_tp_self_move_read.lua.
local E = _G.DERPY_TP
if not (E and E.P and E.S) then return "load the pack first" end
local mr = _G.memreader_plus
if not mr then return "no memreader_plus" end
if _G.TP_SELF_MOVE and not _G.TP_SELF_MOVE.done then return "already running" end
local P, F, S = E.P, E.F, E.S
local T = {base = mr.tostring(mr.base), events = {}, vts = {}, done = false, ticks = 0}
_G.TP_SELF_MOVE = T
local t0, last_vt, last_m, win
local function note(s)
	if #T.events < 400 then T.events[#T.events + 1] = math.floor((os.clock() - t0) * 10) / 10 .. "s " .. s end
end
local function keys()
	local k = S.keys
	return P.held(k.forward) or P.held(k.back) or P.held(k.left) or P.held(k.right)
end
local function ctx(u)
	local q, o = u:position(), u:ordered_position()
	return "regiment: melee " .. tostring(u:is_in_melee()) .. ", moving " .. tostring(u:is_moving()) .. ", order "
		.. math.floor(math.sqrt((o:get_x() - q:get_x()) ^ 2 + (o:get_z() - q:get_z()) ^ 2)) .. " m off; his clip "
		.. tostring(P.anim_slot(F.model)) .. ", keys " .. tostring(keys()) .. ", shot " .. tostring(F.shot ~= nil)
		.. ", action " .. tostring(F.lock ~= nil) .. ", charging " .. tostring(F.charging)
end
t0 = os.clock()
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		T.ticks = T.ticks + 1
		if os.clock() - t0 > 600 then T.done = true return end
		if not (F.on and F.model) then last_m, last_vt, win = nil, nil, nil return end
		local m, u = F.model, F.unit
		if not (last_m and P.same(last_m, m)) then last_m, last_vt, win = m, nil, nil note("playing " .. tostring(F.utype)) end
		local vt = mr.tostring(mr.read_pointer(m, 0x330))
		if vt ~= last_vt then
			T.vts[vt] = (T.vts[vt] or 0) + 1
			if T.vts[vt] <= 3 then note("command " .. vt .. " (" .. tostring(P.command(m)) .. "); " .. ctx(u)) end
			last_vt = vt
		end
		local x, _, z = P.model_pos(m)
		local ours = keys() or F.shot ~= nil or F.lock ~= nil
		if ours or not win then win = {t = os.clock(), x = x, z = z}
		elseif os.clock() - win.t >= 1 then
			local d = math.sqrt((x - win.x) ^ 2 + (z - win.z) ^ 2)
			if d > 0.5 then note("moved " .. math.floor(d * 10) / 10 .. " m by himself in 1 s, command " .. vt .. "; " .. ctx(u)) end
			win = {t = os.clock(), x = x, z = z}
		end
	end)
	if not ok then T.err = tostring(err) T.done = true end
	if T.done then bm:remove_real_callback("tp_self_move") end
end, 100, "tp_self_move")
return "recording 10 minutes; base " .. T.base
