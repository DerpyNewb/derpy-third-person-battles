-- Read-only: does the HUD panel exist, is it and its parents visible, where are its parts. NO string library calls.
local out = {}
local ok, err = pcall(function()
	local root = core:get_ui_root()
	local ui = find_uicomponent(root, "derpy_tp_hud")
	out.exists = ui and true or false
	if not ui then return end
	out.vis = ui:Visible()
	out.vis_full = ui:VisibleFromRoot()
	local p = UIComponent(ui:Parent())
	out.parent = p:Id()
	out.kids = ui:ChildCount()
	local x, y = ui:Position() local w, h = ui:Dimensions()
	out.root_box = x .. "," .. y .. " " .. w .. "x" .. h
	for _, id in ipairs({"portrait", "plate_left", "name", "health_back", "slot_1_frame", "plate_right", "ammo"}) do
		local c = find_uicomponent(ui, id)
		if c then
			local cx, cy = c:Position() local cw, ch = c:Dimensions()
			out[id] = cx .. "," .. cy .. " " .. cw .. "x" .. ch .. " vis=" .. tostring(c:Visible()) .. " full=" .. tostring(c:VisibleFromRoot())
		else
			out[id] = "missing"
		end
	end
	local xh = find_uicomponent(root, "derpy_tp_crosshair")
	out.crosshair = xh and tostring(xh:VisibleFromRoot()) or "missing"

end)
if not ok then out.err = tostring(err) end
return out
