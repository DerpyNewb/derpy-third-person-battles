-- Test scaffolding (2026-10-18, a player's report via the author: "the uncontrollable unit card problem ... all types of
-- units, once controlled, become like that and cannot be controlled a second time"). Mode "aim": _G.TP_CO_IDX (player
-- army index) selected and the camera put over it, looking at the ground _G.TP_CO_AHEAD (20) m in front, so a real
-- right-click at the screen's centre is a move order there; records where it stands and is ordered. Mode "read": the
-- same again, so the click's effect shows as a change. Read the returned string. No string library calls.
local ok, res = pcall(function()
	local u = bm:get_player_army():units():item(_G.TP_CO_IDX or 5)
	local q, o = u:position(), u:ordered_position()
	local function r(n) return math.floor(n * 10) / 10 end
	local line = u:type() .. " pos " .. r(q:get_x()) .. "," .. r(q:get_z()) .. " ordered " .. r(o:get_x()) .. "," .. r(o:get_z())
		.. " moving " .. tostring(u:is_moving()) .. " script " .. tostring(u:is_script_controlled()) .. " player " .. tostring(u:is_player_controlled())
		.. " selected " .. bm:num_units_selected() .. " third person " .. tostring(_G.DERPY_TP and _G.DERPY_TP.F.on)
	if _G.TP_CO_MODE == "aim" then
		bm:clear_selection()
		u:select_in_ui()
		local b, d = math.rad(u:bearing()), _G.TP_CO_AHEAD or 20
		local tx, tz = q:get_x() + math.sin(b) * d, q:get_z() + math.cos(b) * d
		local ty = bm:get_terrain_height(tx, tz)
		cam:move_to(v(q:get_x() - math.sin(b) * 10, ty + 30, q:get_z() - math.cos(b) * 10), v(tx, ty, tz), 0, false, 0)
		line = line .. " | looking at " .. r(tx) .. "," .. r(tz)
	end
	return line
end)
return ok and res or "ERR " .. tostring(res)
