C = "script/derpy_tp/combat.lua"
T = "later_shots_send_fire_before_the_raise_ends"
MUTANTS = [
    (C, "and len and now >= shot.at + len - AIM_LEAD then", "and false then", T),
    (C, "and len and now >= shot.at + len - AIM_LEAD then", "and len and now >= shot.at + len then", T),
    (C, "aim_len[F.utype .. shot.aim_slot] = aim_len[F.utype .. shot.aim_slot] or now - shot.at", "aim_len[F.utype .. shot.aim_slot] = nil", T),
    (C, "shot.started, shot.at = true, now", "shot.started, shot.at = true, 0", T),
    (C, "local AIM_LEAD = 0.15", "local AIM_LEAD = 1.5", T),
]
