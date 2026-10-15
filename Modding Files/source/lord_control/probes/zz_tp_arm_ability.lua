-- Approach A, measurement: in third person, list CA's porthole ability buttons (every child of each slot, its context
-- and the ability key through three candidate fields) and, when _G.TP_ARM names a slot id, SimulateLClick that slot's
-- button and read its state after. NO string library calls.
local root = core:get_ui_root()
local parent = find_uicomponent(root, "hud_battle", "porthole_parent", "ability_parent")
if not parent then return "no ability_parent" end
local out = {cinematic = tostring(bm:is_cinematic_ui_enabled()), parent_vis = tostring(parent:VisibleFromRoot())}
local function key_of(cid)
	for _, f in ipairs({"SetupAbilityContext.RecordKey", "RecordKey", "AbilityRecordContext.Key"}) do
		local ok, v = pcall(common.get_context_value, "CcoBattleAbility", cid, f)
		if ok and v ~= nil then return f .. "=" .. tostring(v) end
	end
	return "?"
end
for i = 0, parent:ChildCount() - 1 do
	local slot = UIComponent(parent:Find(i))
	local row = {vis = tostring(slot:Visible())}
	for j = 0, slot:ChildCount() - 1 do
		local c = UIComponent(slot:Find(j))
		local ok, cid = pcall(function() return c:GetContextObjectId("CcoBattleAbility") end)
		row[c:Id()] = c:CurrentState() .. " " .. ((ok and cid) and (tostring(cid) .. " " .. key_of(cid)) or "-")
	end
	out[slot:Id()] = row
end
if _G.TP_ARM then
	local b = find_uicomponent(parent, _G.TP_ARM, "button_ability")
	if b then
		local before = b:CurrentState()
		b:SimulateLClick()
		out.clicked = _G.TP_ARM .. ": " .. before .. " -> " .. b:CurrentState()
	else
		out.clicked = "no button_ability under " .. _G.TP_ARM
	end
	_G.TP_ARM = nil
end
return out
