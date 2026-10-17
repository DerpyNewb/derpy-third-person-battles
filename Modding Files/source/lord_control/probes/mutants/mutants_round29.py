C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
V = "script/derpy_tp/move.lua"
MUZ = "a_muzzle_inside_him_moves_out_along_the_shot"
RAISE = "the_first_high_shot_goes_from_the_raise_into_the_fire"
LEARN = "a_raise_data_lua_lacks_is_learned_on_the_first_shot"
FAST, WHOLE = "a_sprint_is_half_again_as_fast", "a_unit_played_whole_sprints_half_again_as_fast"
STALL, NEVER = "a_stall_with_the_keys_held_is_logged", "a_swing_the_engine_never_plays_is_logged"
# Round 29 (2026-10-16): a muzzle inside him moves out, each raise's length off its .anim, the sprint 1.2 times, and the
# in-combat stall logged
MUTANTS = [
    (C, "local SHOT_CLEAR = 1.1", "local SHOT_CLEAR = 0", MUZ),
    (C, "if c2 < 0 and a > 1e-4 then", "if false then", MUZ),
    (C, "local k = (-b + math.sqrt(b * b - a * c2)) / a", "local k = (-b - math.sqrt(b * b - a * c2)) / a", MUZ),
    (C, "from = v(fx + dx * k, fy + dy * k, fz + dz * k)", "from = v(fx + dx * k, fy, fz + dz * k)", MUZ),
    (C, "local len = r and r[shot.aim_slot - 1552]", "local len = nil", RAISE),
    (C, "local len = r and r[shot.aim_slot - 1552]", "local len = r and r[2]", RAISE),
    (C, "if not len or len <= 0 then len = aim_len", "if not len then len = aim_len", LEARN),
    (C, "\t\tif L.m and not L.seen then\n", "\t\tif false then\n", NEVER),
    (M, "F.sprinting and SPRINT_SPEED or 1) end", "1) end", FAST),
    (M, "local SPRINT_SPEED = 1.5", "local SPRINT_SPEED = 1.2", FAST),
    (M, "if E.S.debug and not paused then", "if false then", STALL),
    (M, "\t\t\t\ts.told = true\n", "\n", STALL),
    (M, "if kf == 0 and kr == 0 then F.stall = nil", "if false then F.stall = nil", STALL),
    (M, "elseif not s.told and gnow - s.t >= 1 then", "elseif not s.told and gnow - s.t >= 0.3 then", STALL),
    (V, "if speed ~= 1 then F.uc:change_current_walk_speed(speed) end", "", WHOLE),
    (V, "or run ~= F.run or speed ~= F.speed or", "or run ~= F.run or", WHOLE),
    (V, "F.kf, F.kr, F.run, F.speed, F.driving, F.last_order = kf, kr, run, speed, true, now",
     "F.kf, F.kr, F.run, F.driving, F.last_order = kf, kr, run, true, now", WHOLE),
    (V, "run, F.face_yaw, speed)", "run, F.face_yaw)", FAST),
]
RUN, LETGO, REG = "the_charge_attack_is_thrown_on_the_run", "letting_go_of_shift_in_the_charge_attack_does_not_cut_it", "a_regiment_throws_the_charge_attack_on_the_run"
CLICK = "a_click_in_the_charge_throws_the_charge_attack"
# the charge attack thrown on the run (2026-10-16): steered on, at the sprint, over his torso and arms, nothing over it
MUTANTS += [
    (C, "local TORSO_AND_ARMS = 1", "local TORSO_AND_ARMS = 0", CLICK),
    (C, "swing(SLOTS_RUN, true, now, nil, TORSO_AND_ARMS)", "swing(SLOTS_RUN, true, now)", CLICK),
    (C, "P.play(m, slot, mask) return m, slot end", "P.play(m, slot) return m, slot end", CLICK),
    (C, "\t\t\tF.lock.runs = true\n", "", RUN),
    (C, "(not C.locked(now) or F.lock.runs)", "not C.locked(now)", RUN),
    (C, "if F.lock then -- the charge attack, thrown on the run: neither clip over it", "if false then", LETGO),
    (M, "elseif E.combat.locked(gnow) and not F.lock.runs then", "elseif E.combat.locked(gnow) then", REG),
    (V, "not F.charging and not F.lock and now", "not F.charging and now", LETGO),
]
STOPPED = "a_charge_attack_he_stops_in_frees_his_arms_too"
FREE, CHG, CAPT = "the_charge_attack_frees_his_arms_when_its_clip_ends", "sprinting_on_past_the_charge_attack_the_charge_frees_it", "a_charge_attack_with_no_length_holds_to_the_cap"
# a charge attack on the run stays latched (measured 2026-10-16): the lock ends at its .anim length and frees it
MUTANTS += [
    (C, "local CLIP_START = 0.2", "local CLIP_START = 0.6", FREE),
    (C, "if len then F.lock.till = math.min(F.lock.till, now + len + CLIP_START) end", "", FREE),
    (C, "if L.runs and not F.sprinting then each(", "if L.runs then each(", CHG),
    (C, "if L.runs and not F.sprinting then each(", "if false then each(", STOPPED),
    (C, "local len = E.D.runs and E.D.runs[F.utype]", "local len = 1.6", CAPT),
]
