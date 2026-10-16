C = "script/derpy_tp/combat.lua"
MUTANTS = [
    (C, "C.drop(now)\n\t\tF.face_yaw = nil\n", "C.drop(now)\n", "a_swing_turns_a_walked_man_back_to_the_crosshair"),
    (C, "F.face_yaw = nil -- he shoots along the crosshair", "", "a_shot_turns_a_walked_man_back_to_the_crosshair"),
]
