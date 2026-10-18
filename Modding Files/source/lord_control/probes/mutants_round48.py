# Round 48 (2026-10-18): clips the pack timed on fixed numbers, read per unit instead. The author: "Kugath cant use his
# ranged attack ... why cant the full animation play" - his throw began 7 s after the order (his reload) and released
# 3.8 s into a 5.8 s clip, and the click's 4 s commit halted every one; "looping charging animation ... looks like its
# not looping but being cut off mid animation" - CHARGE re-sent every 0.6 s whatever its length (the Great Unclean
# One's 1.9 s); and his jump "never played": CA ships it as an empty file.
C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
THROW = "a_late_throw_is_held_to_its_release_and_plays_out"
MOVE = "a_move_key_ends_a_ground_fire_shot_still_to_come"
CYCLE = "the_charge_clip_plays_its_whole_cycle_before_it_goes_again"
OVER = "a_charge_of_no_known_length_goes_again_when_it_ends"
BLANK = "a_jump_whose_clip_is_an_empty_file_is_no_jump"
MUTANTS = [
    # the commit: the reload and the release in its cap, each
    (C, "+ (shot and shot[2] or 0)", "", THROW),
    (C, "local wait = FIRE_COMMIT + (fires and fires[1] and fires[1][1] or 0)", "local wait = FIRE_COMMIT",
        "a_click_just_after_a_shot_waits_the_whole_reload_and_the_release"),
    # after the shot: the clip it left in plays out
    (C, "local over = not last[1] or clip ~= last[1] or now - last[2] > FIRE_TAIL", "local over = true", THROW),
    (C, "if ammo < F.fire_ammo then F.fire_ammo, F.fire_clip = ammo, {clip, now} end",
        "if ammo < F.fire_ammo then F.fire_ammo, F.fire_clip = ammo, {nil, now} end", THROW),
    # a move key ends it
    (M, "if F.firing and not held and (kf ~= 0 or kr ~= 0) then E.combat.stop_fire() end", "", MOVE),
    # the charge at its own length, and at once when seen over
    (C, "len = len and len[air and 2 or 1] or 0", "len = 0", CYCLE),
    (C, "len > CHARGE_LEAD and len - CHARGE_LEAD or LOCK_MAX", "0.6", CYCLE),
    (C, "or F.charge_seen and not playing) then", ") then", OVER),
    (C, "\t\tif playing then F.charge_seen = true end\n", "", OVER),
    # an empty clip is no slot
    (M, "if P.has_slot(m, s) and not blank[s] then return true end", "if P.has_slot(m, s) then return true end", BLANK),
]
