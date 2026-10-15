-- HUD diagnosis with derpy_tp_uitest.pack loaded: which layout paths does CreateComponent accept. Each test copy is
-- created under its own name and hidden at once. NO string library calls.
local out = {}
local root = core:get_ui_root()
local paths = {ours = "ui/derpy_tp/hud", battle = "ui/battle ui/derpy_tp_hud", campaign = "ui/campaign ui/derpy_tp_hud",
	known_ours = "ui/derpy_tp/known", known_battle = "ui/battle ui/derpy_tp_known"}
for tag, path in pairs(paths) do
	local name = "derpy_tp_paths_" .. tag
	local ok, err = pcall(function()
		local c = find_uicomponent(root, name)
		if not c then
			root:CreateComponent(name, path)
			c = find_uicomponent(root, name)
		end
		if c then
			out[tag] = "made, kids " .. c:ChildCount()
			c:SetVisible(false)
		else
			out[tag] = "nil"
		end
	end)
	if not ok then out[tag] = "error: " .. tostring(err) end
end
return out
