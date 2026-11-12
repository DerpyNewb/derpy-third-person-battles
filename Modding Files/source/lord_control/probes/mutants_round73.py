# Round 73 (2026-11-11): the AZERTY box, the lock-on's reach and aim, the block key, and nothing of ours over the engine's
# knock (docs/sessions/PATCH_NOTES_20261111_THIRD_PERSON.md). Each a plausible slip, not a typo.
SET = "script/derpy_tp/settings.lua"
CMB = "script/derpy_tp/combat.lua"
MAIN = "script/derpy_tp/main.lua"
MOVE = "script/derpy_tp/move.lua"
AZ = "settings_azerty_moves_the_defaults"
REACH = "locked_on_his_blow_reaches_further_and_follows_the_aim"
HELD = "a_held_block_defends_him_on_stamina"
TAP = "a_tapped_block_is_one_whole_clip"
WAIT = "a_block_shields_from_the_press_and_waits_for_a_swing"
ONLY = "only_a_single_entity_with_a_defend_clip_blocks"
KNOCK = "nothing_of_ours_plays_over_a_knock"
MUTANTS = [
    # AZERTY: a key left at its default not moved; a clash falling back to the QWERTY default; the box never read
    (SET, " or name == K.defaults[action] then name = default", " then name = default", AZ),
    (SET, "local fallback = default", "local fallback = K.defaults[action]", AZ),
    (SET, "local azerty = get(\"key_azerty\", false) == true", "local azerty = false", AZ),
    # the lock-on: no further reach; the body's facing, not the swing's aim
    (CMB, "local LOCK_REACH = 1.6", "local LOCK_REACH = 0", REACH),
    (CMB, "men_of(held, LOCK_REACH, aim and math.sin(aim), aim and math.cos(aim))", "men_of(held, LOCK_REACH)", REACH),
    # the block: over a swing under way; no drain; no shield before the clip's report; a new press under a quarter; the
    # rider's own defend forgotten; said every frame; a hit reaction in a defend's place; armed under it
    (CMB, "if able and (C.locked(now) or knocked(man)) then return end", "if able and knocked(man) then return end", WAIT),
    (CMB, "or F.block and -1 / BLOCK_DRAIN or 1 / STAMINA_FILL", "or 1 / STAMINA_FILL", HELD),
    (CMB, "slot = slot, guard = true, block = true}", "slot = slot, block = true}", WAIT),
    # held on below a quarter: the third clip of a full bar starts at 0.18 (HELD); a new press under it starts none (TAP)
    (CMB, "not F.blocked and F.stamina < STAMINA_AGAIN", "F.stamina < STAMINA_AGAIN", HELD),
    (CMB, "not F.blocked and F.stamina < STAMINA_AGAIN", "not F.blocked and F.stamina < 0", TAP),
    (CMB, "if body ~= man then\n\t\t\tslot = pick(man", "if false then\n\t\t\tslot = pick(man", ONLY),
    (CMB, "if pressed then E.say(\"derpy_tp_block_single\") end", "E.say(\"derpy_tp_block_single\")", ONLY),
    (CMB, "local slot = pick(body, {air and {504, 513} or {474, 483}})", "local slot = pick(body, {{474, 483}, {368, 377}})", ONLY),
    (MAIN, "if F.lock and not F.lock.block or F.swung", "if F.lock or F.swung", HELD),
    # the knock: the defend over it; the block, a click, the cheer, the jump, the sprint over it; the mount's knock not
    # read; knockbacks left out; a walk sent under it
    (CMB, "if knocked(man) then return false end -- a blow", "if false then return false end -- a blow", KNOCK),
    (CMB, "if able and (C.locked(now) or knocked(man)) then return end", "if able and C.locked(now) then return end", KNOCK),
    (CMB, "if C.locked(now) or knocked() then return end\n\t\tif clicked and", "if C.locked(now) then return end\n\t\tif clicked and", KNOCK),
    (CMB, "function C.cheer(now)\n\t\tif C.locked(now) or knocked() then", "function C.cheer(now)\n\t\tif C.locked(now) then", KNOCK),
    (CMB, "if C.locked(now) or knocked() or not F.can_jump", "if C.locked(now) or not F.can_jump", KNOCK),
    (CMB, "if knocked() then return end -- neither his CHARGE", "if false then return end -- neither his CHARGE", KNOCK),
    (CMB, " or mount ~= nil and knock(P.anim_slot(mount))", "", KNOCK),
    (CMB, "return s ~= nil and s >= 143 and s <= 197 end", "return s ~= nil and s >= 153 and s <= 197 end", KNOCK),
    (MOVE, "if E.combat.knocked(man) then F.man_hold, F.lead = nil, nil return end", "", KNOCK),
]
