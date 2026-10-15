C = "script/derpy_tp/combat.lua"
MUTANTS = [
    (C, "F.next_swing = now + E.S.swing_cooldown", "F.next_swing = now", "swing_plays_on_one_man_with_cooldown"),
    (C, "local slot = has[k % #has + 1]", "local slot = has[1]", "swing_plays_on_one_man_with_cooldown"),
    (C, "if P.features.anim and F.men_ok then swing", "if F.men_ok then swing", "swing_falls_back_to_an_attack_order"),
    (C, "if d < AIM_CLOSE or (c > AIM_COS and d < AIM_RANGE) then", "if d < AIM_CLOSE then", "swing_falls_back_to_an_attack_order"),
    (C, "local shot = F.unit:ammo_left() < F.fire_ammo", "local shot = true", "ground_fire_commits_one_shot"),
    (C, "local shot = F.unit:ammo_left() < F.fire_ammo", "local shot = false", "ground_fire_commits_one_shot"),
    (C, "(not held and (shot or expired))", "(shot or expired)", "ground_fire_holds_while_held"),
    (C, "if math.abs((want - F.unit:bearing() + 540) % 360 - 180) > FIRE_ARC then", "if false then", "ground_fire_turns_first"),
    ("script/derpy_tp/main.lua", "\t\t\tE.combat.attack(now, false, false)\n", "", "ground_fire_stops_on_focus_loss"),
    (C, "F.ranged = not F.ranged", "F.ranged = F.ranged", "mode_switches_melee_and_ranged"),
    (C, "c:SetVisible(c:Id() == \"crosshair\")", "c:SetVisible(true)", "crosshair_shows_in_ranged_mode_only"),
    ("script/derpy_tp/main.lua", "\t\tE.combat.crosshair(false)\n", "", "crosshair_shows_in_ranged_mode_only"),
    ("script/derpy_tp/main.lua", "E.combat.crosshair(F.ranged and F.dragging)", "E.combat.crosshair(F.dragging)", "crosshair_shows_in_ranged_mode_only"),
]
