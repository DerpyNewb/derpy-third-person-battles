# Round 68 (2026-10-25): three Workshop reports. Two humans on one side: F2 played the partner's general (CA's
# get_player_army() is the alliance's first army, not this machine's). Big ranged units shot themselves from 1.1 m out.
# Wind spells all went one way (the ground cast's orientation was never passed).
MAIN = "script/derpy_tp/main.lua"
COMBAT = "script/derpy_tp/combat.lua"
ABIL = "script/derpy_tp/abilities.lua"
ARMY = "f2_and_command_mode_take_this_machines_army_not_the_alliances_first"
BIG = "a_big_bodys_muzzle_clears_his_radius"
MAN = "a_muzzle_inside_him_moves_out_along_the_shot"
WIND = "a_ground_cast_goes_the_way_he_looks"
MUTANTS = [
    # CA's helper back: the alliance's first army
    (MAIN, "function E.army() return bm:get_player_alliance():armies():item(bm:local_army()) end",
     "function E.army() return bm:get_player_army() end", ARMY),
    # the first army by index
    (MAIN, "armies():item(bm:local_army())", "armies():item(1)", ARMY),
    # a big body cleared by a man's 1.1 m again
    (COMBAT, "local clear = body and body[1] > 1 and body[1] + 0.8 or SHOT_CLEAR", "local clear = SHOT_CLEAR", BIG),
    # cleared by the radius alone, no margin
    (COMBAT, "body[1] > 1 and body[1] + 0.8", "body[1] > 1 and body[1]", BIG),
    # the radius rule for every man: a man's 0.5 m gives 1.3, not his 1.1
    (COMBAT, "body and body[1] > 1 and body[1] + 0.8", "body and body[1] + 0.8", MAN),
    # no orientation: CA's default 0
    (ABIL, ", v(x, bm:get_terrain_height(x, z), z),\n\t\t\t\tmath.deg(E.rig.yaw) % 360)", ", v(x, bm:get_terrain_height(x, z), z))", WIND),
    # radians where CA takes degrees
    (ABIL, "math.deg(E.rig.yaw) % 360)", "E.rig.yaw)", WIND),
]
