# Round 52 (2026-10-18): the camera's floor counts the terrain alone while third person is on. The floor (exe+2ebf734)
# lifts the eye over a raycast height that counts a roof (exe+2ee841c); its entry jumps to the terrain's (exe+2ec2710)
# (the author: "if its around a building, it would go way up").
MAIN, P = "script/derpy_tp/main.lua", "script/derpy_tp/platform.lua"
ON, LEFT, ALONE = ("the_camera_floor_counts_the_terrain_alone_while_on", "a_battle_left_with_the_terrain_floor_on_finds_it_off",
    "the_terrain_floor_is_left_alone_where_it_is_not_the_raycast")
WHILE = "the_camera_floor_is_lowered_only_while_on"
MUTANTS = [
    (P, "local rel = row.cam_terrain - row.cam_collide - 5", "local rel = row.cam_terrain - row.cam_collide", ON),
    (P, "t[#t + 1] = rel < 0 and 255 - b or b", "t[#t + 1] = b", ON),
    # not "u = u / 256": string.char rounds to nearest (fistp), and this jump's fractions all round back to its bytes
    (P, "for _ = 1, 4 do local b = u % 256", "for _ = 1, 3 do local b = u % 256", ON),
    (P, "if on then return mr.patch(floor_at, PROLOGUE, floor_jmp) ~= nil end",
        "if on then return mr.patch(floor_at, PROLOGUE, PROLOGUE) ~= nil end", ON),
    (P, "return mr.patch(floor_at, floor_jmp, PROLOGUE) ~= nil", "return true", ON),
    (P, "\tP.terrain_floor(false)\n", "\n", LEFT),
    (P, "local floor_at = row and row.cam_collide and mr.patch and at(base, row.cam_collide)",
        "local floor_at = mr.patch and at(base, 0x2ee841c)", ALONE),
    (P, "local PROLOGUE = string.char(0x48, 0x8b, 0xc4, 0x48, 0x89)", "local PROLOGUE = string.char(0x40, 0x53, 0x48, 0x83, 0xec)", ON),
    (MAIN, "F.floored = P.terrain_floor(true)", "F.floored = true", WHILE),
    (MAIN, "if F.floored then F.floored = nil try(function() P.terrain_floor(false) end) end", "F.floored = nil", WHILE),
]
