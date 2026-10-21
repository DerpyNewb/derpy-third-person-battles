HUD = "script/derpy_tp/hud.lua"
MUTANTS = [
    (HUD, 'text("hidden", unspottable and "Unspottable" or "Hidden")', 'text("hidden", "Hidden")', "unspottable_reads_unspottable"),
    (HUD, 'img("hidden_icon", unspottable and L.art.unspottable or L.art.hidden)', 'img("hidden_icon", L.art.hidden)',
     "unspottable_reads_unspottable"),
    (HUD, "for _, id in ipairs(GROUPS.hidden) do vis(id, hidden) end", "for _, id in ipairs(GROUPS.hidden) do vis(id, true) end",
     "the_hidden_mark_shows_while_he_is_hidden"),
    (HUD, 'or cco("IsHidden") == true or u:is_hidden()', 'or cco("IsHidden") == true', "hidden_in_tall_grass_reads_hidden"),
    (HUD, 'local hidden = unspottable or cco("IsHidden") == true', 'local hidden = unspottable or false', "the_hidden_mark_shows_while_he_is_hidden"),
]
