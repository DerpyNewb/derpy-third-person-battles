C = "script/derpy_tp/combat.lua"
R = "script/derpy_tp/rig.lua"
S = "script/derpy_tp/settings.lua"
G = "script/mct/settings/derpy_third_person.lua"
H = "script/derpy_tp/hud.lua"
RL = "the_reload_setting_scales_one_mans_reload"
MUTANTS = [
    (S, 'S.height = get("camera_height", 25) / 10', 'S.height = 2.5', "camera_height_and_lag_come_from_the_settings"),
    (S, 'S.lag = get("camera_lag", 45) / 100', 'S.lag = 0.45', "settings_camera_and_combat_tuning"),
    (S, 'S.aim_back = get("camera_aim_back", 32) / 10', 'S.aim_back = 3.2', "the_aiming_camera_sits_the_set_distance_back"),
    (S, 'S.reload_factor = get("combat_reload", 100) / 100', 'S.reload_factor = 1', RL),
    (S, 'S.spread = get("combat_spread", 15) / 10', 'S.spread = 1.5', "the_spread_setting_can_close_the_volley"),
    (R, "local tp = now - S.lag", "local tp = now - 0.45", "the_follow_delay_comes_from_the_settings"),
    (R, "R.sy + S.height * zm + lift", "R.sy + 2.5 * zm + lift", "camera_height_and_lag_come_from_the_settings"),
    (R, "(rx * OTS_SIDE - fx * S.aim_back) * zm", "(rx * OTS_SIDE - fx * 3.2) * zm", "the_aiming_camera_sits_the_set_distance_back"),
    (R, "(rz * OTS_SIDE - fz * S.aim_back) * zm", "(rz * OTS_SIDE - fz * 3.2) * zm", "the_aiming_camera_sits_the_set_distance_back"),
    (C, "(math.random() * 2 - 1) * E.S.spread, (math.random() * 2 - 1) * E.S.spread", "(math.random() * 2 - 1) * 1.5, (math.random() * 2 - 1) * 1.5", "the_spread_setting_can_close_the_volley"),
    (C, 'if shot and shot.phase == "reload" and E.S.reload_factor < 1 and now >= F.ready_at then', "if false then", RL),
    # (2026-10-16: the clip-length scaling went with "the game's reload time decides"; the factor itself)
    (C, "F.ready_at = now + E.D.shots[F.utype][2] * E.S.reload_factor\n", "F.ready_at = now + E.D.shots[F.utype][2]\n", RL),
    (G, 'slider("camera", "camera_height"', 'local _ = ("camera", "camera_height"', "mct_defaults_agree_with_settings"),
]
