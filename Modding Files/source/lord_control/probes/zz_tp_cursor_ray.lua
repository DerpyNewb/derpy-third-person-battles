-- 2026-10-15: can the engine's own mouse-over ray give the aim point? CcoBattleCursorContext (BattleCursorContext, a
-- global context function) has FirstIntersectPosition and GroundIntersectPosition. Third person parks the cursor at the
-- screen centre, which is the crosshair. Read-only; no string library calls.
local out = ""
for _, e in ipairs({"BattleCursorContext.FirstIntersectPosition", "BattleCursorContext.GroundIntersectPosition",
	"BattleCursorContext.ContextPosition", "BattleCursorContext.UnitContext.Name", "BattleCursorContext.IsAttackCursor"}) do
	for _, c in ipairs({"", ".x", ".y", ".z"}) do
		if c == "" or e ~= "BattleCursorContext.UnitContext.Name" and e ~= "BattleCursorContext.IsAttackCursor" then
			local ok, v = pcall(common.get_context_value, e .. c)
			out = out .. " | " .. e .. c .. " = " .. tostring(ok) .. " " .. tostring(v)
		end
	end
end
return out
