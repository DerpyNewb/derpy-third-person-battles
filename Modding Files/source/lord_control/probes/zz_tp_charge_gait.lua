-- Test scaffolding (2026-10-18): what the engine's own charge puts in a unit of one's walk. Third person off; the unit of
-- _G.TP_CG_TYPE (Harald by default) is ordered to attack the nearest enemy unit at the run (CA's attack_unit), and for
-- 6 s every change of his command, its gait byte (+0x3ae, the steer writes 0 walk / 1 run), its run flag (+0x390?) and
-- speed (+0x394), and his clip is kept, with his speed every 0.5 s. Then he is halted. Read: _G.TP_CG.
-- No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.P and mr) then return "no pack" end
	local P, F = E.P, E.F
	if F.on then pcall(E.main.stop, "charge gait test") end
	local want = _G.TP_CG_TYPE or "wh3_pro11_chs_cha_harald_hammerstorm"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do local x = army:units():item(i) if x:type() == want then u = x end end
	if not u then return "no " .. want end
	local q, best, bd = u:position(), nil, nil
	local all = bm:get_non_player_alliance():armies()
	for a = 1, all:count() do
		local l = all:item(a):units()
		for i = 1, l:count() do
			local e = l:item(i)
			if e:number_of_men_alive() > 0 then
				local p = e:position()
				local d = (p:get_x() - q:get_x()) ^ 2 + (p:get_z() - q:get_z()) ^ 2
				if not bd or d < bd then best, bd = e, d end
			end
		end
	end
	if not best then return "no enemy" end
	local T = {rows = {}, speeds = {}, dist = math.floor(math.sqrt(bd))}
	_G.TP_CG = T
	local c = army:create_unit_controller()
	c:add_units(u)
	_G.TP_CG_UC = c
	-- _G.TP_CG_AT m from the target (45 by default), facing it: inside the range a charge starts from
	local at = _G.TP_CG_AT or 45
	local p = best:position()
	local dx, dz = q:get_x() - p:get_x(), q:get_z() - p:get_z()
	local n = math.sqrt(dx * dx + dz * dz)
	local sx, sz = p:get_x() + dx / n * at, p:get_z() + dz / n * at
	c:teleport_to_location(v(sx, bm:get_terrain_height(sx, sz), sz), math.deg(math.atan2(-dx, -dz)) % 360, 1)
	T.dist = at
	c:attack_unit(best, true, true)
	local m = P.models(u)[1]
	local b = P.mount(m) or m
	local function now() return bm:time_elapsed_ms() / 1000 end
	local t0, last, lp = now(), nil, nil
	local function r1(x) return math.floor(x * 100 + 0.5) / 100 end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			local t = now() - t0
			if t > 9 then
				bm:remove_real_callback("tp_charge_gait")
				c:halt() c:release_control()
				T.done = true
				return
			end
			local key = mr.tostring(mr.read_pointer(b, 0x330)) .. " gait " .. mr.read_uint8(b, 0x3ae) .. " run "
				.. mr.read_uint32(b, 0x390) .. " speed " .. r1(mr.read_float(b, 0x394)) .. " clip " .. tostring(P.anim_slot(b))
			if key ~= last and #T.rows < 120 then T.rows[#T.rows + 1] = r1(t) .. " " .. key last = key end
			local x, _, z = P.model_pos(b)
			if not lp then lp = {x, z, t} elseif t - lp[3] >= 0.5 then
				T.speeds[#T.speeds + 1] = r1(t) .. ":" .. r1(math.sqrt((x - lp[1]) ^ 2 + (z - lp[2]) ^ 2) / (t - lp[3]))
				lp = {x, z, t}
			end
		end)
		if not worked then T.err = tostring(err) bm:remove_real_callback("tp_charge_gait") T.done = true end
	end, 1, "tp_charge_gait")
	return "charging " .. best:type() .. " " .. T.dist .. " m off"
end)
return ok and res or "ERR " .. tostring(res)
