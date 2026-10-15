-- Switch the unit flags off again now, with whatever cinematic state third person is in. No string library calls.
local E = _G.DERPY_TP
bm.battle:set_banners_enabled(false)
return "on " .. tostring(E and E.F and E.F.on) .. " dragging " .. tostring(E and E.F and E.F.dragging) .. " cinematic " .. tostring(bm:is_cinematic_ui_enabled())
