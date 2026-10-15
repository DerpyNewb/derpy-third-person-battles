-- Read-only: every ability of the controlled unit (else the general) as its unit context reports it - state, timers,
-- reach and target flags - and the unit's behaviours and melee state. NO string library calls.
local E = _G.DERPY_TP
local u = E and E.F.on and E.F.unit
if not u then
	local units = bm:get_player_army():units()
	for i = 1, units:count() do if units:item(i):is_commanding_unit() then u = units:item(i) end end
end
if not u then return "no unit" end
local card = find_uicomponent(core:get_ui_root(), "cards_panel", tostring(u:unique_ui_id()))
local id = card and card:GetContextObjectId("CcoBattleUnit")
local function get(expr)
	local ok, val = pcall(common.get_context_value, "CcoBattleUnit", id, expr)
	return ok and tostring(val) or "ERR"
end
local out = {unit = u:type(), cco = tostring(id), in_melee = tostring(u:is_in_melee()),
	defend = tostring(u:is_behaviour_active("defend")), can_defend = tostring(u:can_use_behaviour("defend")),
	skirmish = tostring(u:is_behaviour_active("skirmish")), fire_at_will = tostring(u:is_behaviour_active("fire_at_will"))}
local n = id and tonumber(get("BattleAbilityList.Size")) or 0
for i = 0, n - 1 do
	local a = "BattleAbilityList.At(" .. i .. ")."
	local s = a .. "SetupAbilityContext."
	local r = s .. "UnitSpecialAbilityRecordContext."
	out["a" .. i] = get(s .. "RecordKey") .. " | state " .. get(a .. "CurrentState") .. " active " .. get(a .. "IsActive")
		.. " left " .. get(a .. "ActiveTimeRemainingSecs") .. " recharge " .. get(a .. "RechargeTimeRemainingSecs")
		.. " windup " .. get(a .. "WindUpTimeRemainingSecs") .. " | target_range " .. get(s .. "TargetRange")
		.. " cast_range " .. get(s .. "CastRange") .. " min " .. get(s .. "MinimumRange") .. " | ground "
		.. get(r .. "TargetGround") .. " enemies " .. get(r .. "TargetEnemies") .. " friends " .. get(r .. "TargetFriends")
		.. " self " .. get(r .. "TargetSelf")
end
return out
