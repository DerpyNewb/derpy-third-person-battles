MUTANTS = [
    ("script/battle/mod/derpy_third_person.lua", "if bm:is_multiplayer() or bm:is_replay() then", "if bm:is_multiplayer() then", "multiplayer_and_replays_do_nothing"),
    ("script/derpy_tp/main.lua", "F.dragging = false\n\t\t\tcursor(true)", "cursor(true)", "focus_return_does_not_jump_the_camera"),
]
