# Round 71 (2026-11-07): the Workshop reports of 2026-11-03 to 11-07 (docs/sessions/WORKSHOP_REPORTS_20261107_THIRD_PERSON.md).
# Frame drops: the men under the bars read ten times a second and placed every frame, CA's HUD hidden again four times a
# second and at once on a change, the panel's parts looked up once. The rider's blocks left out of the disarm. Command mode's
# Vanilla style naming the key that frees the cursor.
P = "script/derpy_tp/platform.lua"
MAIN = "script/derpy_tp/main.lua"
HUD = "script/derpy_tp/hud.lua"
CMD = "script/derpy_tp/command.lua"
FRAG = "the_man_played_alone_points_at_a_fragment_with_no_attack_clips"
BARS = "the_men_under_the_bars_are_read_ten_times_a_second"
SWEEP = "cas_hud_is_hidden_again_four_times_a_second"
PARTS = "the_panels_parts_are_looked_up_once"
LINE = "vanilla_command_mode_says_which_key_frees_the_cursor"
MUTANTS = [
    # the disarm: the old sweep back, or the rider's moving, jumping and flying swings left in
    (P, "s >= 1901 and s <= 1910 or s >= 1931 and s <= 1950 end", "s >= 1901 and s <= 1950 end", FRAG),
    (P, "s >= 1901 and s <= 1910 or s >= 1931 and s <= 1950 end", "s >= 1901 and s <= 1910 end", FRAG),
    (P, "s >= 1901 and s <= 1910 or s >= 1931 and s <= 1950 end", "s >= 1901 and s <= 1920 or s >= 1931 and s <= 1950 end", FRAG),
    # the bars: read every frame again; placed only when read; the read's place not used
    (HUD, "if on and now - men_at >= MEN_EVERY then", "if on then", BARS),
    (HUD, "then shown[b] = true place(b, sx, sy, p[4]) end", "then shown[b] = true if now == men_at then place(b, sx, sy, p[4]) end end", BARS),
    (HUD, "men_seen[b] = {x, y + up, z, cur / max}", "men_seen[b] = {x, y, z, cur / max}", BARS),
    # CA's HUD: never again after the first pass; no pass on the freed mouse
    (MAIN, "or now >= (F.hud_at or 0) then", "then", SWEEP),
    (MAIN, "F.dragging ~= F.hud_drag or ", "", SWEEP),
    # the cinematic UI's test: always (CA's interface showing, passes four times a second), never (every frame again)
    (MAIN, "local veiled = not P.features.net and (F.ui_off or F.dragging and not vanilla_ui and not F.banners)", "local veiled = true", SWEEP),
    (MAIN, "local veiled = not P.features.net and (F.ui_off or F.dragging and not vanilla_ui and not F.banners)", "local veiled = false", SWEEP),
    (MAIN, "local vanilla_ui = E.command.vanilla()", "local vanilla_ui = false", "vanilla_command_mode_shows_cas_hud_and_the_packs_panel_on_top"),
    # the panel's parts: searched every time
    (HUD, "\t\tif not c then c = find_uicomponent(ui, id)", "\t\tif true then c = find_uicomponent(ui, id)", PARTS),
    # the line: none, the two ways round, the key not as MCT has it
    (CMD, "labels(now) cursor_line() end", "labels(now) end", LINE),
    (CMD, "local s = F.free_cursor and E.loc(", "local s = not F.free_cursor and E.loc(", LINE),
    (CMD, "E.hud.target((s:gsub(\"%%s\", function() return key end)))", "E.hud.target((s:gsub(\"%%s\", function() return \"Middle mouse\" end)))", LINE),
]
