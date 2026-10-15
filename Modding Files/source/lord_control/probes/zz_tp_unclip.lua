-- Walking out of a running reload clip, 2026-10-14: third person on the Iron Hail Gunners. Three rounds, each one
-- shot then, 2.5 s into its reload (1564), the shot is dropped as the mode key drops it and he walks forward
-- 2.5 s. Round A walks at once; round B plays WALK_1 (42, mask 0) first; round C calls the engine's own stop
-- (exe+3069d7c, what uc:halt leaves on each man) first. Our E.move.drive is wrapped to press forward; nothing
-- of the game's is patched. Logs clip slot and command type on each change. No string library calls.
-- Read back: zz_tp_unclip_read.lua. Round starts: A 0 s, B 9 s, C 18 s; walks from +5.3 s to +7.8 s.
local E = _G.DERPY_TP
if not (E and E.main) then return "load the bridge first" end
if E.F.on then return "switch third person off first" end
local mr = memreader_plus
local GUN = "wh3_main_cth_inf_iron_hail_gunners_0"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GUN then u = units:item(i) end end
if not u then return "no gunners" end
local stop = mr.add(mr.add(mr.base, 0x3060000), 0x9d7c)
local T = {log = "", walk = false, done = {}}
_G.TP_UNCLIP = T
local drive = E.move.drive
E.move.drive = function(now, kf, kr, run) if T.walk then kf = 1 end return drive(now, kf, kr, run) end
local t0, last = os.clock(), ""
local function note(s) T.log = T.log .. " || " .. math.floor((os.clock() - t0) * 100) / 100 .. "s " .. s end
bm:repeat_real_callback(function()
	local t = os.clock() - t0
	local ok, err = pcall(function()
		if not T.started then T.started = true E.main.start(u) E.F.ranged = true end
		local F, m = E.F, E.F.model
		if not m then return end
		for r, name in ipairs({"A", "B", "C"}) do
			local s0 = (r - 1) * 9
			if t > s0 + 0.3 and not T.done[name .. "shot"] then T.done[name .. "shot"] = true note("round " .. name .. " shot") F.want_shot = true end
			if t > s0 + 5.3 and not T.done[name .. "walk"] then
				T.done[name .. "walk"] = true
				note("round " .. name .. " drop, phase " .. tostring(F.shot and F.shot.phase))
				F.want_shot, F.shot = false, nil
				if name == "B" then note("WALK_1 played " .. tostring(E.P.play(m, 42, 0))) end
				if name == "C" then mr.call(stop, "pointer(pointer)", m) note("stopped") end
				T.walk = true
			end
			if t > s0 + 7.8 and not T.done[name .. "end"] then T.done[name .. "end"] = true T.walk = false note("round " .. name .. " end") end
		end
		local s = "slot " .. tostring(E.P.anim_slot(m)) .. " raw " .. mr.read_uint16(m, 0x278) .. " p898 " .. tostring(not mr.is_null(mr.read_pointer(m, 0x898))) .. " i284 " .. mr.read_int32(m, 0x284) .. " cmd " .. mr.tostring(mr.read_pointer(m, 0x330))
		if s ~= last then local x, _, z = E.P.model_pos(m) note(s .. " at " .. math.floor(x * 10) / 10 .. "," .. math.floor(z * 10) / 10) last = s end
	end)
	if not ok then T.err = tostring(err) end
	if t > 27 or not ok then
		bm:remove_real_callback("tp_unclip")
		E.move.drive = drive
		pcall(E.main.stop, "unclip probe")
		T.ended = true
	end
end, 30, "tp_unclip")
return "started"
