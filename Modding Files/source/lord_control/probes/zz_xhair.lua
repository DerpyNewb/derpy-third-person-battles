-- show the first-person mode's crosshair while the follow camera runs on the crossbowmen; screenshot
local ok, res = pcall(function()
	local F = _G.DERPY_FOLLOW
	if F.on then F.stop_fn("xhair") end
	F.start_fn(bm:get_player_army():units():item(4))
	local fp = find_uicomponent(core:get_ui_root(), "first_person_ui")
	local x = fp and find_uicomponent(fp, "crosshair")
	local p, path = fp, {}
	while p and #path < 8 do path[#path + 1] = p:Id() .. (p:Visible() and "" or "(h)") local pp = p:Parent() p = pp and UIComponent(pp) or nil end
	local T = {path = table.concat(path, " < ")}
	_G.DERPY_X = T
	bm:real_callback(function()
		fp:SetVisible(true)
		x:SetVisible(true)
		local w, h = x:Dimensions()
		local px, py = x:Position()
		T.xhair = {w, h, px, py, x:Visible(), x:VisibleFromRoot()}
		T.fp_visible = fp:VisibleFromRoot()
		bm:real_callback(function() common.take_screenshot("derpy_xhair.tga") end, 500, "derpy_x_shot")
	end, 1500, "derpy_x_show")
	return T
end)
if ok then return res end
return "ERR " .. tostring(res)
