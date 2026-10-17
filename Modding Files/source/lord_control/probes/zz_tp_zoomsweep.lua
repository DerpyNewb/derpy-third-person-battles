-- Test scaffolding (2026-10-17): why the third-person eye comes in to his head at the closer zooms. One man of
-- _G.TP_ZS_TYPE (default the Hessmarine Bayonets) in third person, the view level; the zoom set to 1, 0.95 ... 0.6, 1.5 s
-- each; then: the eye ahead of his feet along the view (negative: behind) and up, the boom, the ground under the eye
-- from his feet, and how far above the eye asked the engine put it. Read with zz_tp_zoomsweep_read.lua. No string
-- library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local want = _G.TP_ZS_TYPE or "emp_hessmarines_bayonets"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 1 then u = x end
	end
	if not u then return "no " .. tostring(want) end
	if F.on then E.main.stop("zoom sweep") end
	E.first_person = false
	local saved = {}
	for _, k in ipairs({"held", "pressed", "focused", "look_begin", "look_delta", "wheel"}) do saved[k] = P[k] end
	P.held = function() return false end
	P.pressed = function() return false end
	P.focused = function() return true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	local T = {type = want, at = {}, done = false}
	_G.TP_ZS = T
	local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
	local function finish(why)
		T.done, T.why = true, why
		if F.on then pcall(E.main.stop, "zoom sweep") end
		for k, f in pairs(saved) do P[k] = f end
		pcall(function() bm:remove_real_callback("tp_zoomsweep") end)
	end
	E.main.start(u)
	if not F.on then finish("could not start") return T.why end
	P.wheel = function() return 0 end
	local zooms = {1, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6}
	local k, t0 = 1, os.clock()
	E.rig.zoom, E.rig.pitch, E.rig.want_pitch = zooms[1], 0, 0
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			if not F.on then finish("third person went off") return end
			if os.clock() - t0 < 1.5 then return end
			local R = E.rig
			local mx, my, mz = P.model_pos(F.model)
			local fx, fz = math.sin(R.yaw), math.cos(R.yaw)
			local ahead = (R.ex - mx) * fx + (R.ez - mz) * fz
			local ground = bm:get_terrain_height(R.ex, R.ez) - my
			local behind = bm:get_terrain_height(mx - fx * 6 * R.zoom, mz - fz * 6 * R.zoom) - my
			T.at[#T.at + 1] = "zoom " .. r2(R.zoom) .. ": eye ahead " .. r2(ahead) .. " up " .. r2(R.ey - my) .. " boom " .. r2(R.boom)
				.. " ground under eye " .. r2(ground) .. " ground at the full boom " .. r2(behind) .. " engine lift "
				.. r2(cam:position():get_y() - R.ey) .. " his y - R.sy " .. r2(my - R.sy)
			k = k + 1
			if not zooms[k] then finish("ran") return end
			R.zoom, t0 = zooms[k], os.clock()
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_zoomsweep")
	return "sweeping on " .. want
end)
return ok and res or "ERR " .. tostring(res)
