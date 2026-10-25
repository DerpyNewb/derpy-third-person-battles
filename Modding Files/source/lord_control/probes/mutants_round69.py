# Round 69 (2026-10-25): a player's report, multiplayer "forced to move forwards only", turning "takes an eternity". A
# heading there is a queued command run two ticks later or more, so M.turn steps from the heading last asked for the
# same model, not the engine's, which lags it (move.lua).
TESTS = "third_person_lockstep_tests.lua"
MOVE = "script/derpy_tp/move.lua"
TURN = "ls_he_turns_at_his_rate_through_the_queue_delay"
MUTANTS = [
    # stepped from the engine's heading again
    (MOVE, "if P.features.net and asked and P.same(asked.m, m)", "if false and asked and P.same(asked.m, m)", TURN),
    # nothing remembered of what was asked
    (MOVE, "asked = {m = m, yaw = face, t = now}", "asked = nil", TURN),
    # what was asked forgotten by the next frame
    (MOVE, "local ASKED_KEEP = 1", "local ASKED_KEEP = 0", TURN),
]
