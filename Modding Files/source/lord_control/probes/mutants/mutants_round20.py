M = "script/derpy_tp/main.lua"
V = "script/derpy_tp/move.lua"
F2, SHIFT = "f2_takes_the_unit_the_game_has_selected", "shift_clicking_another_unit_drops_it_again"
DROP, ONE = "a_walk_order_the_engine_dropped_is_sent_again", "walking_orders_a_single_entity"
LOST = "or (o:get_x() - F.gx) ^ 2 + (o:get_z() - F.gz) ^ 2 > TOOK * TOOK)"
MUTANTS = [
    # F2 takes the unit the game says is selected, not one a callback set remembers
    (M, "return ok and s == true", "return ok", F2),
    (M, 'pcall(common.get_context_value, "CcoBattleUnit", tostring(u:unique_ui_id()), "IsSelected")',
     'pcall(common.get_context_value, "CcoBattleUnit", u:unique_ui_id(), "IsSelected")', F2),
    (M, "if one and selected(u) then return u end", "if one and u:is_commanding_unit() then return u end", F2),
    # in play, his unit is put back when the game's selection is anything else
    (M, "if bm:num_units_selected() ~= 1 or not selected(unit) then", "if bm:num_units_selected() ~= 1 then", F2),
    (M, "if bm:num_units_selected() ~= 1 or not selected(unit) then", "if not selected(unit) then", SHIFT),
    # a walk order the engine dropped is sent again, no sooner than STEER_GAP, and only when dropped
    (V, LOST, ")", DROP),
    (V, "local TOOK = 2 ", "local TOOK = 1e9 ", DROP),
    (V, "> TOOK * TOOK)", "< TOOK * TOOK)", ONE),
    (V, "local o = F.unit:ordered_position()", "local o = F.unit:position()", ONE),
    (V, "local need = now - (F.last_order or -1e9) >= STEER_GAP and (",
     "local need = F.driving and (o:get_x() - F.gx) ^ 2 + (o:get_z() - F.gz) ^ 2 > TOOK * TOOK"
     " or now - (F.last_order or -1e9) >= STEER_GAP and (", DROP),
]
