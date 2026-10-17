C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
U = "script/derpy_tp/hud.lua"
WIND = "a_winding_up_ability_shows_the_plain_ring_and_its_seconds"
MUTANTS = [
    (U, "local winding = windup > 0", "local winding = false", WIND),
    (U, "local secs = winding and windup or cco", "local secs = cco", WIND),
    (M, "if unit:missile_range() > 0 then F.held_fire = true F.uc:fire_at_will(false) end",
     "if F.solo then F.held_fire = true F.uc:fire_at_will(false) end", "a_unit_played_whole_shoots_only_when_told"),
    (M, "if not F.fire_slot then F.solo = false end",
     "if not F.reload_slot or not F.fire_slot then F.solo = false F.uc:fire_at_will(true) end",
     "solo_regiment_down_to_one_still_holds_fire"),
    (M, 'if not F.defend_was and unit:can_use_behaviour("defend") then', "if false then",
     "a_played_unit_keeps_its_ground_and_gets_its_setting_back"),
    (M, 'if F.defend_was == false then try(', "if false then try(",
     "a_played_unit_keeps_its_ground_and_gets_its_setting_back"),
    (C, "\t\tF.uc:fire_at_will(true)\n\t\tF.uc:attack_location(", "\t\tF.uc:attack_location(", "fire_at_will_is_on_only_while_he_shoots"),
    (C, "if F.held_fire then F.uc:fire_at_will(false) end -- shooting over", "-- shooting over",
     "fire_at_will_is_on_only_while_he_shoots"),
]
