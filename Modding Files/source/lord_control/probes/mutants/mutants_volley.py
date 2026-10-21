COMBAT = "script/derpy_tp/combat.lua"
MUTANTS = [
    (COMBAT, "if target and whole_volley() then", "if false and target and whole_volley() then",
     "a_regiment_aimed_at_an_enemy_attacks_that_unit"),
    (COMBAT, "if F.fire_unit == id or (F.fire_unit or F.fire_at) and in_shot()", "if (F.fire_unit or F.fire_at) and in_shot()",
     "a_regiment_aimed_at_an_enemy_attacks_that_unit"),
    (COMBAT, "F.fire_unit, F.fire_at, F.turn_to, F.last_order, F.driving = id, nil, nil, now, false",
     "F.fire_at, F.turn_to, F.last_order, F.driving = nil, nil, now, false", "a_regiment_aimed_at_an_enemy_attacks_that_unit"),
    (COMBAT, "if target and not target:is_valid_target() or target and target:is_routing() then target = nil end", "",
     "a_routing_target_falls_back_to_ground_fire"),
    (COMBAT, "return not F.crew and not F.unit:is_war_machine()", "return not F.unit:is_war_machine()",
     "a_crew_on_one_body_keeps_ground_fire"),
    (COMBAT, "if best < t_max then return best, best_u end", "if best < t_max then return best end",
     "a_new_unit_under_the_crosshair_gets_a_new_order"),
]
MUTANTS.append((COMBAT, "if (F.fire_at or F.fire_unit) and in_shot() then return end", "if F.fire_at and in_shot() then return end",
                "the_crosshair_off_the_unit_mid_shot_waits_for_the_shot"))
