# Round 75 (2026-11-18): the fixes for the 11-12 to 11-18 Workshop reports (docs/sessions/THIRD_PERSON_BUGS_20261024.md,
# "Status on 2026-11-18"): CA's button state for a unit ability, the refusal hints, the label's target on the click, a
# unit's front on the crosshair, hidden army buttons, the click held for the swing gap, the clip that reaches, and the
# walk out of a swing. Each a plausible slip, not a typo.
HUD = "script/derpy_tp/hud.lua"
ABL = "script/derpy_tp/abilities.lua"
CMB = "script/derpy_tp/combat.lua"
GREY = "a_unit_ability_cas_button_greys_out_is_dimmed_and_not_cast"
SAYS = "a_refused_press_says_why_on_screen"
REFUSED = "a_cast_the_game_refuses_says_so_every_time"
STAYS = "a_click_with_nothing_to_hit_stays_armed"
LABEL = "the_click_casts_at_the_unit_the_label_names"
WIDE = "a_wide_unit_is_on_the_crosshair_when_its_flank_is"
HIDDEN = "a_hidden_army_button_gets_no_slot"
HELD = "a_click_inside_the_swing_gap_swings_as_it_ends"
DROPPED = "a_click_held_for_the_gap_can_go_unswung"
REACH = "a_swing_takes_a_clip_of_its_button_that_reaches"
WALK = "a_move_key_walks_out_once_the_blow_has_landed"
MUTANTS = [
    # a unit ability still judged by the engine: in the key's test, in the dim, in the read that feeds the dim
    (HUD, "if ok or e.army then return ok and can == true end", "if e.army then return ok and can == true end", GREY),
    (HUD, "if can == nil and not on_page[n].army then can = u:can_perform_special_ability(keys[n]) end",
     "if not on_page[n].army then can = u:can_perform_special_ability(keys[n]) end", GREY),
    (HUD, "if okc then able[n] = c == true else able[n] = nil end", "able[n] = nil", GREY),
    # the refusal's line left up with nothing armed; the cooldown named as "cannot"; the winds compared the wrong way
    (HUD, "if hint and now >= hint.till and not F.armed then H.target(nil) end", "", SAYS),
    (ABL, 'E.loc("derpy_tp_ui_ability_recharging", "Recharging")', "cannot_now()", SAYS),
    (ABL, "w and w < c and", "w and w > c and", "a_spell_the_winds_cannot_pay_for_says_so"),
    # the reason not shown: on a press, on a cast that needs no aim, on the game's refusal
    (ABL, "		if not key then\n			if said then E.hud.refuse(n, said) end\n", "		if not key then\n", SAYS),
    (ABL, "			why, said = A.cast(n)\n			if said then E.hud.refuse(n, said) end\n", "			why, said = A.cast(n)\n", REFUSED),
    (ABL, '" (" .. kind .. "): " .. tostring(err))\n			return "the game refused " .. key, cannot_now()',
     '" (" .. kind .. "): " .. tostring(err))\n			return nil', REFUSED),
    # nothing to land on disarms again
    (ABL, "if aim and F.armed == a then E.hud.refuse(a.n, said) return why end", "", STAYS),
    # the label's unit ignored; not handed to the cast; kept when no longer a target; kept out of reach
    (ABL, "		if pick and pick:number_of_men_alive() > 0", "		if false and pick and pick:number_of_men_alive() > 0", LABEL),
    (ABL, "A.cast(a.n, a.over, a.unit)", "A.cast(a.n, a.over)", LABEL),
    (ABL, "(enemy and pick:is_valid_target() or not enemy and not pick:is_routing())", "true", LABEL),
    (ABL, "<= range * range then return pick end", "<= 1e12 then return pick end", LABEL),
    # the centre alone again; half its front ignored; a tie between two fronts left to the order they come in
    (ABL, "local e, d = math.max(m - half_width(u), 0) / t, m / t", "local e, d = m / t, m / t", WIDE),
    (ABL, "math.min(w / 2, MAX_HALF)", "math.min(w / 2, 0)", WIDE),
    (ABL, "(not best_e or e < best_e or e == best_e and d < best_d)", "(not best_e or e < best_e)", WIDE),
    # a hidden button listed; the bar not rebuilt when CA's shows or hides one
    (HUD, "			if c:Visible() then ids[#ids + 1] = c:Id() end", "			ids[#ids + 1] = c:Id()", HIDDEN),
    (HUD, "if okn and list_n and n ~= list_n or shown ~= army_shown_ids then", "if okn and list_n and n ~= list_n then", HIDDEN),
    # the click in the gap not held; held forever past a knock; kept through arming an ability
    (CMB, "if now < F.next_swing then F.held_click = {primary} return end", "if now < F.next_swing then return end", HELD),
    (CMB, "local HELD_LATE = 0.5", "local HELD_LATE = 1e9", DROPPED),
    (CMB, "F.native_attack, F.held_click = nil, nil", "F.native_attack = nil", DROPPED),
    # a click through his swing not held; held through a cheer or jump too; a jump marked as a swing; the click through a
    # swing not handed on from the left button
    (CMB, "			if F.lock and F.lock.swing then F.held_click = {primary} end\n", "", "a_click_during_his_swing_swings_after_it"),
    (CMB, "if F.lock and F.lock.swing then F.held_click", "if F.lock then F.held_click", "a_click_during_his_swing_swings_after_it"),
    (CMB, "if clicked and not F.ranged then C.melee(now, true) end -- held", "if false then C.melee(now, true) end -- held",
     "a_click_during_his_swing_swings_after_it"),
    # the click held through the swing kept by the walk out
    (CMB, "if walked then F.swung, F.held_click = nil, nil end", "if walked then F.swung = nil end", WALK),
    # the clip that reaches not looked for; looked for past the turn's own clip only
    (CMB, "if victim(mount or first, s) then slot = s break end", "if false then slot = s break end", REACH),
    (CMB, "for j = 0, #has - 1 do", "for j = 1, #has - 1 do", REACH),
    # the walk out: before the blow lands; with no move key; with the key held from before the swing; never marked as a
    # struck swing; his clip's turn kept, so he stays armed for the engine's own swing
    (CMB, " and not F.blow and P.blow(L.m) == nil", " and not F.blow", WALK),
    (CMB, "L.still and L.seen and F.moving and not F.strike", "L.still and L.seen and not F.strike", WALK),
    (CMB, "local walked = L.strikes and L.still and", "local walked = L.strikes and", WALK),
    (CMB, "F.strike, F.lock.strikes = {m = carrier, slot = played, till = give_up or 0}, true",
     "F.strike = {m = carrier, slot = played, till = give_up or 0}", WALK),
    (CMB, "if walked then F.swung, F.held_click = nil, nil end", "if walked then F.held_click = nil end", WALK),
]
