-- Casts the controlled unit's first ground ability 40 m ahead along the camera, the way the pack does and two other
-- ways, one per send: set _G.DERPY_TP_GROUND_WAY to "plain" (key, position), "facing" (+ the camera's bearing and a
-- 20 m width) or "held" (plain, and the controller is NOT released). Read zz_tp_ability_state.lua 2 s later to see
-- whether it went off. NO string library calls.
local E = _G.DERPY_TP
if not (E and E.F.on) then return "not in third person" end
local F = E.F
local card = find_uicomponent(core:get_ui_root(), "cards_panel", tostring(F.unit:unique_ui_id()))
local id = card and card:GetContextObjectId("CcoBattleUnit")
local key
for i = 0, (tonumber(common.get_context_value("CcoBattleUnit", id, "BattleAbilityList.Size")) or 0) - 1 do
	local s = "BattleAbilityList.At(" .. i .. ").SetupAbilityContext."
	if not key and common.get_context_value("CcoBattleUnit", id, s .. "UnitSpecialAbilityRecordContext.TargetGround") == true then
		key = common.get_context_value("CcoBattleUnit", id, s .. "RecordKey")
	end
end
if not key then return "no ground ability" end
local q = F.unit:position()
local yaw = E.rig.yaw
local pos = v(q:get_x() + math.sin(yaw) * 40, q:get_y(), q:get_z() + math.cos(yaw) * 40)
local way = _G.DERPY_TP_GROUND_WAY or "plain"
local ok, err
if way == "facing" then
	ok, err = pcall(F.uc.perform_special_ability_ground, F.uc, key, pos, math.deg(yaw) % 360, 20)
else
	ok, err = pcall(F.uc.perform_special_ability_ground, F.uc, key, pos)
end
if way ~= "held" then F.uc:release_control() end
return {key = key, way = way, ok = tostring(ok), err = tostring(err), can = tostring(F.unit:can_perform_special_ability(key))}
