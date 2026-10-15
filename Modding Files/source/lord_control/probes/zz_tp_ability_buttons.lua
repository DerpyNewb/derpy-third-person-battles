-- Read-only: CA's ability buttons under the porthole - each slot's id, state, visibility and the ability its context
-- names. NO string library calls.
local root = core:get_ui_root()
local parent = find_uicomponent(root, "hud_battle", "porthole_parent", "ability_parent")
if not parent then return "no ability_parent" end
local out = {kids = parent:ChildCount(), vis = tostring(parent:VisibleFromRoot())}
for i = 0, parent:ChildCount() - 1 do
	local slot = UIComponent(parent:Find(i))
	local row = {id = slot:Id(), vis = tostring(slot:Visible())}
	local b = find_uicomponent(slot, "button_ability")
	if b then
		row.state = b:CurrentState()
		for _, cco in ipairs({"CcoBattleAbility", "CcoUnitAbility"}) do
			local ok, cid = pcall(function() return b:GetContextObjectId(cco) end)
			if ok and cid then
				row[cco] = tostring(cid)
				local ok2, key = pcall(common.get_context_value, cco, cid, cco == "CcoBattleAbility"
					and "SetupAbilityContext.RecordKey" or "RecordKey")
				row[cco .. "_key"] = ok2 and tostring(key) or "err"
			end
		end
	end
	out[i] = row
end
return out
