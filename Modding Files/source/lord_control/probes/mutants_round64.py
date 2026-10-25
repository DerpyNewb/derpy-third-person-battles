# Round 64 (2026-10-24): the author, "charge animations of characters are stil not looping properly, theres 1 frame
# glitching". The charge went again a tick before its clip ended, so every stride lost its last 0.1 s; it now goes again
# on the tick the clip ends.
CB = "script/derpy_tp/combat.lua"
WHOLE = "the_charge_goes_again_a_whole_clip_after_it_last_went"
AGAIN = "a_second_sprint_charges_again"
MUTANTS = [
    # a tick early, as before
    (CB, "len > 0 and len - TICK / 2 or LOCK_MAX", "len > 0 and len - TICK or LOCK_MAX", WHOLE),
    # on the tick exactly: a float sum a hair over it misses the tick, and the run shows for one
    (CB, "len > 0 and len - TICK / 2 or LOCK_MAX", "len > 0 and len or LOCK_MAX", WHOLE),
    # the known length kept past the sprint: the next one compares with nothing
    (CB, "F.charge_at, F.charge_seen, F.charge_known = nil, nil, nil", "F.charge_at, F.charge_seen = nil, nil", AGAIN),
]
