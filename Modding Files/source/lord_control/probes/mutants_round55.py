# Round 55 (2026-10-19): one man of a regiment gives it no halt and no defend at the start - CA's halt turned the
# regiment's fire at will off and it stayed off past the end (measured live on Dragon Guard Crossbowmen).
MAIN = "script/derpy_tp/main.lua"
ONE = "one_man_leaves_his_regiments_fire_setting_alone"
WHOLE = "a_played_unit_keeps_its_ground_and_gets_its_setting_back"
F2 = "f2_cancels_existing_movement_before_accepting_input"
MUTANTS = [
    # the guard dropped: one man's regiment halted and put in defend again
    (MAIN, "\t\tif not F.model then\n\t\t\tF.defend_was = unit:is_behaviour_active(\"defend\")",
        "\t\tif true then\n\t\t\tF.defend_was = unit:is_behaviour_active(\"defend\")", ONE),
    # the halt moved out of the guard
    (MAIN, "\t\t\tF.uc:halt()\n\t\t\tF.uc:release_control()\n\t\tend\n",
        "\t\t\tF.uc:release_control()\n\t\tend\n\t\tF.uc:halt()\n", ONE),
    # a unit played whole no longer keeps its ground
    (MAIN, "\t\t\tif not F.defend_was and unit:can_use_behaviour(\"defend\") then F.uc:change_behaviour_active(\"defend\", true, false) end\n",
        "", WHOLE),
    # a unit played whole no longer halted at the start
    (MAIN, "\t\t\tF.uc:halt()\n\t\t\tF.uc:release_control()\n\t\tend\n", "\t\t\tF.uc:release_control()\n\t\tend\n", F2),
]
