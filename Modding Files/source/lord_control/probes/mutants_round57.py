# Round 57 (2026-10-19): a health bar over every unit in its side's colour, and CA's markers under the men of every unit
# the player does not command (players: "a health bar each unit and a ally or enemy highlight"); then the guide on Alt
# (hold or press), the game's Alt shortcuts off on its keys, and a bar only near the man played or with the markers.
HUD = "script/derpy_tp/hud.lua"
MAIN = "script/derpy_tp/main.lua"
SET = "script/derpy_tp/settings.lua"
BARS = "every_unit_gets_a_bar_over_its_men_on_its_own_context"
MARK = "markers_go_under_enemies_seen_and_allies_never_the_players_own"
NEAR = "a_bar_shows_only_near_the_man_played_and_with_the_guide_setting_only_with_the_markers"
ALT = "with_alt_the_guide_key_the_games_alt_shortcuts_on_its_keys_are_off"
MUTANTS = [
    # the played unit's bar shown over him
    (HUD, "near and u ~= F.unit and alive, function(c, b)", "near and alive, function(c, b)", BARS),
    # a dead unit's bar left up
    (HUD, "near and u ~= F.unit and alive, function(c, b)", "near and u ~= F.unit, function(c, b)", BARS),
    # every unit at the lowest lift
    (HUD, "for n, m in ipairs(L.bar.lifts) do if m >= want then return n end end", "do return 1 end", BARS),
    # no clearance over his men
    (HUD, "local want = (body and body[2] or 1.8) + L.bar.clear", "local want = (body and body[2] or 1.8)", BARS),
    # the bar on no unit
    (HUD, "\t\t\t\tpin:SetContextObject(context(\"CcoBattleUnit\", id))\n", "", BARS),
    # CA's context constructor looked for in _G, where it is not (the first live run, 2026-10-19: one bar, at the corner)
    (HUD, "local context = cco\n", "local context = _G.cco\n", BARS),
    # remade every refresh
    (HUD, "if not pin and made < BARS_MADE then", "if made < BARS_MADE then", BARS),
    # the setting off leaves the holder shown
    (HUD, "\t\tvis(\"bars\", E.S.bars ~= false)\n", "", BARS),
    # the setting off still makes bars
    (HUD, "local holder = E.S.bars and part(\"bars\")", "local holder = part(\"bars\")", BARS),
    # a unit gone from its list keeps its bar
    (HUD, "for id, pin in pairs(pins) do if not seen[id] then", "for id, pin in pairs(pins) do if false then", BARS),
    # a controller on the player's own units
    (HUD, "if not u:is_player_controlled() then mark(", "if true then mark(", MARK),
    # an enemy he cannot see marked
    (HUD, "mark(u, guide_was and alive and (not enemy or u:is_valid_target()))", "mark(u, guide_was and alive)", MARK),
    # marked with the guide key up
    (HUD, "mark(u, guide_was and alive and", "mark(u, alive and", MARK),
    # the guide key answered only at the next refresh
    (HUD, "if now < bars_at and (F.guide or false) == guide_was then return end", "if now < bars_at then return end", MARK),
    # the key never followed while held
    (MAIN, "if S.guide_hold then F.guide = P.held(S.keys.guide) elseif", "if false then elseif", MARK),
    # a press never switches them
    (MAIN, "elseif P.pressed(S.keys.guide) then F.guide = not F.guide end", "end", MARK),
    # pressing to switch by default
    (SET, 'S.guide_hold = get("display_guide_hold", true) == true', 'S.guide_hold = get("display_guide_hold", false) == true', MARK),
    # marked again every refresh
    (HUD, "\t\tif (m and m.on or false) == on then return end\n", "", MARK),
    # left on after third person
    (HUD, "\t\tif not on then pcall(unmark) end\n", "", MARK),
    # never released
    (HUD, "\t\tm.uc:highlight(on)\n\t\tm.uc:release_control()\n", "\t\tm.uc:highlight(on)\n", MARK),
    # every bar shown whatever the distance
    (HUD, "local near = (p:get_x() - mx) ^ 2 + (p:get_z() - mz) ^ 2 <= reach", "local near = true", NEAR),
    # the default distance not near
    (SET, 'S.bars_range = get("display_bars_range", 40)', 'S.bars_range = get("display_bars_range", 100)', NEAR),
    # 1000 not the whole field
    (HUD, "local reach = E.S.bars_range >= 1000 and math.huge or", "local reach =", NEAR),
    # measured from his regiment when he plays one man of it
    (HUD, "if F.model then local x, _, z = E.P.model_pos(F.model) mx, mz = x, z else", "if false then else", NEAR),
    # the guide setting shows them with the markers off
    (HUD, 'or E.S.bars == "guide" and guide_was', 'or E.S.bars == "guide"', NEAR),
    # the guide setting never shows them
    (HUD, 'or E.S.bars == "guide" and guide_was', "", NEAR),
    # the bars only with the markers by default
    (SET, 'get("display_bars_show", "always")', 'get("display_bars_show", "guide")', BARS),
    # the bars shown on the markers key answered only at the next refresh
    (HUD, "if now < bars_at and (F.guide or false) == guide_was then return end", "if now < bars_at then return end", NEAR),
    # the game's Alt shortcuts left on
    (MAIN, 'sc = S.names.guide == "Alt" and E.K.game_alt[name]', "sc = nil", ALT),
    # turned off with the guide on another key
    (MAIN, 'sc = S.names.guide == "Alt" and E.K.game_alt[name]', "sc = E.K.game_alt[name]", ALT),
    # not given back at the end
    (MAIN, 'sc = S.names.guide == "Alt" and E.K.game_alt[name]\n\t\t\tif sc then bm:disable_shortcut(sc, true) F.shortcuts[#F.shortcuts + 1] = sc end',
     'sc = S.names.guide == "Alt" and E.K.game_alt[name]\n\t\t\tif sc then bm:disable_shortcut(sc, true) end', ALT),
]
