# Round 40 (2026-10-17): zooming in goes first person where the ground would bring the third-person eye in to his head
# (live: from zoom 0.9 on a slope, probes/zz_tp_zoomsweep.lua), and zooming out leaves it only where the eye fits behind.
R = "script/derpy_tp/rig.lua"
M = "script/derpy_tp/main.lua"
BANK = "zooming_in_once_the_ground_brings_the_eye_in_goes_first_person"
MUTANTS = [
    (R, "return i > 1", "return true", BANK),
    (R, "return i > 1", "return i > 0", BANK),
    (R, "if y >= g or i == 1 then return x, math.max(y, g), z, i end",
        "if y >= g or i == 1 then return x, math.max(y, g), z, 10 end", BANK),
    (M, "local fits = E.rig.fits(E.rig.zoom)", "local fits = E.rig.fits(1)", BANK),
    (M, "if step < 0 and (closest or not fits) then", "if step < 0 and closest then", BANK),
    (M, "if step < 0 and (closest or not fits) then", "if step < 0 and not fits then", BANK),
    (M, "elseif step > 0 and fits then", "elseif step > 0 then", BANK),
]
