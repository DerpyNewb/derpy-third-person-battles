# Round 78 (2026-11-28): the block raises the shield (docs/sessions/PATCH_NOTES_20261128_THIRD_PERSON.md). Held, a unit
# of one on foot whose table has a shield-up clip of its own holds STAND_SHIELD_UP, walks and runs on WALK_ and
# RUN_SHIELD_UP_1, each sent again at its length or as the engine's clip takes its place; let go, out of stamina or
# knocked, it is lowered. No sprint under it. Each a plausible slip, not a typo.
CMB = "script/derpy_tp/combat.lua"
HELD = "a_held_block_raises_his_shield_on_stamina"
LET_GO = "a_block_is_lowered_when_let_go"
MOVES = "a_blocking_unit_of_one_walks_and_runs_with_his_shield_up"
BREAK = "a_knock_or_the_engines_clip_breaks_the_shield"
ONLY = "only_a_single_entity_with_a_shield_up_clip_blocks"
MUTANTS = [
    # the lock ended as any other clip's when the engine's clip takes the shield's place: his walk for a frame between
    (CMB, "or L.m and not L.block and (L.seen", "or L.m and (L.seen", BREAK),
    # never lowered when the bar is empty, or by a knock
    (CMB, "if not want or F.stamina <= 0 or knocked(b.m) then return lowered(now) end",
     "if not want or knocked(b.m) then return lowered(now) end", HELD),
    (CMB, "if not want or F.stamina <= 0 or knocked(b.m) then return lowered(now) end",
     "if not want or F.stamina <= 0 then return lowered(now) end", BREAK),
    # lowered with the clip unseen: the lock's "never played" path leaves it pending, and him armed
    (CMB, "F.lock.till, F.lock.seen, F.block = now, true, nil", "F.lock.till, F.block = now, nil", LET_GO),
    # a lock that does not run: he stands; and the sprint let in under it
    (CMB, "slot = slot, guard = true, block = true, runs = true}", "slot = slot, guard = true, block = true}", MOVES),
    (CMB, "or F.lock.runs and not F.lock.block) and F.stamina > 0", "or F.lock.runs) and F.stamina > 0", MOVES),
    # moving ignored, the run taken in walk mode, the walk taken for the run
    (CMB, "\t\tif F.moving then\n\t\t\tif F.running", "\t\tif false then\n\t\t\tif F.running", MOVES),
    (CMB, "if F.running and lens[3] > 0 and P.has_slot(man, RUN_SHIELD_UP)", "if lens[3] > 0 and P.has_slot(man, RUN_SHIELD_UP)", MOVES),
    (CMB, "then return RUN_SHIELD_UP, lens[3] end", "then return WALK_SHIELD_UP, lens[2] end", MOVES),
    # sent again only as it ends, which a latched clip never reports; or never over the engine's clip
    (CMB, "if slot ~= b.slot or now >= b.again or b.seen and s ~= b.slot then",
     "if slot ~= b.slot or b.seen and s ~= b.slot then", MOVES),
    (CMB, "if slot ~= b.slot or now >= b.again or b.seen and s ~= b.slot then",
     "if slot ~= b.slot or now >= b.again then", BREAK),
    # a body without the slot taken at its table's word
    (CMB, "if F.unit:is_currently_flying() or P.mount(man) or not P.has_slot(man, SHIELD_UP) then return end",
     "if F.unit:is_currently_flying() or P.mount(man) then return end", ONLY),
]
