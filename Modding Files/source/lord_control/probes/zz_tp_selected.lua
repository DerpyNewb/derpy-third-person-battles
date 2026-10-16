-- 2026-10-15, "the camera jumps one unit to another": the log shows card 1010 clicked and F2 taking 1012, the unit
-- before. Which units the game says are selected (CcoBattleUnit.IsSelected by unique_ui_id, num_units_selected) against
-- the set main.lua keeps from selection callbacks. Read-only; no string library calls.
local SEL = _G.DERPY_TP_SELECTED
local out = "num_units_selected " .. tostring(bm:num_units_selected()) .. " | IsSelected:"
local units = bm:get_player_army():units()
for i = 1, units:count() do
	local u = units:item(i)
	local id = tostring(u:unique_ui_id())
	local ok, s = pcall(common.get_context_value, "CcoBattleUnit", id, "IsSelected")
	if not ok or s ~= false then out = out .. " " .. id .. " " .. u:type() .. "=" .. tostring(ok) .. "/" .. tostring(s) end
end
out = out .. " | callback set:"
if SEL then for id, u in pairs(SEL.set) do out = out .. " " .. tostring(id) end end
return out
