# Round 77 (2026-11-25): the splash and the reaction-cut fixes (combat.lua C.splash and C.locked, main.lua M.stop;
# docs/sessions/THIRD_PERSON_BUGS_20261024.md, the 11-23 and 11-25 reports). Each a plausible slip, not a typo.
COMBAT = "script/derpy_tp/combat.lua"
MAIN = "script/derpy_tp/main.lua"
SPLASH = "one_mans_clip_splashes_only_where_his_weapon_does"
CUT = "a_swing_cut_by_a_reaction_before_its_blow_swings_again_once"
NOT = "a_swing_whose_blow_landed_or_found_nobody_is_not_swung_again"
MUTANTS = [
    # the splash: never switched; switched off for a weapon with one too; off for a regiment; posted for nobody;
    # sent every frame; left off at F2
    (MAIN, "E.combat.splash()", "", SPLASH),
    (COMBAT, "and not (E.D.splashers and E.D.splashers[F.utype])", "", SPLASH),
    (COMBAT, "local want = strikes() and not", "local want = not", SPLASH),
    (COMBAT, "P.nosplash(want, F.model or F.single)", "P.nosplash(want, nil)", SPLASH),
    (COMBAT, "if want == (F.nosplash == true) then return end", "", SPLASH),
    (MAIN, "if F.nosplash then F.nosplash = nil try(function() P.nosplash(false) end) end", "", SPLASH),
    # the cut: never swung again; swung again for ever; after a landed blow; after a whiff; on any clip after it;
    # the armed blow left on him
    (COMBAT, "F.next_swing, F.held_click, F.retry = now, {L.primary}, true", "F.retry = true", CUT),
    (COMBAT, "and not L.landed and not L.retried and strikes() then", "and not L.landed and strikes() then", CUT),
    (COMBAT, "if P.blow(L.m) ~= nil then L.armed = true elseif L.armed then L.landed = true end", "if P.blow(L.m) ~= nil then L.armed = true end", NOT),
    (COMBAT, "if F.lock and F.lock.m == s.m then F.lock.landed = true end", "", NOT),
    (COMBAT, "slot ~= L.slot and reeling(slot) and not L.landed", "slot ~= L.slot and not L.landed", NOT),
    (COMBAT, "if L.armed and P.blow(L.m) ~= nil then P.unblow(L.m) end", "", CUT),
    (COMBAT, "retried = attack and F.retry or nil}", "retried = nil}", CUT),
]
