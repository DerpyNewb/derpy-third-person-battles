-- The sprint's charge clip, 2026-10-18 (the author: "looping charging animation is not good and looks like its not
-- looping but being cut off mid animation"). Third person on _G.TP_CC_TYPE; only watches: the keys are real
-- (probes/tp_keys.ps1, W then Shift). Every 20 ms: each clip the pack sends (E.P.play wrapped, put back at the end) and
-- each change of the clip on the body that plays the charge (his mount, else him), model time, for 14 s. NO string.* calls.
-- Read back with zz_tp_fly_swing_read.lua (_G.TP_FS).
local E = _G.DERPY_TP
if not (E and E.main and E.combat) then return "no third person" end
local want = _G.TP_CC_TYPE
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == want then u = units:item(i) end end
if not u then return "no " .. tostring(want) end
local T = {n = 0, log = {}}
_G.TP_FS = T
local function note(s) T.log[#T.log + 1] = s end
local function t() return math.floor(bm:time_elapsed_ms() / 10 + 0.5) / 100 end
local play = E.P.play
E.P.play = function(m, slot, mask)
	if slot == 135 or slot == 102 or slot == 42 then pcall(note, t() .. " send " .. slot) end
	return play(m, slot, mask)
end
local last
bm:repeat_real_callback(function()
	T.n = T.n + 1
	local ok, err = pcall(function()
		if T.n == 1 then
			if not E.F.on then E.main.start(u) end
			note("on " .. tostring(E.F.on) .. " charges " .. tostring(E.D.charges and E.D.charges[want] and E.D.charges[want][1])
				.. " in melee " .. tostring(u:is_in_melee()))
		end
		local m = E.P.models(u)[1]
		m = m and (E.P.mount(m) or m)
		local s = tostring(m and E.P.anim_slot(m)) .. (E.F.sprinting and " sprint" or "")
		if s ~= last then note(t() .. " clip " .. s) last = s end
		-- his speed over each 0.5 s
		local q = u:position()
		if T.n % 25 == 0 then
			if T.p then note(t() .. " speed " .. math.floor(((q:get_x() - T.p[1]) ^ 2 + (q:get_z() - T.p[2]) ^ 2) ^ 0.5 * 20 + 0.5) / 10) end
			T.p = {q:get_x(), q:get_z()}
		end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= 700 or not ok then
		bm:remove_real_callback("tp_cc")
		E.P.play = play
		T.ended = true
	end
end, 20, "tp_cc")
return "started"
