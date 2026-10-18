C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
U = "script/derpy_tp/hud.lua"
S = "script/derpy_tp/settings.lua"
R = "script/derpy_tp/rig.lua"
NOQ = "no_charge_for_a_unit_without_the_clips"
JUMP, NOJ = "e_jump_attacks_then_cools_down", "e_does_nothing_for_a_unit_without_the_clip"
LOCK, QLOCK, CAP = "a_jump_plays_out_whatever_is_pressed", "the_charge_attack_plays_out_too", "a_clip_the_engine_never_ends_frees_him_after_the_cap"
SHOWS, COUNTS, CHG, RELOAD, EMPTY = ("the_action_bar_shows_what_the_unit_can_do", "the_action_bar_counts_each_cooldown_down",
    "the_action_bar_shows_the_charge_then_its_cooldown", "the_action_bar_counts_the_reload_down",
    "out_of_ammo_the_fire_button_dims_without_seconds")
TEAM = "a_weapon_team_man_fires_alone_and_reloads_on_the_clock"
MUTANTS = [
    # the three bugs of the morning
    (C, "elseif clicked and not F.arty then", "elseif clicked then", "an_artillery_crew_never_swings"),
    # a weapon team's man shoots alone, his reload on the clock
    (M, "P.features.anim and F.fire_slot ~= nil\n", "P.features.anim and F.reload_slot ~= nil and F.fire_slot ~= nil\n", TEAM),
    (C, "F.ready_at, F.shot = now + E.D.shots[F.utype][2] * E.S.reload_factor, nil", "F.ready_at, F.shot = now, nil", TEAM),
    # the camera floor
    (R, "local CLEAR = 1.6", "local CLEAR = 0.5", "looking_up_the_camera_comes_in_rather_than_being_lifted"),
    # the charge
    (C, "swing(SLOTS_RUN, true, now, nil", "swing(SLOTS_JUMP, true, now, nil", "a_click_in_the_charge_throws_the_charge_attack"),
    (C, "local on = want and F.can_charge and", "local on = want and", NOQ),
    (M, "F.can_charge, F.can_jump = not F.arty and any(484), not F.arty and any(489)", "F.can_charge, F.can_jump = true, not F.arty and any(489)", NOQ),
    # the jump
    (C, "if C.locked(now) or not F.can_jump or now < F.next_jump or", "if C.locked(now) or now < F.next_jump or",
     "e_does_nothing_for_a_whole_unit_without_the_clip"),
    (C, "F.next_jump = now + E.S.jump_cooldown", "F.next_jump = now", JUMP),
    (M, "if P.pressed(S.keys.jump) and F.dragging and not F.armed then E.combat.jump(gnow) end", "", JUMP),
    (S, 'S.jump_cooldown = get("combat_jump_cooldown", 100) / 10', "S.jump_cooldown = 10", "charge_and_jump_have_keys_and_settings"),
    # the lock
    (C, "\t\tif now then F.lock = {from = now, till = now + (hold or LOCK_MAX), yaw = E.rig.yaw, turns = hold ~= nil} end\n", "", LOCK),
    (C, "		if C.locked(now) then return end\n		if clicked and F.charging", "		if clicked and F.charging", "a_shot_waits_for_a_jump"),
    (M, "elseif E.combat.locked(gnow) and not F.lock.runs then", "elseif false then", LOCK),
    (C, "local LOCK_MAX, LOCK_WAIT = 3, 1", "local LOCK_MAX, LOCK_WAIT = 30, 1", CAP),
    (C, "\t\t\t\t\tF.lock.m, F.lock.slot = carrier, played\n", "", "the_lock_ends_with_the_clip"),
    # the HUD
    (U, "fire = F.unit:missile_range() > 0\n\t\t\tand not F.cannot_shoot,", "fire = true,", SHOWS),
    (U, 'sprint = "sprint", attack = "attack"', 'sprint = "attack", attack = "attack"', SHOWS),
    (U, 'show("attack", F.next_swing - now)', "", COUNTS),
    (U, 'show("jump", F.next_jump - now)', "", COUNTS),
    (U, 'show("sprint", F.next_charge - now, not E.combat.can_sprint(), true)', "", CHG),
    (U, "local secs = frac and frac < 1 and", "local secs = false and", RELOAD),
    (U, 'vis(p .. "dim", empty or wait and not still)', 'vis(p .. "dim", wait and not still)', EMPTY),
    (U, "if at[1] == \"actions\" then dx = dx + ((act_at[id:match(\"^act_(%a+)_\")] or 1) - 1) * L.action_pitch end", "", "the_action_bar_packs_the_shown_buttons_to_the_right"),
]
