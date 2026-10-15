A = "script/derpy_tp/abilities.lua"
U = "script/derpy_tp/hud.lua"
MUTANTS = [
    (U, "local front = z > 0 and z < 1", "local front = z < 1", "no_arrow_behind_the_camera_off_a_unit_or_on_the_ground"),
    (U, "local front = z > 0 and z < 1", "local front = z > 0", "no_arrow_behind_the_camera_off_a_unit_or_on_the_ground"),
    (U, "cm2(p:get_y() + L.arrow_lift)", "cm2(p:get_y())", "the_arrow_points_at_the_unit_an_armed_ability_would_hit"),
    (U, " - L.size.target_arrow[2] * s)", ")", "the_arrow_points_at_the_unit_an_armed_ability_would_hit"),
    (U, " - L.size.target_arrow[1] * s / 2)", ")", "the_arrow_points_at_the_unit_an_armed_ability_would_hit"),
    (U, "H.target(nil) H.mark(nil)", "H.target(nil)", "the_arrow_is_hidden_until_an_ability_is_armed"),
    (A, "\t\tE.hud.mark(a.unit)\n", "", "the_arrow_points_at_the_unit_an_armed_ability_would_hit"),
    (A, "\t\t\tE.hud.target(s)\n\t\tend\n\t\tE.hud.mark(a.unit)\n",
     "\t\t\tE.hud.target(s)\n\t\t\tE.hud.mark(a.unit)\n\t\tend\n", "the_arrow_follows_the_view_every_frame"),
    (A, "\t\tE.hud.target(nil)\n\t\tE.hud.mark(nil)\n", "\t\tE.hud.target(nil)\n",
     "the_arrow_points_at_the_unit_an_armed_ability_would_hit"),
]
