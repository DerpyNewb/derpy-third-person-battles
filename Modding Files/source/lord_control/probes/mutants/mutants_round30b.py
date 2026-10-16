C = "script/derpy_tp/combat.lua"
INTO, NONE = "the_raise_goes_into_its_aim_before_the_fire", "a_man_with_no_aim_clip_goes_from_the_raise_into_the_fire"
CUT, STEP = "an_aim_cut_short_still_fires", "a_step_does_not_cut_the_aim_hold"
LEARN = "a_raise_of_no_known_length_goes_into_its_aim_too"
TIMED = """				shot.raise_end = shot.at + len
				if shot.hold_slot then play_phase(shot, "hold", shot.hold_slot, now) else play_phase(shot, "fire", shot.fire_slot, now) end"""
LEARNED = """				aim_len[F.utype .. shot.aim_slot] = aim_len[F.utype .. shot.aim_slot] or now - shot.at
				if shot.hold_slot then play_phase(shot, "hold", shot.hold_slot, now) else play_phase(shot, "fire", shot.fire_slot, now) end"""
# Round 30b (2026-10-16): the pair's AIM clip between the raise and the fire (the Streltsi's raise ends ~20 deg up)
MUTANTS = [
    (C, "level = {1554, 1557, 1548}", "level = {1554, 1557, 1547}", INTO),
    (C, "shot.hold_slot = P.has_slot(F.model, PAIRS[pair][3]) and PAIRS[pair][3] or nil", "shot.hold_slot = PAIRS[pair][3]", NONE),
    (C, "local AIM_HOLD = 0.2", "local AIM_HOLD = 0", INTO),
    (C, "if shot.phase == \"hold\" and shot.started and clip == shot.slot and now >= shot.at + AIM_HOLD then", "if false then", INTO),
    (C, "\t\t\tif shot.phase == \"hold\" then play_phase(shot, \"fire\", shot.fire_slot, now) return end\n", "", CUT),
    (C, TIMED, TIMED.replace('if shot.hold_slot then play_phase(shot, "hold", shot.hold_slot, now) else play_phase(shot, "fire", shot.fire_slot, now) end', 'play_phase(shot, "fire", shot.fire_slot, now)'), INTO),
    (C, LEARNED, LEARNED.replace('if shot.hold_slot then play_phase(shot, "hold", shot.hold_slot, now) else play_phase(shot, "fire", shot.fire_slot, now) end', 'play_phase(shot, "fire", shot.fire_slot, now)'), LEARN),
    (C, 'if not shot or (step and shot.phase ~= "reload") then return end', 'if not shot or (step and shot.phase ~= "reload" and shot.phase ~= "hold") then return end', STEP),
]
