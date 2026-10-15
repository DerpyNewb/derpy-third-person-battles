-- Sliding after a shot, 2026-10-14: with third person off, steer the gunners' front man 2 s, hold, play his
-- fire clip, let the engine settle 2.5 s, steer 2 s again. Each phase logs its clip slots and how far he
-- moved. No string library calls. Read back: zz_tp_slide_read.lua.
local E = _G.DERPY_TP
if not (E and E.P) then return "load the bridge first" end
if E.F.on then return "switch third person off first" end
local P = E.P
local GUN = "wh3_main_cth_inf_iron_hail_gunners_0"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GUN then u = units:item(i) end end
local m = E.move.front_man(u)
if not m then return "no man" end
local b = math.rad(u:bearing())
local T = {phase = "walk1", log = "", t0 = os.clock()}
_G.TP_SLIDE = T
local last, sx, sz
local function mark(name) local x, _, z = P.model_pos(m) if sx then T.log = T.log .. " moved " .. math.floor(math.sqrt((x - sx) ^ 2 + (z - sz) ^ 2) * 100) / 100 .. "m" end T.log = T.log .. " || " .. name .. ":" sx, sz, last = x, z, -1 end
mark("walk1")
local n = 0
bm:repeat_real_callback(function()
	n = n + 1
	local ok, err = pcall(function()
		local t = os.clock() - T.t0
		local s = P.anim_slot(m)
		if s ~= last then T.log = T.log .. " " .. tostring(s) last = s end
		local x, _, z = P.model_pos(m)
		if (T.phase == "walk1" or T.phase == "walk2") and n % 2 == 0 then P.steer(m, x + 3 * math.sin(b), z + 3 * math.cos(b), false, b) end
		if T.phase == "walk1" and t > 2 then P.hold(m, x, z, b) T.phase = "fire" mark("fire") end
		if T.phase == "fire" and t > 2.5 then T.phase = "settle" T.played = P.play(m, 1557, 0) end
		if T.phase == "settle" and t > 5 then T.phase = "walk2" mark("walk2") end
		if T.phase == "walk2" and t > 7 then P.hold(m, x, z, b) mark("end") T.phase = "done" bm:remove_real_callback("tp_slide") end
	end)
	if not ok then T.err = tostring(err) bm:remove_real_callback("tp_slide") end
end, 50, "tp_slide")
return "started"
