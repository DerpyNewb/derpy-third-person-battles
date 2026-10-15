-- One cast: masterful_calibration on the tank with NO target (it targets nothing and affects itself), to see
-- whether the engine takes an untargeted order where it refused the unit-as-target one. NO string library calls.
local units = bm:get_player_alliance():armies():item(1):units()
local u
for i = 1, units:count() do if units:item(i):type() == "wh_main_dwf_cha_greybeard_tank" then u = units:item(i) end end
if not u then return "no tank" end
local key = "masterful_calibration"
local before = u:can_perform_special_ability(key)
local uc = create_unitcontroller(u)
local ok, err = pcall(function() uc:perform_special_ability(key) end)
local ok2 = pcall(function() uc:release_control() end)
return {can_before = tostring(before), cast = ok and "ok" or tostring(err), released = tostring(ok2)}
