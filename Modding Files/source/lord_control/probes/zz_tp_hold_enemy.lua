-- Takes the enemy out of AI control and halts every unit, so a test beside the player is not fought.
-- The controllers stay in TP_AI_CONTROLLERS; send again to re-halt. Battle lists are 1-based.
local held = 0
_G.TP_AI_CONTROLLERS = _G.TP_AI_CONTROLLERS or {}
local armies = bm:get_non_player_alliance():armies()
for a = 1, armies:count() do
	local units = armies:item(a):units()
	for i = 1, units:count() do
		local u = units:item(i)
		local uc = TP_AI_CONTROLLERS[u:unique_ui_id()] or create_unitcontroller(u)
		if uc then
			uc:take_control()
			uc:halt()
			TP_AI_CONTROLLERS[u:unique_ui_id()] = uc
			held = held + 1
		end
	end
end
local q, e = bm:get_player_army():units():item(1):position(), bm:get_non_player_alliance():armies():item(1):units():item(1):position()
return {held = held, distance = math.floor(q:distance_xz(e))}
