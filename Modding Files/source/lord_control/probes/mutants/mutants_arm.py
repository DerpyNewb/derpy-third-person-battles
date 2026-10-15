A, MN, HUD = "script/derpy_tp/abilities.lua", "script/derpy_tp/main.lua", "script/derpy_tp/hud.lua"
ARMS, DISARM, LABEL = ("an_aimed_ability_arms_on_its_key_and_goes_off_on_the_left_click",
    "the_key_again_or_the_mode_key_disarms", "the_target_label_names_what_the_crosshair_is_on")
MUTANTS = [
    (A, "if not AIMED[kind] then", "if true then", ARMS),
    (A, "if F.armed and F.armed.n == n then A.cancel() return nil end", "", DISARM),
    (MN, "if F.armed then E.abilities.cancel() else E.combat.mode(gnow) end", "E.combat.mode(gnow)", DISARM),
    (MN, "if F.dragging and clicked then E.abilities.fire() F.swallow = true end", "", ARMS),
    (MN, "(F.ranged or F.armed ~= nil) and F.dragging", "F.ranged and F.dragging", ARMS),
    (MN, "\t\tE.abilities.update(now) -- real time", "\t\t-- real time", LABEL),
    (A, 'or (a.kind ~= "enemy" and "On himself") or', 'or "On himself" or', LABEL),
    (A, "s = a.unit and E.hud.unit_name(a.unit)\n", "s = a.unit and a.unit:type()\n", LABEL),
    (HUD, 'vis("slot_" .. k .. "_armed", k == n)', 'vis("slot_" .. k .. "_armed", false)', ARMS),
    (HUD, "vis(\"target_plate\", s ~= nil) vis(\"target\", s ~= nil)", "vis(\"target_plate\", true) vis(\"target\", true)", LABEL),
]
