-- Porthole survey, 2026-10-14 (v4): on a timer, switches third person on for the General, and 1 s later lists
-- the porthole subtree (depth, id, visible, position, size) and whether SpecialTooltip shows, then switches
-- off. Every line also goes to the script log ("derpy_tp survey:"). v1-v3 each called the string library
-- (string.format, string.gsub, even one plain string.find) and each scrambled string.sub for the bridge AND
-- the game (memory wh3-mcp-bridge-wedges-on-interface-walks): NO string.* or s:method() anywhere here.
-- The eval itself only registers the timer. Read back with zz_tp_ui_tree_read.lua.
local E = _G.DERPY_TP
if not (E and E.main) then return "load the bridge first" end
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GENERAL then u = units:item(i) end end
if not u then return "no " .. GENERAL end
local T = {porthole = {}, roots = {}, n = 0}
_G.TP_UI_TREE = T
local function line(s) T.porthole[#T.porthole + 1] = s out("derpy_tp survey: " .. s) end
local function walk(c, depth)
	local x, y = c:Position()
	local w, h = c:Dimensions()
	line(depth .. " " .. tostring(c:Id()) .. " v=" .. tostring(c:Visible()) .. " at " .. math.floor(x) .. "," .. math.floor(y) .. " size " .. math.floor(w) .. "x" .. math.floor(h))
	if depth < 4 then for i = 0, c:ChildCount() - 1 do walk(UIComponent(c:Find(i)), depth + 1) end end
end
bm:repeat_real_callback(function()
	T.n = T.n + 1
	local ok, err = pcall(function()
		if T.n == 1 then
			if not E.F.on then E.main.start(u) end
			T.on = E.F.on == true
		elseif T.n == 11 then
			local root = core:get_ui_root()
			local sw, sh = core:get_screen_resolution()
			line("screen " .. sw .. "x" .. sh .. ", third person " .. tostring(E.F.on))
			local tip = find_uicomponent(root, "SpecialTooltip")
			line("SpecialTooltip " .. (tip and ("v=" .. tostring(tip:Visible())) or "absent"))
			local port = find_uicomponent(root, "porthole_parent")
			if port then walk(port, 0) else line("no porthole_parent") end
		end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= 11 or not ok then
		bm:remove_real_callback("tp_ui_tree")
		T.ended = true
		pcall(E.main.stop, "ui survey")
	end
end, 100, "tp_ui_tree")
return "started"
