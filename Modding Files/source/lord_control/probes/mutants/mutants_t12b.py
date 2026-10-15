A = "script/derpy_tp/abilities.lua"
MUTANTS = [
    (A, "local key = list and list[n]", "local key = list and list[1]", "ability_key_n_casts_slot_n"),
    (A, "if t > 0 and t < RANGE then", "if true then", "ability_ignores_units_behind_the_camera"),
]
