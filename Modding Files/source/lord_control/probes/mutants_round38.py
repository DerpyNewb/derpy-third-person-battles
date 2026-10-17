# Round 38 (2026-10-17): the author, "make default cooldonw of melee attack to 4, jumpattack to 10".
S = "script/derpy_tp/settings.lua"
MCT = "script/mct/settings/derpy_third_person.lua"
MUTANTS = [
    (S, 'get("combat_swing_cooldown", 40)', 'get("combat_swing_cooldown", 15)', "settings_defaults_without_mct"),
    (S, 'get("combat_jump_cooldown", 100)', 'get("combat_jump_cooldown", 60)', "charge_and_jump_have_keys_and_settings"),
    (MCT, 'so this keeps them fair.", 40, 5, 100)', 'so this keeps them fair.", 15, 5, 100)', "mct_defaults_agree_with_settings"),
    (MCT, '"Tenths of a second between two jump attacks.", 100, 5, 300)', '"Tenths of a second between two jump attacks.", 60, 5, 300)',
     "mct_defaults_agree_with_settings"),
]
# "smoothness of the camera turning": the view eases to where the mouse put it
R = "script/derpy_tp/rig.lua"
M = "script/derpy_tp/main.lua"
K = "local k = S.smooth > 0 and 1 - math.exp(-dt / S.smooth) or 1"
MUTANTS += [
    (R, K, "local k = 1", "mouse_turns_the_camera"),
    (R, K, "local k = S.smooth > 0 and 1 - math.exp(-dt / S.smooth) or 0", "turn_smoothing_off_turns_at_once"),
    (R, "R.pitch + (R.want_pitch - R.pitch) * k", "R.want_pitch", "mouse_turns_the_camera"),
    (S, 'get("camera_smoothing", 5)', 'get("camera_smoothing", 0)', "settings_camera_and_combat_tuning"),
    # "first person camera"
    (M, "\t\t\tif P.pressed(S.keys.view) then E.first_person = not E.first_person end -- kept for the battle\n", "",
     "v_switches_to_first_person_and_back"),
    (M, "local head = E.first_person and (F.model or single) or nil", "local head = E.first_person and F.model or nil",
     "a_unit_of_one_sees_from_its_head"),
    (M, "local head = E.first_person and (F.model or single) or nil",
     "local head = E.first_person and (F.model or single or P.models(unit)[1]) or nil", "a_regiment_played_whole_stays_behind"),
    (R, "local FP_EYE, FP_AHEAD, FP_LAG, FP_PITCH_MIN = 0.92, 0.35, 0.25, -1.2",
     "local FP_EYE, FP_AHEAD, FP_LAG, FP_PITCH_MIN = 0.92, 0, 0.25, -1.2", "v_switches_to_first_person_and_back"),
    (R, "local FP_EYE, FP_AHEAD, FP_LAG, FP_PITCH_MIN = 0.92, 0.35, 0.25, -1.2",
     "local FP_EYE, FP_AHEAD, FP_LAG, FP_PITCH_MIN = 0.92, 0.35, 0.12, -1.2", "first_person_keeps_up_with_his_head"),
    (R, "local FP_EYE, FP_AHEAD, FP_LAG, FP_PITCH_MIN = 0.92, 0.35, 0.25, -1.2",
     "local FP_EYE, FP_AHEAD, FP_LAG, FP_PITCH_MIN = 0.92, 0.35, 0.45, -1.2", "first_person_keeps_up_with_his_head"),
    (R, "local FP_EYE, FP_AHEAD, FP_LAG, FP_PITCH_MIN = 0.92, 0.35, 0.25, -1.2",
     "local FP_EYE, FP_AHEAD, FP_LAG, FP_PITCH_MIN = 0.92, 0.35, 0.25, -0.25", "first_person_is_kept_and_looks_up_further"),
    (R, "local a = R.first and 1 or 1 - math.exp(-K_POS * dt)", "local a = 1 - math.exp(-K_POS * dt)",
     "first_person_keeps_up_with_his_head"),
    (R, "\t\tif not R.first and R.want_pitch < PITCH_MIN then R.want_pitch = PITCH_MIN end\n", "",
     "first_person_is_kept_and_looks_up_further"),
    (R, "local c = math.cos(R.pitch)\n\t\t\tlocal lx, ly, lz = ex + fx * c * AHEAD, ey - math.sin(R.pitch) * AHEAD",
     "local c = math.cos(R.pitch)\n\t\t\tlocal lx, ly, lz = ex + fx * c * AHEAD, ey + math.sin(R.pitch) * AHEAD", "v_switches_to_first_person_and_back"),
]
