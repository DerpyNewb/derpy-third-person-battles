C, MV, MN = "script/derpy_tp/combat.lua", "script/derpy_tp/move.lua", "script/derpy_tp/main.lua"
SLIDE, REST, SPACED = "a_step_after_the_mode_key_mid_aim_does_not_slide", "walking_from_rest_plays_no_clip", "a_clip_that_keeps_reporting_is_not_queued_every_frame"
CUT, KEEP, DELAY = "a_step_cuts_the_reload_short", "a_step_does_not_cut_the_aim_or_the_firing_clip", "a_cut_reload_still_delays_the_next_shot"
MODE, MID_AIM, XBOW = "the_mode_key_does_not_skip_the_reload", "the_mode_key_mid_aim_adds_no_wait", "a_crossbow_switching_modes_after_its_bolt_still_waits"
PLAY = "\t\t\t\tP.play(m, WALK_1, 0)\n"
STEER = "\t\t\tP.steer(m, x + dx * lead, z + dz * lead, run, F.face_yaw, speed)\n"
GATE = "if shot.launched then F.ready_at = (shot.reload_at or now) + E.D.shots[F.utype][2] * E.S.reload_factor end"
MUTANTS = [
    # the walking clip that ends a latched one (measured 2026-10-14, probes/zz_tp_unclip.lua)
    (MV, PLAY, "", SLIDE),
    (MV, PLAY, "", CUT),
    (MV, "P.play(m, WALK_1, 0)", "P.play(m, WALK_1, 6)", SLIDE),
    (MV, "if P.anim_slot(m) and not F.charging and not F.lock and now", "if true and not F.charging and not F.lock and now", REST),
    (MV, "\t\t\t\tF.unlatch_at = now + UNLATCH_GAP\n", "", SPACED),
    (MV, "local WALK_1, UNLATCH_GAP = 42, 0.3", "local WALK_1, UNLATCH_GAP = 43, 0.3", SLIDE),
    (MV, "\t\t\tend\n" + STEER, "\t\t\tend\n", SLIDE),
    (MV, PLAY + "\t\t\t\tF.unlatch_at = now + UNLATCH_GAP\n\t\t\tend\n" + STEER,
     "\t\t\t\tF.unlatch_at = now + UNLATCH_GAP\n\t\t\tend\n" + STEER + PLAY.replace("\t\t\t\t", "\t\t\t"), SLIDE),
    # a step ends the reload, never the aim or the firing clip
    (MN, "if F.shot and (kf ~= 0 or kr ~= 0) then E.combat.drop(gnow, true) end", "", CUT),
    (MN, "E.combat.drop(gnow, true)", "E.combat.drop(gnow)", KEEP),
    (C, '(step and shot.phase ~= "reload")', "false", KEEP),
    # the reload still counts after a cut
    (C, "\t\tif now < F.ready_at then return end\n", "", DELAY),
    (C, "\t\tif now < F.ready_at then return end\n", "", MODE),
    (C, GATE, "", MODE),
    (C, "if shot.launched then F.ready_at", "if true then F.ready_at", MID_AIM),
    # 2026-10-17: a crossbow exempted again, as before ("some ranged units bypass the reload time")
    (C, "if shot.launched then F.ready_at", "if shot.launched and F.reload_slot then F.ready_at", XBOW),
    (C, "(shot.reload_at or now)", "now", MODE),
    (C, "(shot.reload_at or now)", "(shot.reload_at or 0)", MODE),
    (C, "\t\t\t\tshot.reload_at = now\n", "", MODE),
    (C, "E.D.shots[F.utype][2] * E.S.reload_factor end", "0 end", DELAY),
    (C, "\t\tC.drop(now)\n\t\tF.want_shot = false", "\t\tF.want_shot = false", MODE),
]
