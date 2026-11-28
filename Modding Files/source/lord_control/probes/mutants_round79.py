# Round 79 (2026-11-28): a walking block stops where he stops (docs/sessions/PATCH_NOTES_20261128_THIRD_PERSON.md).
# Measured live: the stand clip pushed over his walk kept him walking under it, 3.7 m; a walk clip of ours pushed in the
# tick he stopped did the same, 2.9 m. The stand waits for P.hold to stop the walk, and that clip gets one step of our
# own walk, which P.hold can stop. Each a plausible slip, not a typo.
CMB = "script/derpy_tp/combat.lua"
MOV = "script/derpy_tp/move.lua"
MAIN = "script/derpy_tp/main.lua"
WAIT = "a_walking_block_stands_once_his_walk_has_stopped"
STEP = "a_walk_clip_sent_as_he_stops_gets_a_step_of_our_walk"
DRIFT = "a_blocking_man_drifting_under_a_clip_gets_a_step_of_our_walk"
MOVES = "a_blocking_unit_of_one_walks_and_runs_with_his_shield_up"
ARM = ("\t\t\t\t\tif not b.stop_by then\n\t\t\t\t\t\tb.stop_by = now + STOP_WAIT\n"
       "\t\t\t\t\t\tif now - b.pushed < 1.5 * TICK then F.unslide = 1 end\n\t\t\t\t\tend\n")
MUTANTS = [
    # the stand over his walk at once; and the wait taken from the run too, which stopped him dead without it
    (CMB, "if now < b.stop_by and (F.unslide or P.command(b.m) == \"walk\") then L.till = now + LOCK_MAX return end",
     "", WAIT),
    (CMB, "if slot == SHIELD_UP and b.slot == WALK_SHIELD_UP then", "if slot == SHIELD_UP and b.slot ~= SHIELD_UP then",
     MOVES),
    # the stand sent while the step is under way: it lands on our walk and he walks on under it
    (CMB, "(F.unslide or P.command(b.m) == \"walk\")", "(P.command(b.m) == \"walk\")", STEP),
    # never armed, armed at every stop, armed on every frame of the wait, timed from the block's first clip only
    (CMB, "if now - b.pushed < 1.5 * TICK then F.unslide = 1 end", "if false then F.unslide = 1 end", STEP),
    (CMB, "if now - b.pushed < 1.5 * TICK then F.unslide = 1 end", "if true then F.unslide = 1 end", WAIT),
    (CMB, ARM, "\t\t\t\t\tif not b.stop_by then\n\t\t\t\t\t\tb.stop_by = now + STOP_WAIT\n\t\t\t\t\tend\n"
     "\t\t\t\t\tif now - b.pushed < 1.5 * TICK then F.unslide = F.unslide or 1 end\n", STEP),
    (CMB, "b.seen, b.pushed = slot, now + (len > 0 and len - TICK / 2 or LOCK_MAX), false, now",
     "b.seen, b.pushed = slot, now + (len > 0 and len - TICK / 2 or LOCK_MAX), false, b.pushed", STEP),
    # a wait left over from a stop he walked on from
    (CMB, "if slot ~= SHIELD_UP then b.stop_by = nil end", "", WAIT),
    # the step sent once, which the next frame's hold overwrites before the engine takes it; and sent at the run
    (MOV, "if cmd == \"other\" and (F.unslide == 2 or", "if cmd == \"other\" and (", STEP),
    (MOV, "P.steer(m, x + math.sin(f) * SLID, z + math.cos(f) * SLID, false, f)",
     "P.steer(m, x + math.sin(f) * SLID, z + math.cos(f) * SLID, true, f)", STEP),
    # his hold left where he stopped: he is past it after the step, and steps again for ever
    (MOV, "F.unslide, F.man_hold = 2, nil", "F.unslide = 2", DRIFT),
    # every settling taken for a slide; and a step for a man not blocking
    (MOV, "(x - hx) ^ 2 + (z - hz) ^ 2 > SLID * SLID", "(x - hx) ^ 2 + (z - hz) ^ 2 > 0", DRIFT),
    (MOV, "local cmd = F.block and P.command(m)", "local cmd = P.command(m)", DRIFT),
    # armed, he walks on: the next clip's command takes a step he never needed
    (MOV, "F.man_hold, F.unslide = nil, nil", "F.man_hold = nil", STEP),
    # armed when third person stops: the next block steps at once
    (MAIN, "F.block, F.block_want, F.unslide = nil, nil, nil", "F.block, F.block_want = nil, nil", STEP),
]
