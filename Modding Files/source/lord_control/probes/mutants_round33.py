P = "script/derpy_tp/platform.lua"
M = "script/derpy_tp/main.lua"
FRAG = "the_man_played_alone_points_at_a_fragment_with_no_attack_clips"
PUSH = "his_own_swing_is_pushed_on_his_own_fragment"
OWN = "the_man_played_alone_has_no_swing_but_his_own"
MUTANTS = [
    # the platform: the copy and what reads it
    (P, "\t\tif is_attack(slot) then unpoint(m) end", "", PUSH),
    (P, "\t\tif is_attack(slot) then unpoint(m) end", "\t\tunpoint(m)", PUSH),
    (P, "or s >= 1901 and s <= 1950 end", "end", FRAG),
    (P, "or s >= 484 and s <= 500 or", "or", FRAG),
    (P, "s >= 454 and s <= 463 or", "s >= 454 and s <= 460 or", FRAG),
    (P, "\t\tanim = orig_of[mr.tostring(anim)] or anim", "", FRAG),
    (P, "\t\tif body then point(body) end\n", "", FRAG),
    (P, "\t\tif body then unpoint(body) end\n", "", FRAG),
    (P, "if mr.is_null(a) or orig_of[mr.tostring(a)] then return end", "if mr.is_null(a) then return end", FRAG),
    (P, "local c = copy_of[key]\n", "local c = nil\n", FRAG),
    (P, "for off = 0, FRAG_COPY - 8, 8 do", "for off = 0x50, FRAG_COPY - 8, 8 do", FRAG),
    (P, "local FRAG, FRAG_COPY = 0x308, 0x50 + 6004 * 2", "local FRAG, FRAG_COPY = 0x308, 0x50 + 1904 * 2", FRAG),
    (P, "mr.uint16(0xffff)) end end", "mr.uint16(0)) end end", FRAG),
    (P, "function P.disarm(m) -- the horse's swings and the rider's\n\t\tif not P.features.steer then return end",
     "function P.disarm(m) -- the horse's swings and the rider's", "no_fragment_is_touched_on_another_build"),
    # main: when he is disarmed, and given back
    (M, "if F.lock or F.swung or F.native_attack or F.pending then", "if F.swung or F.native_attack or F.pending then", OWN),
    (M, "if F.lock or F.swung or F.native_attack or F.pending then", "if F.lock or F.native_attack or F.pending then", OWN),
    (M, "if F.lock or F.swung or F.native_attack or F.pending then", "if F.lock or F.swung or F.pending then", "a_single_entitys_attack_order_arms_him"),
    (M, "local man = F.model or single\n", "local man = F.model\n", "a_single_entitys_attack_order_arms_him"),
    (M, "if F.disarmed then try(function() if P.alive(F.unit, F.disarmed) then P.arm(F.disarmed) end end) F.disarmed = nil end",
     "", OWN),
    (M, "if P.alive(F.unit, F.disarmed) then P.arm(F.disarmed) end", "P.arm(F.disarmed)",
     "the_next_man_is_disarmed_and_the_dead_left_alone"),
    (M, "\t\t\t\tF.disarmed = man\n", "", OWN),
]
