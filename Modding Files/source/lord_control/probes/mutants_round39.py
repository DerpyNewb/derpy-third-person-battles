# Round 39 (2026-10-17): the author, "the first person mode should work if the player scrolled to the lowest".
R = "script/derpy_tp/rig.lua"
M = "script/derpy_tp/main.lua"
ZOOMED = "zooming_in_all_the_way_goes_first_person"
# on flat ground the eye no longer fits behind him at the closest zoom, so only ground falling away behind him tells
# "closest" apart (round 40). Not here: dropping "step < 0" from the switch in; it differs only after V put him in
# third person where the eye does not fit, and a notch out there putting him in first person is not wrong
BANK = "zooming_in_once_the_ground_brings_the_eye_in_goes_first_person"
OUT = "elseif step > 0 and fits then E.first_person = false end"
MUTANTS = [
    (R, "return R.zoom <= ZOOM_MIN", "return false", BANK),
    (R, "return R.zoom <= ZOOM_MIN", "return R.zoom < ZOOM_MAX", ZOOMED),
    (M, OUT, "end", ZOOMED),
]
