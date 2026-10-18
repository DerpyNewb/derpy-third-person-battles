-- Test scaffolding (2026-10-18): third person on the first unit of _G.TP_CAM_TYPE, with the aiming shoulder set to
-- _G.TP_CAM_SHOULDER (1 right, -1 left, 0 top) and ranged mode if _G.TP_CAM_RANGED; for a screenshot of the camera.
-- No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.main) then return "no pack" end
	local want = _G.TP_CAM_TYPE or "wh3_pro11_chs_cha_harald_hammerstorm"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if not u and x:type() == want and x:number_of_men_alive() > 0 then u = x end
	end
	if not u then return "no " .. want end
	if E.F.on then E.main.stop("camera test") end
	E.main.start(u)
	if _G.TP_CAM_SHOULDER then E.S.shoulder = _G.TP_CAM_SHOULDER end
	if _G.TP_CAM_RANGED ~= nil and E.F.ranged ~= _G.TP_CAM_RANGED then E.combat.mode(bm:time_elapsed_ms() / 1000) end
	return "on " .. want .. ", ranged " .. tostring(E.F.ranged) .. ", shoulder " .. tostring(E.S.shoulder)
end)
return ok and res or "ERR " .. tostring(res)
