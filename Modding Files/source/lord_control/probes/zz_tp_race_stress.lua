-- Test scaffolding (2026-10-17), expected to crash the game: the OLD guard route, multiplied. Every 30 ms, every man of
-- the first regiment of _G.TP_RS_TYPE (default teb_montante_greatswords, put into a melee by zz_tp_engage.lua first)
-- whose command is one of the engine's four (regiment walk, two moves, melee) gets the engine's stop (exe+306edd4)
-- called FROM THE SCRIPT THREAD, as P.guard did before the mailbox. If destroying a command from here is what crashed
-- (exe+7AB1DA, exe+305B39A), this falls over far sooner than one man did. _G.TP_RS counts the calls; the crash
-- report's time against T.t0 (os.time) gives the time to the crash. No string library calls.
local E, mr = _G.DERPY_TP, _G.memreader_plus
if not (E and mr and E.P.build == "6acec6f4") then return "the pack on 6acec6f4 first" end
local P = E.P
local function at(hi, lo) return mr.add(mr.add(mr.base, hi), lo) end
local STOP = at(0x3060000, 0xedd4)
local ENGINE = {at(0x3910000, 0x9350), at(0x3910000, 0x99f8), at(0x3ae0000, 0x1928), at(0x3ad0000, 0x24b8)}
local want = _G.TP_RS_TYPE or "teb_montante_greatswords"
local army, u = bm:get_player_army(), nil
for i = 1, army:units():count() do
	local x = army:units():item(i)
	if not u and x:type() == want and x:number_of_men_alive() > 0 then u = x end
end
if not u then return "no " .. want end
if E.F.on then pcall(E.main.stop, "test") end
local T = {calls = 0, ticks = 0, t0 = os.time(), done = false}
_G.TP_RS = T
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		if T.done then return end
		T.ticks = T.ticks + 1
		for _, m in ipairs(P.models(u)) do
			local body = P.mount(m) or m
			if P.model_hp(body) > 0 then
				local c = mr.read_pointer(body, 0x330)
				for _, e in ipairs(ENGINE) do
					if mr.eq(c, e) then mr.call(STOP, "pointer(pointer)", body) T.calls = T.calls + 1 break end
				end
			end
		end
		if T.ticks >= 4000 then T.done = true bm:remove_real_callback("zz_tp_race_stress") end
	end)
	if not ok then T.err = tostring(err) T.done = true pcall(function() bm:remove_real_callback("zz_tp_race_stress") end) end
end, 30, "zz_tp_race_stress")
return "stressing " .. #P.models(u) .. " men of " .. want .. " from " .. T.t0
