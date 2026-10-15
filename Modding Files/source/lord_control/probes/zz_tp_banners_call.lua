-- Does the battle interface carry set_banners_enabled? No string library calls.
return tostring(type(bm.battle.set_banners_enabled)) .. " " .. tostring(type(bm.battle.enable_tooltips))
