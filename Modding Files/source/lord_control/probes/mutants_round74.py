# Round 74 (2026-11-12): the Deceiver's raise as a shot under way, and a routing enemy as an ability's target
# (docs/sessions/WORKSHOP_REPORTS_20261112_THIRD_PERSON.md). Each a plausible slip, not a typo.
CMB = "script/derpy_tp/combat.lua"
ABL = "script/derpy_tp/abilities.lua"
RAISE = "a_unit_of_one_raising_to_shoot_is_not_re_aimed"
ROUT = "an_enemy_ability_lands_on_a_routing_enemy"
MUTANTS = [
    # the lowering left out of the shooting clips; the raise there instead
    (CMB, "\n\tor s == 1464) or nil end", ") or nil end", RAISE),
    (CMB, "or s == 1464) or nil end", "or s == 1465) or nil end", RAISE),
    # raised and waiting for his reload, left open: no hold; the hold only a tail; held forever; never let go by the throw;
    # the raise read off the lowering
    (CMB, " or F.raised and now - F.raised < (shot and shot[2] or 0)", "", RAISE),
    (CMB, "now - F.raised < (shot and shot[2] or 0)", "now - F.raised < STEER_GAP", RAISE),
    (CMB, "now - F.raised < (shot and shot[2] or 0)", "now - F.raised < 1e9", RAISE),
    (CMB, "{shooting(mine) and mine, shooting(its) and its, now}, nil end", "{shooting(mine) and mine, shooting(its) and its, now}, F.raised end", RAISE),
    (CMB, "if mine == 1465 or its == 1465 then F.raised = now end", "if mine == 1464 or its == 1464 then F.raised = now end", RAISE),
    # his own clip recorded and his body's not (the Necrofex Colossus's shot is the colossus's)
    (CMB, "if shooting(mine) or shooting(its) then F.shot_seen = now end", "if shooting(mine) then F.shot_seen = now end",
     "a_shot_under_way_is_not_re_aimed"),
    # routing enemies still skipped; the rule turned the wrong way round (friends allowed, enemies not)
    (ABL, "(enemy or not u:is_routing())", "not u:is_routing()", ROUT),
    (ABL, "(enemy or not u:is_routing())", "(not enemy or not u:is_routing())", ROUT),
]
