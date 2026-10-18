-- Test scaffolding: the results screen's Rematch, clicked (custom battle; nothing is saved). No string library calls.
local ok, res = pcall(function()
	if bm:get_current_phase_name() ~= "Complete" then return "not over: " .. bm:get_current_phase_name() end
	local b = find_uicomponent(core:get_ui_root(), "in_battle_results_popup", "background", "button_background", "button_parent", "button_rematch")
	if not b then return "no rematch button" end
	b:SimulateLClick()
	return "rematch clicked"
end)
return ok and res or "ERR " .. tostring(res)
