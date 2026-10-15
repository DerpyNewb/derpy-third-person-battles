-- spike setup: silence every player unit, bring one enemy regiment to STOP_AT m in front of the
-- crossbowmen and hold it there under script control, as a clean target for one man's forced fire
local MY, ENEMY_ARMY, ENEMY_IDX, STOP_AT = 2, 1, 5, 70
local ok, res = pcall(function()
	local F = _G.DERPY_FOLLOW
	if F and F.on then F.stop_fn("target setup") end
	local S = {ucs = {}, my = MY}
	_G.DERPY_TGT = S
	local mine = bm:get_player_army():units()
	for i = 1, mine:count() do
		local uc = create_unitcontroller(mine:item(i))
		uc:fire_at_will(false)
		uc:halt()
		S.ucs[#S.ucs + 1] = uc
	end
	local me = mine:item(MY)
	local q = me:position()
	local b = math.rad(me:bearing())
	local tx, tz = q:get_x() + math.sin(b) * STOP_AT, q:get_z() + math.cos(b) * STOP_AT
	local e = bm:get_non_player_alliance():armies():item(ENEMY_ARMY):units():item(ENEMY_IDX)
	S.enemy, S.uce = e, create_unitcontroller(e)
	S.uce:goto_location(v(tx, q:get_y(), tz), true)
	S.target = {tx, tz}
	bm:remove_real_callback("derpy_tgt_watch")
	bm:repeat_real_callback(function()
		local p = e:position()
		S.dist = math.floor(math.sqrt((p:get_x() - q:get_x()) ^ 2 + (p:get_z() - q:get_z()) ^ 2))
		S.men = e:number_of_men_alive()
		if S.dist <= STOP_AT + 5 and not S.arrived then S.arrived = true S.uce:halt() end
	end, 500, "derpy_tgt_watch")
	return {enemy = e:type(), men = e:number_of_men_alive(), target = S.target, silenced = #S.ucs}
end)
if ok then return res end
return "ERR " .. tostring(res)
