# Round 58 (2026-10-22): the guide key brings CA's own unit banners back and the pack's bars step aside (players: "a
# keybind to toggle unit banners", "morale or status effects on units"); and the unit an armed ability would hit gets
# CA's markers, one of his own included ("show the outline of the targeted unit").
HUD = "script/derpy_tp/hud.lua"
MAIN = "script/derpy_tp/main.lua"
SET = "script/derpy_tp/settings.lua"
BAN = "the_guide_key_brings_cas_banners_back_and_the_bars_step_aside"
AIM = "an_armed_abilitys_target_is_marked_one_of_his_own_too"
MUTANTS = [
    # the key never brings them
    (MAIN, "banners(F.guide and S.guide_banners and not F.ui_off)", "banners(false)", BAN),
    # the MCT switch ignored
    (MAIN, "banners(F.guide and S.guide_banners and not F.ui_off)", "banners(F.guide and not F.ui_off)", BAN),
    # the interface hidden, banners all the same
    (MAIN, "banners(F.guide and S.guide_banners and not F.ui_off)", "banners(F.guide and S.guide_banners)", BAN),
    # set again every frame
    (MAIN, "if F.banners == on then return end", "", BAN),
    # their holder left hidden by hud()
    (MAIN, "if ids then ids:SetVisible(true) end", "", BAN),
    # their holder shown with the banners off
    (MAIN, "local ids = F.banners and find_uicomponent(root, \"unit_id_holder\")",
     "local ids = find_uicomponent(root, \"unit_id_holder\")", BAN),
    # the cursor switch brings them back whatever the key says
    (MAIN, "bm.battle:set_banners_enabled(F.banners == true)", "bm.battle:set_banners_enabled(true)", BAN),
    # third person off leaves them off
    (MAIN, "try(function() bm.battle:set_banners_enabled(true) end)", "", BAN),
    # off by default
    (SET, "get(\"display_guide_banners\", true)", "get(\"display_guide_banners\", false)", BAN),
    # the bars stay up under CA's banners (a refresh on the banners alone was cut: they change with the guide key, or
    # with the interface hidden, whose return starts the refresh over - its mutant survived the hardest test, 2026-10-22)
    (HUD, ") and not F.banners", ")", BAN),
    # an armed ability's target never marked
    (HUD, "mark(u, (uid == aimed or not u:is_player_controlled()", "mark(u, (not u:is_player_controlled()", AIM),
    # the target followed only at the next refresh
    (HUD, "and aimed == aimed_was then return end", "then return end", AIM),
]
