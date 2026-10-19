# Round 56 (2026-10-19): the "fix all" set - one man kept from his regiment's volleys (his shot clips blanked too),
# the attack clips halved between the buttons (ATTACK_1-10, on the mount that carries them), the HUD whole again with
# each session and when a late card comes, and a blow on a unit of one standing idle playing his defend.
PLAT = "script/derpy_tp/platform.lua"
MAIN = "script/derpy_tp/main.lua"
COMBAT = "script/derpy_tp/combat.lua"
HUD = "script/derpy_tp/hud.lua"
FRAG = "one_man_points_at_a_fragment_with_no_shot_clips_either"
VOLLEY = "one_man_is_kept_from_his_regiments_volleys_and_armed_for_his_own_shot"
BOTH = "both_buttons_together_reach_every_attack_clip_he_has"
RANGED = "a_ranged_units_left_button_has_every_attack_clip"
MOUNTED = "mounted_swings_use_rider_slots"
ROTATE = "a_swing_rotates_only_through_the_clips_he_has"
NEXT = "the_hud_comes_back_whole_with_the_next_session"
LATE = "a_new_form_taken_before_its_card_gets_its_hud_when_the_card_comes"
DEFEND = "a_blow_on_a_unit_of_one_standing_idle_plays_his_defend"
MUTANTS = [
    # shot clips no longer blanked on one man's copy
    (PLAT, "if is_attack(s) or shots and is_shot(s) then mr.write", "if is_attack(s) then mr.write", FRAG),
    # one copy for both kinds: the shot-blanked copy served to a unit of one, or the reverse
    (PLAT, "local key = mr.tostring(a) .. (shots and \"+shots\" or \"\")", "local key = mr.tostring(a)", FRAG),
    # never moved off a copy of the other kind
    (PLAT, "if shots_of[on] == shots then return end", "return", FRAG),
    # his own shot played on the blanked copy
    (PLAT, "if is_attack(slot) or is_shot(slot) then unpoint(m) end", "if is_attack(slot) then unpoint(m) end", FRAG),
    # one man disarmed as a unit of one: his regiment's volleys still play on him
    (MAIN, "P.disarm(man, F.model ~= nil)", "P.disarm(man, false)", VOLLEY),
    # not armed for his own shot
    (MAIN, "or F.native_attack or F.pending or F.shot then P.arm(man)", "or F.native_attack or F.pending then P.arm(man)", VOLLEY),
    # the old split back: four a button whatever he has
    (COMBAT, "if (i <= half) == (primary == true) or #has == 1", "if (i <= 4) == (primary == true) or #has == 1", BOTH),
    # ATTACK_8-10 dropped from the list
    (COMBAT, "local SLOTS_ATTACK = {454, 455, 456, 457, 458, 459, 460, 461, 462, 463}",
        "local SLOTS_ATTACK = {454, 455, 456, 457, 458, 459, 460}", BOTH),
    # a ranged unit's clips halved again, its right button being its mode
    (COMBAT, "local half, mine = E.can_shoot() and #has or math.ceil(#has / 2), {}",
        "local half, mine = math.ceil(#has / 2), {}", RANGED),
    # out of ammo, still all on the left
    (COMBAT, "local half, mine = E.can_shoot() and #has or math.ceil(#has / 2), {}",
        "local half, mine = (E.can_shoot() or F.unit:missile_range() > 0) and #has or math.ceil(#has / 2), {}", RANGED),
    # one counter for both buttons
    (COMBAT, "has, key = mine, primary and \"attack_left\" or \"attack_right\"", "has = mine", BOTH),
    # the mount's own clips no longer give the list
    (COMBAT, "if P.has_slot(mount, s) then body = mount break end", "if false then body = mount break end", MOUNTED),
    # the next session keeps the HUD off
    (HUD, "\t\tif on then off, errors = false, 0 end\n", "", NEXT),
    # the late card never looked for
    (HUD, "if card and card:GetContextObjectId(\"CcoBattleUnit\") then H.show(true) end", "", LATE),
    # no defend on a blow
    (COMBAT, "and not (F.lock or F.swung or F.pending or F.shot or F.firing or F.native_attack) and react(man) then",
        "and not (F.lock or F.swung or F.pending or F.shot or F.firing or F.native_attack) and false then", DEFEND),
    # a defend for every blow
    (COMBAT, "\t\t\t\tF.next_react = now + REACT_GAP\n", "", DEFEND),
    # the same defend every time
    (COMBAT, "\t\t\t\tturn.react = k + 1\n", "", DEFEND),
    # a defend under his own swing
    (COMBAT, "and not (F.lock or F.swung or F.pending or F.shot or F.firing or F.native_attack) and react(man)",
        "and react(man)", DEFEND),
    # a defend while he walks
    (MAIN, "E.combat.invincible(single, gnow, kf == 0 and kr == 0)", "E.combat.invincible(single, gnow, true)", DEFEND),
    # not held whole
    (COMBAT, "return P.play(body, has[k % #has + 1], 6)", "return P.play(body, has[k % #has + 1])", DEFEND),
    # one man of a regiment reacts too
    (MAIN, "E.combat.invincible(single, gnow, kf == 0 and kr == 0)", "E.combat.invincible(single or F.model, gnow, kf == 0 and kr == 0)", DEFEND),
]
