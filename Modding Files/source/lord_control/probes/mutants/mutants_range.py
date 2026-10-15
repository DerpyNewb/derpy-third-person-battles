A = "script/derpy_tp/abilities.lua"
U = "script/derpy_tp/hud.lua"
RING = "a_running_ability_shows_the_green_ring_and_its_seconds_left"
MUTANTS = [
    (A, "> range * range then far = true", "> 1e12 then far = true", "an_enemy_past_the_abilitys_range_is_out_of_range"),
    (A, 'or (far and "Out of range") or', "or", "an_enemy_past_the_abilitys_range_is_out_of_range"),
    (A, "local x, y, z = E.combat.aim_point(reach(n))", "local x, y, z = E.combat.aim_point(RANGE)",
     "a_ground_ability_lands_no_farther_than_its_range"),
    (A, 'return ok and type(r) == "number" and r > 0 and r or RANGE', "return RANGE",
     "an_enemy_past_the_abilitys_range_is_out_of_range"),
    (U, '(active and "ActiveTimeRemainingSecs" or "RechargeTimeRemainingSecs")', '"RechargeTimeRemainingSecs"', RING),
    (U, 'vis("slot_" .. n .. "_active_l", active) vis', 'vis("slot_" .. n .. "_active_l", false) vis', RING),
    (U, 'vis("slot_" .. n .. "_active_r", active)', 'vis("slot_" .. n .. "_active_r", true)', RING),
]
