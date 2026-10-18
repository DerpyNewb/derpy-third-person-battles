# Round 50 (2026-10-18): a shot under way is not re-aimed. The author: "theres a bug when moving the mouse and aiming for
# fire, it keeps repeating the aim animation and never firing" - the Necrofex Colossus, a new fire order every 0.6 s as
# the crosshair moved, his FIRE_LEVEL one 9.5 s clip letting the shot go 2.66 s in.
C = "script/derpy_tp/combat.lua"
OWN = "a_shot_under_way_is_not_re_aimed"
MUTANTS = [
    (C, "\t\tif F.fire_at and in_shot() then return end\n", "", OWN),
    (C, "or shooting(body and P.anim_slot(body))\n", "\n", OWN),
    (C, "if F.fire_at and in_shot() then return end", "if in_shot() then return end", "a_click_in_a_shooting_clip_still_orders_at_once"),
]
