-- The engine's own ground-fire shot with nothing to halt it, 2026-10-18: third person on Ku'gath (_G.TP_GF_TYPE
-- overrides), then the order fire() sends - fire at will on, attack_location at the crosshair's point - sent here once,
-- no click, so the pack's commit never runs. Every 100 ms, logged on change: his clip, his mount's, his ammo, his bearing
-- (10 deg steps), for 15 s. NO string.* calls. Read back with zz_tp_fly_swing_read.lua (_G.TP_FS).
local E = _G.DERPY_TP
if not (E and E.main and E.combat) then return "no third person" end
local want = _G.TP_GF_TYPE or "wh3_main_nur_cha_ku_gath_plaguefather_0"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == want then u = units:item(i) end end
if not u then return "no " .. want end
local T = {n = 0, log = {}}
_G.TP_FS = T
local function note(s) T.log[#T.log + 1] = s end
local last
bm:repeat_real_callback(function()
	T.n = T.n + 1
	local ok, err = pcall(function()
		local now = bm:time_elapsed_ms() / 1000
		if T.n == 1 then
			if not E.F.on then E.main.start(u) end
			note("on " .. tostring(E.F.on) .. " ammo " .. u:ammo_left())
		end
		if T.n == 10 then
			local ax, ay, az = E.combat.aim_point(u:missile_range())
			local q = u:position()
			note("order at " .. now .. " to " .. math.floor(ax) .. "," .. math.floor(az) .. " from " .. math.floor(q:get_x()) .. ","
				.. math.floor(q:get_z()))
			E.F.uc:fire_at_will(true)
			E.F.uc:attack_location(v(ax, bm:get_terrain_height(ax, az), az), false)
			E.F.uc:release_control()
		end
		local m = E.P.models(u)[1]
		local mt = m and E.P.mount(m)
		local s = tostring(m and E.P.anim_slot(m)) .. "/" .. tostring(mt and E.P.anim_slot(mt)) .. " ammo " .. u:ammo_left()
			.. " bearing " .. math.floor(u:bearing() / 10) * 10
		if s ~= last then note(math.floor(now * 10 + 0.5) / 10 .. " " .. s) last = s end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= 150 or not ok then
		bm:remove_real_callback("tp_gff")
		T.ended = true
		pcall(function() E.F.uc:halt() E.F.uc:release_control() end)
		pcall(E.main.stop, "ground fire free probe")
	end
end, 100, "tp_gff")
return "started"
