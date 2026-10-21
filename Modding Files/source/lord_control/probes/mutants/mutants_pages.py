HUD, A = "script/derpy_tp/hud.lua", "script/derpy_tp/abilities.lua"
MUTANTS = [
    (HUD, "if not (base and listed[base]) then", "if true then", "no_overcast_copy_gets_a_slot"),
    (HUD, "table.insert(kinds[e.spell and 2 or 1], e)", "table.insert(kinds[1], e)", "spells_are_on_their_own_page"),
    (HUD, "pages[#pages + 1] = {name = p == 1 and name or name .. \" \" .. p, slots = slots}",
     "pages[#pages + 1] = {name = name, slots = slots}", "eleven_abilities_make_two_pages"),
    (HUD, "if okn and list_n and n ~= list_n then", "if false then", "a_changed_list_rebuilds_the_page"),
    (HUD, "or nil\n\t\tpage = 1\n", "or nil\n", "a_new_session_opens_on_abilities"),
    (HUD, "if #entries == 0 then", "if false then", "without_a_context_the_copies_are_still_dropped"),
    (A, "local key = E.hud.key(n) -- slot n", "local key = (F.unit:owned_non_passive_special_abilities() or {})[n] --",
     "key_one_casts_slot_one_of_the_shown_page"),
]
MN = "script/derpy_tp/main.lua"
MUTANTS += [
    (HUD, "local tab = #pages > 1 and E.S.names.page", "local tab = E.S.names.page", "no_tab_with_one_page"),
    (HUD, 'tab_text = tab and "(" .. tab .. ") " .. H.page_name(1) or nil', 'tab_text = tab and "(" .. tab .. ") " .. H.page_name(0) or nil',
     "the_tab_names_the_next_page_with_its_key"),
    (MN, "then E.abilities.cancel() E.hud.next_page() end", "then E.hud.next_page() end", "the_page_key_disarms"),
    (HUD, 'text("slot_" .. n .. "_cool", "") --', "--", "a_turned_page_shows_no_seconds_from_the_page_before"),
    (HUD, "if tab_text and tp and tt then", "if false then", "the_bar_and_its_tab_centre_together"),
]
MUTANTS.append((HUD, 'if not (okp and passive == true) and okk then', "if okk then", "a_passive_in_cas_list_takes_no_slot"))
MUTANTS.append((HUD, "if tab_text and tp and tt then", "if false then", "the_tab_fits_its_text"))
MUTANTS.append((HUD, 'if tab_dw and id == "tab_plate" then dx = -tab_w elseif tab_dw and id == "tab" then dx = -tab_w + L.pad end', "", "the_tab_fits_its_text"))
MUTANTS.append((HUD, "tab_w = tab_dw + gap", "tab_w = tab_dw", "the_tab_fits_its_text"))
MUTANTS.append((HUD, "if F.armed then E.abilities.cancel() end -- an armed slot", "if false then E.abilities.cancel() end -- an armed slot",
                "a_rebuilt_list_disarms"))
MUTANTS.append((HUD, '"winds_frame", "winds_cost"}', '"winds_frame"}', "the_panel_shows_health_and_a_casters_winds"))
