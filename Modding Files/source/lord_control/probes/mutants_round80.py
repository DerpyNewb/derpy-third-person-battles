# Round 80 (2026-11-28): the slot decides who blocks (the author's choice). data.lua shields lists every table CA and the
# mods installed here ship with a STAND_SHIELD_UP row: its lengths where the row shows a raise, false where it holds a
# plain stand. A table it never read (a mod not installed here) blocks on the slot alone, timed by shield_default.
CMB = "script/derpy_tp/combat.lua"
ONLY = "only_a_single_entity_with_a_shield_up_clip_blocks"
UNREAD = "a_table_data_lua_never_read_blocks_on_its_slot"
MUTANTS = [
    # a plain stand taken for a raise
    (CMB, "if lens == false then return end\n", "", ONLY),
    # back to the allow list: every lord of a mod the author does not have loses his block
    (CMB, "lens = lens or E.D.shield_default or {0, 0, 0}", "if not lens then return end", UNREAD),
    # no default timing: an unread table walks and runs under his standing clip
    (CMB, "lens = lens or E.D.shield_default or {0, 0, 0}", "lens = lens or {0, 0, 0}", UNREAD),
]
