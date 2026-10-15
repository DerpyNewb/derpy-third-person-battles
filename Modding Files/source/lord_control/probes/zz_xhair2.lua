-- a plain crosshair at the screen centre: our own instance of the first-person mode's layout
-- (ui/battle ui/first_person_ui, which places crosshair.png at the centre), every other part hidden
local ok, res = pcall(function()
	local root = core:get_ui_root()
	local ui = find_uicomponent(root, "derpy_crosshair_ui")
	if not ui then ui = UIComponent(root:CreateComponent("derpy_crosshair_ui", "ui/battle ui/first_person_ui")) end
	local kids = {}
	for i = 0, ui:ChildCount() - 1 do
		local c = UIComponent(ui:Find(i))
		c:SetVisible(c:Id() == "crosshair")
		kids[#kids + 1] = c:Id()
	end
	ui:SetVisible(true)
	local x = find_uicomponent(ui, "crosshair")
	local sw, sh = core:get_screen_resolution()
	local w, h = x:Dimensions()
	x:MoveTo(math.floor(sw / 2 - w / 2), math.floor(sh / 2 - h / 2))
	local px, py = x:Position()
	return {kids = table.concat(kids, " "), screen = {sw, sh}, size = {w, h}, pos = {px, py}, visible = x:VisibleFromRoot(), image = x:GetImagePath(0)}
end)
if ok then return res end
return "ERR " .. tostring(res)
