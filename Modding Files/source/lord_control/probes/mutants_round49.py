# Round 49 (2026-10-18): a crew on one body is played as a unit of one. The author: "cannot fire range mode using
# necrofex" - the Necrofex Colossus's five men are his crew on the one colossus (read live); played as the front man, his
# rider fire clip was sent 15 times and seen only on the crew's first man, and no shot left.
C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
CREW = "a_crew_on_one_body_is_played_as_a_unit_of_one"
ONCE = "a_crew_on_one_body_swings_once"
OWN = "riders_on_mounts_of_their_own_are_still_one_man"
MUTANTS = [
    (M, "\t\tif not body then return false end\n", "\t\tif not body then return false end return false\n", CREW),
    (M, "and not F.crew and E.move.front_man(unit) or nil", "and E.move.front_man(unit) or nil", CREW),
    (M, "(unit:number_of_men_alive() == 1 or F.crew)", "unit:number_of_men_alive() == 1", CREW),
    (M, "if not (b and P.same(b, body)) then return false end", "if not b then return false end", OWN),
    (C, "local one = F.model or F.single\n", "local one = F.model\n", ONCE),
    # his shot: the colossus's FIRE_LEVEL ran 6 s past his crewman's RIDER_FIRE (read live), and an idle holds nothing
    (C, "local mine, its = first and P.anim_slot(first), body and P.anim_slot(body)",
        "local mine, its = first and P.anim_slot(first), nil", "a_crews_shot_plays_out_on_the_body"),
    (C, "and (not last[2] or its ~= last[2])", "", "a_crews_shot_waits_for_every_shooting_clip_and_no_idle"),
    (C, "shooting(its) and its, now}", "its, now}", "a_crews_shot_waits_for_every_shooting_clip_and_no_idle"),
    (C, "s >= 2104 and s <= 2116) or nil end", "false) or nil end", "a_late_throw_is_held_to_its_release_and_plays_out"),
    (C, "local FIRE_TAIL = 10\n", "local FIRE_TAIL = 6\n", "a_crews_shot_plays_out_on_the_body"),
]
