-- select the artillery unit, then (once the HUD has its buttons) click "Manual fire mode"; report the result
local IDX = 13
local ok, res = pcall(function()
	local u = bm:get_player_army():units():item(IDX)
	local T = {}
	_G.DERPY_FP = T
	u:select_in_ui()
	bm:real_callback(function()
		local b = find_uicomponent(core:get_ui_root(), "hud_battle", "porthole_parent", "button_unit_manual_fire")
		T.selected, T.visible, T.state = bm:num_units_selected(), b and b:Visible(), b and b:CurrentState()
		if b then b:SimulateLClick() end
		bm:real_callback(function()
			local fp = find_uicomponent(core:get_ui_root(), "first_person_ui")
			T.fp_after, T.state_after, T.visible_after = fp and fp:Visible(), b:CurrentState(), b:Visible()
			local c = bm:camera():position()
			T.cam = {c:get_x(), c:get_y(), c:get_z()}
		end, 1500, "derpy_fp_check")
	end, 300, "derpy_fp_click")
	return "selected, clicking in 0.3 s"
end)
if ok then return res end
return "ERR " .. tostring(res)
