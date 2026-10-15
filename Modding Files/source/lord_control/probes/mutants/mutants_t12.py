A = "script/derpy_tp/abilities.lua"
MUTANTS = [
    (A, "if not F.unit:can_perform_special_ability(key) then return nil, key .. \" cannot be cast now\" end", "", "ability_refused_or_missing_does_nothing"),
    (A, "local key = list and list[n]", "local key = list and list[1]", "ability_key_n_casts_slot_n"),
    (A, "if kind == \"ground\" then", "if false then", "ability_ground_lands_on_the_crosshair"),
    (A, "if t > 0 and t < RANGE then", "if true then", "ability_ignores_units_behind_the_camera"),
    (A, "local d = math.sqrt(cx * cx + cy * cy + cz * cz) / t", "local d = -math.sqrt(cx * cx + cy * cy + cz * cz) / t", "ability_enemy_goes_to_the_unit_on_the_ray"),
    (A, "if d < CONE and (not best_d", "if (not best_d", "ability_enemy_far_off_the_crosshair_is_not_a_target"),
    (A, "local CONE = math.tan(math.rad(12))", "local CONE = math.tan(math.rad(40))", "ability_enemy_far_off_the_crosshair_is_not_a_target"),
    (A, "local CONE = math.tan(math.rad(12))", "local CONE = math.tan(math.rad(8))", "an_ally_ability_goes_to_the_ally_on_the_crosshair_else_himself"),
    (A, "return E.D.abilities[key] or \"self\"", "return E.D.abilities[key] or \"enemy\"", "ability_unknown_kind_casts_on_self"),
]
