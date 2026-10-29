-- Third-Person Battles: the unit stats in this mod's settings, in campaign battles. The battle script casts one of the
-- pack's hidden army abilities (script/derpy_tp/buffs.lua), which the army has to own. In custom battles every faction
-- owns them through army_special_abilities_for_faction_junctions, which does nothing in campaign (a campaign army listed
-- none of them, measured 2026-10-29). Here a hidden faction bundle enables them on every force of each human faction, as
-- CA's own HIDDEN effect enables Relentless Rage. The rows are tools/build_third_person.py's (stat_rows), which checks
-- this key against them.
local BUNDLE = "derpy_tp_stats"

-- first tick, on every load: a save from before the mod gets it too, and no world call runs at the script's root
cm:add_first_tick_callback(function()
	for _, key in ipairs(cm:get_human_factions()) do
		local faction = cm:get_faction(key)
		-- 0 turns is indefinite (campaign_manager:apply_effect_bundle)
		if faction and not faction:has_effect_bundle(BUNDLE) then cm:apply_effect_bundle(BUNDLE, key, 0) end
	end
end)
