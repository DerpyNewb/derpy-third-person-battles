# Round 63 (2026-10-24, the author live): the plate's health and stamina bars gone after command mode, and the attack
# button naming the left button alone for a unit that swings on both.
HUD = "script/derpy_tp/hud.lua"
PLATE = "leaving_the_mode_gives_the_plate_its_bars_back"
BOTH = "the_attack_button_names_both_buttons_for_a_unit_that_cannot_shoot"
MUTANTS = [
    # a part no update asks about given back hidden, as before
    (HUD, "if c then asked[id] = c:Visible() end", "", PLATE),
    # its state read after the mode has hidden it
    (HUD, "local c = asked[id] == nil and part(id)", "local c = false", PLATE),
    # the left button alone, or both for a shooter too
    (HUD, "text(\"act_attack_key\", E.can_shoot() and a or both)", "text(\"act_attack_key\", a)", BOTH),
    (HUD, "text(\"act_attack_key\", E.can_shoot() and a or both)", "text(\"act_attack_key\", both)", BOTH),
    # "mouse" said twice: wider than the key plate
    (HUD, "local both = (a:match(\"^(.-) mouse$\") and m:match(\"^(.-) mouse$\")) and", "local both = false and", BOTH),
]
