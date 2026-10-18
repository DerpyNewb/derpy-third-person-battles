# Round 47 (2026-10-18): a flyer on his own wings swings his air attacks. Read live: Be'lakor flying, no mount, ATTACK_1-5
# and FLY_ATTACK_1-4; the swing took FLY_ATTACK only for a mount, so he played 454 and 458 in the air (the author:
# "flying units when using melee uses ground melee attacks e.g belakor"). No jump attack in the air: a ground clip.
C = "script/derpy_tp/combat.lua"
OWN = "a_flyer_with_no_mount_swings_his_air_attacks"
MUTANTS = [
    (C, "\t\tlocal flyer = mount or first\n", "\t\tlocal flyer = mount\n", OWN),
    (C, "\t\t\t\tP.play(m, slot + 40, mask) return m, slot + 40 -- FLY_ATTACK_n, as a mount's\n", "", OWN),
    (C, "if F.unit:is_currently_flying() and slot >= 454 and slot <= 460 and P.has_slot(m, slot + 40) then",
        "if slot >= 454 and slot <= 460 and P.has_slot(m, slot + 40) then", OWN),
    (C, "if air and #has == 0 then for s = 454, 460 do if P.has_slot(flyer, s + 40)", "if false then for s = 454, 460 do if P.has_slot(flyer, s + 40)", OWN),
    (C, "\t\t\tor F.unit:is_currently_flying() then return end", "\t\t\tthen return end", OWN),
]
