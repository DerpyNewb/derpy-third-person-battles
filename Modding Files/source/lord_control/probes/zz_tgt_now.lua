local ok, res = pcall(function()
	local S = _G.DERPY_TGT
	local u, e = S.shooter, S.enemy
	return {ammo = u:ammo_left(), men = u:number_of_men_alive(), emen = e:number_of_men_alive(), dist = math.floor(u:position():distance_xz(e:position())), erout = e:is_routing()}
end)
if ok then return res end
return "ERR " .. tostring(res)
