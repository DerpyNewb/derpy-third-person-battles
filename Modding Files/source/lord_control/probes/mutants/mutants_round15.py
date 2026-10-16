C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
V = "script/derpy_tp/move.lua"
WM = "a_war_machine_swings_with_a_crew_that_has_the_clip"
MOD = "a_modded_shooter_takes_his_shot_from_his_own_context"
FACE = "one_man_faces_where_he_walks"
EARLY = "an_early_fire_command_still_waits_for_the_fire_clip"
MUTANTS = [
    (C, "elseif P.has_slot(m, slot) then P.play(m, slot, mask) return m, slot end", "end", WM),
    (C, "if P.features.anim and F.men_ok then swing(", "if P.features.anim and F.men_ok and not F.unit:is_war_machine() then swing(", WM),
    (M, "\t\tlearn_shot(unit)\n", "", MOD),
    (M, "E.D.shots[t] = {key, reload, n}", "E.D.shots[t] = nil", MOD),
    (V, "\t\t\tF.face_yaw = face\n", "", FACE),
    (V, "P.hold(m, F.man_hold[1], F.man_hold[2], not sw and (F.face_yaw or E.rig.yaw) or nil)", "P.hold(m, F.man_hold[1], F.man_hold[2], not sw and E.rig.yaw or nil)", FACE),
    (C, "shot.from, shot.spawned = math.max(now, shot.raise_end or now), 0", "shot.from, shot.spawned = now, 0", EARLY),
    (C, "\t\t\t\tshot.raise_end = shot.at + len\n", "", EARLY),
]
