M = "script/derpy_tp/main.lua"
MUTANTS = [
    (M, "try(function() F.uc:fire_at_will(F.fire_was) F.uc:release_control() end)", "", "one_man_regiment_with_shots_holds_fire"),
    (M, "try(function() F.uc:fire_at_will(F.fire_was) F.uc:release_control() end)", "", "error_restores_everything"),
    (M, "\t\t\tif not paused then E.combat.attack(gnow, false, false) end\n", "", "ground_fire_stops_on_focus_loss"),
    (M, "try(function() E.combat.crosshair(false) end)", "", "crosshair_shows_in_ranged_mode_only"),
    (M, "try(cursor, true)", "", "error_restores_everything"),
]
