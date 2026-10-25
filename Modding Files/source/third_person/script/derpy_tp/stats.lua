-- The "Unit stats" options on the MCT page: the stats a player can raise or lower on the unit they play, and by how much.
-- tools/build_third_person.py reads this file and makes one hidden army ability per stat and step (T.ability), so a stat
-- or a step added here needs a build. buffs.lua casts the chosen ones; the MCT page and settings.lua read the rest.
-- keys: the engine's stat keys (special_ability_phase_stat_effects); points: the step is added, else it is a percent.
-- icon: CA's ability icon the unit's effect list shows beside the step (ui/battle ui/ability_icons/)
local T = {}

T.order = {"melee_attack", "melee_defence", "weapon_strength", "charge_bonus", "armour", "missile_strength", "speed",
	"leadership"}

T.stats = {
	melee_attack = {label = "Melee attack", keys = {"stat_melee_attack"}, icon = "upgrade_weapon_silver"},
	melee_defence = {label = "Melee defence", keys = {"stat_melee_defence"}, icon = "upgrade_shield_silver"},
	weapon_strength = {label = "Weapon strength", keys = {"stat_melee_damage_base", "stat_melee_damage_ap"},
		icon = "upgrade_weapon_gold"},
	charge_bonus = {label = "Charge bonus", keys = {"stat_charge_bonus"}, icon = "upgrade_weapon_bronze"},
	armour = {label = "Armour", keys = {"stat_armour"}, icon = "upgrade_armour_silver"},
	missile_strength = {label = "Missile strength", keys = {"scalar_missile_damage_base", "scalar_missile_damage_ap"},
		icon = "upgrade_missile_silver"},
	speed = {label = "Speed", keys = {"scalar_speed"}, icon = "wh_main_item_abilities_potion_of_speed"},
	-- CA adds to leadership and never multiplies it (no stat_morale "mult" row in 9.0)
	leadership = {label = "Leadership", keys = {"stat_morale"}, points = true, icon = "wh_main_character_abilities_rally"},
}

T.percent = {-50, -25, 25, 50, 100}
T.points = {-20, -10, 10, 20, 40}

function T.steps(stat) return T.stats[stat].points and T.points or T.percent end
-- a step as the MCT page shows it: "+25%", "-10"
function T.text(stat, v) return (v > 0 and "+" or "") .. v .. (T.stats[stat].points and "" or "%") end
-- the step's part of an option value and an ability key: -25 is "m25", 50 "p50"
function T.step_key(v) return (v < 0 and "m" or "p") .. math.abs(v) end
function T.ability(stat, v) return "derpy_tp_stat_" .. stat .. "_" .. T.step_key(v) end

return T
