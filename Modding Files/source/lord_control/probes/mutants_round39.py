# Round 39 (2026-10-17): the author, "the first person mode should work if the player scrolled to the lowest".
R = "script/derpy_tp/rig.lua"
M = "script/derpy_tp/main.lua"
ZOOMED = "zooming_in_all_the_way_goes_first_person"
SWITCH = "if step < 0 and closest then E.first_person = true elseif step > 0 then E.first_person = false end"
MUTANTS = [
    (R, "return R.zoom <= ZOOM_MIN", "return false", ZOOMED),
    (R, "return R.zoom <= ZOOM_MIN", "return R.zoom < ZOOM_MAX", ZOOMED),
    (M, SWITCH, "if step < 0 and closest then E.first_person = true end", ZOOMED),
    (M, SWITCH, "if closest then E.first_person = true end", ZOOMED),
]
