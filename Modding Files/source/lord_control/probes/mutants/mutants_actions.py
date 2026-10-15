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
    (M, "and not unit:can_fly()\n", "\n", "a_flying_unit_is_played_whole"),
    (M, "\n\t\tif F.model and not F.solo and unit:missile_range() > 0 then F.model = nil end", "", "a_regiment_whose_man_cannot_shoot_alone_is_played_whole"),
    (C, "elseif clicked then -- an artillery crew swings too", "elseif clicked and not F.arty then --", "an_artillery_crew_swings_on_a_click"),
    (M, "\n\t\t\tif F.model and not F.solo and unit:missile_range() > 0 then F.model = nil end", "", "the_next_man_who_cannot_shoot_alone_hands_over_to_the_regiment"),
    # a weapon team's man shoots alone, his reload on the clock
    (M, "P.features.anim and P.has_slot(F.model, 1557)\n", "P.features.anim and F.reload_slot ~= nil and P.has_slot(F.model, 1557)\n", TEAM),
    (C, "F.ready_at, F.shot = now + E.D.shots[F.utype][2] * E.S.reload_factor, nil", "F.ready_at, F.shot = now, nil", TEAM),
    # the camera floor
    (R, "local CLEAR = 1.6", "local CLEAR = 0.5", "looking_up_the_camera_comes_in_rather_than_being_lifted"),
    # the charge
    (C, "swing(SLOTS_RUN, true, now)", "swing(SLOTS_JUMP, true, now)", "a_click_in_the_charge_throws_the_charge_attack"),
    (C, "local on = want and F.can_charge and", "local on = want and", NOQ),
    (M, "F.can_charge, F.can_jump = any(484), any(489)", "F.can_charge, F.can_jump = true, any(489)", NOQ),
    # the jump
    (C, "if C.locked(now) or not F.can_jump or now < F.next_jump or", "if C.locked(now) or now < F.next_jump or", NOJ),
    (C, "F.next_jump = now + E.S.jump_cooldown", "F.next_jump = now", JUMP),
    (M, "if P.pressed(S.keys.jump) and F.dragging and not F.armed then E.combat.jump(gnow) end", "", JUMP),
    (S, 'S.jump_cooldown = get("combat_jump_cooldown", 60) / 10', "S.jump_cooldown = 6", "charge_and_jump_have_keys_and_settings"),
    # the lock
    (C, "		if now then F.lock = {from = now, till = now + LOCK_MAX} end\n", "", LOCK),
    (C, "		if C.locked(now) then return end\n		if clicked and F.charging", "		if clicked and F.charging", LOCK),
    (M, "elseif not F.firing and not E.combat.locked(gnow) then E.move.drive", "elseif not F.firing then E.move.drive", LOCK),
    (M, "elseif not F.firing and not E.combat.locked(gnow) then E.move.drive", "elseif not F.firing then E.move.drive", QLOCK),
    (C, "local LOCK_MAX, LOCK_START = 3, 0.25", "local LOCK_MAX, LOCK_START = 30, 0.25", CAP),
    (C, "if carrier and not any and F.lock and not F.lock.m then F.lock.m, F.lock.slot = carrier, played end", "", "the_lock_ends_with_the_clip"),
    # the HUD
    (U, "fire = F.unit:missile_range() > 0 and not F.arty,", "fire = true,", SHOWS),
    (U, "charge = F.can_charge,\n", "charge = true,\n", "the_action_bar_hides_charge_and_jump_without_their_clips"),
    (U, 'charge = "charge", jump = "jump"}', 'charge = "attack", jump = "jump"}', SHOWS),
    (U, 'show("attack", F.next_swing - now)', "", COUNTS),
    (U, 'show("jump", F.next_jump - now)', "", COUNTS),
    (U, 'show("charge", F.next_charge - now)', "", CHG),
    (U, "local secs = frac and frac < 1 and", "local secs = false and", RELOAD),
    (U, 'vis(p .. "dim", empty or wait)', 'vis(p .. "dim", wait)', EMPTY),
    (U, "if at[1] == \"actions\" then dx = dx + ((act_at[id:match(\"^act_(%a+)_\")] or 1) - 1) * L.action_pitch end", "", "the_action_bar_packs_the_shown_buttons_to_the_right"),
]
