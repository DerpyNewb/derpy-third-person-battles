-- Eight walk/stop handovers with an enemy already pinned in range. Run after the bridge loader.
local E, mr = assert(_G.DERPY_TP), assert(_G.memreader_plus)
local P, u = E.P, bm:get_player_army():units():item(3)
assert(u:type():find("crossbow"), "player unit 3 must be crossbowmen")
E.main.stop("cycle test")
local focused, held, pressed = P.focused, P.held, P.pressed
local T = {cycles = {}, commands = {}, done = false, started = bm:time_elapsed_ms()}
_G.TP_CYCLE_TEST = T
local walking, stage, at, m = false, "start", T.started, nil
P.focused = function() return true end
P.held = function(k) return k == E.S.keys.look_free or (walking and k == E.S.keys.forward) end
P.pressed = function() return false end
local function finish(why)
	P.focused, P.held, P.pressed = focused, held, pressed
	E.main.stop("cycle test complete")
	bm:remove_real_callback("tp_cycle_test")
	T.done, T.reason, T.strikes = true, why, E.strikes
end
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		local now = bm:time_elapsed_ms()
		if stage == "start" then
			E.main.start(u)
			m = E.F.model
			assert(m and E.F.solo, "one-man shooting must be active")
			T.cycles[#T.cycles + 1] = {from = {P.model_pos(m)}, ammo_before = u:ammo_left(), off_frames = {}}
			walking, stage, at = true, "walk", now
		end
		assert(P.alive(u, m), "test soldier died")
		local command = mr.tostring(mr.read_pointer(m, 0x330))
		T.commands[command] = (T.commands[command] or 0) + 1
		local row = T.cycles[#T.cycles]
		if stage == "walk" and now - at >= 2000 then
			row.to = {P.model_pos(m)}
			walking, stage, at = false, "hold", now
		elseif stage == "hold" and now - at >= 500 then
			E.main.stop("cycle handover")
			row.ammo_off = u:ammo_left()
			stage, at = "off", now
		elseif stage == "off" then
			if #row.off_frames < 16 then
				row.off_frames[#row.off_frames + 1] = {dt = now - at, command = command,
					state = mr.read_uint16(m, 0x318), state_hi = mr.read_uint16(m, 0x31a),
					union_lo = mr.read_uint16(m, 0x368), union_hi = mr.read_uint16(m, 0x36a)}
			end
			if now - at >= 3000 then
				row.ammo_after = u:ammo_left()
				if #T.cycles == 8 then finish("eight handovers completed") else stage = "start" end
			end
		end
	end)
	if not ok then finish(tostring(err)) end
end, 50, "tp_cycle_test")
return "eight controlled handovers started; read _G.TP_CYCLE_TEST after about 45 seconds"
