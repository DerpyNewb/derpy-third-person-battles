# Round 54 (2026-10-19): one man of a regiment leaves its fire setting alone; a unit played whole, or down to its last
# man, holds its fire (the author: "controlling a ranged unit disables the rest of the battalions ranged option too").
MAIN = "script/derpy_tp/main.lua"
ONE = "one_man_leaves_his_regiments_fire_setting_alone"
LAST, OTHERS = "solo_regiment_down_to_one_still_holds_fire", "solo_others_die_still_holds_fire"
BACK = "leaving_gives_back_the_players_own_fire_setting"
MUTANTS = [
    (MAIN, "if F.held_fire or F.model or unit:missile_range() <= 0 then return end",
        "if F.held_fire or unit:missile_range() <= 0 then return end", ONE),
    (MAIN, "\t\t\t-- played whole from here: it holds its fire until third person ends\n\t\t\thold_fire(unit)\n",
        "\t\t\t-- played whole from here: it holds its fire until third person ends\n", LAST),
    (MAIN, "\t\t\t-- played whole from here: it holds its fire until third person ends\n\t\t\thold_fire(unit)\n",
        "\t\t\t-- played whole from here: it holds its fire until third person ends\n", OTHERS),
    (MAIN, "\t\t-- keeps its ground (defend: no pursuit) - both given back as the player had them\n\t\thold_fire(unit)\n",
        "\t\t-- keeps its ground (defend: no pursuit) - both given back as the player had them\n", ONE),
    (MAIN, "\t\tF.held_fire = true\n\t\tF.uc:fire_at_will(false)\n", "\t\tF.uc:fire_at_will(false)\n", BACK),
    (MAIN, "\t\tF.held_fire = true\n\t\tF.uc:fire_at_will(false)\n", "\t\tF.held_fire = true\n", ONE),
]
