# Round 43 (2026-10-17): the author, "check artillery still bugging" - a whole unit turning to an aim outside its arc
# swung back to the enemy it could already shoot, because the click had put fire at will on; it goes on with the fire
# order now (probes/zz_tp_tank_fire.lua, the Tilean tank).
C = "script/derpy_tp/combat.lua"
TURN = "ground_fire_turns_with_fire_at_will_off"
ON = "fire_at_will_is_on_only_while_he_shoots"
MUTANTS = [
    (C, "F.firing, F.fire_ammo, F.fire_order_t, F.fire_clip = true, F.unit:ammo_left(), now, nil\n",
        "F.firing, F.fire_ammo, F.fire_order_t, F.fire_clip = true, F.unit:ammo_left(), now, nil F.uc:fire_at_will(true)\n", TURN),
    (C, "\t\tF.uc:fire_at_will(true)\n\t\tF.uc:attack_location(", "\t\tF.uc:attack_location(", ON),
]
