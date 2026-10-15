-- HUD diagnosis: is E.hud loaded, and does CreateComponent from our file give a panel. Creates a TEST copy under
-- another name and hides it at once. NO string library calls.
local out = {}
local ok, err = pcall(function()
	local E = _G.DERPY_TP
	out.E = E and true or false
	if not E then return end
	out.hud = type(E.hud)
	out.show = E.hud and type(E.hud.show) or "none"
	out.on = E.F and tostring(E.F.unit ~= nil) or "no F"
	local root = core:get_ui_root()
	local t = find_uicomponent(root, "derpy_tp_hud_test")
	if not t then
		local ok2, res = pcall(function() return root:CreateComponent("derpy_tp_hud_test", "ui/derpy_tp/hud") end)
		out.create = ok2 and tostring(res) or ("error: " .. tostring(res))
		t = find_uicomponent(root, "derpy_tp_hud_test")
	end
	out.test_exists = t and true or false
	if t then
		out.test_kids = t:ChildCount()
		out.test_vis = tostring(t:VisibleFromRoot())
		t:SetVisible(false)
	end
end)
if not ok then out.err = tostring(err) end
return out
