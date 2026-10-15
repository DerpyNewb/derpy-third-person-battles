-- Read-only: per unit type, each ability's targeting flags and the unit's projectile record, through the card's
-- CcoBattleUnit context. NO string library calls.
local root = core:get_ui_root()
local out, done = {}, {}
local function get(id, expr)
	local ok, v = pcall(common.get_context_value, "CcoBattleUnit", id, expr)
	if not ok then return "err" end
	return tostring(v)
end
local units = bm:get_player_alliance():armies():item(1):units()
for i = 1, units:count() do
	local u = units:item(i)
	local t = u:type()
	if not done[t] then
		done[t] = true
		local card = find_uicomponent(root, "cards_panel", tostring(u:unique_ui_id()))
		local id = card and card:GetContextObjectId("CcoBattleUnit")
		local row = {id = tostring(id)}
		if id then
			local n = tonumber(get(id, "BattleAbilityList.Size")) or 0
			for k = 0, n - 1 do
				local a = "BattleAbilityList.At(" .. k .. ").SetupAbilityContext."
				local r = a .. "UnitSpecialAbilityRecordContext."
				row["ab" .. k] = get(id, a .. "RecordKey") .. " targeted " .. get(id, a .. "IsTargettedAbility")
					.. " ground " .. get(id, r .. "TargetGround") .. " enemies " .. get(id, r .. "TargetEnemies")
					.. " friends " .. get(id, r .. "TargetFriends") .. " self " .. get(id, r .. "TargetSelf")
					.. " affect_self " .. get(id, r .. "AffectSelf") .. " passive " .. get(id, a .. "IsPassive")
			end
			local p = "ActiveProjectileContext."
			row.projectile = get(id, p .. "Key") .. " reload " .. get(id, p .. "BaseReloadTimeContext.Value")
				.. " / " .. get(id, p .. "BaseReloadTime") .. " n " .. get(id, p .. "NumProjectiles")
		end
		out[t] = row
	end
end
return out
