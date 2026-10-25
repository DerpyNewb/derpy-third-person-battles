# Round 70 (2026-10-25): a swing hits through its clip's SPLASH_ATTACK, so the attack slots with a clip that has none
# (data.lua dulls) are left out while one with a splash is left (combat.lua swing). Celestial Guard: all four dull.
COMBAT = "script/derpy_tp/combat.lua"
DULL = "a_swing_skips_the_clips_with_no_splash"
MUTANTS = [
    # the dull slots swung again
    (COMBAT, "if not dull[s] then keep[#keep + 1] = s end", "keep[#keep + 1] = s", DULL),
    # a unit with no splash clip left with nothing to swing
    (COMBAT, "if #keep > 0 then has = keep end", "has = keep", DULL),
    # the data never read
    (COMBAT, "E.D.dulls and E.D.dulls[F.utype] or {}", "{}", DULL),
]
