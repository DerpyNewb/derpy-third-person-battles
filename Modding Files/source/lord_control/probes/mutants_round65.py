# Round 65 (2026-10-24): the author, "cannot zoom out or in in command mode, make the zooming more smooth". The zoom eases
# to where the wheel or keys put it, and command mode zooms its own view.
RIG = "script/derpy_tp/rig.lua"
MAIN = "script/derpy_tp/main.lua"
EASE = "a_wheel_notch_eases_the_zoom_in"
CMD = "the_wheel_zooms_command_modes_view"
FP = "zooming_in_command_mode_leaves_his_own_view_as_it_was"
MUTANTS = [
    # the jump again
    (RIG, "R.zoom = R.zoom + (R.want_zoom - R.zoom) * ease", "R.zoom = R.want_zoom", EASE),
    # the command view at its MCT distance whatever the wheel
    (RIG, "local d = S.command_distance * R.cmd_zoom", "local d = S.command_distance", CMD),
    (RIG, "R.cmd_zoom = R.cmd_zoom + (R.want_cmd_zoom - R.cmd_zoom) * ease", "", CMD),
    # the wheel in command mode zooms his third-person view instead
    (RIG, "if E.F.command and E.S.command_distance > 0 then", "if false then", CMD),
    # the wheel dropped in command mode, as before
    (MAIN, "\t\t\tzoom(dt)\n", "\t\t\tif not F.command then zoom(dt) end\n", CMD),
    # command mode's zoom turning him first person
    (MAIN, "if F.command then return end -- command mode's own view", "-- command mode's own view", FP),
]
