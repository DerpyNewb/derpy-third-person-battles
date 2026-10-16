C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
U = "script/derpy_tp/hud.lua"
K = "script/derpy_tp/keys.lua"
CHEER, NOCHEER, TAUNT = ("o_cheers_with_his_celebrate_clip", "a_man_with_no_cheer_clip_has_no_cheer",
                         "a_man_with_only_a_taunt_clip_taunts")
HIDE, BACK, SHORT = ("p_hides_all_the_interface_even_paused", "stopping_with_the_interface_hidden_brings_it_back",
                     "the_games_shortcuts_on_its_keys_are_off_while_on")
MELEE, NOMISSILE, CANNOT = ("a_unit_played_whole_takes_his_melee_mode", "a_unit_with_no_missile_weapon_is_never_put_in_melee_mode",
                            "a_man_who_cannot_shoot_alone_leaves_his_regiments_mode")
BAR, FULL, CORNERS = ("the_action_bar_shows_fly_and_cheer", "a_full_action_bar_clears_the_ability_bar",
                      "the_hud_sits_in_the_bottom_corners_and_centre")
MELEE_LINE = "local melee = unit:missile_range() > 0 and not F.arty and not F.ranged"
LIFT = "if #keys > 0 and o.actions[1] < o.bar[1] + bar_w * s and o.actions[2] + g.actions[2] * s > o.bar[2] then"
MUTANTS = [
    # O and P by default, and the game's own shortcut on each off while on
    (K, 'cheer = "O", hide_ui = "P"', 'cheer = "U", hide_ui = "P"', CHEER),
    (K, 'cheer = "O", hide_ui = "P"', 'cheer = "O", hide_ui = "L"', HIDE),
    (K, 'K.game = {P = "toggle_pause", ', "K.game = {", SHORT),
    (M, "if sc then bm:disable_shortcut(sc, true) F.shortcuts[#F.shortcuts + 1] = sc end",
        "if sc then bm:disable_shortcut(sc, true) end", SHORT),
    (M, "\t\tfor _, sc in ipairs(F.shortcuts or {}) do try(function() bm:disable_shortcut(sc, false) end) end\n", "", SHORT),
    # P hides everything, paused too; the freed mouse brings the cursor and not CA's interface; the stop brings it back
    (M, "\t\t\tif P.pressed(S.keys.hide_ui) then hide_ui(not F.ui_off) end", "", HIDE),
    (M, "if show and not F.ui_off then", "if show then", HIDE),
    (M, "E.hud.show(not off)", "E.hud.show(true)", HIDE),
    (M, "and F.dragging and not F.ui_off)", "and F.dragging)", HIDE),
    (M, "F.ui_off, F.cursor_shown = false, nil", "F.cursor_shown = nil", BACK),
    # O cheers: CELEBRATE, else TAUNT, else the taunt cry; held like an action
    (M, "\t\t\t\tif P.pressed(S.keys.cheer) and F.dragging and not F.armed then E.combat.cheer(gnow) end\n", "", CHEER),
    (C, "\t\tif #clips == 0 then clips = has(SLOTS_TAUNT) end\n", "", TAUNT),
    (C, "F.lock = {from = now, till = now + LOCK_MAX, yaw = E.rig.yaw, turns = true}", "F.lock = {from = now, till = now, yaw = E.rig.yaw, turns = true}", CHEER),
    # the game's melee mode follows his, only for a unit with a missile weapon, and off at the end
    (M, MELEE_LINE, "local melee = not F.ranged", NOMISSILE),
    (M, MELEE_LINE, "local melee = unit:missile_range() > 0 and not F.arty", MELEE),
    (M, "\t\tif F.melee_on then F.melee_on = false try(function() F.uc:melee(false) F.uc:release_control() end) end\n", "", MELEE),
    (M, "F.man_hold, F.frames, F.swallow, F.ui_off, F.melee_on, F.face_yaw, F.queued = nil, 0, nil, false, false, nil, nil",
        "F.man_hold, F.frames, F.swallow, F.ui_off, F.face_yaw, F.queued = nil, 0, nil, false, nil, nil", NOMISSILE),
    (M, "if melee ~= F.melee_on then", "if false then", MELEE),
    # the bar: fly for a flyer, lit in the air; cheer and hide always, on their keys; up a row over the ability bar
    (U, "fly = F.unit:can_fly(), cheer", "fly = false, cheer", BAR),
    (U, "fly = F.unit:can_fly(), cheer", "fly = true, cheer", BAR),
    (U, ' lit("fly", u:is_currently_flying())', "", BAR),
    (U, 'text("hide_key", E.S.names.hide_ui or "")', 'text("hide_key", E.S.names.hide or "")', "the_hide_button_sits_alone_in_the_top_right_corner"),
    (U, LIFT, "if #keys > 0 and o.actions[2] + g.actions[2] * s > o.bar[2] then", CORNERS),
    (U, LIFT, "if false then", FULL),
]
