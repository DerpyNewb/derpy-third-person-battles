C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
MUTANTS = [
    (C, "if not F.on or not F.model or not P.same(F.model, m) or not P.alive(unit, m) then return end", "if not F.on then return end", "solo_dead_man_launches_nothing"),
    (C, "F.next_shot = now + s[2] * E.S.reload_factor", "F.next_shot = now + s[2]", "solo_hold_repeats_at_the_reload_pace"),
    (C, "if clicked then F.want_shot = true end", "", "solo_click_during_reload_is_kept"),
    (C, "if not E.can_shoot() then F.want_shot = false return end", "", "solo_ammo_runs_out"),
    (C, "for k = 1, s[3] do", "for k = 1, 1 do", "solo_iron_hail_fires_three"),
    (C, "if full > 0 then unit:set_current_ammo_unary(math.max(0, ammo - 1) / full) end", "", "solo_click_fires_one_shot"),
    (C, "P.play(m, SLOT_RELOAD)", "", "solo_click_fires_one_shot"),
    (C, "if F.solo then C.solo(now, clicked, held) else C.ground(now, clicked, held) end", "C.ground(now, clicked, held)", "solo_click_fires_one_shot"),
    (M, "if not F.model and F.held_fire then", "if false then", "solo_regiment_down_to_one_restores_fire"),
    (M, "if F.held_fire then F.uc:fire_at_will(true) F.uc:release_control() F.held_fire = false end", "", "error_restores_everything"),
    (M, "cursor(true)\n\t\tF.dragging = false\n\t\tbm:disable_orders(false)", "F.dragging = false\n\t\tbm:disable_orders(false)", "error_restores_everything"),
]
