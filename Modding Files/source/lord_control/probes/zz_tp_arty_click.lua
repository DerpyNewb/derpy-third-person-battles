-- Test scaffolding (2026-10-18, the author: artillery in third person "I am only controlling the gunners ... When I clicked
-- the mouse, all the gunners uniformly started slashing"). Third person on _G.TP_AC_IDX (player army index) through the
-- shipped start and frame loop; after 1 s the attack key read as pressed and then held for _G.TP_AC_HOLD s (synthetic:
-- the question is what a click does to a gun). Records F.ranged, the pack's log lines, every clip P.play sends and the
-- ammo. Read: _G.TP_AC. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local u = bm:get_player_army():units():item(_G.TP_AC_IDX or 18)
	if F.on then E.main.stop("arty click test") end
	local T = {type = u:type(), log = {}, plays = 0, done = false, ammo0 = u:ammo_left()}
	_G.TP_AC = T
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel", "play"}) do saved[k] = P[k] end
	local log_was = E.log
	local atk = E.S.keys.attack
	local id = type(atk) == "table" and atk[1] or atk
	local held, pressed = false, false
	P.held = function(k) return held and (type(k) == "table" and k[1] or k) == id end
	P.pressed = function(k) if pressed and (type(k) == "table" and k[1] or k) == id then pressed = false return true end return false end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
	P.play = function(m, slot, mask) T.plays = T.plays + 1 T.last_play = slot return saved.play(m, slot, mask) end
	E.log = function(msg) if #T.log < 40 then T.log[#T.log + 1] = math.floor((os.clock() - (T.t0 or os.clock())) * 10) / 10 .. " " .. tostring(msg) end return log_was(msg) end
	local function put_back()
		for k, f in pairs(saved) do P[k] = f end
		E.log = log_was
		if F.on then pcall(E.main.stop, "arty click test") end
	end
	E.main.start(u)
	T.ranged, T.arty = F.ranged, F.arty
	-- the view along his facing, tipped down so the crosshair meets the ground inside his range
	local b = math.rad(u:bearing())
	-- _G.TP_AC_AT_ENEMY: the view turned to the nearest enemy unit instead
	if _G.TP_AC_AT_ENEMY then
		local q, best = u:position(), nil
		local all = bm:get_non_player_alliance():armies()
		for a = 1, all:count() do
			for i = 1, all:item(a):units():count() do
				local p = all:item(a):units():item(i):position()
				local dx, dz = p:get_x() - q:get_x(), p:get_z() - q:get_z()
				if not best or dx * dx + dz * dz < best then best, b = dx * dx + dz * dz, math.atan2(dx, dz) end
			end
		end
	end
	E.rig.yaw, E.rig.want_yaw, E.rig.pitch, E.rig.want_pitch = b, b, 0.25, 0.25
	local t0 = os.clock()
	T.t0, T.clips = t0, {}
	local crew = P.models(u)[1]
	local gun = crew and P.mount(crew)
	local last_clip
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = os.clock() - t0
			local c = gun and P.anim_slot(gun)
			if c ~= last_clip and #T.clips < 40 then last_clip = c T.clips[#T.clips + 1] = math.floor(t * 10) / 10 .. " gun " .. tostring(c) .. " ammo " .. u:ammo_left() end
			if t >= 1 and not T.clicked then T.clicked, pressed, held = true, true, true end
			if t >= 1 + (_G.TP_AC_HOLD or 8) then
				held = false
				T.ammo1, T.done = u:ammo_left(), true
				put_back()
				bm:remove_real_callback("tp_arty_click")
			end
		end)
		if not worked then T.err = tostring(err) T.done = true put_back() pcall(function() bm:remove_real_callback("tp_arty_click") end) end
	end, 1, "tp_arty_click")
	return "clicking " .. u:type() .. " ranged " .. tostring(F.ranged)
end)
return ok and res or "ERR " .. tostring(res)
