# Round 53 (2026-10-19): a unit of one cannot be hurt through his jump, his charge attack, or a block or hit reaction
# the engine plays on him or his mount (the author: "no invisibility frames"; asked, those three, units of one only).
C, MAIN = "script/derpy_tp/combat.lua", "script/derpy_tp/main.lua"
JUMP, CHARGE = "a_unit_of_one_cannot_be_hurt_through_his_jump", "a_unit_of_one_cannot_be_hurt_through_his_charge_attack"
REEL, MOUNT = "a_unit_of_one_cannot_be_hurt_while_he_blocks_or_reels", "a_mounted_unit_of_one_cannot_be_hurt_while_his_mount_reels"
SWING, REGIMENT = "a_swing_or_a_cheer_gives_no_invincibility", "one_man_of_a_regiment_has_no_invincibility"
THEIRS, BACK = "an_invincibility_the_battle_gave_him_is_left_alone", "handing_him_back_mid_jump_ends_his_invincibility"
MUTANTS = [
    (C, "if F.lock then F.lock.guard = true end", "if F.lock then F.lock.guard = false end", JUMP),
    (C, "F.lock.runs, F.lock.guard = true, true", "F.lock.runs = true", CHARGE),
    # each range's edge, one way or the other
    (C, "s >= 368 and s <= 387", "s >= 367 and s <= 387", REEL),
    (C, "s >= 368 and s <= 387", "s >= 368 and s <= 386", REEL),
    (C, "s >= 474 and s <= 483", "s >= 474 and s <= 484", REEL),
    (C, "s >= 504 and s <= 513", "s >= 505 and s <= 513", REEL),
    (C, "s >= 1217 and s <= 1246", "s >= 1217 and s <= 1247", REEL),
    (C, "s >= 1921 and s <= 1930", "s >= 1920 and s <= 1930", REEL),
    (C, "s >= 1951 and s <= 1960", "s >= 1951 and s <= 1959", REEL),
    (C, "s >= 2202 and s <= 2221", "s >= 2202 and s <= 2222", REEL),
    (C, " or mount and reeling(P.anim_slot(mount))) or false", ") or false", MOUNT),
    (C, "F.lock and F.lock.guard or reeling", "F.lock and true or reeling", SWING),
    (MAIN, "E.combat.invincible(single)", "E.combat.invincible(F.model or single)", REGIMENT),
    (C, "if want == (F.invincible or false) or want and F.unit:is_invulnerable() then return end",
        "if want == (F.invincible or false) then return end", THEIRS),
    (C, "if want == (F.invincible or false) or want", "if want == (F.invincible or false) or not want or want", JUMP),
    (C, "\t\tF.uc:set_invincible(want)\n\t\tF.uc:release_control()\n", "\t\tF.uc:set_invincible(want)\n", JUMP),
    (C, "F.invincible = want or nil", "F.invincible = nil", JUMP),
    (MAIN, "if F.invincible then F.invincible = nil try(function() F.uc:set_invincible(false) F.uc:release_control() end) end",
        "F.invincible = nil", BACK),
    (MAIN, "F.uc:set_invincible(false) F.uc:release_control() end) end", "F.uc:set_invincible(false) end) end", BACK),
]
