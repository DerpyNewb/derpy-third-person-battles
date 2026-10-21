MN, MV = "script/derpy_tp/main.lua", "script/derpy_tp/move.lua"
ONE, SINGLE, SHOOT, SAME = ("one_man_on_plays_one_chariot", "a_unit_of_one_chariot_is_steered_alone",
    "a_shooting_war_machine_plays_as_today", "the_next_man_rides_the_same_chariot")
MUTANTS = [
    (MN, "and (not unit:is_war_machine() or chariot(unit)) and not F.crew", "and not unit:is_war_machine() and not F.crew", ONE),
    (MN, "\t\t\tand (not unit:is_war_machine() or chariot(unit))\n", "\t\t\tand not unit:is_war_machine()\n", SINGLE),
    (MN, "return E.D.chariots ~= nil and E.D.chariots[unit:type()] == true end", "return true end", SHOOT),
    (MN, "E.move.front_man(unit, F.body)", "E.move.front_man(unit)", SAME),
    (MV, "if P.model_hp(m) > 0 and (not mate or o and P.same(o, body)) then", "if P.model_hp(m) > 0 then", SAME),
]
