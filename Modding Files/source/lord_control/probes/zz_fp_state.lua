local ok, res = pcall(function()
	local fp = find_uicomponent(core:get_ui_root(), "first_person_ui")
	local b = find_uicomponent(core:get_ui_root(), "hud_battle", "porthole_parent", "button_unit_manual_fire")
	local T = {fp = fp and fp:Visible(), button = b and b:Visible(), selected = bm:num_units_selected()}
	if fp then
		local kids = {}
		for i = 0, math.min(fp:ChildCount(), 20) - 1 do local c = UIComponent(fp:Find(i)) kids[#kids + 1] = c:Id() .. (c:Visible() and "" or "(h)") end
		T.fp_children = table.concat(kids, " ")
	end
	return T
end)
if ok then return res end
return "ERR " .. tostring(res)
