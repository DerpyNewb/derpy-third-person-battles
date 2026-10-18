-- Re-aims under the engine's own shot, 2026-10-18 (the author: "moving the mouse and aiming for fire, it keeps repeating
-- the aim animation and never firing"; their log, the Necrofex Colossus: a fire order every 0.6 s as the crosshair moved).
-- Third person on _G.TP_RA_TYPE, then the order fire() sends, at the crosshair; every _G.TP_RA_EVERY ticks (6: 0.6 s) the
-- order again, 10 m to one side of that point and then the other - none when _G.TP_RA_EVERY is 0. Every 100 ms, logged on
-- change: the first man's clip, his mount's, the ammo; for 18 s. NO string.* calls. Read back with zz_tp_fly_swing_read.lua.
local E = _G.DERPY_TP
if not (E and E.main and E.combat) then return "no third person" end
local want = _G.TP_RA_TYPE or "wh2_dlc11_cst_mon_necrofex_colossus_0"
local every = _G.TP_RA_EVERY or 6
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == want then u = units:item(i) end end
if not u then return "no " .. want end
local T = {n = 0, log = {}}
_G.TP_FS = T
local function note(s) T.log[#T.log + 1] = s end
local last, aim, side
local function order(x, z) E.F.uc:attack_location(v(x, bm:get_terrain_height(x, z), z), false) E.F.uc:release_control() end
bm:repeat_real_callback(function()
	T.n = T.n + 1
	local ok, err = pcall(function()
		local now = bm:time_elapsed_ms() / 1000
		if T.n == 1 then
			if not E.F.on then E.main.start(u) end
			note("on " .. tostring(E.F.on) .. " ammo " .. u:ammo_left() .. " every " .. every)
		end
		if T.n == 10 then
			local ax, _, az = E.combat.aim_point(u:missile_range())
			aim, side = {ax, az}, 1
			E.F.uc:fire_at_will(true)
			order(ax, az)
			note(math.floor(now * 10 + 0.5) / 10 .. " order")
		elseif aim and every > 0 and T.n > 10 and (T.n - 10) % every == 0 then
			side = -side
			order(aim[1] + 10 * side, aim[2])
			T.reaims = (T.reaims or 0) + 1
		end
		local m = E.P.models(u)[1]
		local mt = m and E.P.mount(m)
		local s = tostring(m and E.P.anim_slot(m)) .. "/" .. tostring(mt and E.P.anim_slot(mt)) .. " ammo " .. u:ammo_left()
		if s ~= last then note(math.floor(now * 10 + 0.5) / 10 .. " " .. s .. " (re-aims " .. tostring(T.reaims or 0) .. ")") last = s end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= 180 or not ok then
		bm:remove_real_callback("tp_ra")
		T.ended = true
		pcall(function() E.F.uc:halt() E.F.uc:release_control() end)
		pcall(E.main.stop, "re-aim probe")
		-- no shot on his own before the next run: its reload starts from a known shot
		pcall(function() local uc = create_unitcontroller(u) uc:fire_at_will(false) uc:halt() uc:release_control() end)
	end
end, 100, "tp_ra")
return "started"
