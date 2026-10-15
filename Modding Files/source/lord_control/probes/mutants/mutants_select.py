M = "script/derpy_tp/main.lua"
A, G = "clicking_another_unit_keeps_the_controlled_one_selected", "clicking_empty_ground_keeps_the_controlled_one_selected"
MUTANTS = [
    (M, "local lost = SEL.ids[uid] and not SEL.set[uid]", "local lost = false", G),
    (M, "for id in pairs(SEL.set) do if id ~= uid then lost = true end end", "", "shift_clicking_another_unit_drops_it_again"),
    (M, "if lost then bm:clear_selection() unit:select_in_ui() end", "", A),
    (M, "if lost then bm:clear_selection() unit:select_in_ui() end", "if lost then bm:clear_selection() end", G),
    (M, "local lost = SEL.ids[uid] and not SEL.set[uid]", "local lost = true", G),
]
