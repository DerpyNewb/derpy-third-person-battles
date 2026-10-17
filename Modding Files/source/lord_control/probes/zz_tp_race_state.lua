-- after zz_tp_race_stress.lua: the battle, the regiment, and what its men's commands are now (test scaffolding)
local ok, r = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	local P = E.P
	local want = _G.TP_RS_TYPE or "teb_montante_greatswords"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if not u and x:type() == want then u = x end
	end
	local kinds, n = {}, 0
	for _, m in ipairs(P.models(u)) do
		local k = mr.tostring(mr.read_pointer(m, 0x330))
		kinds[k] = (kinds[k] or 0) + 1
		n = n + 1
	end
	local s = ""
	for k, c in pairs(kinds) do s = s .. k .. "=" .. c .. " " end
	return {phase = bm:get_current_phase_name(), alive = u:number_of_men_alive(), melee = tostring(u:is_in_melee()), models = n, commands = s,
		time = bm:time_elapsed_ms()}
end)
if ok then return r end
return "ERR " .. tostring(r)
