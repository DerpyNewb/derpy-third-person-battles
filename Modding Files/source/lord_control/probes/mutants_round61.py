# Round 61 (2026-10-23): the Workshop reports the author handed over (docs/sessions/THIRD_PERSON_PLAYER_REPORTS_20261023.md).
# Report 1: Grimgor's You're Next!, for lords and heroes only, aimed at a regiment never landed and cooled down all the
# same. The aim, its label and its arrow take only a unit the ability may land on (data.lua targets).
AB = "script/derpy_tp/abilities.lua"
LORDS = "an_ability_for_lords_and_heroes_aims_past_the_regiment"
NEVER = "an_ability_never_for_lords_and_heroes_is_never_cast_on_him"
LABEL = "the_target_label_names_only_a_unit_the_ability_may_land_on"
# Report 3: Shift in a crowd locked the lord onto an enemy and no longer ran him away. Read live: the sprint's charge
# took an enemy behind him. The charge takes only an enemy ahead, the locked one too, and lets go of one he turns from.
CB = "script/derpy_tp/combat.lua"
CHG = "the_sprints_charge_takes_only_an_enemy_ahead_and_lets_go_behind"
MUTANTS = [
    # any enemy close by again, the locked one wherever he is, the charge never letting go, ahead read backwards
    (CB, "if d < AIM_CLOSE and not only_ahead or", "if d < AIM_CLOSE or", CHG),
    (CB, "local target = pick_target(CHARGE_REACH, false, true)", "local target = pick_target(CHARGE_REACH)", CHG),
    (CB, "if held and not (only_ahead and not ahead(held)) then", "if held then", CHG),
    (CB, "or co.target:is_routing() or not ahead(co.target, 0)) then", "or co.target:is_routing()) then", CHG),
    (CB, "/ math.max(math.sqrt(dx * dx + dz * dz), 0.01) > (cos or AIM_COS)", "/ math.max(math.sqrt(dx * dx + dz * dz), 0.01) < (cos or AIM_COS)", CHG),
    # the let-go at the pick's own 45 degrees: in a crowd the order went from one enemy to the next and back
    (CB, "or not ahead(co.target, 0)) then", "or not ahead(co.target)) then", CHG),
    # the aim takes any unit, the key never reaches it, one side of the flag read as the other
    (AB, "and (not enemy or u:is_valid_target()) and may_target(key, u) then", "and (not enemy or u:is_valid_target()) then", LORDS),
    (AB, "local target, far = nearest_to_ray(true, reach(n), base)", "local target, far = nearest_to_ray(true, reach(n))", LORDS),
    (AB, "return not t or (u:unit_class() == \"com\") == (t == \"com\")", "return not t or u:unit_class() == \"com\"", NEVER),
    # a friend ability with no ally on the crosshair cast on him though it never lands on a lord
    (AB, "or may_target(base, F.unit) and F.unit", "or F.unit", NEVER),
    # the label and arrow left on the old pick; the label's two new words gone
    (AB, "nearest_to_ray(a.kind == \"enemy\", a.range, a.key)", "nearest_to_ray(a.kind == \"enemy\", a.range)", LABEL),
    (AB, "or (lords and \"No lord or hero in sight\")", "", LABEL),
    (AB, "(may_target(a.key, F.unit) and \"On himself\" or \"No ally in sight\")", "\"On himself\"", LABEL),
]
