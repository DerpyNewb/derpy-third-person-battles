-- Clicks CA's first porthole ability button twice from script (SimulateLClick), reading its state and the unit's
-- missile range after each: does the script click toggle the ability where perform_special_ability refused it.
-- Ends where it began. NO string library calls.
local root = core:get_ui_root()
local b = find_uicomponent(root, "hud_battle", "porthole_parent", "ability_parent", "button_slot1", "button_ability")
if not b then return "no button" end
local u = bm:get_player_alliance():armies():item(1):units():item(1)
local out = {before = b:CurrentState() .. " range " .. u:missile_range(), ability = tostring(b:GetContextObjectId("CcoBattleAbility"))}
b:SimulateLClick()
out.after_one = b:CurrentState() .. " range " .. u:missile_range()
return out
