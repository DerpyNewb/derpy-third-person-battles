C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
H = "script/derpy_tp/hud.lua"
K = "script/derpy_tp/keys.lua"
S = "script/derpy_tp/settings.lua"
ST = "a_sprint_spends_stamina_and_it_comes_back"
MAP = "m_shows_the_minimap_and_puts_it_back"
Z = "z_toggles_walking_and_running_is_the_default"
# Round 28 (2026-10-16): Z walks, Shift sprints on stamina, M shows CA's radar in the panel
MUTANTS = [
    (C, "F.stamina + dt * (F.sprinting and -1 / STAMINA_DRAIN or", "F.stamina + dt * (F.sprinting and -1 / 16 or", ST),
    (C, "or 1 / STAMINA_FILL)))", "or 1 / 24)))", ST),
    (C, "F.stamina > 0 and (F.sprinting or F.stamina >= STAMINA_AGAIN)", "F.stamina > 0 and true", ST),
    (C, "or F.lock.runs) and F.stamina > 0 and", "or F.lock.runs) and", ST),
    (C, "F.sprinting = want and (not C.locked(now) or F.lock.runs) and", "F.sprinting = want and", "a_jump_on_the_sprint_ends_it"),
    (C, "\t\tF.stamina_t = now\n", "\n", ST),
    (C, "C.charge_run(now, F.sprinting)", "C.charge_run(now, want)", ST),
    (C, "function C.can_sprint() return F.sprinting or F.stamina >= STAMINA_AGAIN end", "function C.can_sprint() return true end", ST),
    (M, "elseif P.pressed(S.keys.walk) then F.walking = not F.walking end", "end", Z),
    (M, "if S.walk_hold then F.walking", "if false then F.walking", "walk_can_be_held_instead"),
    (M, "F.running = F.sprinting or not F.walking", "F.running = not F.walking", "shift_sprints_at_the_run_even_from_a_walk"),
    (M, "F.running = F.sprinting or not F.walking", "F.running = not F.walking", "a_unit_played_whole_sprints_at_the_run"),
    (M, "and not F.armed and (kf ~= 0 or kr ~= 0))\n\t\t\t\tF.running", "and not F.armed)\n\t\t\t\tF.running",
     "shift_held_on_the_move_charges_for_as_long_as_it_is_held"),
    (M, "then E.combat.sprint(gnow, false) E.combat.attack", "then E.combat.attack", "losing_the_window_ends_the_sprint"),
    (M, "if P.pressed(S.keys.minimap) then F.map = E.hud.map(not F.map) end", "", MAP),
    (M, "try(function() E.hud.map(false) end)", "", MAP),
    (M, "F.walking, F.sprinting, F.stamina, F.stamina_t, F.map = false,", "F.walking, F.sprinting, F.stamina, F.stamina_t, F.map = true,", Z),
    (K, '\tZ = "cam_down"}', "}", "the_games_shortcuts_on_its_keys_are_off_while_on"),
    (K, 'walk = "Z", sprint = "Shift"', 'walk = "Z", sprint = "Q"', "charge_and_jump_have_keys_and_settings"),
    (S, 'S.walk_hold = get("combat_walk_hold", false) == true', "S.walk_hold = false", "walk_can_be_held_instead"),
    (H, "r:MoveTo(math.floor(sw - m - w), math.floor(o.toggle[2] + (g.toggle[2] + L.stack) * s))", "r:MoveTo(0, 0)", MAP),
    (H, "home[1]:Adopt(r:Address(), 0)", "home[1]:Adopt(r:Address())", MAP),
    (H, "home[1]:Adopt(r:Address(), 0) r:MoveTo(home[2], home[3])", "home[1]:Adopt(r:Address(), 0)", MAP),
    (H, 'if not r then E.once("map", "no minimap in this battle\'s interface") return false end', "if not r then return true end",
     "with_no_minimap_m_does_nothing"),
    (H, "if off or not ui then return false end", "if not ui then return false end", "the_hud_going_off_puts_the_minimap_back"),
    (H, "\t\t\tH.map(false) -- CA's radar back in its holder: this panel is going\n", "\n", "the_hud_going_off_puts_the_minimap_back"),
    (H, 'vis("map_active_l", home ~= nil)', 'vis("map_active_l", false)', MAP),
    (H, 'text("map_key", E.S.names.minimap or "")', "", MAP),
    (H, 'width("stamina_fill", F.stamina)', 'width("stamina_fill", 1)', ST),
    (H, "show(\"sprint\", F.next_charge - now, not E.combat.can_sprint(), true)",
     "show(\"sprint\", F.next_charge - now, not E.combat.can_sprint())", "the_action_bar_shows_the_charge_then_its_cooldown"),
    (H, 'lit("walk", F.walking)', 'lit("walk", false)', Z),
    (H, 'lit("sprint", F.sprinting)', 'lit("sprint", false)', "shift_sprints_at_the_run_even_from_a_walk"),
    (H, "local can = {walk = true, sprint = true,", "local can = {walk = true, sprint = false,", "the_action_bar_hides_jump_without_its_clips"),
]
