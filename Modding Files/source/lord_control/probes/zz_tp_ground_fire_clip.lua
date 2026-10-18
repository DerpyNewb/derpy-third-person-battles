-- A ground-fire shot's clip against the pack's commit, 2026-10-18 (the author: "Kugath cant use his ranged attack ...
-- why cant the full animation play"). Third person on Ku'gath (_G.TP_GF_TYPE overrides), one click through
-- E.combat.attack as the frame calls it; every 100 ms, logged on change: his clip, his mount's, his ammo, the pack's firing
-- state and his bearing (10 deg steps), for 25 s. NO string.* calls. Read back with zz_tp_fly_swing_read.lua (_G.TP_FS).
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
			note("on " .. tostring(E.F.on) .. " ranged " .. tostring(E.F.ranged) .. " ammo " .. u:ammo_left() .. " range "
				.. u:missile_range())
		end
		if T.n == 10 then
			E.combat.attack(now, true, false)
			note("click at " .. now)
		end
		-- _G.TP_GF_NUDGE: deg the view turns every _G.TP_GF_EVERY ticks (1.5 s) while the shot waits, as a player's camera
		-- does (re-aims past 5 m); the sign flips each time, so the view swings about the first aim
		if _G.TP_GF_NUDGE and T.n > 10 and T.n % (_G.TP_GF_EVERY or 15) == 0 and E.F.firing then
			T.sign = -(T.sign or -1)
			_G.TP_GF_NUDGE = math.abs(_G.TP_GF_NUDGE) * T.sign
			E.rig.yaw = E.rig.yaw + math.rad(_G.TP_GF_NUDGE)
			note(math.floor(now * 10 + 0.5) / 10 .. " nudge")
		end
		local m = E.P.models(u)[1]
		local mt = m and E.P.mount(m)
		local s = tostring(m and E.P.anim_slot(m)) .. "/" .. tostring(mt and E.P.anim_slot(mt)) .. " ammo " .. u:ammo_left()
			.. " firing " .. tostring(E.F.firing) .. " bearing " .. math.floor(u:bearing() / 10) * 10
		if s ~= last then note(math.floor(now * 10 + 0.5) / 10 .. " " .. s) last = s end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= 250 or not ok then
		bm:remove_real_callback("tp_gf")
		T.ended = true
		pcall(E.main.stop, "ground fire clip probe")
	end
end, 100, "tp_gf")
return "started"
