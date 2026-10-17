C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
A = "script/derpy_tp/abilities.lua"
P = "script/derpy_tp/platform.lua"
G = "script/derpy_tp/rig.lua"
U = "script/derpy_tp/hud.lua"
XH, BURST, XBOW = ("a_shot_goes_where_the_crosshair_meets_the_ground", "a_burst_follows_the_crosshair",
                   "solo_click_fires_one_shot")
SHARED, NEXT, DEEP, NEVER = ("a_regiment_whose_man_cannot_shoot_alone_keeps_its_shot",
                             "a_next_man_who_cannot_shoot_alone_hands_the_aim_to_the_regiment",
                             "men_check_takes_a_deep_block", "men_check_accepts_men_never_ordered")
ROOF, OWN, GROUND = ("a_building_behind_pulls_the_camera_in_not_up", "played_as_one_man_the_panel_shows_his_own_health",
                     "a_ground_ability_lands_no_farther_than_its_range")
MUTANTS = [
    # the shot goes to where the crosshair meets the ground, or along it to his reach
    (C, "return y <= bm:get_terrain_height(x, z) or", "return y <= 0 or", XH),
    (C, "or (x - ux) ^ 2 + (z - uz) ^ 2 > reach * reach end", "end", XBOW),
    (C, "for _ = 1, 5 do local mid", "for _ = 1, 0 do local mid", XH),
    (C, "v(ax + jx, ay, az + jz)", "v(ax + jx, ay + 1, az + jz)", XH),
    # each spawn takes the crosshair as it leaves
    (C, "local ax, ay, az = C.aim_point(shot.unit:missile_range())", "local ax, ay, az = unpack(shot.aim)", BURST),
    # a cast on the ground lands on it
    (A, "v(x, bm:get_terrain_height(x, z), z)", "v(x, 0, z)", GROUND),
    # F2 plays one man even when he cannot shoot alone; ranged mode hands the shot to the regiment
    # the men check: their centre or one of them near the unit
    (P, "if not (near <= 25 or centre <= 25) then", "if not (centre <= 25) then", DEEP),
    (P, "if not (near <= 25 or centre <= 25) then", "if not (near <= 25) then", NEVER),
    # the camera comes in along its boom while the engine lifts it over a roof, and back out once clear
    (G, "if got_y - math.max(R.ey, R.ey1 or R.ey, R.ey2 or R.ey) > LIFT_TOL then", "if false then", ROOF),
    (G, "R.boom + BOOM_OUT * dt)", "R.boom)", ROOF),
    (G, "local t = i / 10 * R.boom", "local t = i / 10", ROOF),
    (G, "R.cap = {R.boom, R.sx, R.sz, R.yaw}", "R.cap = nil", ROOF),
    (G, "R.boom = math.min(R.cap and R.cap[1] or 1, R.boom", "R.boom = math.min(1, R.boom", ROOF),
    (G, "if c and ((R.sx - c[2])", "if false and ((R.sx - c[2])", ROOF),
    (G, "or math.abs(R.yaw - c[4]) > TURNED) then", "or false) then", ROOF),
    (M, "cam:position():get_y(), height)", "nil, height)", ROOF),
    # the man's own hit points when one man is played
    (U, "width(\"health_fill\", cur and cur / max or u:unary_hitpoints())", "width(\"health_fill\", u:unary_hitpoints())", OWN),
    (U, "\t\t\t\tlocal cur, max = own_hp()\n", "\t\t\t\tlocal cur, max\n", OWN),
    (U, "\t\tif not F.model then return nil end\n", "", OWN),
    (U, "if max > 0 and cur >= 0 and cur <= max then return cur, max end", "return cur, max", OWN),
]
