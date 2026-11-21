# Round 76 (2026-11-21): the trample fix (move.lua single_order; docs/sessions/THIRD_PERSON_BUGS_20261024.md, the 11-20
# collision report). A unit of one walked on the keys keeps CA's move order on the unit. Each a plausible slip, not a typo.
MOVE = "script/derpy_tp/move.lua"
MAIN = "script/derpy_tp/main.lua"
KEEPS = "a_unit_of_one_walking_keeps_a_move_order_so_it_does_not_trample"
SPRINT = "a_sprint_carries_no_move_order_and_its_charge_is_not_dropped"
NOCHARGE = "a_sprint_with_no_charge_keeps_our_order_to_halt"
DROPPED = "a_dropped_move_order_is_sent_again"
F2 = "f2_off_halts_a_unit_of_ones_move_order"
FLY = "a_unit_of_one_flying_gets_no_move_order"
ONE_MAN = "one_man_of_a_regiment_gets_no_move_order"
MUTANTS = [
    # the order never sent; sent for one man of a regiment too
    (MOVE, "		if F.single then single_order(now, dx, dz, run) end\n", "", KEEPS),
    (MOVE, "		if F.single then single_order(now, dx, dz, run) end", "		if F.single or F.model then F.single = F.single or F.model single_order(now, dx, dz, run) end", ONE_MAN),
    # sent every frame; never re-sent on a turn; never re-sent at the walk; its point at his feet
    (MOVE, "		if o and run == o.run and dx * o.dx", "		if false and run == o.run and dx * o.dx", KEEPS),
    (MOVE, "dx * o.dx + dz * o.dz >= math.cos(math.rad(ORDER_DEG))", "true", KEEPS),
    (MOVE, "		if o and run == o.run and", "		if o and", KEEPS),
    (MOVE, "local tx, tz = x + dx * ORDER_LEAD, z + dz * ORDER_LEAD", "local tx, tz = x, z", KEEPS),
    # not halted at the release. (Not cleared after its halt is an equivalent mutant: the halt moves the ordered
    # position off our point and the next frame's check forgets it, so it was dropped from the round.)
    (MOVE, "			if o then\n				F.uc:halt()\n				F.uc:release_control()\n				F.order, F.last_order = nil, now\n			end\n",
     "", KEEPS),
    # not spaced from the last order
    (MOVE, "		if now - (F.last_order or -1e9) < STEER_GAP then return end\n		if dx == 0 and dz == 0 then", "		if dx == 0 and dz == 0 then", DROPPED),
    (MOVE, "F.order, F.last_order = {x = tx, z = tz, dx = dx, dz = dz, run = run}, now", "F.order = {x = tx, z = tz, dx = dx, dz = dz, run = run}", SPRINT),
    # sent under the sprint; forgotten at the sprint (the slip caught writing these tests)
    (MOVE, "		if F.sprinting or F.charge_order or", "		if F.charge_order or", NOCHARGE),
    (MOVE, "		if F.sprinting or F.charge_order or F.native_attack or F.firing or F.move_fire or F.queued then return end",
     "		if F.sprinting or F.charge_order or F.native_attack or F.firing or F.move_fire or F.queued then F.order = nil return end", NOCHARGE),
    # a replaced order never noticed: not re-sent when dropped, halted over the charge that replaced it
    (MOVE, "> TOOK * TOOK then F.order, o = nil, nil end", "> 1e12 then F.order, o = nil, nil end", DROPPED),
    (MOVE, "> TOOK * TOOK then F.order, o = nil, nil end", "> 1e12 then F.order, o = nil, nil end", SPRINT),
    # sent in the air
    (MOVE, "		if F.unit:is_currently_flying() then return end\n		local m = P.mount(F.single)", "		local m = P.mount(F.single)", FLY),
    # not halted at F2
    (MOVE, "		if F.order then\n			F.order = nil\n			F.uc:halt()\n			F.uc:release_control()\n		end\n", "", F2),
]
