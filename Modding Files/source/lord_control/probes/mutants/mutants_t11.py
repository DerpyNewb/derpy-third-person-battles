C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
MUTANTS = [
    (C, "if open then fp.seen = true end", "", "artillery_mode_opens_manual_fire"),
    (C, "if b and b:Visible() then b:SimulateLClick() fp.clicked, fp.t = true, now return end", "if false then end", "artillery_mode_opens_manual_fire"),
    (C, "if F.arty then C.manual() return end", "if F.arty then return end", "artillery_mode_opens_manual_fire"),
    (C, "if open and asked then local b = manual_button() if b then b:SimulateLClick() end end", "", "f2_leaves_manual_fire"),
    (M, "if E.fp then E.combat.manual_exit()", "if false then", "f2_leaves_manual_fire"),
    (C, "local timed_out = not fp.seen and now - fp.t > 3", "local timed_out = false", "manual_fire_without_a_button_gives_control_back"),
    (C, "E.once(\"fp_button_\" .. fp.unit:type(), \"no Manual fire button for \" .. fp.unit:type())", "", "manual_fire_without_a_button_gives_control_back"),
]
