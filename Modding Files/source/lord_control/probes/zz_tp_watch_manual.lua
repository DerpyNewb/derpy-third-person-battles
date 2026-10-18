-- Test scaffolding (2026-10-18, the author: "switching to range is also inconsistent and the camera switches unit to
-- unit"). Read-only: every 100 ms, a line whenever third person, the Manual fire view, the selection or the played unit
-- changes, or the camera jumps over 5 m. _G.TP_WM_MODE "read" returns the lines, "off" stops it. No string library calls.
local ok, res = pcall(function()
	local mode = _G.TP_WM_MODE or "on"
	if mode == "read" then
		local s = ""
		for _, l in ipairs(_G.TP_WM or {}) do s = s .. l .. " || " end
		return s
	end
	bm:remove_real_callback("tp_watch_manual")
	if mode == "off" then return "watch off" end
	_G.TP_WM = {}
	local last = {}
	local t0 = bm:time_elapsed_ms()
	local function sel()
		local s, army = "", bm:get_player_army()
		for i = 1, army:units():count() do
			local u = army:units():item(i)
			local ok2, on = pcall(common.get_context_value, "CcoBattleUnit", tostring(u:unique_ui_id()), "IsSelected")
			if ok2 and on then s = s .. i .. "," end
		end
		return s
	end
	bm:repeat_real_callback(function()
		local T = _G.DERPY_TP
		local F = T and T.F or {}
		local fp = find_uicomponent(core:get_ui_root(), "first_person_ui")
		local c = cam:position()
		local now = {on = tostring(F.on), unit = tostring(F.utype), fp = tostring(fp and fp:Visible() or false),
			watch = tostring(T and T.fp ~= nil), sel = sel(), ranged = tostring(F.ranged), man = tostring(F.model)}
		local jump = last.cx and ((c:get_x() - last.cx) ^ 2 + (c:get_z() - last.cz) ^ 2) > 25
		local changed = jump
		for k, v in pairs(now) do if last[k] ~= v then changed = true end end
		if changed and #_G.TP_WM < 80 then
			_G.TP_WM[#_G.TP_WM + 1] = math.floor((bm:time_elapsed_ms() - t0) / 100) / 10 .. "s on " .. now.on .. " unit " .. now.unit
				.. " ranged " .. now.ranged .. " man " .. now.man .. " fp " .. now.fp .. " watch " .. now.watch .. " sel [" .. now.sel .. "] cam " .. math.floor(c:get_x()) .. ","
				.. math.floor(c:get_y()) .. "," .. math.floor(c:get_z()) .. (jump and " JUMP" or "")
		end
		for k, v in pairs(now) do last[k] = v end
		last.cx, last.cz = c:get_x(), c:get_z()
	end, 100, "tp_watch_manual")
	return "watching"
end)
return ok and res or "ERR " .. tostring(res)
