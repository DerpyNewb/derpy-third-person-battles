C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
V = "script/derpy_tp/move.lua"
R = "script/derpy_tp/rig.lua"
S = "script/derpy_tp/settings.lua"
U = "script/derpy_tp/hud.lua"
ROT, THROW = "a_swing_rotates_only_through_the_clips_he_has", "a_thrown_bomb_leaves_late_in_the_throw"
QHELD, CLICK, COOL = "shift_held_on_the_move_charges_for_as_long_as_it_is_held", "a_click_in_the_charge_throws_the_charge_attack", "the_charge_attack_cools_down"
TOGGLE = "z_toggles_walking_and_running_is_the_default"
TURN, TURN_LOCK, MELEE = "he_turns_toward_a_new_direction_at_a_rate", "after_an_action_he_still_turns_at_the_rate", "in_melee_the_camera_comes_in"
SETTINGS, BAR = "charge_and_jump_have_keys_and_settings", "the_action_bar_shows_the_charge_then_its_cooldown"
MUTANTS = [
    # the rotation: only his clips, each list on its own count
    (C, "(P.has_slot(first, s) or mount and P.has_slot(mount, s))", "true", ROT),
    (C, "local k = turn[slots] or 0", "local k = F.swings", ROT),
    (C, "turn[slots], F.swings = k + 1, F.swings + 1", "F.swings = F.swings + 1", ROT),
    (M, "F.can_charge, F.can_jump = any(484), any(489)", "F.can_charge, F.can_jump = any(484), first ~= nil and P.has_slot(first, 489)", ROT),
    # the thrown bomb
    (C, "(F.thrown and THROW_MS or SHOT_DELAY_MS)", "SHOT_DELAY_MS", THROW),
    (M, 'F.thrown = ok and kind == "explosives"', "F.thrown = false", THROW),
    (M, "if E.D.shots[t] or unit:missile_range() <= 0 then return end", "if unit:missile_range() <= 0 then return end", "a_known_unit_keeps_its_data_shot"),
    # the walk key (2026-10-16: was the run key; mutants_round28 carries its hold, setting and lit mutants)
    (U, "local can = {walk = true,", "local can = {walk = false,", TOGGLE),
    (U, 'key_of = {walk = "walk",', 'key_of = {walk = "attack",', TOGGLE),
    # Shift held (2026-10-16: was Q held on the run; held on the move now, from a walk too)
    (M, "P.held(S.keys.sprint) and F.dragging", "P.pressed(S.keys.sprint) and F.dragging", QHELD),
    (C, "F.charge_at = now + CHARGE_GAP", "F.charge_at = now + 60", QHELD),
    (C, "P.play(m, clip, 6)", "P.play(m, clip, 0)", QHELD),
    (C, "local CHARGE, CHARGE_GAP, WALK_1 = 135,", "local CHARGE, CHARGE_GAP, WALK_1 = 136,", QHELD),
    (C, "\t\t\teach(function(m) if P.has_slot(m, WALK_1) then P.play(m, WALK_1, 0) end end)\n", "", "a_lord_charges_too_and_the_charge_ends_on_release"),
    (V, "if P.anim_slot(m) and not F.charging and not F.lock and now", "if P.anim_slot(m) and not F.lock and now", QHELD),
    # (2026-10-16: charge_run's own lock check went; C.sprint's is mutants_round28's)
    # the charge attack
    (C, "if clicked and F.charging and now >= F.next_charge then", "if false then", CLICK),
    (C, "F.next_charge = now + E.S.charge_cooldown", "F.next_charge = now", COOL),
    # turning
    (V, "E.S.turn_rate * dt", "1e9", TURN),
    (V, "\t\t\tdx, dz = math.sin(face), math.cos(face)\n", "", TURN),
    (S, 'S.turn_rate = math.rad(get("move_turn_rate", 360))', "S.turn_rate = math.rad(get(\"move_turn_rate\", 3600))", TURN),
    # the melee camera
    (M, "F.ranged, unit:is_in_melee(),", "F.ranged, false,", MELEE),
    (R, "((melee and 1 or 0) - R.close)", "(0 - R.close)", MELEE),
    (S, 'get("camera_melee_distance", 35) / 10', 'get("camera_melee_distance", 35) / 1', MELEE),
    (R, "local back, lift = dist * zm", "local back, lift = S.distance * zm", MELEE),
    # settings
    (S, 'math.rad(get("move_turn_rate", 360))', 'math.rad(360)', SETTINGS),
]
