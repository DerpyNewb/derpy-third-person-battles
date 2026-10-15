-- Clear the selection. No string library calls.
bm:clear_selection()
return "cleared " .. tostring(bm:is_any_unit_selected())
