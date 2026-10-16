M = "script/derpy_tp/main.lua"
A, G = "clicking_another_unit_keeps_the_controlled_one_selected", "clicking_empty_ground_keeps_the_controlled_one_selected"
# re-aimed 2026-10-15 to the game's own selection (round 20); the callback set's three were dropped with it
NEW = "if bm:num_units_selected() ~= 1 or not selected(unit) then bm:clear_selection() unit:select_in_ui() end"
MUTANTS = [
    (M, NEW, "", A),
    (M, NEW, "if bm:num_units_selected() ~= 1 or not selected(unit) then bm:clear_selection() end", G),
]
