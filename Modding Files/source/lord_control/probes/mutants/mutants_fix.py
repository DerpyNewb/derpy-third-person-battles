C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
V = "script/derpy_tp/move.lua"
N = "script/battle/mod/derpy_third_person.lua"
MUTANTS = [
    (C, "unit:set_current_ammo_unary(math.max(0, ammo - 1) / full)", "unit:set_current_ammo_unary((ammo - 1) / full)", "solo_ammo_never_goes_negative"),
    (C, "or not P.same(F.model, m) or not P.alive(unit, m) then return end", "or not P.same(F.model, m) then return end", "solo_dead_man_launches_nothing_before_the_frame_sees_it"),
    (M, "E.S = E.settings(get_mct and get_mct(), E.K)", "E.S = E.load(\"settings\")(get_mct and get_mct(), E.K)", "toggle_loads_no_files"),
    (M, "if F.model and (unit:number_of_men_alive() < 2 or not P.alive(unit, F.model)) then", "if F.model and not P.alive(unit, F.model) then", "solo_others_die_still_holds_fire"),
    (M, "try(function() E.move.halt() end)", "E.move.halt()", "stop_restores_past_a_failing_step"),
    (M, "\t\tF.on = true\n\t\t-- the author: \"absolute control", "\t\t-- the author: \"absolute control", "start_error_gives_fire_back"),
    (M, "local paused = now - F.gt_real > PAUSE_AFTER", "local paused = false", "pause_holds_the_one_man"),
    (M, "local paused = now - F.gt_real > PAUSE_AFTER", "local paused = false", "pause_holds_fire"),
    (V, "local need = now - (F.last_order or -1e9) >= STEER_GAP and (", "local need = true and (", "walking_orders_keep_half_a_second_apart"),
    (C, "if F.ranged or E.can_shoot() then", "if E.can_shoot() then", "mode_leaves_ranged_without_ammo"),
    (M, "local ok, res, why = pcall(fn, ...)\n\t\tif ok then return res, why end", "local res, why = fn(...)\n\t\tif true then return res, why end", "throwing_checks_fall_back_without_a_strike"),
    (M, "\t\tP.features[group] = false\n", "", "throwing_checks_fall_back_without_a_strike"),
    (V, "if stuck and now - F.man_walk < MAN_WINDOW then", "if stuck then", "one_man_nudges_only_at_the_start"),
    (V, "if keys ~= F.man_keys then F.man_keys, F.man_walk = keys, now end", "if not F.man_walk then F.man_walk = now end", "one_man_nudges_only_at_the_start"),
    (N, "\t\twhen_shown(function() E.say(\"derpy_tp_needs_memreader\") end)\n\t\tE.once(\"memreader\"", "\t\tE.say(\"derpy_tp_needs_memreader\")\n\t\tE.once(\"memreader\"", "needs_memreader_said_after_loading"),
    (N, "local function once() if not done then done = true fn() end end", "local function once() fn() end", "needs_memreader_said_after_loading"),
    (C, "if not ok then E.pending = err end -- E.fail registers a timer: not from in here\n\t\tend, SHOT_DELAY_MS", "if not ok then E.fail(err) end\n\t\tend, SHOT_DELAY_MS", "error_in_a_shot_still_hides_its_message"),
    (M, "if E.pending then local err = E.pending E.pending = nil E.fail(err) end", "", "error_in_a_shot_still_hides_its_message"),
    # (round 25: removed the "or 0" fallback mutant - F2 stamps last_order, so the fallback is never read)
]
