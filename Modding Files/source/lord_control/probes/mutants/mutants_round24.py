M = "script/derpy_tp/main.lua"
WHOLE, REGIMENT = "a_unit_played_whole_takes_his_melee_mode", "a_regiment_played_as_one_man_keeps_its_own_mode"
CANNOT = "a_man_who_cannot_shoot_alone_leaves_his_regiments_mode"
LINE = "local melee = unit:missile_range() > 0 and not F.arty and not F.ranged and not F.model"
MUTANTS = [
    # melee mode is the whole unit's: only for a unit played whole, never for one man of a regiment
    (M, LINE, "local melee = unit:missile_range() > 0 and not F.arty and not F.ranged", REGIMENT),
    (M, LINE, "local melee = unit:missile_range() > 0 and not F.arty and not F.ranged", CANNOT),
    (M, LINE, "local melee = unit:missile_range() > 0 and not F.arty and not F.ranged and F.model ~= nil", WHOLE),
]
