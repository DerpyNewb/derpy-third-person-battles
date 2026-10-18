# Round 45 (2026-10-18): the sprint, the fly charge and the camera. CA's change_current_walk_speed leaves a single
# entity's speed alone at any scale, run or walk (probes/zz_tp_walk_scalar.lua), so a lord, hero or monster never sprinted
# (the author, 2026-10-17: "charging doesnt even speedup units"); a unit of one now walks steered alone through the
# mailbox, as one man does, from a point 15 m ahead (probes/zz_tp_entity_steer.lua). In the air the sprint plays his
# FLY_CHARGE_AIR_TO_AIR, not the ground CHARGE, and throws no charge attack (2026-10-18: "charging belakors triggers his
# land charge run"). Melee mode centres the camera on him, an ability armed looks ahead, and the aiming shoulder can be
# top (2026-10-17: "center when melee, shoulder either left right or top on options, right as default").
M = "script/derpy_tp/move.lua"
C = "script/derpy_tp/combat.lua"
MAIN = "script/derpy_tp/main.lua"
R = "script/derpy_tp/rig.lua"
S = "script/derpy_tp/settings.lua"
AIR = "in_the_air_the_sprint_plays_his_fly_charge"
NONE = "a_flyer_with_no_fly_charge_plays_no_charge_in_the_air"
ONE = "a_single_entity_is_steered_alone_and_sprints"
MUTANTS = [
    # the fly charge
    (C, "local clip = F.unit:is_currently_flying() and FLY_CHARGE or CHARGE", "local clip = CHARGE", AIR),
    (C, "if P.has_slot(m, clip) then P.play(m, clip, 6) end", "if P.has_slot(m, CHARGE) then P.play(m, CHARGE, 6) end", AIR),
    (C, "and P.has_slot(first, clip) and P.features.anim", "and P.has_slot(first, CHARGE) and P.features.anim", NONE),
    (C, "and now >= F.next_charge and not F.unit:is_currently_flying() then", "and now >= F.next_charge then", AIR),
    # a unit of one steered alone
    (MAIN, "F.single = F.single_steer and single or nil", "F.single = nil", ONE),
    (MAIN, "F.single_steer = not F.model and men_ok and P.features.steer and P.features.mailbox and",
     "F.single_steer = not F.model and men_ok and P.features.steer and", "a_single_entity_with_no_mailbox_walks_by_orders"),
    (MAIN, "\t\tif P.features.steer and not P.features.mailbox then",
     "\t\tif S.one_man and P.features.steer and not P.features.mailbox then", "a_single_entity_is_steered_with_one_man_off"),
    (MAIN, "\t\t\tand not unit:is_war_machine()\n", "\n", "a_war_machine_of_one_walks_by_orders"),
    (M, "P.steer(m, x + dx * STEER_LEAD, z + dz * STEER_LEAD,", "P.steer(m, x + dx * 3, z + dz * 3,", ONE),
    (M, "if F.model or F.single then man_drive(now, dx, dz, run, speed) return end",
     "if F.model then man_drive(now, dx, dz, run, speed) return end", ONE),
    (M, "\t\tlocal man = F.model or F.single\n\t\tif man and P.alive(F.unit, man) then",
     "\t\tlocal man = F.model\n\t\tif man and P.alive(F.unit, man) then", "f2_off_in_mid_walk_holds_a_single_entity"),
    # the camera
    (R, "local ahead = AHEAD * zm * (1 - R.centre)", "local ahead = AHEAD * zm", "rig_looks_at_him_when_centred"),
    (R, "\t\tR.centre = R.centre + ((centre and 1 or 0) - R.centre) * math.min(1, OTS_RATE * dt)\n", "\n",
     "rig_looks_at_him_when_centred"),
    (R, "R.close, R.centre = yaw, 0, zoom, ranged and 1 or 0, 0, ranged and 0 or 1",
     "R.close, R.centre = yaw, 0, zoom, ranged and 1 or 0, 0, 0", "rig_looks_at_him_when_centred"),
    (MAIN, "height, not F.ranged and not F.armed)", "height, not F.ranged)",
     "melee_mode_centres_the_camera_on_him_but_not_aiming_an_ability"),
    (MAIN, "height, not F.ranged and not F.armed)", "height, false)",
     "melee_mode_centres_the_camera_on_him_but_not_aiming_an_ability"),
    (R, "local up = S.shoulder == 0 and OTS_TOP or OTS_HEIGHT", "local up = OTS_HEIGHT", "rig_shoulder_side"),
    (S, "({left = -1, right = 1, top = 0})", "({left = -1, right = 1, top = 1})", "settings_reads_mct"),
]
