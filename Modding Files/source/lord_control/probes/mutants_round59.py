# Round 59 (2026-10-23): command mode - the author, 2026-10-23: "the player lord when pressing a button, will switch to
# command mode where they can command their units in third person". Q slows the battle, 1-6 pick Bannerlord's groups,
# the clicks and F1/F3/F4 order them, the freed mouse gives CA's own orders (docs/superpowers/specs/
# 2026-10-22-third-person-command-mode-design.md).
MAIN = "script/derpy_tp/main.lua"
CMD = "script/derpy_tp/command.lua"
RIG = "script/derpy_tp/rig.lua"
HUD = "script/derpy_tp/hud.lua"
SET = "script/derpy_tp/settings.lua"
KEYS = "script/derpy_tp/keys.lua"
SLOW = "slow_motion_is_no_pause"
ZERO = "speed_zero_is_a_pause_at_once"
SPEED = "the_command_key_slows_the_battle_and_gives_its_speed_back"
LOCK = "command_mode_lets_go_of_the_lock_on_and_drops_the_wheel"
OFF = "third_person_off_ends_command_mode_and_gives_the_speed_back"
MP = "in_multiplayer_command_mode_never_touches_the_speed"
ARMED = "an_armed_ability_is_put_down_by_command_mode"
LORD = "the_general_and_heroes_command_and_a_setting_lets_any_unit"
DEF = "command_mode_settings_defaults"
VIEW = "the_command_view_eases_back_and_up_and_returns"
GROUPS = "number_keys_pick_bannerlord_groups_never_the_played_unit"
CASTE = "a_units_card_category_decides_its_group"
CLICK = "a_click_moves_the_pick_to_the_banner_under_the_crosshair"
CHARGE = "right_click_attacks_the_enemy_on_the_crosshair_and_f3_charges"
HOLD = "f4_holds_and_shooters_keep_firing"
FOLLOW = "f1_follow_me_repeats_until_another_order"
GAP = "an_order_inside_the_gap_waits_and_the_latest_wins"
ROUT = "a_routing_unit_gets_no_order"
FREE = "the_freed_mouse_in_command_mode_gives_cas_orders_never_to_his_unit"
FAST = "fast_motion_keeps_the_half_second_wait"
WHOLE = "an_order_waits_whole_when_part_of_the_pick_is_inside_the_gap"
FOLLOW_FREE = "follow_me_lets_go_of_a_unit_selected_with_the_freed_mouse"
MUTANTS = [
    # slow motion read as a pause again
    (MAIN, "> PAUSE_AFTER / math.min(speed, 1)", "> PAUSE_AFTER", SLOW),
    # the wait cut short above normal speed (final review)
    (MAIN, "> PAUSE_AFTER / math.min(speed, 1)", "> PAUSE_AFTER / speed", FAST),
    # speed 0 waits out the half second
    (MAIN, "local paused = speed <= 0 or now", "local paused = now", ZERO),
    # the key does nothing
    (MAIN, "if P.pressed(S.keys.command) or F.back_click and F.command then E.command.toggle(gnow) end", "", SPEED),
    # the speed never given back
    # (re-aimed 2026-10-23: the vanilla round moved the speed onto c.set, mutants_round60.py; then onto ask(), which
    # remembers the speed asked for while current_battle_speed lags it)
    (CMD, "if c.set and c.was and s and math.abs(s - c.set) < 0.01 then ask(c.was) end", "", SPEED),
    # a speed the player picked in the mode overwritten on leaving
    (CMD, "math.abs(s - c.set) < 0.01", "true", SPEED),
    # a stopped battle started on entering
    (CMD, "S.command_speed ~= 1 and c.was and c.was > 0 then", "S.command_speed ~= 1 and c.was then", SPEED),
    # Normal still sets a speed
    (CMD, "not bm:is_multiplayer() and S.command_speed ~= 1 and", "not bm:is_multiplayer() and", SPEED),
    # one player slows a shared battle
    (CMD, "if not bm:is_multiplayer() and S.command_speed", "if S.command_speed", MP),
    # third person off leaves the mode on and the battle slow
    (MAIN, "try(function() E.command.stop() end)", "", OFF),
    # anyone commands; a hero refused; the setting ignored (the author, 2026-10-23: heroes too, any unit by MCT)
    (CMD, "if not (E.S.command_any_unit or u:is_commanding_unit() or u:unit_class() == \"com\") then", "if false then", LORD),
    (CMD, " or u:unit_class() == \"com\") then", ") then", LORD),
    (CMD, "E.S.command_any_unit or ", "", LORD),
    (SET, "get(\"command_any_unit\", false)", "get(\"command_any_unit\", true)", DEF),
    # refused without a word
    (CMD, "E.say(\"derpy_tp_command_general_and_heroes\") return", "return", LORD),
    # an armed ability left armed
    (CMD, "E.abilities.cancel() -- or its click would cast instead of order", "", ARMED),
    # the lock-on kept
    (CMD, "F.target = nil", "", LOCK),
    # its click locks on in the mode
    (MAIN, "LOCK_CLICK and not F.command then", "LOCK_CLICK then", LOCK),
    # the wheel's notches kept for leaving
    (MAIN, "if not F.command then zoom(dt) elseif P.wheel then P.wheel() end", "if not F.command then zoom(dt) end", LOCK),
    # the view never moves
    (RIG, "local want_cmd = E.F.command and S.command_distance > 0 and 1 or 0", "local want_cmd = 0", VIEW),
    # 0 m moves it anyway
    (RIG, "local want_cmd = E.F.command and S.command_distance > 0 and 1 or 0", "local want_cmd = E.F.command and 1 or 0", VIEW),
    # the look rises into the sky
    (RIG, "local p = math.max(R.pitch, CMD_LOOK_MIN)", "local p = R.pitch", VIEW),
    # entering keeps his pitch
    (RIG, "if E.S.command_distance > 0 then R.want_pitch = CMD_START end", "", VIEW),
    # his pitch not given back
    (RIG, "R.want_pitch, R.cmd_pitch = R.cmd_pitch, nil", "R.cmd_pitch = nil", VIEW),
    # first person kept in the mode
    (MAIN, "local head = E.first_person and not F.command and", "local head = E.first_person and", VIEW),
    # no crosshair to aim orders with
    (MAIN, "(F.ranged or F.armed ~= nil or F.command ~= nil)", "(F.ranged or F.armed ~= nil)", VIEW),
    # defaults
    (SET, "[get(\"command_speed\", \"quarter\")]", "[get(\"command_speed\", \"half\")]", DEF),
    (SET, "get(\"command_distance\", 20)", "get(\"command_distance\", 10)", DEF),
    (KEYS, "command = \"Q\", cmd_follow", "command = \"G\", cmd_follow", SPEED),
    # the keys never read in the mode
    (MAIN, "E.command.update(now, gnow, focused and F.command ~= nil, kf", "E.command.update(now, gnow, false, kf", GROUPS),
    # group_of: heroes, artillery, shooters
    (CMD, "if u:unit_class() == \"com\" then return 6 end", "", GROUPS),
    (CMD, "if u:is_artillery() then return 5 end", "", GROUPS),
    (CMD, "return u:missile_range() > 0 and 2 or 1", "return 1", GROUPS),
    # the card's category ignored, and each caste branch
    (CMD, "local caste = E.D.castes and E.D.castes[u:type()]", "local caste = nil", CASTE),
    (CMD, "if CAVALRY[caste] then return 3 end", "", CASTE),
    (CMD, "if MONSTERS[caste] then return 4 end", "", CASTE),
    # each getter fallback
    (CMD, "elseif u:is_cavalry() or u:is_chariot() then", "elseif u:is_chariot() then", GROUPS),
    (CMD, "or u:is_chariot() then return 3", "then return 3", GROUPS),
    (CMD, "elseif u:is_war_beasts() or u:is_war_machine() then", "elseif u:is_war_machine() then", GROUPS),
    (CMD, "or u:is_war_machine() then return 4", "then return 4", GROUPS),
    # the unit he plays picked
    (CMD, "if u:unique_ui_id() ~= mine and ", "if ", GROUPS),
    # no chevrons on the pick, or only at the next refresh
    (HUD, "picked[uid] or ", "", GROUPS),
    (HUD, "and pick == pick_was then return end", "then return end", GROUPS),
    # the click orders: the move, its run, its ping, the attack
    (CMD, "local run = P.held(S.keys.sprint)", "local run = false", CLICK),
    (CMD, "ping(x, y, z, 2, now)", "", CLICK),
    (CMD, "if not now or now >= p[4] then", "if not now then", CLICK),
    (CMD, "order(units, function(uc) uc:attack_unit(enemy, true, true) end, gnow)", "", CHARGE),
    # F3, and its targets
    (CMD, "if e then order({u}, function(uc) uc:attack_unit(e, true, true) end, gnow) end", "", CHARGE),
    (CMD, "not e:is_routing() and e:is_valid_target()", "not e:is_routing()", CHARGE),
    # F4: no halt, the shooters silent, the infantry too
    (CMD, "\tuc:halt()", "\t", HOLD), # the tab: F.uc:halt() is the vanilla style's stay-put halt
    (CMD, "s:fire_at_will(true)", "s:fire_at_will(false)", HOLD),
    (CMD, "if u:missile_range() > 0 then shooters[#shooters + 1] = u end", "shooters[#shooters + 1] = u", HOLD),
    # F1: never repeated, never ended by another order, never ended with third person
    (CMD, "if next(follow) and gnow >= follow_at then", "if false then", FOLLOW),
    (CMD, "if not following then follow[id] = nil end", "", FOLLOW),
    (CMD, "follow, waiting = {}, {}", "", FOLLOW),
    # the pings left on the field when third person ends
    (CMD, "unping(nil)", "", CLICK),
    # the routing filter
    (CMD, "u:number_of_men_alive() > 0 and not u:is_routing()", "u:number_of_men_alive() > 0", ROUT),
    # the gap: an order inside it sent (and dropped), the first waiting order kept, a waiting order never sent
    (CMD, "local wait = at > gnow", "local wait = false", GAP),
    (CMD, "waiting[u:unique_ui_id()] = wait and", "waiting[u:unique_ui_id()] = waiting[u:unique_ui_id()] or wait and", GAP),
    (CMD, "if gnow >= w.at then", "if false then", GAP),
    # one order split: the units clear of the gap sent at once; a newer order leaving the waiting one in place (final review)
    (CMD, "at = math.max(at, (sent[id] or -1e9) + ORDER_GAP)", "if (sent[id] or -1e9) + ORDER_GAP > gnow then waiting[id] = {fn = fn, at = sent[id] + ORDER_GAP, unit = u} list[#list] = nil end", WHOLE),
    (CMD, "unit = u} or nil end", "unit = u} or waiting[u:unique_ui_id()] end", WHOLE),
    # follow me takes back a unit the player ordered with the freed mouse (final review)
    (CMD, "if F.free_orders then for id, u in pairs(follow) do if E.selected(u) then follow[id] = nil end end end", "", FOLLOW_FREE),
    # the freed mouse: CA's orders never on, on outside the mode, his unit left selected, the click ordering on top
    (MAIN, "if free ~= (F.free_orders or false) then F.free_orders = free bm:disable_orders(not free) end", "", FREE),
    (MAIN, "local free = F.command ~= nil and (vanilla or not F.dragging)", "local free = vanilla or not F.dragging", FREE),
    (MAIN, "if free then if selected(unit) then bm:clear_selection() end", "if free then", FREE),
    (CMD, "P.pressed(S.keys.attack) and F.dragging", "P.pressed(S.keys.attack)", FREE),
]
