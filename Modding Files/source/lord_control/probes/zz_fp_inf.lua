-- does the "Manual fire mode" button show for each ranged unit? select each in turn and read it
local ok, res = pcall(function()
	local T = {}
	_G.DERPY_FPI = T
	local list = {2, 3, 4, 11, 12, 13, 14}
	local i = 0
	local function nexto()
		i = i + 1
		if i > #list then return end
		local u = bm:get_player_army():units():item(list[i])
		u:select_in_ui()
		bm:real_callback(function()
			local b = find_uicomponent(core:get_ui_root(), "hud_battle", "porthole_parent", "button_unit_manual_fire")
			T[#T + 1] = u:type() .. "=" .. tostring(b and b:Visible()) .. "/" .. bm:num_units_selected()
			nexto()
		end, 300, "derpy_fpi")
	end
	nexto()
	return "checking"
end)
if ok then return res end
return "ERR " .. tostring(res)
