-- the artillery "Manual fire mode" (Insert) button: select the unit, find the button, report it
local IDX = 13
local ok, res = pcall(function()
	local F = _G.DERPY_FOLLOW
	if F and F.on then F.stop_fn("fp probe") end
	local u = bm:get_player_army():units():item(IDX)
	u:select_in_ui()
	local T = {unit = u:type(), selected = bm:num_units_selected()}
	local b = find_uicomponent(core:get_ui_root(), "button_unit_manual_fire")
	if b then
		T.found, T.visible, T.state, T.parent = true, b:Visible(), b:CurrentState(), b:Parent() and UIComponent(b:Parent()):Id()
		local p, path = b, {}
		while p and #path < 12 do path[#path + 1] = p:Id() local pp = p:Parent() p = pp and UIComponent(pp) or nil end
		T.path = table.concat(path, " < ")
	end
	local fp = find_uicomponent(core:get_ui_root(), "first_person_ui")
	T.fp_ui = fp and fp:Visible()
	return T
end)
if ok then return res end
return "ERR " .. tostring(res)
