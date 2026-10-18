-- Test scaffolding (2026-10-18, the author: "if its around a building, it would go way up"). Watches, never drives:
-- every 100 ms while third person is on (not first person), counts samples, and logs a row when the engine put the eye
-- over LIFT_TOL above every one of the rig's last three asked heights (rig.lua's own lift test) or the boom is pulled in:
-- where the eye was, the ground under it, his height, the boom. _G.TP_LW_MODE "read" returns them, "off" stops.
-- _G.TP_LW_SECONDS (default 600). No string library calls.
local ok, res = pcall(function()
	local mode = _G.TP_LW_MODE or "on"
	if mode == "read" then
		local W = _G.TP_LW or {rows = {}}
		local s = "samples " .. (W.n or 0) .. " lifted " .. (W.lifts or 0) .. " pulled " .. (W.pulled or 0) .. (W.err and (" ERR " .. W.err) or "") .. " | "
		for _, l in ipairs(W.rows) do s = s .. l .. " | " end
		return s
	end
	bm:remove_real_callback("tp_cam_lift_watch")
	if mode == "off" then return "off" end
	local W = {rows = {}, n = 0, lifts = 0, pulled = 0}
	_G.TP_LW = W
	local t0 = os.clock()
	local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if os.clock() - t0 > (_G.TP_LW_SECONDS or 600) then bm:remove_real_callback("tp_cam_lift_watch") return end
			local E = _G.DERPY_TP
			local R, F = E and E.rig, E and E.F
			if not (F and F.on and R and R.ey and not R.first) then return end
			W.n = W.n + 1
			local c = cam:position()
			local asked = math.max(R.ey, R.ey1 or R.ey, R.ey2 or R.ey)
			local lift = c:get_y() - asked
			local pulled = (R.boom or 1) < 0.95
			if lift > 0.3 then W.lifts = W.lifts + 1 end
			if pulled then W.pulled = W.pulled + 1 end
			if (lift > 0.3 or pulled) and #W.rows < 120 then
				W.rows[#W.rows + 1] = r1(os.clock() - t0) .. "s " .. F.unit:type() .. " lift " .. r1(lift) .. " boom " .. r1(R.boom or -1)
					.. " eye " .. r1(c:get_x()) .. "," .. r1(c:get_y()) .. "," .. r1(c:get_z())
					.. " ground " .. r1(bm:get_terrain_height(c:get_x(), c:get_z())) .. " him y " .. r1(R.sy)
			end
		end)
		if not worked then W.err = tostring(err) bm:remove_real_callback("tp_cam_lift_watch") end
	end, 100, "tp_cam_lift_watch")
	return "watching lifts " .. (_G.TP_LW_SECONDS or 600) .. " s"
end)
return ok and res or "ERR " .. tostring(res)
