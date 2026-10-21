HUD, AB = "script/derpy_tp/hud.lua", "script/derpy_tp/abilities.lua"
ARMY, PREVIEW, ENGINE, CASTER, ENTRY = ("with_no_card_context_the_winds_come_from_his_army",
    "an_overcast_refused_for_winds_previews_its_cost", "an_overcast_the_engine_refuses_previews_no_cost",
    "a_rebuild_that_makes_him_a_caster_shows_the_winds", "one_unreadable_entry_costs_only_itself")
MUTANTS = [
    (HUD, "ok, w = pcall(function() return F.unit:army():winds_of_magic_current() end)", "ok, w = false, nil", ARMY),
    (HUD, "local c = math.min((hint and now < hint.till and hint.cost) or cost or 0, cur)",
          "local c = math.min(cost or 0, cur)", PREVIEW),
    (HUD, "local c = math.min((hint and now < hint.till and hint.cost) or cost or 0, cur)",
          "local c = math.min((hint and hint.cost) or cost or 0, cur)", PREVIEW),
    (AB, 'else E.hud.refuse(n, "Cannot overcast now") end', 'else E.hud.refuse(n, "Cannot overcast now", c) end', ENGINE),
    (HUD, "\t\t\t\tshow_page(indexed, why)\n\t\t\t\tshow_caster()\n", "\t\t\t\tshow_page(indexed, why)\n", CASTER),
    (HUD, "if not (okp and passive == true) and okk then", "if not (okp and passive == true) then", ENTRY),
    (HUD, "\t\t\tlist_n = n\n\t\t\tfor i = 0, n - 1 do", "\t\t\tfor i = 0, n - 1 do", ENTRY),
]
