C = "script/derpy_tp/combat.lua"
STOPS, OVER = "the_aim_stops_at_the_enemy_under_the_crosshair", "a_view_over_his_head_goes_on_to_the_ground"
TALL, BESIDE = "a_tall_enemy_stops_a_view_a_man_would_not", "an_enemy_beside_the_view_does_not_stop_it"
BEHIND, FRIEND = "an_enemy_behind_the_camera_does_not_stop_the_aim", "a_friend_in_the_way_does_not_stop_the_aim"
# Round 30c (2026-10-16): the aim stops at the first enemy man the view passes through, not the ground behind him
MUTANTS = [
    (C, "return at(first_enemy(R.ex, R.ey, R.ez, dx, dy, dz, t) or t)", "return at(t)", STOPS),
    (C, "y >= my and y <= my + h then best = s end", "y >= my then best = s end", OVER),
    (C, "local r, h = body and body[1] or 0.5, body and body[2] or 1.8", "local r, h = 0.5, 1.8", TALL),
    (C, "cx * cx + cz * cz <= r * r and y >= my", "y >= my", BESIDE),
    (C, "if s > 0 and s < best and", "if s < best and", BEHIND),
    (C, "local best = t_max\n\t\tlocal armies = bm:get_non_player_alliance():armies()",
     "local best = t_max\n\t\tlocal armies = bm:get_player_alliance():armies()", FRIEND),
]
