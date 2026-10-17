# Round 36 (2026-10-17): "some ranged units bypass the reload time" - a man with no RELOAD_1 (Hessmarine Grenadiers,
# crossbows, gunshields) had his raise to aim taken for his reload, so no clock held his next shot.
C = "script/derpy_tp/combat.lua"
P = "script/derpy_tp/platform.lua"
WAITS = "solo_without_a_reload_clip_waits_the_game_reload"
A, M = "script/derpy_tp/abilities.lua", "script/derpy_tp/main.lua"
# and "change ammunition units will disappear when the ability is pressed": a transformation cast with a man played on
TF = "a_transformation_ends_third_person_before_it_goes_off"
NEW, LATE = "a_transformation_plays_on_as_its_new_form", "a_transformation_that_never_comes_leaves_third_person_off"
STOP_CAST = ('E.main.stop("transform")\n\t\t\tE.main.follow()\n\t\t\tif not pcall(E.hud.ability_command, n, "PerformAbilityForOwner") then '
             'pcall(F.uc.perform_special_ability, F.uc, key, F.unit) end')
MUTANTS = [
    (A, 'if E.D.abilities[key] == "transform" then', 'if false then', TF),
    (A, '\t\t\tE.main.stop("transform")\n', '', TF),
    (A, STOP_CAST, 'if not pcall(E.hud.ability_command, n, "PerformAbilityForOwner") then '
                   'pcall(F.uc.perform_special_ability, F.uc, key, F.unit) end\n\t\t\tE.main.stop("transform")\n\t\t\tE.main.follow()', TF),
    (A, 'if not pcall(E.hud.ability_command, n, "PerformAbilityForOwner") then pcall(F.uc.perform_special_ability, F.uc, key, F.unit) end',
     'pcall(F.uc.perform_special_ability, F.uc, key, F.unit)', TF),
    (M, '\t\t\t\t\t\tif not F.on then return end -- a transformation ends this session: nothing more on the old unit\n', '', TF),
    # "seems to deactivate f2 when changing ammo": the new form taken over, once its card is there
    (A, '\t\t\tE.main.follow()\n', '', NEW),
    (M, '\n\t\t\t\tand find_uicomponent(core:get_ui_root(), "cards_panel", tostring(u:unique_ui_id())) then', ' then', NEW),
    (M, '\t\tswap = nil -- the key, or the new form: either way nothing more is waited for\n', '', NEW),
    (M, 'if not swap.before[u:unique_ui_id()] and', 'if', NEW),
    (M, '\t\tif gnow > swap.till then swap = nil return end\n', '', LATE),
    (M, 'local SWAP_WAIT = 10', 'local SWAP_WAIT = 20', LATE),
    # fire held as a session starts: no eye until its first frame
    ("script/derpy_tp/rig.lua", '\t\tR.ex, R.ez, R.lx, R.ly, R.lz = nil, nil, nil, nil, nil\n', '', "fire_held_as_a_session_starts_waits_for_the_camera"),
    # the clock for a man with no reload clip
    (C, "F.ready_at, F.shot = now + E.D.shots[F.utype][2] * E.S.reload_factor, nil", "F.shot = nil", WAITS),
    (C, "F.ready_at, F.shot = now + E.D.shots[F.utype][2] * E.S.reload_factor, nil", "F.ready_at, F.shot = now + 1, nil", WAITS),
    # the bug as it was: the raise reported as his reload clip
    (P, "if P.has_slot(m, 1564) then return 1564 end", "if P.has_slot(m, 1564) or P.has_slot(m, 1554) then return 1564 end",
     "platform_reload_uses_the_active_fragment"),
]
