# Round 42 (2026-10-17): the author, "flying units still controls the whole battalion as well when moving" - a flyer is
# played as one man (measured live: a Birdman steered alone, probes/zz_tp_fly_one.lua).
M = "script/derpy_tp/main.lua"
FLY = "a_flying_unit_is_played_one_man"
MUTANTS = [
    (M, "and not F.arty and not unit:is_war_machine()\n", "and not F.arty and not unit:is_war_machine() and not unit:can_fly()\n", FLY),
]
