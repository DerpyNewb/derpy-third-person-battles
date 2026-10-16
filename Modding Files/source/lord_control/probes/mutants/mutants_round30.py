P = "script/derpy_tp/platform.lua"
M = "script/derpy_tp/main.lua"
STOPPED, LEFT = "the_engines_own_orders_on_him_are_stopped", "his_own_commands_his_idle_and_a_hit_are_left_to_run"
UNKNOWN = "unknown_build_has_no_walk_command_writes"
KEPT, WHOLE = "the_man_played_alone_is_kept_from_the_engines_orders", "a_regiment_played_whole_is_not_guarded"
# Round 30 (2026-10-16): the engine's own orders on the man played alone (the regiment's walk, two moves, the melee
# attack) stopped with its own stop every frame the battle runs; his idle, the hits and a dead man's left to run
MUTANTS = [
    (P, " move_a = 0x39199f8,", "", STOPPED),
    (P, ", melee = 0x3ad24b8}", "}", STOPPED),
    (P, '{"walk_a", "move_a", "move_b", "melee"}', '{"move_a", "move_b", "melee"}', STOPPED),
    (P, 'if mr.eq(c, e) then mr.call(walk_stop, "pointer(pointer)", m) return true end', "if mr.eq(c, e) then return true end", STOPPED),
    (P, "if mr.eq(c, e) then mr.call(walk_stop", "if true then mr.call(walk_stop", LEFT),
    (P, "P.model_hp(m) <= 0 then return false end", "P.model_hp(m) < 0 then return false end", LEFT),
    (P, "\tif P.features.steer then\n\t\tfor _, k in ipairs", "\tif true then\n\t\tfor _, k in ipairs", UNKNOWN),
    (M, "if F.model then P.guard(F.model) end", "", KEPT),
    (M, "if F.model then P.guard(F.model) end", "if F.model and not F.lock then P.guard(F.model) end", KEPT),
    (M, "if F.model then P.guard(F.model) end", "P.guard(F.model)", WHOLE),
    (M, "\t\tif not paused then\n\t\t\t-- the engine's own orders on him go",
     "\t\tif F.model then P.guard(F.model) end\n\t\tif not paused then\n\t\t\t-- the engine's own orders on him go", KEPT),
]
