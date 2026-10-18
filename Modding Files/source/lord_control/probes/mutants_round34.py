C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
V = "script/derpy_tp/move.lua"
HORSE = "a_horses_steering_point_is_far_enough_to_run"
SHOT = "a_raise_reported_late_still_goes_straight_into_its_hold"
BLOCK = "a_swing_held_back_by_a_block_still_plays"
NEVER = "a_swing_that_never_plays_gives_him_back_after_lock_max"
MUTANTS = [
    # the horse's steering point
    (V, "local STEER_LEAD = 15", "local STEER_LEAD = 3", HORSE),
    (V, "P.steer(m, x + dx * STEER_LEAD, z + dz * STEER_LEAD,", "P.steer(m, x + dx * 3, z + dz * 3,", "one_man_walks_alone"),
    # the shot's lead timed from the raise's send
    (C, "now >= shot.sent + len - AIM_LEAD then", "now >= shot.at + len - AIM_LEAD then", SHOT),
    # a swing held back past its lock
    (C, "\t\t\tF.pending = {m = L.m, slot = L.slot, till = L.from + LOCK_MAX}\n", "", BLOCK),
    (C, "till = L.from + LOCK_MAX}", "till = L.from + LOCK_WAIT}", BLOCK),
    (M, "if F.lock or F.swung or F.native_attack or F.pending then", "if F.lock or F.swung or F.native_attack then", BLOCK),
    (M, "\t\t\t\tif c == pd.slot then pd.seen = true end\n", "", BLOCK),
    (M, "if pd.seen and c ~= pd.slot or not pd.seen and gnow >= pd.till then", "if not pd.seen and gnow >= pd.till then", BLOCK),
    (M, "if pd.seen and c ~= pd.slot or not pd.seen and gnow >= pd.till then", "if pd.seen and c ~= pd.slot then", NEVER),
]
