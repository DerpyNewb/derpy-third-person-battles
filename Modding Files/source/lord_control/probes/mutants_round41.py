# Round 41 (2026-10-17): the author, "are mounted archers not supported? they are missing their ranged option" - a
# rider with no FIRE_LEVEL or GRENADIER shoots from RIDER_FIRE_FORWARD_LEVEL (2105); "add 50% speed boost when
# charging/sprinting" is round 29's SPRINT_SPEED mutant, re-aimed at 1.5.
M = "script/derpy_tp/main.lua"
HORSE = "a_horse_archer_shoots_from_the_saddle_alone"
MUTANTS = [
    (M, "for _, s in ipairs({1557, 949, 2105}) do", "for _, s in ipairs({1557, 949}) do", HORSE),
    (M, "if P.has_slot(m, s) then return s end", "if P.has_slot(m, s) then return 1557 end", HORSE),
]
