C = "script/derpy_tp/combat.lua"
M = "script/derpy_tp/main.lua"
U = "script/derpy_tp/hud.lua"
L = "script/derpy_tp/hud_layout.lua"
TURN, JUMP = "a_swing_lets_its_clip_turn_him", "an_action_faces_the_camera_and_keeps_it"
NOCHEER, TAUNT = "a_man_with_no_cheer_clip_has_no_cheer", "a_man_with_only_a_taunt_clip_taunts"
HIDE = "the_hide_button_sits_alone_in_the_top_right_corner"
LATE = "a_camera_that_reports_late_is_no_roof"
CAN = "F.can_cheer = any(1094) or any(1099) or any(1104) or any(1109)"
TOGGLE = "toggle = {sw - m - g.toggle[1] * s, m}}"
SHOWN = 'for _, s in ipairs({"frame", "icon", "keyplate", "key"}) do vis("hide_" .. s, true) vis("map_" .. s, true) end'
MUTANTS = [
    # a swing faces the camera as it starts, then its clip turns him; jump and charge attacks keep the camera's facing
    (C, "turns = hold ~= nil}", "turns = true}", JUMP),
    (C, "turns = hold ~= nil}", "turns = false}", TURN),
    (C, "\t\tif F.model then P.face(F.model, E.rig.yaw) end\n", "", TURN),
    (M, "if m and not (F.lock.turns and F.lock.seen) then", "if m then", TURN),
    # cheer only for a man with a CELEBRATE or TAUNT clip
    (M, CAN, "F.can_cheer = any(1094) or any(1099)", TAUNT),
    (M, CAN, "F.can_cheer = true", NOCHEER),
    (U, "cheer = F.can_cheer}", "cheer = true}", NOCHEER),
    # hide alone in the top-right corner, on its key
    (U, TOGGLE, "toggle = {sw - m - g.toggle[1] * s, sh - m}}", HIDE),
    (U, SHOWN, SHOWN.replace("true", "false"), HIDE),
    (L, '["hide_frame"] = {"toggle", 77, 0},', '["hide_frame"] = {"actions", 77, 0},', HIDE),
    (L, '["hide_keyplate"] = {"toggle", 75, 63},', '["hide_keyplate"] = {"toggle", 75, -30},', HIDE),
    # a lift is a roof's only above all three of the last asked eyes: the engine reports two frames late
    ("script/derpy_tp/rig.lua", "math.max(R.ey, R.ey1 or R.ey, R.ey2 or R.ey)", "math.max(R.ey, R.ey1 or R.ey)", LATE),
    ("script/derpy_tp/rig.lua", "math.max(R.ey, R.ey1 or R.ey, R.ey2 or R.ey)", "R.ey", LATE),
    ("script/derpy_tp/rig.lua", "\t\tR.ey2, R.ey1 = R.ey1, R.ey\n", "", LATE),
    ("script/derpy_tp/rig.lua", "R.ey2, R.ey1 = R.ey1, R.ey", "R.ey1 = R.ey", LATE),
]
