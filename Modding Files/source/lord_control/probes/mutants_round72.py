# Round 72 (2026-11-08): the two bugs the live test confirmed (docs/sessions/LIVE_TEST_20261108_THIRD_PERSON.md). Command
# mode's card numbers: a numpad key by its digit, a lozenge never wider than its card. F2 with nobody to play says so.
MAIN = "script/derpy_tp/main.lua"
HUD = "script/derpy_tp/hud.lua"
CMD = "script/derpy_tp/command.lua"
CARDS = "a_long_card_key_widens_its_lozenge"
NOBODY = "f2_with_nobody_to_play_says_so"
MUTANTS = [
    # the card's label: the key's full name again; any digit key cut to its digit (the main row's too)
    (CMD, "list[n] = {k, name:match(\"^Numpad (%d)$\") or name}", "list[n] = {k, name}", CARDS),
    (CMD, "list[n] = {k, name:match(\"^Numpad (%d)$\") or name}", "list[n] = {k, name:match(\"(%d)$\") or name}", CARDS),
    # the lozenge: as wide as its text again, past its card
    (HUD, "local w = math.min(cw, math.floor(", "local w = math.max(cw * 0, math.floor(", CARDS),
    # F2 with nobody: silent again; the key not named; said where somebody is played
    (MAIN, "then E.say(\"derpy_tp_no_unit\", E.S.names.toggle) return end", "then return end", NOBODY),
    (MAIN, "then E.say(\"derpy_tp_no_unit\", E.S.names.toggle) return end", "then E.say(\"derpy_tp_no_unit\") return end", NOBODY),
    (MAIN, "if not unit or unit:number_of_men_alive() == 0 then E.say(", "if not unit then E.say(", NOBODY),
]
