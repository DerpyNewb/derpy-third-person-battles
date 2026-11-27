# Round 77 (2026-11-27): sync kills (docs/sessions/HANDOFF_20261127_THIRD_PERSON_SYNC_KILLS.md, docs/BATTLE_ENGINE_RE.md
# section 12b). A unit of one tries CA's kill-move check inside CA's melee, only where the game's pair table has a pair
# for him and the enemy, a ridden man by his mount and himself together; a pair never started in 3 tries is given up;
# a pair holds him to its end, 30 s at most. Each a plausible slip, not a typo.
COMBAT = "script/derpy_tp/combat.lua"
TRIES = "a_click_tries_a_sync_kill_inside_cas_melee_and_waits_out_the_pair"
FALLBACK = "a_sync_kill_not_rolled_or_not_paired_swings_his_own"
NEVER = "no_sync_kill_is_tried_where_it_cannot_be"
RIDDEN = "a_ridden_sync_kill_needs_his_mount_and_him_together"
GIVEN_UP = "a_pair_never_started_in_three_tries_is_given_up"
LONG = "a_long_sync_kill_keeps_him_to_its_end"
MUTANTS = [
    # the attack order never given; not asked again each frame; the guard kept up through the wait
    (COMBAT, "send(function() F.uc:attack_unit(foe_unit, true, false) end)", "send(function() end)", TRIES),
    (COMBAT, "if now < Y.till then P.sync(Y.man, Y.foe) return true end", "if now < Y.till then return true end", TRIES),
    (COMBAT, "\t\t\tF.native_attack = \"sync\"\n", "\n", TRIES),
    # a lock dropped mid-wait leaves CA's order running
    (COMBAT, "if not L or not L.sync then unsync() end", "", TRIES),
    # one man of a regiment tried; the odds not rolled; the order not ended before the fallback swing
    (COMBAT, "if not (F.single ~= nil and strikes()", "if not (strikes()", NEVER),
    (COMBAT, "math.random() < SYNC_CHANCE and ", "", FALLBACK),
    (COMBAT, "\t\t\tunsync()\n\t\t\tlocal n = Y.pair", "\t\t\tlocal n = Y.pair", FALLBACK),
    # tried with no pair in the table
    (COMBAT, "if not ks then return false end", "if not ks then F.sync_pair = {kill_sets.tried, \"x\"} return true end", NEVER),
    # a ridden man looked up as if on foot; by his mount's feral pairs too; by his mount alone
    (COMBAT, "\t\tif mount then\n\t\t\tlocal rides", "\t\tif false then\n\t\t\tlocal rides", RIDDEN),
    (COMBAT, "\t\t\tk = rides and rides[D.mc_riders[P.anim_table(m)] or 0]",
     "\t\t\tk = rides and rides[D.mc_riders[P.anim_table(m)] or 0] or D.mc_attacks[P.anim_table(mount)]", RIDDEN),
    (COMBAT, "rides[D.mc_riders[P.anim_table(m)] or 0]", "select(2, next(rides))", RIDDEN),
    # never given up; a miss not counted; a start forgotten; given up before any try
    (COMBAT, "SYNC_TRIES = 0.5, 1.5, 30, 3", "SYNC_TRIES = 0.5, 1.5, 30, 99", GIVEN_UP),
    (COMBAT, "if n ~= true then Y.pair[1][Y.pair[2]] = (n or 0) + 1 end", "", GIVEN_UP),
    (COMBAT, "\t\t\t\tY.pair[1][Y.pair[2]] = true\n", "\n", GIVEN_UP),
    (COMBAT, "(n == true or n < SYNC_TRIES)", "(n == true or n < 1)", GIVEN_UP),
    # the 10 s cap the first builds had: Kroll's 15.6 s pair let go in the middle
    (COMBAT, "SYNC_TRIES = 0.5, 1.5, 30, 3", "SYNC_TRIES = 0.5, 1.5, 10, 3", LONG),
]
