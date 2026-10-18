# Round 46 (2026-10-18): a unit of one steered alone fights as one man does. Measured live (probes/zz_tp_one_timeline.lua):
# in a lasting melee the engine orders the Mutalith's melee attack again every tick and the guard stops it, and a queued
# clip loses to that order - his jump and four swings in 11 s, none played, while the pending swing kept him armed; the
# gate in, all six played (the author: "mutalith is spamming the melee button, its like the actions are queued or still
# auto attacking"). Standing with the camera 60 deg off his facing, Harald's swing took the turn order a unit walked by
# orders needs and never played; and the lock read the turn order's wait (no clip yet, nil == nil) as reported, so it ended
# as the clip was sent and the next click or the sprint's charge clip cut it ("pressing charge attack as well repeats the
# charge animation randomly").
C = "script/derpy_tp/combat.lua"
MAIN = "script/derpy_tp/main.lua"
GATE = "the_gate_is_in_while_a_unit_of_one_is_steered_alone"
FACE = "a_unit_of_one_swings_where_the_camera_looks_with_no_turn_order"
LOCK = "a_swing_after_a_turn_order_keeps_its_lock_until_its_clip_plays"
MUTANTS = [
    (MAIN, "\t\tif F.model or F.single_steer then\n\t\t\tF.gated = P.gate(true)", "\t\tif F.model then\n\t\t\tF.gated = P.gate(true)", GATE),
    (MAIN, "\t\tif F.model or F.single_steer then\n\t\t\tF.gated = P.gate(true)", "\t\tif true then\n\t\t\tF.gated = P.gate(true)", GATE),
    (C, "if off > TURN_DEG and not (F.model or F.single) then", "if off > TURN_DEG and not F.model then", FACE),
    (MAIN, "\t\t\t\tlocal m = F.model or F.single\n", "\t\t\t\tlocal m = F.model\n", FACE),
    (C, "if L.m and slot == L.slot then L.seen = true end", "if slot == L.slot then L.seen = true end", LOCK),
]
