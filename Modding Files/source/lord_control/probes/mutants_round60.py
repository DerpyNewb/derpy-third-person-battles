# Round 60 (2026-10-23): command mode, Vanilla style - the author, 2026-10-23: "it should jsut be like the vanilla command
# but just in third person view". CA's own clicks, selection and HUD at the crosshair, the number row picking cards, E paging,
# a middle click freeing the cursor, Space and Shift on the speed, his own unit staying put
# (docs/superpowers/specs/2026-10-23-third-person-command-mode-vanilla-design.md). Round 59 guards the Bannerlord style.
MAIN = "script/derpy_tp/main.lua"
CMD = "script/derpy_tp/command.lua"
SET = "script/derpy_tp/settings.lua"
KEYS = "script/derpy_tp/keys.lua"
STYLE = "vanilla_command_style_and_keys"
CLICKS = "vanilla_command_mode_hands_the_clicks_to_ca"
HUD = "vanilla_command_mode_shows_cas_hud_and_the_packs_panel_on_top"
BACK = "the_way_back_takes_the_freed_cursors_click"
DRAG = "a_middle_drag_turns_the_view_and_switches_nothing"
HUDL = "script/derpy_tp/hud.lua"
MID = "a_middle_click_frees_the_cursor_and_the_next_takes_it_back"
F2 = "f2_in_vanilla_command_mode_leaves_vanillas_own_controls"
PAD = "the_number_row_selects_the_cards_in_order_and_e_steps_the_pages"
DEAD = "a_dead_units_number_selects_nothing_and_the_numbers_hold"
SPACE = "space_pauses_and_unpauses_in_command_mode_in_both_styles"
SHIFT = "a_shift_tap_switches_between_slow_and_normal"
MP = "in_multiplayer_command_mode_never_touches_the_speed"
PUT = "his_unit_stays_put_when_a_ca_order_takes_it_in"
REG = "a_regiment_played_whole_stays_put_too"
ONE = "one_man_leaves_his_regiment_to_the_player"
FAW = "cas_fire_at_will_is_held_again_and_his_melee_sent_again_on_leaving"
NETPUT = "in_multiplayer_the_stay_put_halt_is_one_shared_order"
GROUPS = "number_keys_pick_bannerlord_groups_never_the_played_unit"
CENTRE = "cas_centre_holders_take_no_click_in_vanilla_command_mode"
FAWL = "cas_fire_at_will_is_held_again_once_while_it_lands"
GUARD = "the_way_back_leaves_the_mode_inside_the_ticks_guard"
HIDDEN = "the_way_back_takes_no_click_while_hidden"
ASIDE = "vanilla_command_mode_sets_his_plate_and_the_actions_aside"
MCTF = "script/mct/settings/derpy_third_person.lua"
WALK = "a_walk_just_after_the_stay_put_halt_waits_out_its_gap"
PAGE = "leaving_the_mode_keeps_the_ability_bars_page"
FLOOR = "a_band_part_ca_hides_sets_no_floor"
KEYTXT = "the_key_texts_say_which_style_and_which_keys_share"
QLAG = "a_quick_q_after_leaving_still_gives_back_full_speed"
SPACELAG = "space_again_inside_the_lag_unpauses"
SPEED = "the_command_key_slows_the_battle_and_gives_its_speed_back"
FLAGS = "third_person_takes_the_3d_flags_down_and_gives_them_back"
BAND = "command_mode_panel_follows_cas_band_to_its_rest"
BANNER = "command_mode_hides_his_own_banner_under_the_crosshair"
RIG = "script/derpy_tp/rig.lua"
TOP = "the_command_views_top_has_no_dead_mouse_past_it"
MUTANTS = [
    # the style: Bannerlord by default, an unknown value kept
    (SET, "get(\"command_style\", \"vanilla\") == \"bannerlord\" and \"bannerlord\" or \"vanilla\"", "\"bannerlord\"", STYLE),
    (SET, "get(\"command_style\", \"vanilla\") == \"bannerlord\" and \"bannerlord\" or \"vanilla\"", "get(\"command_style\", \"vanilla\")", STYLE),
    # the shared keys: no share, and a fallback that ignores the share
    (KEYS, ", cmd_page = \"jump\", cmd_pause = \"fly\", cmd_speed = \"sprint\"}", "}", STYLE),
    (SET, "(not owner[fallback] or owner[fallback] == K.shares[action]) and fallback or nil", "not owner[fallback] and fallback or nil", STYLE),
    # (re-aimed 2026-10-23: the numpad's Num Lock label went with the numpad - the author: "USE THE NUM ROW FOR
    # SELECTING UNITS") the units back on the numpad; the number row not shared with the abilities, so it conflicts
    (KEYS, "K.defaults[\"cmd_unit_\" .. n] = tostring(n)", "K.defaults[\"cmd_unit_\" .. n] = \"Numpad \" .. n", STYLE),
    (KEYS, "for n = 1, 10 do K.shares[\"cmd_unit_\" .. n] = \"ability_\" .. n end", "", STYLE),
    # CA's control groups left on the number row: a key picked his unit and CA's group both
    (KEYS, "for n = 0, 9 do K.game[tostring(n)] = \"usegroup\" .. n end", "", "the_games_shortcuts_on_its_keys_are_off_while_on"),
    # the style never Vanilla
    (CMD, "vanilla = S.command_style == \"vanilla\"}", "vanilla = false}", CLICKS),
    # the selection his unit alone on entering; then forced as outside the mode; his unit cleared out of it
    (CMD, "bm:clear_selection()", "", CLICKS),
    (MAIN, "if vanilla then -- nothing forced", "if false then -- nothing forced", CLICKS),
    # CA's orders on only with the mouse freed, as the Bannerlord style
    (MAIN, "(vanilla or not F.dragging)", "(not F.dragging)", CLICKS),
    # the interface cinematic while the view turns: CA takes no click
    (MAIN, "if (show or E.command.vanilla()) and not F.ui_off then", "if show and not F.ui_off then", CLICKS),
    # the switch not re-applied on entering or on leaving
    (CMD, "F.cursor_shown = nil -- cursor() applies", "-- cursor() applies", CLICKS),
    (CMD, "F.cursor_shown, F.free_cursor = nil, nil -- the mouse-look", "F.free_cursor = nil -- the mouse-look", CLICKS),
    # the Bannerlord groups, clicks and F keys still acting
    (CMD, "if C.vanilla() then number_keys(P, S) return end", "if C.vanilla() then number_keys(P, S) end", CLICKS),
    # CA's HUD left hidden; the panel left where it was, the way back never shown, the panel not given back on leaving;
    # the radar left in it, or not back (live run 2026-10-23: the author picked the pack's panel with CA's HUD)
    (MAIN, "\t\t\thud(vanilla_ui)", "\t\t\thud(false)", HUD),
    # (retired 2026-10-23: enter() without its place() - equivalent since H.update places again, in the same frame,
    # whenever CA's band moves the floor, which entering the Vanilla style always does)
    (CMD, "\t\tE.hud.back(true) -- first: the bar centres without the page tab it sets aside\n\t\tE.hud.place()", "\t\tE.hud.place()", HUD),
    # placed before the tab is set aside: the bar off centre by the tab it no longer shows (the final review pass)
    (CMD, "\t\tE.hud.back(true) -- first: the bar centres without the page tab it sets aside\n\t\tE.hud.place()", "\t\tE.hud.place()\n\t\tE.hud.back(true) -- first: the bar centres without the page tab it sets aside", ASIDE),
    (CMD, "\t\t\tE.hud.back(false)\n", "", ASIDE),
    (CMD, "\t\t\tE.hud.back(false)\n\t\t\tE.hud.place()", "\t\t\tE.hud.back(false)", PAGE),
    # the final review's minors: leaving draws the HUD over (the bar back on page 1); the stay-put halt unknown to the
    # steering, so a walk right after it is dropped
    (CMD, "\t\t\tE.hud.back(false)\n\t\t\tE.hud.place()", "\t\t\tE.hud.show(not F.ui_off)", PAGE),
    (CMD, "\t\t\t\t\tF.driving, F.last_order = false, gnow\n", "", WALK),
    (CMD, "if F.map then F.map = E.hud.map(false) end", "", HUD),
    (CMD, "if c.map then F.map = E.hud.map(true) end", "", HUD),
    # P keeps the panel aside in the mode; M moves the radar in the mode; CA's flags shown in the mode
    (MAIN, "E.hud.show(not off) --", "E.hud.show(not off and not E.command.vanilla()) --", HUD),
    (MAIN, "if P.pressed(S.keys.minimap) and not vanilla then", "if P.pressed(S.keys.minimap) then", HUD),
    # (live run 2026-10-23: his own flag under the crosshair took the clicks, so the mode shows none)
    (MAIN, "banners(not F.ui_off and F.guide and S.guide_banners)", "banners(not F.ui_off and (vanilla or F.guide and S.guide_banners))", HUD),
    # the Bannerlord style losing its plate to the Vanilla branch
    (CMD, "if not c.vanilla then E.hud.target(\"Pick units: 1 to 6, 0 for all\") return end", "E.hud.target(\"Pick units: 1 to 6, 0 for all\")", GROUPS),
    # the middle click: no switch; the hold as in the Bannerlord style; the free cursor kept past the mode
    (MAIN, "if now - F.mid.at <= LOCK_CLICK and F.mid.moved <= MID_STILL then F.free_cursor = not F.free_cursor end", "", MID),
    (MAIN, "if E.command.vanilla() then\n\t\t\tlocal held", "if false then\n\t\t\tlocal held", MID),
    # a drag switching (the author, 2026-10-23: "middle mouse dragging should not also activate toggle"): on the press,
    # whatever its length, whatever the mouse did; the mouse never counted; free, a held drag turning nothing
    (MAIN, "if held and not F.mid then F.mid = {at = now, moved = 0}", "if held and not F.mid then F.mid = {at = now, moved = 0} F.free_cursor = not F.free_cursor", DRAG),
    (MAIN, "now - F.mid.at <= LOCK_CLICK and ", "", DRAG),
    (MAIN, " and F.mid.moved <= MID_STILL", "", DRAG),
    (MAIN, "if F.mid then F.mid.moved = F.mid.moved + math.abs(dx) + math.abs(dy) end", "", DRAG),
    (MAIN, "if F.free_cursor and not held then F.dragging = false return end", "if F.free_cursor then F.dragging = false return end", DRAG),
    (CMD, "F.cursor_shown, F.free_cursor = nil, nil -- the mouse-look", "F.cursor_shown = nil -- the mouse-look", MID),
    # the numpad: his own card numbered; never read; a dead unit selected; no wrap; the page kept; the page unsaid
    (CMD, "by_id[tostring(F.unit:unique_ui_id())] = nil", "", PAD),
    (CMD, "if C.vanilla() then number_keys(P, S) return end", "if C.vanilla() then return end", PAD),
    (CMD, "if u and u:number_of_men_alive() > 0 then u:select_in_ui() end", "if u then u:select_in_ui() end", DEAD),
    (CMD, "c.page = (c.page + 1) % math.ceil(n / 10)", "c.page = c.page + 1", PAD),
    (CMD, "if n > 10 then c.page", "if n > 0 then c.page", DEAD),
    (CMD, "c.page = 0", "c.page = 1", PAD),
    (CMD, "if n > 0 then say_page(n) end", "", PAD),
    (CMD, "% math.ceil(n / 10) say_page(n) end", "% math.ceil(n / 10) end", PAD),
    # Space: never read, no pause, the speed before it lost, whose it was lost, a battle entered paused left at 1x
    (CMD, "\t\ttime_keys(P, S, now)\n", "\n", SPACE),
    (CMD, "set_speed(0)", "", SPACE),
    (CMD, "set_speed(c.resume or (S.command_speed > 0", "set_speed((S.command_speed > 0", SPACE),
    (CMD, "if resumed then c.set = set end", "", SPACE),
    (CMD, "(S.command_speed > 0 and S.command_speed) or ", "", SPACE),
    # Shift: a hold counts; a mouse button or a number key with it counts; paused it unpauses; the Bannerlord style too
    (CMD, "now - t.at < SHIFT_TAP", "true", SHIFT),
    # the tap's spoilers (spec 4.6: no other key or mouse button): Shift spoiling itself, the mouse or W left out
    (CMD, "if vk ~= S.keys.cmd_speed and P.held(vk) then", "if P.held(vk) then", SHIFT),
    (CMD, "if vk ~= S.keys.cmd_speed and P.held(vk) then", "if vk ~= S.keys.cmd_speed and type(vk) == \"number\" and vk > 0x06 and P.held(vk) then", SHIFT),
    (CMD, "if vk ~= S.keys.cmd_speed and P.held(vk) then", "if vk ~= S.keys.cmd_speed and vk ~= E.K.vk.W and P.held(vk) then", SHIFT),
    (CMD, "if vk ~= S.keys.cmd_speed and P.held(vk) then", "if vk ~= S.keys.cmd_speed and not (type(vk) == \"number\" and vk >= 0x30 and vk <= 0x39) and P.held(vk) then", SHIFT),
    (CMD, "if not t.spoiled and now - t.at < SHIFT_TAP and s and s > 0 then", "if not t.spoiled and now - t.at < SHIFT_TAP and s then", SHIFT),
    (CMD, "if not c.vanilla then return end", "", SHIFT),
    # one player slows a shared battle with Space or Shift
    (CMD, "if bm:is_multiplayer() then return end", "", MP),
    # he stays put: halted inside the gap (dropped); halted while he walks on W; never halted; one man's regiment ordered
    (CMD, "if gnow - stray >= ORDER_GAP then", "if true then", PUT),
    (CMD, "if u:is_moving() and not walking then", "if u:is_moving() then", PUT),
    (MAIN, ", kf ~= 0 or kr ~= 0)", ")", PUT),
    (CMD, "\t\t\t\t\tF.uc:halt()\n", "\n", REG),
    (CMD, "if C.vanilla() and not F.model then", "if C.vanilla() then", ONE),
    # the clock not started over after a halt: CA's next order halted inside the gap
    (CMD, "\t\t\t\t\tstray = nil\n\t\t\t\t\tF.uc:halt()", "\t\t\t\t\tF.uc:halt()", PUT),
    # the multiplayer halt sent inside the gap of CA's order
    (CMD, "if gnow - stray >= ORDER_GAP then", "if true then", NETPUT),
    # CA's fire at will kept on him; his melee not sent again; sent to one man's regiment
    (CMD, "\t\t\t\tF.uc:fire_at_will(false)\n", "", FAW),
    (CMD, "if not F.model and F.on then F.melee_on = nil end", "", FAW),
    (CMD, "if not F.model and F.on then F.melee_on = nil end", "if F.on then F.melee_on = nil end", ONE),
    # the final review pass: F2 inside the mode clearing what the stop reads (his unit left in melee); the re-hold sent
    # every frame until it lands, its clock never set
    (CMD, "if not F.model and F.on then", "if not F.model then", FAW),
    (CMD, " and gnow - faw_at >= ORDER_GAP then", " then", FAWL),
    (CMD, "\t\t\t\tfaw_at = gnow\n", "", FAWL),
    # F2 in the mode with the cursor free: the next session starts free
    (CMD, "F.cursor_shown, F.free_cursor = nil, nil -- the mouse-look", "F.cursor_shown = nil -- the mouse-look", F2),
    # CA's centre holders (live run 2026-10-23): left interactive, never given back, one of the two forgotten
    (CMD, "c.centre[#c.centre + 1] = {h, h:IsInteractive()} h:SetInteractive(false)", "c.centre[#c.centre + 1] = {h, h:IsInteractive()}", CENTRE),
    (CMD, "for _, h in ipairs(c.centre) do h[1]:SetInteractive(h[2]) end", "", CENTRE),
    (CMD, "{\"spawn_zone_icons_parent\", \"reinforcement_icons_parent\"}", "{\"reinforcement_icons_parent\"}", CENTRE),
    (CMD, "{\"spawn_zone_icons_parent\", \"reinforcement_icons_parent\"}", "{\"spawn_zone_icons_parent\"}", CENTRE),
    # the panel on CA's band (hud.lua): never lifted; the porthole, the highest part, not counted; the corner buttons
    # left under CA's radar; the way back off the bar's left edge, or below it
    (HUDL, "if E.command and E.command.vanilla() then", "if false then", HUD),
    (HUDL, "{\"porthole_parent\", \"battle_orders\", \"winds_of_magic\"}", "{\"battle_orders\", \"winds_of_magic\"}", HUD),
    (HUDL, "top = math.max(top, y + rh + m)", "top = top", HUD),
    (HUDL, "o.back = {o.bar[1],", "o.back = {(sw - g.back[1] * s) / 2,", HUD),
    (HUDL, "o.bar[2] - (L.stack + g.back[2]) * s}", "o.bar[2]}", HUD),
    # the way back: no words, no key, shown outside the mode; its click doing nothing, any click leaving the mode, a
    # click outside the mode entering it
    (HUDL, "text(\"back\", \"Back to third person\") ", "", HUD),
    (HUDL, "text(\"back_key\", E.S.names.command or \"\")", "", HUD),
    (HUDL, "H.back(E.command ~= nil and E.command.vanilla())", "H.back(true)", HUD),
    (HUDL, "function() if F.command then F.back_click = true end end", "function() end", BACK),
    (HUDL, "function(ctx) return ctx.string == \"back_plate\" end", "function(ctx) return true end", BACK),
    # the final review pass: the click leaving the mode in CA's unguarded listener; taken outside the mode, met by F2 in
    # the same frame; never let go of, so the next entry leaves again
    (HUDL, "function() if F.command then F.back_click = true end end", "function() if F.command then E.command.toggle() end end", GUARD),
    (MAIN, "or F.back_click and F.command then", "or F.back_click then", BACK),
    (MAIN, "\t\t\tF.back_click = nil\n", "", BACK),
    # the plate hidden but clickable: after the mode, with the interface hidden
    (HUDL, "\"back_plate.click\", on == true,", "\"back_plate.click\", true,", HIDDEN),
    (HUDL, "if not on then pcall(unmark) H.back(false) end", "if not on then pcall(unmark) end", HIDDEN),
    # his plate, the actions, the keys and the tab (the author, 2026-10-23): never hidden, shown again by the next draw,
    # never given back, drawn before they are set aside; one group left out
    (HUDL, "if on or was == AWAY then for id in pairs(AWAY) do vis(id, asked[id]) end end", "", ASIDE),
    (HUDL, "if on or was == AWAY then", "if on then", ASIDE),
    (HUDL, "\t\tasked[id] = b == true\n", "", ASIDE),
    (HUDL, "away = on and AWAY or {}", "away = {}", ASIDE),
    (HUDL, "asked[id] and not away[id],", "asked[id],", ASIDE),
    # a band part CA hides counted for the floor: always, or by what it shows under the pack's own hiding
    (HUDL, "if c and ca_shows then", "if c then", FLOOR),
    (HUDL, "local kept = F.hidden_ui and F.hidden_ui.hud_battle or {}", "local kept = {}", FLOOR),
    # the key texts: the Bannerlord style's keys and groups unnamed; a shared key's tooltip silent, or one-sided
    (KEYS, "follow me (Bannerlord style)", "follow me", KEYTXT),
    (KEYS, "K.labels[\"ability_\" .. n] = K.labels[\"ability_\" .. n] .. \" (command mode, Bannerlord style: \" .. group .. \")\"", "", KEYTXT),
    (KEYS, "\"heroes\", [10] = \"everyone\"}", "\"heroes\", [7] = \"everyone\"}", KEYTXT),
    (MCTF, "if partner[action] then", "if false then", KEYTXT),
    (MCTF, "partner[a], partner[b] = b, a", "partner[a] = b", KEYTXT),
    (HUDL, "and not away.tab then", "then", ASIDE),
    (HUDL, "H.back(E.command ~= nil and E.command.vanilla()) -- before the parts it sets aside are shown\n\t\tH.unit() -- then: the bar centres on how many abilities he has\n\t\tH.place()",
     "H.unit() -- then: the bar centres on how many abilities he has\n\t\tH.place()\n\t\tH.back(E.command ~= nil and E.command.vanilla())", ASIDE),
    (HUDL, "if at[1] == \"left\" or at[1] == \"actions\" or", "if at[1] == \"actions\" or", ASIDE),
    (HUDL, "or at[1] == \"actions\" or", "or", ASIDE),
    (HUDL, "or id:match(\"^slot_%d+_key\") or", "or", ASIDE),
    (HUDL, " or id:match(\"^tab\") then", " then", ASIDE),
    # the author's live run, 2026-10-23. The speed: the lagging read-back believed, a speed the player picked taken for
    # the mode's, the leave's ask not remembered
    (CMD, "and seen(s) then return asked.s end", "and false then return asked.s end", QLAG),
    (CMD, "and seen(s) then return asked.s end", "and false then return asked.s end", SPACELAG),
    (CMD, "and seen(s) then return asked.s end", "then return asked.s end", SPEED),
    (CMD, "then ask(c.was) end", "then bm:modify_battle_speed(c.was) end", QLAG),
    # CA's 3D flags: never taken down, never given back, the player's value not kept, kept after the stop, not given back
    # as the next battle loads
    (MAIN, "\t\t\tcore:set_integer_preference(\"ui_unit_flags\", 0)\n", "", FLAGS),
    (MAIN, "if flags then try(function() core:set_integer_preference(\"ui_unit_flags\", flags)", "if false then try(function() core:set_integer_preference(\"ui_unit_flags\", flags)", FLAGS),
    (MAIN, "\t\t\tcore:svr_save_registry_string(FLAGS, tostring(flags))\n", "", FLAGS),
    (MAIN, "core:set_integer_preference(\"ui_unit_flags\", flags) core:svr_save_registry_string(FLAGS, \"\")", "core:set_integer_preference(\"ui_unit_flags\", flags)", FLAGS),
    (MAIN, "if left then core:set_integer_preference", "if false then core:set_integer_preference", FLAGS),
    # his skills and the way back centred over the band, not on CA's portrait (the author: "move back the skills to the
    # character portrait")
    (HUDL, "local bar_x = left and left + tab_w * s or", "local bar_x = nil or", HUD),
    (HUDL, "if p then left = p:Position() end", "", HUD),
    # the panel placed once at Q, CA's band read off the model clock the mode slows and its pause stops
    (HUDL, "if floor ~= placed[1] or top ~= placed[2] then H.place() end", "", BAND),
    (HUDL, "if E.command and E.command.vanilla() and os.clock() >= band_at then\n\t\t\tband_at = os.clock() + CCO_EVERY", "if E.command and E.command.vanilla() and now >= band_at then\n\t\t\tband_at = now + CCO_EVERY", BAND),
    # his own banner under the crosshair (the author: "remove this"): never hidden, never given back, the banner itself
    # hidden, which CA shows again every tenth of a second
    (CMD, "if b then c.banner = b:Visible() b:SetVisible(false) end", "", BANNER),
    (CMD, "if b then b:SetVisible(c.banner) end", "", BANNER),
    (CMD, "tostring(F.unit:unique_ui_id()), \"modular_parent\")", "tostring(F.unit:unique_ui_id()))", BANNER),
    # the mouse winding on past command mode's top, or held to it out of the mode too
    (RIG, "if E.F.command and S.command_distance > 0 then top = CMD_LOOK_MIN end", "", TOP),
    (RIG, "if E.F.command and S.command_distance > 0 then top", "if S.command_distance > 0 then top", TOP),
]
