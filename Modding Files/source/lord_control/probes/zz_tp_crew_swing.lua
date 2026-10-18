-- A crew on one body swings, 2026-10-18 (the Warsphinx's "clip 455 never played" in the author's log, played as one of
-- his crew). Third person on _G.TP_CS_TYPE, melee mode; a click through E.combat.attack every 4.5 s, 4 of them; every
-- 100 ms, logged on change: the first crewman's clip, his mount's, and whether the pack holds a lock, for 20 s. Ends third
-- person after. NO string.* calls. Read back with zz_tp_fly_swing_read.lua (_G.TP_FS).
local E = _G.DERPY_TP
if not (E and E.main and E.combat) then return "no third person" end
local want = _G.TP_CS_TYPE
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == want then u = units:item(i) end end
if not u then return "no " .. tostring(want) end
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
			if E.F.ranged then E.combat.mode(now) end
			note("on " .. tostring(E.F.on) .. " one man " .. tostring(E.F.model ~= nil) .. " single " .. tostring(E.F.single ~= nil)
				.. " ranged " .. tostring(E.F.ranged))
		end
		if T.n % 45 == 10 and T.n < 190 then E.combat.attack(now, true, false) note(math.floor(now * 10 + 0.5) / 10 .. " click") end
		local m = E.P.models(u)[1]
		local mt = m and E.P.mount(m)
		local s = tostring(m and E.P.anim_slot(m)) .. "/" .. tostring(mt and E.P.anim_slot(mt)) .. " lock " .. tostring(E.F.lock ~= nil)
		if s ~= last then note(math.floor(now * 10 + 0.5) / 10 .. " " .. s) last = s end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= 200 or not ok then
		bm:remove_real_callback("tp_cs")
		T.ended = true
		pcall(E.main.stop, "crew swing probe")
	end
end, 100, "tp_cs")
return "started"
