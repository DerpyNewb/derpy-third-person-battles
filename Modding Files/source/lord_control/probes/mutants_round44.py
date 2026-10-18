# Round 44 (2026-10-17): the mailbox. The guard's script-thread stop crashed the game (exe+7AB1DA, a command's destructor
# reading FFFFFFFFFFFFFFFF); the stop, the walk builder and the in-place steer now run in a code cave at the top of his
# update, on the battle thread, from requests the script posts. The cave's own bytes are broken by
# tools/third_person_cave.py --selftest; these break the Lua that installs it, finds it again and posts to it.
P = "script/derpy_tp/platform.lua"
M = "script/derpy_tp/main.lua"
IN = "the_mailbox_is_put_in_once_and_found_by_the_next_battle"
NONE = "no_mailbox_nothing_is_posted_and_nothing_called"
SCRIPT = "nothing_builds_or_destroys_his_command_from_the_script"
WHOLE = "no_mailbox_plays_the_regiment_whole_and_asks_again"
MUTANTS = [
    # putting it in
    (P, "if mr.read_original(update, 0, #CAVE_SITE) ~= string.char(unpack(CAVE_SITE)) then",
        "if false then", NONE),
    (P, 'if not cave then return fail("the cave: " .. tostring(why)) end', "", NONE),
    (P, 'mr.patcher("derpy_tp"):cave("mailbox", update,', 'mr.patcher("derpy_tp"):cave("mailbox", mr.add(update, 1),', IN),
    (P, 'mr.patcher("derpy_tp")', 'mr.patcher("derpy")', IN),
    (P, "tonumber(hex:sub(15 - 2 * i, 16 - 2 * i), 16)", "tonumber(hex:sub(1 + 2 * i, 2 + 2 * i), 16)", IN),
    (P, "bytes[CAVE_BLOCK + i + 1] =", "bytes[CAVE_BLOCK + i] =", IN),
    # the next battle finds its block in the cave
    (P, 'info and info.kind == "cave" and mr.read_pointer(info.cave, CAVE_BLOCK) or', "", IN),
    (P, "mr.read_pointer(info.cave, CAVE_BLOCK)", "mr.read_pointer(info.cave, 0)", IN),
    (P, "\t\tzero(MB.man, 8)\n", "", IN),
    (P, "\t\tzero(MB.guard, MB.buf - MB.guard)\n", "", IN),
    # the walk builder's constants
    (P, "mr.write(block, MB.buf + 0x34, mr.uint32(3))", "", IN),
    (P, "for _, off in ipairs({0x44, 0x45, 0x4a}) do mr.write(block, MB.buf + off, mr.uint8(1)) end", "", IN),
    # posting
    (P, "\t\tmr.write(block, MB.man, m)\n", "", "the_guard_posts_to_his_update"),
    (P, "\t\tif not block then return false end\n\t\tpost(", "\t\tpost(", NONE),
    (P, "P.mailbox, P.features.mailbox = block, true", "P.mailbox, P.features.mailbox = block, false", IN),
    # main: no one man without it, and asked again at the next start
    (M, "S.one_man and men_ok and P.features.steer and P.features.mailbox and not F.arty", "S.one_man and men_ok and P.features.steer and not F.arty", WHOLE),
    (M, "if P.features.steer and not P.features.mailbox then", "if false then", WHOLE),
    (M, 'if not ok then E.once("mailbox", "regiments are played whole: " .. tostring(why)) end', "", WHOLE),
]
