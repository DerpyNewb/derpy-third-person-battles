-- keep the target regiment where it stands: halt plus an order to its own spot, every half second
local ok, res = pcall(function()
	local S = _G.DERPY_TGT
	local e = S.enemy
	local p = e:position()
	S.pin = {p:get_x(), p:get_y(), p:get_z()}
	bm:remove_real_callback("derpy_tgt_watch")
	bm:repeat_real_callback(function()
		local q = e:position()
		local me = bm:get_player_army():units():item(S.my or 4):position()
		S.dist = math.floor(math.sqrt((q:get_x() - me:get_x()) ^ 2 + (q:get_z() - me:get_z()) ^ 2))
		S.men = e:number_of_men_alive()
		S.uce:goto_location(v(S.pin[1], S.pin[2], S.pin[3]), false)
		S.uce:halt()
	end, 500, "derpy_tgt_watch")
	return {pinned_at = S.pin, men = e:number_of_men_alive(), scripted = e:is_script_controlled(), melee = e:is_in_melee()}
end)
if ok then return res end
return "ERR " .. tostring(res)
