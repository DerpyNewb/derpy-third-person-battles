L = "script/derpy_tp/platform.lua"
OUT, NEVER, MOUNT, JUNK = ("men_check_refuses_a_marker_outside_the_exe", "men_check_accepts_men_never_ordered",
    "men_check_accepts_a_lord_on_a_mount", "men_check_refuses_steering_that_is_not_steering")
IMG = 'if s < lo or s >= hi then'
MUTANTS = [
    (L, IMG, 'if false then', "men_check_refuses_any_man_whose_marker_is_outside_the_exe"),
    (L, "local s = mr.tostring(mr.read_pointer(m, 0))", "local s = mr.tostring(mr.read_pointer(ms[1], 0))",
     "men_check_refuses_any_man_whose_marker_is_outside_the_exe"),
    ("script/derpy_tp/main.lua", "and not unit:is_war_machine()\n", "\n", "a_war_machine_is_played_whole"),
    (L, IMG, 'if false then', OUT),
    (L, IMG, 'if s < lo then', OUT),
    (L, IMG, 'if s >= hi then', OUT),
    (L, "if (tx ~= 0 or tz ~= 0) and (", "if (", NEVER),
    (L, "if (tx ~= 0 or tz ~= 0) and", "if (tx ~= 0 and tz ~= 0) and", JUNK),
    (L, "local STEER = {{0x1e0, 0x1e8}, {0x194, 0x198}}", "local STEER = {{0x1e0, 0x1e8}, {0x194, 0x198}, {0x368, 0x370}}",
     MOUNT),
    (L, "(tx ~= tx or tz ~= tz or (tx", "((tx", JUNK),
    (L, "^ 2 > 90000) then return false, \"a steering", "^ 2 > 9e9) then return false, \"a steering", JUNK),
]
