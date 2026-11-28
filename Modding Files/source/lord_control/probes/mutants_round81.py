# Round 81 (2026-11-28): the portrait's border, and a lord's or hero's porthole in place of his card (the author: "add
# borders around the unit portrait, should also use the character portrait IF the unit is a hero or lord"). Each a
# plausible slip, not a typo.
HUD = "script/derpy_tp/hud.lua"
LORD = "a_lord_shows_his_porthole_framed_and_the_plate_moves_beside_it"
LINE = "a_line_unit_keeps_his_card_in_its_border"
NOFILE = "a_lord_whose_porthole_is_no_file_keeps_his_card"
OWN = "a_campaign_lord_shows_his_own_porthole_and_any_slash_is_read"
MUTANTS = [
    # every unit taken for a character: a line unit whose card has a porthole twin loses his card
    (HUD, '\t\tif H.value("IsCharacter") ~= true then return nil end\n', "", LINE),
    # the file never looked for: a missing porthole draws a blank square
    (HUD, 'if dir and common.filesystem_lookup("/" .. dir, file) ~= "" then', "if dir then", NOFILE),
    # the card's twin before his campaign character's own
    (HUD, 'ipairs({H.value("UnitDetailsContext.CharacterContext.PortraitPath") or "", twin})',
     'ipairs({twin, H.value("UnitDetailsContext.CharacterContext.PortraitPath") or ""})', OWN),
    # a card path in backslashes looked for as written
    (HUD, '\t\t\tdir = dir and dir:gsub("[^%w_%-%.]+", "/")\n', "", OWN),
    # a card path in capitals taken as written
    (HUD, '(card:lower():gsub("portraits(%W)units(%W)"', '(card:gsub("portraits(%W)units(%W)"', OWN),
    # the plate left where it was, under the porthole
    (HUD, "\t\t\tif bust and L.beside[id] then dx = dx + L.bust_shift end\n", "", LORD),
    # the border shown for neither, or left up under the porthole
    (HUD, 'for _, id in ipairs({"portrait", "portrait_frame"}) do vis(id, not bust) end', 'vis("portrait", not bust)', LORD),
    (HUD, 'for _, id in ipairs({"portrait", "portrait_frame"}) do vis(id, not bust) end', 'vis("portrait", not bust) vis("portrait_frame", true)', LORD),
    (HUD, 'for _, id in ipairs({"bust_back", "bust", "bust_frame"}) do vis(id, bust) end', 'vis("bust", bust)', LINE),
]
