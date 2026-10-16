C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
U = "script/derpy_tp/hud.lua"
D = "script/derpy_tp/data.lua"
SWING, NOCLIP, COOL = ("a_swing_while_walking_plays_out", "a_swing_with_no_clip_does_not_hold_the_walk",
                       "swing_plays_on_one_man_with_cooldown")
THROW, XBOW = "an_exalted_plaguebearer_throws_his_death_head_alone", "solo_click_fires_one_shot"
NORANGED, NEXT = "a_man_who_cannot_shoot_alone_has_no_ranged_mode", "a_next_man_who_cannot_shoot_alone_is_played_in_melee"
BAR = "the_action_bar_shows_no_fire_for_a_man_who_cannot_shoot_alone"
CALL = "swing(primary and SLOTS_LMB or SLOTS_RMB, primary, now, E.S.swing_cooldown)"
MUTANTS = [
    # a swing holds the walk, to the next swing at most; with no clip, nothing waits
    (C, CALL, "swing(primary and SLOTS_LMB or SLOTS_RMB, primary)", SWING),
    (C, CALL, "swing(primary and SLOTS_LMB or SLOTS_RMB, primary, now)", SWING),
    (C, "till = now + (hold or LOCK_MAX)", "till = now + LOCK_MAX", SWING),
    (C, "if not any then F.lock = nil order(primary) end", "if not any then order(primary) end", NOCLIP),
    # he shoots alone with FIRE_LEVEL, or a thrower's GRENADIER, released when the clip's FIRE_POS says
    (M, "elseif P.has_slot(m, 949) then return 949 end", "end", THROW),
    (M, "if P.has_slot(m, 1557) then return 1557 elseif", "if false then return 1557 elseif", XBOW),
    (C, "aims and shot.aim_slot or shot.fire_slot, now)", "aims and shot.aim_slot or 1557, now)", THROW),
    (D, '\t\t["wh3_main_nur_inf_plaguebearers_1"] = {{1.962, -0.194, 1.984, 1.197}},\n', "", THROW),
    # a man who cannot shoot alone has no ranged mode, and never hands the shot to his regiment
    (M, "return not F.cannot_shoot and F.unit:missile_range() > 0", "return F.unit:missile_range() > 0", NORANGED),
    (M, "F.cannot_shoot = F.model ~= nil and not F.solo and unit:missile_range() > 0", "F.cannot_shoot = false", NORANGED),
    (M, "then F.cannot_shoot, F.ranged = true, false end", "then F.cannot_shoot = true end", NEXT),
    (M, "then F.cannot_shoot, F.ranged = true, false end", "then F.ranged = false end", NEXT),
    (M, "\t\t\tif not F.fire_slot then F.solo = false end\n", "", NEXT),
    (M, "\t\t\tF.fire_slot = F.model and fire_clip(F.model)\n", "", NEXT),
    (U, "\n\t\t\tand not F.cannot_shoot, jump", ", jump", BAR),
]
