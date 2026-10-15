A = "script/derpy_tp/abilities.lua"
C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
U = "script/derpy_tp/hud.lua"
MUTANTS = [
    (A, "\t\tE.combat.stand_down(now) -- the author", "\t\t-- the author", "arming_stops_the_shot_and_frees_his_feet"),
    (C, "\t\tif F.firing then C.stop_fire() end\n\t\tC.drop(now)\n\t\tF.want_shot = false",
     "\t\tC.drop(now)\n\t\tF.want_shot = false", "arming_stops_ground_fire"),
    (M, "E.abilities.fire() F.swallow = true end", "E.abilities.fire() end", "the_casting_click_fires_no_shot"),
    (A, "\t\tif E.hud.cooling(n) then return nil, key .. \" is cooling down\" end\n", "",
     "an_ability_cooling_down_does_not_arm_or_cast"),
    (U, "return ok and secs > 0", "return ok and secs >= -1", "an_ability_cooling_down_does_not_arm_or_cast"),
    (U, "if on and off then H.unit() return end", "if on and off then return end",
     "with_the_hud_off_the_next_unit_casts_through_its_own_context"),
    (M, "\t\t\tready_by[F.unit:unique_ui_id()] = F.ready_at\n", "", "f2_off_and_on_keeps_the_reload"),
    (M, "F.ready_at = ready_by[unit:unique_ui_id()] or 0", "F.ready_at = 0", "f2_off_and_on_keeps_the_reload"),
    (A, "\n\t\t\t\t\tand (not enemy or u:is_valid_target()) then", " then", "a_hidden_enemy_is_not_a_target"),
    (M, "F.uc:fire_at_will(F.fire_was) F.uc:release_control()", "F.uc:fire_at_will(true) F.uc:release_control()",
     "leaving_gives_back_the_players_own_fire_setting"),
    (M, "\t\tE.abilities.update(now) -- real time", "\t\tif not paused then E.abilities.update(gnow) end -- real time",
     "paused_the_arrow_still_follows_the_camera"),
    (A, "\t\tif not R.ex then return nil end -- before the camera's first frame\n", "",
     "arming_on_the_first_frame_is_no_error"),
]
