M = "script/derpy_tp/main.lua"
R = "script/derpy_tp/rig.lua"
FLOOR, HILL = "the_camera_floor_is_lowered_only_while_on", "a_hill_behind_pulls_the_camera_in_not_up"
MUTANTS = [
    (M, "\t\tcam:change_height_range(0, 100)", "\t\t--", FLOOR),
    (M, "try(function() cam:change_height_range(-1, -1) end)", "", FLOOR),
    (R, "if y >= g or i == 1 then", "if true then", HILL),
    (R, "return x, math.max(y, g), z, i end", "return ex, math.max(ey, g), ez, i end", HILL),
]
