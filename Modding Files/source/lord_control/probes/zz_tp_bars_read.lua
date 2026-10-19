-- Test scaffolding (2026-10-19), never shipped. Reads the unit bars the pack made (hud.lua bars()) off the component
-- tree, since the in-game screenshot has no UI layer: per unit, the pin's shown state and box, where the unit's lifted
-- position projects (CA's WorldSpaceToScreenSpace, as hud.lua H.mark), the engine's base shown state (IsVisible), the
-- fill's width against HealthPercent, and whether an enemy is still under its own control. Read: the returned rows.
-- No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.F) then return "no pack" end
	local L = E.load("hud_layout")
	local root = core:get_ui_root()
	local holder = find_uicomponent(root, "derpy_tp_hud", "bars")
	if not holder then return "no holder" end
	local rows = {"holder kids " .. holder:ChildCount() .. " shown " .. tostring(holder:Visible())
		.. " hud " .. tostring(find_uicomponent(root, "derpy_tp_hud"):Visible())}
	local function r2(n) return math.floor(n * 100 + 0.5) / 100 end
	local function lift(u)
		local body = E.D.bodies and E.D.bodies[u:type()]
		local want = (body and body[2] or 1.8) + L.bar.clear
		for _, m in ipairs(L.bar.lifts) do if m >= want then return m end end
		return L.bar.lifts[#L.bar.lifts]
	end
	for side, alliance in ipairs({bm:get_player_alliance(), bm:get_non_player_alliance()}) do
		local armies = alliance:armies()
		for a = 1, armies:count() do
			local units = armies:item(a):units()
			for i = 1, units:count() do
				local u = units:item(i)
				local id = tostring(u:unique_ui_id())
				local pin = find_uicomponent(holder, "derpy_tp_bar_" .. id)
				local row = (side == 1 and "ours/ally " or "enemy ") .. u:type() .. " men " .. u:number_of_men_alive()
				if not pin then
					row = row .. " NO PIN"
				else
					local x, y = pin:Position()
					local w, h = pin:Dimensions()
					local base = find_uicomponent(pin, "base")
					local fill = base and find_uicomponent(base, "fill")
					local fw = fill and select(1, fill:Dimensions())
					local p = u:position()
					local at = "WorldSpaceToScreenSpace(ToVector4(" .. r2(p:get_x()) .. "," .. r2(p:get_y() + lift(u)) .. ","
						.. r2(p:get_z()) .. ",1), false, false)."
					local sx, sy, sz = common.get_context_value(at .. "x"), common.get_context_value(at .. "y"),
						common.get_context_value(at .. "z")
					local hp = common.get_context_value("CcoBattleUnit", id, "HealthPercent")
					local seen = common.get_context_value("CcoBattleUnit", id, "IsVisible")
					row = row .. " pin " .. tostring(pin:Visible()) .. " at " .. x .. "," .. y .. " " .. w .. "x" .. h
						.. " | want " .. r2(sx - w / 2) .. "," .. r2(sy - h) .. " z " .. r2(sz)
						.. " | base " .. tostring(base and base:Visible()) .. " seen " .. tostring(seen)
						.. " | fill " .. tostring(fw) .. " hp " .. tostring(hp and r2(hp))
						.. " | ai " .. tostring(u:is_ai_controlled()) .. " player " .. tostring(u:is_player_controlled())
				end
				rows[#rows + 1] = row
			end
		end
	end
	return rows
end)
return ok and res or "ERR " .. tostring(res)
