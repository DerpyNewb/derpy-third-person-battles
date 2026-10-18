-- Test scaffolding (2026-10-18, the author: "charging does not make harald faster than running", "are you testing it
-- properly?"). Watches, never drives: the keys are real (sent to the game window by tools outside), the start is F2.
-- For _G.TP_WS_SECONDS (default 40) s, every 0.25 s while third person is on, a row: his unit type, whether he is steered
-- alone (F.single) or as one man (F.model), F.walking / F.running / F.sprinting / F.charging, stamina, the speed the
-- frame loop asked E.move.drive for, the scale and run flag the last P.steer carried, his command and its speed (+0x394),
-- and his speed over the last 0.5 s. P.steer and E.move.drive are wrapped only to record their arguments.
-- Read: _G.TP_WS.rows. No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.main and E.P and mr) then return "no pack" end
	if _G.TP_WS and not _G.TP_WS.done then return "already watching" end
	local P, F = E.P, E.F
	local T = {rows = {}, done = false, steers = 0, drives = 0}
	_G.TP_WS = T
	local steer0, drive0 = P.steer, E.move.drive
	-- _G.TP_WS_LEAD: the experiment (as zz_tp_run_speed.lua's TP_RS_LEAD) - his steering point that many metres ahead,
	-- the direction move.lua chose kept
	P.steer = function(m, x, z, run, yaw, scale)
		T.steers = T.steers + 1
		local bx, _, bz = P.model_pos(P.mount(m) or m)
		T.s_run, T.s_scale, T.s_lead = run, scale, math.floor(math.sqrt((x - bx) ^ 2 + (z - bz) ^ 2) * 10) / 10
		local L = _G.TP_WS_LEAD
		if L and T.s_lead > 0 then x, z = bx + (x - bx) * L / T.s_lead, bz + (z - bz) * L / T.s_lead end
		return steer0(m, x, z, run, yaw, scale)
	end
	E.move.drive = function(now, kf, kr, run, speed)
		T.drives = T.drives + 1
		T.d_run, T.d_speed, T.d_keys = run, speed, kf .. "," .. kr
		return drive0(now, kf, kr, run, speed)
	end
	local function now() return os.clock() end
	local function r1(x) return math.floor(x * 100 + 0.5) / 100 end
	local t0, last, hist = now(), -1, {}
	local function finish()
		T.done = true
		P.steer, E.move.drive = steer0, drive0
		pcall(function() bm:remove_real_callback("tp_watch_sprint") end)
	end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			local t = now() - t0
			if t > (_G.TP_WS_SECONDS or 40) or _G.TP_WS_STOP then finish() return end
			if t - last < 0.25 then return end
			last = t
			if not F.on then hist = {} return end
			local man = F.model or F.single
			local b = man and (P.mount(man) or man)
			local x, z
			if b then x, _, z = P.model_pos(b) else local q = F.unit:position() x, z = q:get_x(), q:get_z() end
			hist[#hist + 1] = {t, x, z}
			local sp = -1
			for i = #hist, 1, -1 do
				if t - hist[i][1] >= 0.5 then sp = math.sqrt((x - hist[i][2]) ^ 2 + (z - hist[i][3]) ^ 2) / (t - hist[i][1]) break end
			end
			local cmd = b and mr.tostring(mr.read_pointer(b, 0x330)) or "-"
			-- the man played can change (dead, or the front man again at a start): a row says which
			local who = b and mr.tostring(b) or "-"
			if who ~= T.who then hist, T.who = {{t, x, z}}, who end
			if #T.rows < 400 then
				T.rows[#T.rows + 1] = r1(t) .. " " .. F.unit:type() .. (F.model and " MODEL" or "") .. (F.single and " SINGLE" or "")
					.. " walk " .. tostring(F.walking) .. " run " .. tostring(F.running) .. " spr " .. tostring(F.sprinting)
					.. " chg " .. tostring(F.charging) .. " stam " .. r1(F.stamina or -1) .. " drive " .. tostring(T.d_keys)
					.. " x" .. tostring(T.d_speed) .. " steer run " .. tostring(T.s_run) .. " x" .. tostring(T.s_scale) .. " lead " .. tostring(T.s_lead)
					.. " n " .. T.drives .. "/" .. T.steers .. " cmd " .. cmd .. " cmdspeed "
					.. (b and r1(mr.read_float(b, 0x394)) or -1) .. " clip " .. tostring(b and P.anim_slot(b)) .. " m/s " .. r1(sp) .. " man " .. who
			end
		end)
		if not worked then T.err = tostring(err) finish() end
	end, 1, "tp_watch_sprint")
	return "watching " .. (_G.TP_WS_SECONDS or 40) .. " s"
end)
return ok and res or "ERR " .. tostring(res)
