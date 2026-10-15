A = "script/derpy_tp/abilities.lua"
MUTANTS = [
    (A, "if ok then return kind end", "if false then return kind end", "a_modded_ability_aims_by_its_own_record"),
    (A, '{"TargetGroundUnderEnemies", "ground"}, ', "", "a_modded_ability_aims_by_its_own_record"),
    (A, 'elseif kind == "none" then', 'elseif kind == "nonex" then',
     "an_ability_that_targets_nothing_is_activated_through_its_context"),
    (A, "if not ok then ok, err = pcall(F.uc.perform_special_ability, F.uc, key, F.unit) end", "",
     "an_untargeted_ability_without_a_context_falls_back_to_the_unit_order"),
    (A, "u:unique_ui_id() ~= F.unit:unique_ui_id() and ", "",
     "a_regiment_played_by_one_man_is_not_his_own_target"),
    (A, "nearest_to_ray(false, reach(n)) or F.unit)", "nearest_to_ray(false, reach(n)))",
     "an_ally_ability_goes_to_the_ally_on_the_crosshair_else_himself"),
    (A, 'return "none"\n\t\tend)', 'return "self"\n\t\tend)',
     "an_ability_that_targets_nothing_is_activated_through_its_context"),
    (A, "via_context = ok", "via_context = false",
     "an_ability_that_targets_nothing_is_activated_through_its_context"),
]
