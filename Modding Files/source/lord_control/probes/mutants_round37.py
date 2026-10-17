# Round 37 (2026-10-17): "test out artillery and warmachines with the mod" - the mode key's Manual fire opened and the game
# closed it again within 1.2 s on all four guns: the click came 0.1-0.3 s after third person's stop, before what the stop
# puts back had settled.
C = "script/derpy_tp/combat.lua"
SETTLE = "manual_fire_waits_for_the_game_to_settle"
MUTANTS = [
    (C, "\t\t\t\tif now - fp.t < SETTLE then return end\n", "", SETTLE),
    (C, "local SETTLE = 1", "local SETTLE = 0.2", SETTLE),
    (C, "local SETTLE = 1", "local SETTLE = 3", "artillery_mode_opens_manual_fire"),
]
