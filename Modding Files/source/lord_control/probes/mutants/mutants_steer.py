L = "script/derpy_tp/platform.lua"
MV = "script/derpy_tp/move.lua"
LEAD = "P.steer(m, x + dx * lead, z + dz * lead, run, F.face_yaw, speed)"
WALK, HOLD = "a_steer_posts_the_walk_builders_block", "holding_still_posts_a_stop"
MUTANTS = [
    # walking (2026-10-17: posted to the mailbox; the in-place-or-build decision is the cave's, and
    # tools/third_person_cave.py --selftest breaks that half)
    (L, "mr.write(m, 0xb0, mr.uint16(angle))", "do end", WALK),
    (L, "mr.write(block, b, x) mr.write(block, b + 4, my)", "mr.write(block, b + 4, my)", WALK),
    (L, "mr.write(block, b + 8, z)", "", WALK),
    (L, "unit, run and 1 or 0)", "unit, 0)", WALK),
    (L, "if scale then speed = speed * scale end", "", WALK),
    (L, "if not speed then return end", "", WALK),
    (L, "mr.write(block, b + 0x46, mr.uint8(run and 1 or 0))", "mr.write(block, b + 0x46, mr.uint8(1))", WALK),
    (L, "mr.write(block, b + 0x28, mr.uint32(run and 1 or 0))", "mr.write(block, b + 0x28, mr.uint32(1))", WALK),
    (L, "mr.write(block, MB.has_angle, mr.uint8(angle and 1 or 0))", "mr.write(block, MB.has_angle, mr.uint8(1))", WALK),
    (L, "<= 0.01 and 1 or 0))", "<= 0.01 and 0 or 0))", WALK),
    (L, 'post(m, "walk", 2)', 'post(m, "walk", 1)', WALK),
    (L, "mr.write(block, b + 0x30, mr.uint16(angle or", "mr.write(block, b + 0x30, mr.uint16(nil or", WALK),
    (L, "\t\tif not block then return end\n\t\tlocal unit", "\t\tlocal unit", "no_mailbox_nothing_is_posted_and_nothing_called"),
    # holding still: a running walk gets the engine's stop, nothing else is touched (measured 2026-10-14)
    (L, '\t\tif block then post(m, "walk", 1) end\n', "", HOLD),
    (L, 'if block then post(m, "walk", 1) end', 'if block then post(m, "walk", 2) end', HOLD),
    (L, 'if block then post(m, "walk", 1) end', 'post(m, "walk", 1)', "no_mailbox_nothing_is_posted_and_nothing_called"),
    (L, "end\n\t\tP.face(m, yaw)\n\tend", "end\n\tend", HOLD),
    (MV, "P.hold(m, F.man_hold[1], F.man_hold[2], not sw and (F.face_yaw or E.rig.yaw) or nil)", "P.steer(m, F.man_hold[1], F.man_hold[2], false, E.rig.yaw)", "one_man_walks_alone"),
    (MV, "P.hold(man, x, z, F.face_yaw or E.rig.yaw)", "P.steer(man, x, z, false, E.rig.yaw)", "one_man_stop_cancels_its_lead_point"),
    (MV, "if man and P.alive(F.unit, man) then", "if false then", "one_man_stop_cancels_its_lead_point"),
    (MV, LEAD, "P.place(m, x + dx * lead, z + dz * lead) " + LEAD, "one_man_never_nudges_through_a_wall"),
    (MV, LEAD, LEAD.replace(", F.face_yaw, speed)", ", nil, speed)"), "solo_moves_with_own_facing_and_run_toggle"),
    # starting and the fallback
    ("script/derpy_tp/main.lua", "S.one_man and men_ok and P.features.steer and P.features.mailbox and not F.arty", "S.one_man and men_ok and P.features.mailbox and not F.arty", "unknown_walk_commands_play_the_regiment_whole"),
    ("script/derpy_tp/main.lua", "F.uc:halt()", "do end", "solo_start_cancels_the_existing_attack_order"),
    ("script/derpy_tp/main.lua", "F.uc:halt()", "do end", "f2_cancels_existing_movement_before_accepting_input"),
    ("script/derpy_tp/main.lua", 'c:SetVisible(false)', 'c:SetVisible(true)', 'third_person_hides_unrequested_hud'),
    ("script/derpy_tp/main.lua", 'try(hud, true)', 'do end', 'third_person_restores_hud_visibility_after_error'),
    # flying: the game's own Toggle flying button (the author, 2026-10-14)
    ("script/derpy_tp/main.lua", "if P.pressed(S.keys.fly) and F.dragging then toggle_flying() end", "", "fly_key_presses_the_games_toggle_flying_button"),
    ("script/derpy_tp/main.lua", "if b then b:SimulateLClick() else", "if false then b:SimulateLClick() else", "fly_key_presses_the_games_toggle_flying_button"),
    ("script/derpy_tp/main.lua", 'else E.once("fly", "no Toggle flying button for " .. F.utype) end', "end", "fly_key_without_the_button_says_so_once"),
    # no hover panels in third person (the author, 2026-10-14)
    ("script/derpy_tp/main.lua", "bm.battle:enable_tooltips(false)", "do end", "third_person_switches_tooltips_off_and_back"),
    ("script/derpy_tp/main.lua", "try(function() bm.battle:enable_tooltips(true) end)", "", "third_person_switches_tooltips_off_and_back"),
]
