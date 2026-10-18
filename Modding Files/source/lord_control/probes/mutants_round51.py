# Round 51 (2026-10-18): the siege walk and artillery. A steering point the pathfinder finds no way to ends his walk
# (P.walk_ended, his own walk's done byte +0x340): the next is built nearer, halved to LEAD_MIN, then back to 15 m after
# LEAD_BACK (the author: in sieges "the unit cannot move normally forward, as if theres a barrier"). A gun's click is its
# attack order on the enemy nearest the crosshair within its range; its crew never swing, charge or jump (the author:
# "I am only controlling the gunners, not the artillery piece itself").
MV, MAIN, C, P = "script/derpy_tp/move.lua", "script/derpy_tp/main.lua", "script/derpy_tp/combat.lua", "script/derpy_tp/platform.lua"
NEARER, ENDED = "a_walk_the_engine_ends_is_built_again_nearer", "an_ended_walk_is_read_off_his_own_walk"
FIRES, NEVER = "an_artillery_click_fires_the_gun_at_the_crosshair", "an_artillery_crew_never_swings"
MUTANTS = [
    (MV, "if P.walk_ended(m) then", "if false then", NEARER),
    (MV, "if F.lead and now - F.lead_end >= LEAD_BACK then", "if false then", NEARER),
    (MV, "F.lead, F.lead_end, F.lead_retry = math.max(LEAD_MIN, lead / 2), now, now + LEAD_RETRY",
        "F.lead, F.lead_end, F.lead_retry = LEAD_MIN, now, now + LEAD_RETRY", NEARER),
    (MV, "if lead > LEAD_MIN or now >= (F.lead_retry or 0) then", "if true then", NEARER),
    (P, "and mr.read_uint8(m, 0x340) ~= 0", "and mr.read_uint8(m, 0x341) ~= 0", ENDED),
    (P, "return mr.eq(mr.read_pointer(m, 0x330), walk_b) and", "return true and", ENDED),
    (MAIN, "F.can_charge, F.can_jump = not F.arty and any(484), not F.arty and any(489)",
        "F.can_charge, F.can_jump = any(484), any(489)", NEVER),
    (C, "elseif clicked and not F.arty then", "elseif clicked then", NEVER),
    (MAIN, "F.ranged = E.can_shoot()", "F.ranged = E.can_shoot() and not F.arty", FIRES),
    (C, "if F.arty then if clicked then order(true, F.unit:missile_range()) end", "if F.arty then if clicked then order(true) end", FIRES),
]
