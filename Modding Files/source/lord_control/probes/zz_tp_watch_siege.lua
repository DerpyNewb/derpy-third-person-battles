-- Test scaffolding (2026-10-18, the author: "in sieges, the unit cannot move normally forward, as if theres a
-- barrier"). Watches, never drives: the keys are real (tp_keys.ps1), the start is F2. For _G.TP_WG_SECONDS (default 30)
-- s, every 0.25 s while third person is on, a row: his position and height, the point P.steer asked for, and his walk
-- command's own copy of it (+0x368 x, +0x36c y, +0x370 z), its path slots (+0x378, +0x380, +0x3a0, +0x3b8 - null when
-- built from our block), +0x39c (our 3), the cached destination byte +0x3c0, the speed +0x394, and his speed over 0.5 s.
-- _G.TP_WG_LEAD: his steering point that many metres ahead instead (the direction move.lua chose kept).
-- Read: _G.TP_WG.rows. No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.main and E.P and mr) then return "no pack" end
	if _G.TP_WG and not _G.TP_WG.done then return "already watching" end
	local P, F = E.P, E.F
	local T = {rows = {}, done = false, steers = 0}
	_G.TP_WG = T
	local steer0 = P.steer
	P.steer = function(m, x, z, run, yaw, scale)
		T.steers = T.steers + 1
		local bx, _, bz = P.model_pos(P.mount(m) or m)
		local d = math.sqrt((x - bx) ^ 2 + (z - bz) ^ 2)
		local L = _G.TP_WG_LEAD
		if L and d > 0 then x, z = bx + (x - bx) * L / d, bz + (z - bz) * L / d end
		T.ax, T.az = x, z
		return steer0(m, x, z, run, yaw, scale)
	end
	local function r1(x) return math.floor(x * 100 + 0.5) / 100 end
	local function q(b, o) local p = mr.read_pointer(b, o) return mr.is_null(p) and "0" or "P" end
	local t0, last, hist = os.clock(), -1, {}
	local function finish()
		T.done = true
		P.steer = steer0
		pcall(function() bm:remove_real_callback("tp_watch_siege") end)
	end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			local t = os.clock() - t0
			if t > (_G.TP_WG_SECONDS or 30) or _G.TP_WG_STOP then finish() return end
			if t - last < 0.25 then return end
			last = t
			if not F.on then hist = {} return end
			local man = F.model or F.single
			local b = man and (P.mount(man) or man)
			if not b then return end
			local x, y, z = P.model_pos(b)
			hist[#hist + 1] = {t, x, z}
			local sp = -1
			for i = #hist, 1, -1 do
				if t - hist[i][1] >= 0.5 then sp = math.sqrt((x - hist[i][2]) ^ 2 + (z - hist[i][3]) ^ 2) / (t - hist[i][1]) break end
			end
			local who = mr.tostring(b)
			if who ~= T.who then hist, T.who = {{t, x, z}}, who end
			-- his own walk (walk_b) told from the regiment's (walk_a): both read "walk" to P.command; vtables from the mailbox
			local cmd = P.command(b)
			local vt, blk = mr.read_pointer(b, 0x330), P.mailbox
			if blk and mr.eq(vt, mr.read_pointer(blk, 0x8)) then T.na = (T.na or 0) + 1 cmd = "walk_a(regiment)"
			elseif blk and mr.eq(vt, mr.read_pointer(blk, 0x28)) then cmd = "walk" end
			local row = r1(t) .. " " .. F.unit:type() .. (F.model and " MODEL" or " SINGLE") .. " pos " .. r1(x) .. "," .. r1(y) .. "," .. r1(z)
				.. " asked " .. (T.ax and (r1(T.ax - x) .. "," .. r1(T.az - z)) or "-") .. " cmd " .. tostring(cmd)
			if cmd == "walk" then
				row = row .. " wpt " .. r1(mr.read_float(b, 0x368) - x) .. "," .. r1(mr.read_float(b, 0x36c) - y) .. "," .. r1(mr.read_float(b, 0x370) - z)
					.. " paths " .. q(b, 0x378) .. q(b, 0x380) .. q(b, 0x3a0) .. q(b, 0x3b8) .. " k " .. mr.read_int32(b, 0x39c)
					.. " fresh " .. mr.read_uint8(b, 0x3c0) .. " cspeed " .. r1(mr.read_float(b, 0x394))
				-- _G.TP_WG_RAW: the command's dwords +0x338..+0x3cc, to diff a walking frame against a held one
				if _G.TP_WG_RAW then
					local d = {}
					for o = 0x338, 0x3cc, 4 do d[#d + 1] = mr.read_uint32(b, o) end
					row = row .. " raw " .. table.concat(d, ",")
				end
			end
			local R = E.rig
			local cp = cam:position()
			row = row .. " cam asked " .. (R.ey and r1(R.ey - y) or "-") .. " got " .. r1(cp:get_y() - y) .. " off " .. r1(math.sqrt((cp:get_x() - x) ^ 2 + (cp:get_z() - z) ^ 2))
				.. " boom " .. r1(R.boom or -1) .. " ground " .. r1(bm:get_terrain_height(x, z) - y)
			if #T.rows < 400 then T.rows[#T.rows + 1] = row .. " clip " .. tostring(P.anim_slot(b)) .. " melee " .. tostring(F.unit:is_in_melee()) .. " m/s " .. r1(sp) end
		end)
		if not worked then T.err = tostring(err) finish() end
	end, 1, "tp_watch_siege")
	return "watching " .. (_G.TP_WG_SECONDS or 30) .. " s"
end)
return ok and res or "ERR " .. tostring(res)
