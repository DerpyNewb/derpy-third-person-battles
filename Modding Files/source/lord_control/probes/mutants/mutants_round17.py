C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
MANY, FACE = "a_gun_with_many_spawns_fires_each_one", "an_action_faces_the_camera_and_keeps_it"
MUTANTS = [
    # one shot per FIRE_POS spawn, one shot of ammo and one bang for the clip
    (C, "shot.times = fires and fires[F.utype] or {", "shot.times = nil or {", MANY),
    (C, "launch(shot, shot.spawned == 1, ", "launch(shot, true, ", MANY),
    (C, "\t\tif not first then return end\n", "", MANY),
    (C, "now >= shot.from + shot.times[shot.spawned + 1]", "now >= shot.from + shot.times[1]", MANY),
    # an action faces the camera as it starts and keeps that facing
    (M, "if F.model and not (F.lock.turns and F.lock.seen) then P.face(F.model, F.lock.yaw) end", "", FACE),
    (M, "P.face(F.model, F.lock.yaw)", "P.face(F.model, E.rig.yaw)", FACE),
    (C, "till = now + (hold or LOCK_MAX), yaw = E.rig.yaw,", "till = now + (hold or LOCK_MAX), yaw = 0,", FACE),
]
