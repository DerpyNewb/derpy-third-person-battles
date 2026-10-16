-- Why a unit is not shot alone: start on it, read the pieces of F.solo, stop. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local want = _G.TP_SF_TYPE or "wh3_dlc25_emp_inf_hochland_long_rifles_ror"
	local army, out = bm:get_player_army(), {}
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		if u:type() == want and u:number_of_men_alive() > 1 then
			if F.on then E.main.stop("solo why") end
			E.main.start(u)
			out[#out + 1] = "unit " .. i .. " men " .. u:number_of_men_alive() .. ": on " .. tostring(F.on) .. " model " .. tostring(F.model ~= nil)
				.. " shots " .. tostring(E.D.shots[want] ~= nil) .. " anim " .. tostring(P.features.anim) .. " fire_slot "
				.. tostring(F.fire_slot) .. " solo " .. tostring(F.solo) .. " men_ok " .. tostring(F.men_ok)
				.. " has1557 " .. tostring(F.model and P.has_slot(F.model, 1557)) .. " has949 " .. tostring(F.model and P.has_slot(F.model, 949))
			E.main.stop("solo why")
		end
	end
	return out
end)
return ok and res or "ERR " .. tostring(res)
