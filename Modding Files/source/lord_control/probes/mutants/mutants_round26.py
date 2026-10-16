C = "script/derpy_tp/combat.lua"
READY = "				F.ready_at = now + E.D.shots[F.utype][2] * E.S.reload_factor\n"
MUTANTS = [
    # the game's reload time decides the next shot, at 100% too, whatever the clip's length
    (C, READY, "				if E.S.reload_factor ~= 1 then F.ready_at = now + E.D.shots[F.utype][2] * E.S.reload_factor end\n",
     "the_reload_setting_scales_one_mans_reload"),
    (C, READY, "				if E.S.reload_factor ~= 1 then F.ready_at = now + E.D.shots[F.utype][2] * E.S.reload_factor end\n",
     "solo_hold_repeats_at_the_reload_pace"),
    (C, READY, "				if E.S.reload_factor ~= 1 then F.ready_at = now + E.D.shots[F.utype][2] * E.S.reload_factor end\n",
     "the_reload_ring_fills_through_the_reload_for_one_man"),
]
