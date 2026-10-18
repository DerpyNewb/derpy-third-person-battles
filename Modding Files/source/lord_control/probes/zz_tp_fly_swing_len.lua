-- How long each of Be'lakor's air swings runs, 2026-10-18 (zz_tp_fly_swing.lua saw FLY_ATTACK_4 497 last 5.3 s or more
-- against 2.1-2.7 s for 494 and 495). Third person on; whenever no clip has played for 0.5 s, a click's swing
-- (E.combat.attack); every clip's start and end tick logged (100 ms), up to SWINGS swings or 40 s. NO string.* calls.
-- Read back with zz_tp_fly_swing_read.lua (it shares _G.TP_FS).
local E = _G.DERPY_TP
if not (E and E.main and E.combat) then return "no third person" end
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == "wh3_main_dae_cha_be_lakor_0" then u = units:item(i) end end
if not u then return "no Be'lakor" end
local SWINGS, END = 6, 400
local T = {n = 0, log = {}}
_G.TP_FS = T
local function note(s) T.log[#T.log + 1] = s end
local last, idle, swings, from = nil, 0, 0, 0
bm:repeat_real_callback(function()
	T.n = T.n + 1
	local ok, err = pcall(function()
		if T.n == 1 then
			if not E.F.on then E.main.start(u) end
			note("third person " .. tostring(E.F.on) .. " flying " .. tostring(u:is_currently_flying()))
		end
		local clip = E.P.anim_slot(E.P.models(u)[1])
		if clip ~= last then
			if last then note(tostring(last) .. " " .. (T.n - from) / 10 .. " s") end
			last, from = clip, T.n
		end
		idle = clip and 0 or idle + 1
		if idle >= 5 and swings < SWINGS and T.n > 1 then
			swings = swings + 1
			E.combat.attack(bm:time_elapsed_ms() / 1000, true, false)
			idle = 0
		end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= END or (swings >= SWINGS and idle >= 5) or not ok then
		bm:remove_real_callback("tp_fsl")
		T.ended = true
		note("flying " .. tostring(u:is_currently_flying()))
		pcall(E.main.stop, "fly swing length probe")
	end
end, 100, "tp_fsl")
return "started"
