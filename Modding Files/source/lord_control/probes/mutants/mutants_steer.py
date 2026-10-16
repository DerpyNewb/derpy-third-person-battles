L = "script/derpy_tp/platform.lua"
MV = "script/derpy_tp/move.lua"
LEAD = "P.steer(m, x + dx * MAN_LEAD, z + dz * MAN_LEAD, run, F.face_yaw, speed)"
STOP = 'if mr.eq(command, walk_a) or mr.eq(command, walk_b) then mr.call(walk_stop, "pointer(pointer)", m) end'
MUTANTS = [
    # walking: his own walk takes the point in place, anything else is replaced natively
    (L, "if mr.eq(command, walk_b) then", "if true then", "steering_leaves_the_aim_point_alone"),
    (L, "mr.write(m, 0x368, x)", "-- removed walk x", "steering_writes_his_own_walk_and_replaces_a_regiment_walk"),
    (L, "mr.write(m, 0x370, z)", "-- removed walk z", "steering_writes_his_own_walk_and_replaces_a_regiment_walk"),
    (L, "if mr.eq(command, walk_b) then", "if mr.eq(command, walk_b) or mr.eq(command, walk_a) then", "steering_writes_his_own_walk_and_replaces_a_regiment_walk"),
    (L, 'mr.call(walk_start, "pointer(pointer, pointer)", m, walk)', '-- removed native walk start', 'steering_starts_a_native_walk_from_idle'),
    (L, "if (x - mx) ^ 2 + (z - mz) ^ 2 <= 0.01 then return end", "", "steering_at_own_spot_does_not_start_a_walk"),
    (L, '0x44, 0x45, 0x4a', '0x45', 'steering_starts_a_native_walk_from_idle'),
    (L, 'unit, run and 1 or 0)', 'unit, 0)', 'steering_uses_native_run_speed'),
    (L, 'mr.write(m, 0x394, speed)', 'do end', 'steering_uses_native_run_speed'),
    (L, 'mr.write(walk, 0x46, mr.uint8(run and 1 or 0))', 'mr.write(walk, 0x46, mr.uint8(1))', 'steering_starts_a_native_walk_from_idle'),
    (L, 'if changed then mr.write(m, 0x3c0, mr.uint8(0)) end', 'if changed then do end end', 'steering_uses_native_run_speed'),
    (L, 'local changed = moved or', 'local changed =', 'steering_refreshes_a_changed_goal_without_a_gait_change'),
    (L, 'mr.write(m, 0xb0, mr.uint16(angle))', 'do end', 'solo_keeps_its_own_facing'),
    # holding still: a running walk gets the engine's stop, nothing else is touched (measured 2026-10-14)
    (L, STOP, STOP.replace("mr.eq(command, walk_a) or ", ""), "holding_still_stops_a_running_walk_natively"),
    (L, STOP, STOP.replace(" or mr.eq(command, walk_b)", ""), "holding_still_stops_a_running_walk_natively"),
    (L, STOP, 'mr.call(walk_stop, "pointer(pointer)", m)', "holding_still_leaves_a_standing_man_alone"),
    (L, STOP, "", "holding_still_stops_a_running_walk_natively"),
    (L, "end\n\t\tP.face(m, yaw)\n\tend", "end\n\tend", "holding_still_leaves_a_standing_man_alone"),
    (MV, "P.hold(m, F.man_hold[1], F.man_hold[2], not sw and (F.face_yaw or E.rig.yaw) or nil)", "P.steer(m, F.man_hold[1], F.man_hold[2], false, E.rig.yaw)", "one_man_walks_alone"),
    (MV, "P.hold(F.model, x, z, F.face_yaw or E.rig.yaw)", "P.steer(F.model, x, z, false, E.rig.yaw)", "one_man_stop_cancels_its_lead_point"),
    (MV, "if F.model and P.alive(F.unit, F.model) then", "if false then", "one_man_stop_cancels_its_lead_point"),
    (MV, LEAD, "P.place(m, x + dx * MAN_LEAD, z + dz * MAN_LEAD) " + LEAD, "one_man_never_nudges_through_a_wall"),
    (MV, LEAD, LEAD.replace(", F.face_yaw, speed)", ", nil, speed)"), "solo_moves_with_own_facing_and_run_toggle"),
    # starting and the fallback
    ("script/derpy_tp/main.lua", "and P.features.steer and not F.arty", "and not F.arty", "unknown_walk_commands_play_the_regiment_whole"),
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
