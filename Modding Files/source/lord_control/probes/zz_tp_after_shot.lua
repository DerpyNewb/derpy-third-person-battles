-- After one solo shot, what animation does the gunner hold, and which lowering clips does his set have?
-- 2026-10-14. Third person on the Iron Hail Gunners, one shot via F.want_shot (state, not a patch), the clip
-- slot sampled every 50 ms for 8 s, then off. No string library calls. Read back: zz_tp_after_shot_read.lua.
local E = _G.DERPY_TP
if not (E and E.main) then return "load the bridge first" end
local GUN = "wh3_main_cth_inf_iron_hail_gunners_0"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GUN then u = units:item(i) end end
if not u then return "no gunners" end
local T = {log = "", has = ""}
_G.TP_AFTER = T
local t0, last = os.clock(), -1
bm:repeat_real_callback(function()
	local t = os.clock() - t0
	local ok, err = pcall(function()
		if not E.F.on and not T.started then T.started = true E.main.start(u)
			for _, s in ipairs({1448, 1461, 1462, 1464, 1465, 1466, 1467, 1548, 1551, 1554, 1557, 1564, 1566}) do
				T.has = T.has .. s .. "=" .. tostring(E.P.has_slot(E.F.model, s)) .. " "
			end
			T.solo = tostring(E.F.solo)
		end
		if t > 0.5 and not T.fired then T.fired = true E.F.want_shot = true end
		local m = E.F.model
		local s = m and E.P.anim_slot(m)
		if s ~= last then T.log = T.log .. math.floor(t * 1000) .. "ms " .. tostring(s) .. " | " last = s end
	end)
	if not ok then T.err = tostring(err) end
	if t > 8.5 or not ok then bm:remove_real_callback("tp_after") pcall(E.main.stop, "after-shot probe") T.ended = true end
end, 50, "tp_after")
return "started"
