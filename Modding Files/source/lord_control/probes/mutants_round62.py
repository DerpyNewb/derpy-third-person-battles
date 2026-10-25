# Round 62 (2026-10-24): the live real-input pass (docs/sessions/THIRD_PERSON_BUGS_20261024.md).
# The crosshair: CA's first_person_ui hides itself half a second after it is made, and a note of ours said it showed.
# The pack reads the component's own visibility every frame now.
CB = "script/derpy_tp/combat.lua"
XHAIR = "a_crosshair_ca_hides_after_it_is_made_comes_back"
# The author, 2026-10-24: "add mana cost of spells to UI". A spell slot shows its winds, the overcast's while armed so.
HUD = "script/derpy_tp/hud.lua"
MANA = "a_spell_slot_shows_its_winds_cost"
FREE = "an_ability_that_costs_no_winds_shows_no_cost"
MUTANTS = [
    # the visibility set only when the component is made, as the note did
    (CB, "if ui:Visible() ~= show then ui:SetVisible(show) end", "", XHAIR),
    # the cost of the plain cast always, the overcast's never shown
    (HUD, "local winds = mana > 0 and (over or mana)", "local winds = mana > 0 and mana", MANA),
    # the overcast's on every slot while any spell is armed overcast
    (HUD, "local over = a and a.n == n and a.over and", "local over = a and a.over and", MANA),
    # a badge on every ability, a 0 on the ones that cost nothing
    (HUD, "local winds = mana > 0 and (over or mana)", "local winds = (over or mana)", FREE),
    # the plate on every slot; the figure written, its plate or the figure left hidden
    (HUD, "vis(\"slot_\" .. n .. \"_manaplate\", winds ~= false)", "vis(\"slot_\" .. n .. \"_manaplate\", true)", FREE),
    (HUD, "vis(\"slot_\" .. n .. \"_manaplate\", winds ~= false)", "", MANA),
    (HUD, "vis(\"slot_\" .. n .. \"_mana\", winds ~= false)", "", MANA),
]
