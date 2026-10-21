AGAIN = "a_charge_cut_short_by_the_mode_key_leaves_none_behind"
CB, MN = "script/derpy_tp/combat.lua", "script/derpy_tp/main.lua"
ONE, SINGLE, RUN, BEHIND, MAN, STEER, HID = ("a_sprint_into_an_enemy_orders_one_charge",
    "a_unit_of_one_sprinting_into_an_enemy_charges_too", "a_run_into_an_enemy_orders_no_charge",
    "a_sprint_at_an_enemy_out_of_reach_orders_no_charge", "one_man_sprinting_gives_his_regiment_no_charge",
    "the_charge_order_holds_the_steering_till_the_sprint_stops", "no_charge_held_on_a_target_that_hid")
MUTANTS = [
    (CB, "\t\tC.charge(now)\n", "\n", ONE),
    (CB, "F.uc:attack_unit(target, true, true)", "F.uc:attack_unit(target, true, false)", ONE),
    (CB, "if co or F.model or not F.sprinting then return end", "if co or F.model then return end", RUN),
    (CB, "if co or F.model or not F.sprinting then return end", "if co or not F.sprinting then return end", MAN),
    (CB, "if co or F.model or not F.sprinting then return end", "if F.model or not F.sprinting then return end", ONE),
    (CB, "local target = pick_target(CHARGE_REACH)", "local target = pick_target(1e9)", BEHIND),
    (CB, "if co and (not F.sprinting or not co.target:is_valid_target() or co.target:is_routing())",
         "if co and (not co.target:is_valid_target() or co.target:is_routing())", STEER),
    (CB, "if co and (not F.sprinting or not co.target:is_valid_target() or co.target:is_routing())",
         "if co and (not F.sprinting or co.target:is_routing())", HID),
    (MN, "elseif not (F.firing or F.charge_order) then", "elseif not F.firing then", STEER),
    (MN, "F.native_attack, F.charge_order = nil, nil", "F.native_attack = nil", AGAIN),
    (CB, "local on = want and first and (F.model or F.single) and not F.arty",
         "local on = want and first and not F.arty", "a_regiment_played_whole_sprints_with_no_charge_clip"),
    (CB, "if clicked and (F.charging or F.sprinting and not (F.model or F.single)) and F.can_charge",
         "if clicked and F.charging and F.can_charge", "a_regiment_throws_the_charge_attack_on_the_run"),
]
