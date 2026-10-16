C = "script/derpy_tp/combat.lua"
U = "script/derpy_tp/hud.lua"
LATE, MUZZLE, MANY = ("a_charge_attack_reported_late_still_plays_out", "a_shot_leaves_from_the_fire_clips_muzzle",
                      "a_gun_with_many_spawns_fires_each_one")
PANEL, NOHP, MEN = ("the_panel_shows_health_and_a_casters_winds", "no_health_figure_keeps_the_bar",
                    "men_alive_shows_for_a_regiment_only")
MUTANTS = [
    # an action clip the engine reports late (0.19-0.31 s in a busy battle) still holds him to its end
    (C, "if slot == L.slot then L.seen = true end", "", LATE),
    (C, "not L.seen and now >= L.from + LOCK_WAIT", "not L.seen and now >= L.from + 0.25", LATE),
    (C, "local LOCK_MAX, LOCK_WAIT = 3, 1", "local LOCK_MAX, LOCK_WAIT = 3, 0.25", LATE),
    # the shot leaves from the fire clip's FIRE_POS, turned with him
    (C, "x + at[2] * c + at[4] * sn", "x + at[4] * c + at[2] * sn", MUZZLE),
    (C, "z - at[2] * sn + at[4] * c", "z + at[2] * sn + at[4] * c", MUZZLE),
    (C, "y + at[3], z", "y + 1.5, z", MUZZLE),
    # every spawn bangs, not only the first
    # the sound only on the first spawn (re-aimed 2026-10-16: Round 27's shot log sits between the two lines)
    (C, "if s[4] then play_sound(from, new_sfx(s[4], false, false)) end", "if s[4] and first then play_sound(from, new_sfx(s[4], false, false)) end", MANY),
    # the panel: hit points, and a caster's winds on the tall plate with the rows above lifted
    (U, "caster = caster or ok and mana > 0", "caster = false", PANEL),
    (U, "caster = caster or ok and mana > 0", "caster = caster or ok and mana >= 0", PANEL),
    (U, 'vis("plate_left", caster) vis("plate_left_short", not caster)',
     'vis("plate_left", true) vis("plate_left_short", false)', PANEL),
    (U, "for _, id in ipairs(GROUPS.winds) do vis(id, caster) end", "for _, id in ipairs(GROUPS.winds) do vis(id, true) end",
     PANEL),
    (U, "if not caster and L.lifted[id] then dy = dy + L.lift end", "", PANEL),
    (U, 'cur, max = cco("HealthValue"), cco("HealthMax")', 'cur, max = cco("HealthValue"), cco("HealthValue")', PANEL),
    (U, 'text("winds", math.floor(cur) .. " / "', 'text("winds", cur .. " / "', PANEL),
    (U, 'width("winds_fill", max > 0 and cur / max or 0)', 'width("winds_fill", 1)', PANEL),
    (U, "\t\t\tif caster then\n\t\t\t\tguard(\"winds\"", "\t\t\tif true then\n\t\t\t\tguard(\"winds\"", PANEL),
    (U, 'guard("hp", function()', 'guard("health", function()', NOHP),
    (U, 'vis("men", n0 > 1) vis("men_icon", n0 > 1)', 'vis("men", n0 > 1)', MEN),
]
