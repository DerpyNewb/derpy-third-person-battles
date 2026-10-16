C, M, V = "script/derpy_tp/combat.lua", "script/derpy_tp/main.lua", "script/derpy_tp/move.lua"
FACE_TILL = "a_swing_faces_the_camera_until_its_clip_is_reported"
SWING_END, CHEER_END = "a_swing_clip_turns_him_to_its_end", "a_cheer_clip_turns_him_to_its_end"
ACT = """		C.drop(now)
		F.face_yaw = nil
		if F.model then P.face(F.model, E.rig.yaw) end"""
LAUNCH = "return math.atan((v * v - math.sqrt(math.max(0, v ^ 4 - G * (G * d * d + h * v * v * 2)))) / (G * d))"
MUTANTS = [
    # one man gives his regiment no attack order
    (C, "		if F.model then return end\n", "", "one_man_with_no_clip_for_a_swing_gives_no_attack_order"),
    (C, "		if F.model then return end\n", "", "a_swing_with_no_clip_does_not_hold_the_walk"),
    # an action drops a shot under way and ends a charge's run
    (C, ACT, ACT.replace("		C.drop(now)\n", ""), "a_jump_drops_a_shot_under_way"),
    # a swing's and a cheer's clip turns him: faced until reported, then left to the clip to its end
    (C, "turns = hold ~= nil}", "turns = false}", SWING_END),
    (C, "					if F.lock.turns then F.swung = {carrier, played} end\n", "", SWING_END),
    (M, "not (F.lock.turns and F.lock.seen)", "not F.lock.turns", FACE_TILL),
    (M, "not (F.lock.turns and F.lock.seen)", "true", FACE_TILL),
    (V, "			if sw and P.anim_slot(sw[1]) ~= sw[2] then F.swung, sw = nil, nil end\n", "", CHEER_END),
    (V, "not sw and (F.face_yaw or E.rig.yaw) or nil", "F.face_yaw or E.rig.yaw", SWING_END),
    (V, "not sw and (F.face_yaw or E.rig.yaw) or nil", "F.face_yaw or E.rig.yaw", CHEER_END),
    (C, "LOCK_MAX, yaw = E.rig.yaw, turns = true}", "LOCK_MAX, yaw = E.rig.yaw}", CHEER_END),
    (C, "F.lock.m, F.lock.slot, F.swung = m, slot, {m, slot}", "F.lock.m, F.lock.slot = m, slot", CHEER_END),
    # the mode key's swing waits for an action under way
    (C, "if C.locked(now) or now < F.next_swing then return end", "if now < F.next_swing then return end",
     "a_right_click_waits_for_a_jump"),
    # ground fire: the commit from the click; the gap from any order, the walk's halt included
    (C, "F.firing, F.fire_ammo, F.fire_order_t = true, F.unit:ammo_left(), now", "F.firing, F.fire_ammo = true, F.unit:ammo_left()",
     "ground_fire_that_cannot_turn_gives_up_after_its_commit"),
    (V, "F.driving, F.last_order = false, bm:time_elapsed_ms() / 1000", "F.driving = false",
     "a_ground_fire_click_just_after_stopping_is_not_dropped"),
    (C, "		if now - (F.last_order or -1e9) < STEER_GAP\n			or F.fire_at",
     "		if F.fire_at and now - (F.last_order or -1e9) < STEER_GAP\n			or F.fire_at",
     "a_ground_fire_click_just_after_stopping_is_not_dropped"),
    # turning on the frame's real time
    (M, "		F.dt = dt -- real time", "		-- real time", "turning_keeps_its_rate_on_the_games_clock"),
    # the dead man's lock goes with him; a new session faces the camera
    (M, "F.model, F.man_hold, F.shot, F.lock, F.swung = E.move.front_man(unit), nil, nil, nil, nil",
     "F.model, F.man_hold, F.shot = E.move.front_man(unit), nil, nil", "the_next_man_is_not_held_by_the_dead_mans_lock"),
    (M, "F.melee_on, F.face_yaw, F.queued = nil, 0, nil, false, false, nil, nil", "F.melee_on, F.queued = nil, 0, nil, false, false, nil",
     "a_new_session_starts_facing_the_camera"),
    # every order waits STEER_GAP from the last, whichever sent it (round 25b)
    (M, "		F.last_order = bm:time_elapsed_ms() / 1000 -- an order: the first click", "		-- an order: the first click",
     "a_ground_fire_click_just_after_f2_is_not_dropped"),
    (C, "		F.last_order = bm:time_elapsed_ms() / 1000 -- an order: the next click's fire", "		-- an order: the next click's fire",
     "a_ground_fire_just_after_the_last_one_ended_is_not_dropped"),
    (C, "if not F.queued or now - (F.last_order or -1e9) < STEER_GAP then return end", "if not F.queued then return end",
     "a_whole_unit_click_just_after_stopping_attacks"),
    (C, "if not F.queued or now - (F.last_order or -1e9) < STEER_GAP then return end", "if not F.queued then return end",
     "a_whole_unit_turn_just_after_stopping_is_not_dropped"),
    (C, "		F.driving, F.last_order = false, now\n	end\n\n	local function send", "		F.driving = false\n	end\n\n	local function send",
     "a_whole_unit_turned_to_swing_keeps_its_attack_order"),
    (V, "local dt = F.dt or 0", "local dt = math.min(0.05, F.dt or 0)", "turning_keeps_its_rate_at_a_low_frame_rate"),
    (C, "		C.flush(now)\n		if C.locked(now) then return end", "		if C.locked(now) then return end",
     "a_whole_unit_click_just_after_stopping_attacks"),
    (M, "F.melee_on, F.face_yaw, F.queued = nil, 0, nil, false, false, nil, nil", "F.melee_on, F.face_yaw = nil, 0, nil, false, false, nil",
     "an_order_waiting_at_f2_is_not_sent_later"),
    # shots: a spawn in the clip's last tick; a clip that never plays gives up
    (C, 'if shot.phase == "fire" and shot.times then', 'if shot.phase == "fire" and clip == shot.slot and shot.times then',
     "a_spawn_due_as_the_fire_clip_ends_still_leaves"),
    (C, "		if shot and not shot.started and now >= shot.sent + LOCK_WAIT then C.drop(now) shot = nil end\n", "",
     "a_shot_whose_clip_never_plays_gives_up"),
    # the pair, by the angle the shot leaves at
    (C, 'a >= BAND and "high"', 'a >= BAND * 2 and "high"', "a_long_shot_raises_and_fires_high"),
    (C, 'a <= -BAND and "low"', 'a <= -BAND * 3 and "low"', "a_shot_steeply_down_raises_and_fires_low"),
    (C, 'local want = a >= BAND and "high" or a <= -BAND and "low" or "level"', 'local want = "level"', "a_long_shot_raises_and_fires_high"),
    (C, "not (fires and fires[F.utype]) or ", "", "a_unit_with_no_high_muzzle_keeps_the_level_pair"),
    (C, "or not P.has_slot(F.model, p[2])", "", "a_man_without_the_high_fire_clip_keeps_the_level_pair"),
    (C, "\n			or P.has_slot(F.model, p[1]) ~= P.has_slot(F.model, SLOT_AIM) then", " then",
     "a_man_without_the_whole_high_pair_keeps_the_level_one"),
    (C, LAUNCH, LAUNCH.replace("math.max(0, v ^ 4 - G * (G * d * d + h * v * v * 2))", "v ^ 4 - G * (G * d * d + h * v * v * 2)"),
     "a_shot_past_its_arc_still_goes_high"),
    (C, "if not v then return math.atan2(h, d) end", "if not v then return 0 end", "a_shot_with_no_known_speed_steeply_down_goes_low"),
    (C, "if not v then return math.atan2(h, d) end", "", "a_shot_with_no_known_speed_goes_by_the_straight_line"),
    (C, 'shot.fire_slot = pair == "level" and F.fire_slot or PAIRS[pair][2]', "shot.fire_slot = F.fire_slot",
     "a_long_shot_raises_and_fires_high"),
    (C, 'local fires = E.D[shot.pair == "level" and "fires" or "fires_" .. shot.pair]', "local fires = E.D.fires",
     "a_long_shot_raises_and_fires_high"),
    (C, "len = aim_len[F.utype .. shot.aim_slot] end", "len = aim_len[F.utype] end",
     "later_shots_send_fire_before_the_raise_ends"),
    (C, "len = aim_len[F.utype .. shot.aim_slot] end", "len = aim_len[F.utype .. 1554] end",
     "a_high_raise_does_not_take_the_level_ones_length"),
    # act's start face: the only one when the engine reports the clip at once
    (C, ACT, ACT.replace("\n		if F.model then P.face(F.model, E.rig.yaw) end", ""), "a_swing_lets_its_clip_turn_him"),
]
