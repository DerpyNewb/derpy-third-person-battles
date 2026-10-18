P = "script/derpy_tp/platform.lua"
M = "script/derpy_tp/main.lua"
ON = "a_queued_swing_beats_the_ticks_order"
LEFT = "a_battle_left_with_the_gate_on_finds_it_off"
ALONE = "the_gate_is_left_alone_where_it_is_not_the_gate"
PLAYED = "the_gate_is_in_while_a_man_is_played_alone"
MUTANTS = [
    # the patch itself
    (P, "local reset, update = gate_bytes(0x5c), gate_bytes(0x52)", "local reset, update = gate_bytes(0x5c), gate_bytes(0x50)", ON),
    (P, "if on then return mr.patch(gate, reset, update) ~= nil end", "if on then return mr.patch(gate, update, reset) ~= nil end", ON),
    (P, "\t\treturn mr.patch(gate, update, reset) ~= nil\n", "\t\treturn true\n", ON),
    (P, "if on then return mr.patch(gate, reset, update) ~= nil end", "if on then mr.patch(gate, reset, update) return true end", ALONE),
    (P, "0x44, 0x38, 0xbf, 0xf8, 0x06, 0, 0, 0x75, 0x09,", "0x44, 0x38, 0xbf, 0xf8, 0x06, 0, 0, 0x75, 0x0a,", ON),
    (P, "melee = 0x3ad24b8, queued_gate = 0x3087378,", "melee = 0x3ad24b8, queued_gate = 0x3087379,", ON),
    (P, "local gate = row and row.queued_gate and mr.patch and at(base, row.queued_gate)",
     "local gate = mr.patch and at(base, 0x3087378)", ALONE),
    # put back as it loads
    (P, "\tP.gate(false) -- a battle left while it was in (no stop) left it in\n", "", LEFT),
    # in while one man is played, out at the stop
    (M, "\t\t\tF.gated = P.gate(true)\n", "\t\t\tF.gated = true\n", PLAYED),
    (M, "\t\tif F.model or F.single_steer then\n\t\t\tF.gated = P.gate(true)", "\t\tif true then\n\t\t\tF.gated = P.gate(true)", PLAYED),
    (M, "if F.gated then F.gated = nil try(function() P.gate(false) end) end", "", PLAYED),
]
