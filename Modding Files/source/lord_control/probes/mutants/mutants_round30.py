P = "script/derpy_tp/platform.lua"
M = "script/derpy_tp/main.lua"
MAILBOX = "the_mailbox_is_put_in_once_and_found_by_the_next_battle"
GUARD = "the_guard_posts_to_his_update"
KEPT, WHOLE = "the_man_played_alone_is_kept_from_the_engines_orders", "a_regiment_played_whole_is_not_guarded"
# Round 30 (2026-10-16): the engine's own orders on the man played alone (the regiment's walk, two moves, the melee
# attack) stopped with its own stop every frame the battle runs; his idle, the hits and a dead man's left to run.
# Re-aimed 2026-10-17: the stop is the mailbox cave's, on the battle thread; which commands it stops and that a dead
# man's run are tools/third_person_cave.py --selftest's, and the script only posts a guard request
MUTANTS = [
    (P, " move_a = 0x39199f8,", "", MAILBOX),
    (P, ", melee = 0x3ad24b8,", ",", MAILBOX),
    (P, '{"walk_a", "move_a", "move_b", "melee", "walk_b", "walk_stop", "walk_start"}',
     '{"move_a", "move_b", "melee", "walk_b", "walk_stop", "walk_start"}', MAILBOX),
    (P, 'post(m, "guard", 1)\n\t\treturn true', "return true", GUARD),
    (P, 'post(m, "guard", 1)\n\t\treturn true', 'post(m, "walk", 1)\n\t\treturn true', GUARD),
    (M, "if F.model then P.guard(F.model)\n", "if false then P.guard(F.model)\n", KEPT),
    (M, "if F.model then P.guard(F.model)\n", "if F.model and not F.lock then P.guard(F.model)\n", KEPT),
    (M, "if F.model then P.guard(F.model)\n", "P.guard(F.model) if F.model then\n", WHOLE),
]
