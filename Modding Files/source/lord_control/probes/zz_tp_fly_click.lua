-- Fly-key probe, 2026-10-14: does SimulateLClick on button_toggle_flying act while third person has
-- hidden its parent (hud_battle > battle_orders)? On a timer: third person on for the General, 0.5 s later
-- note the button's and its pane's visibility and click it, then sample unit:is_currently_flying() every
-- 100 ms for 6 s, then third person off. NO string.* or s:method() (memory wh3-mcp-bridge-wedges-on-interface-walks).
-- Read back with zz_tp_fly_click_read.lua.
local E = _G.DERPY_TP
if not (E and E.main) then return "load the bridge first" end
local GENERAL = "wh3_dlc24_cth_cha_celestial_general_yang_longma"
local units = bm:get_player_army():units()
local u
for i = 1, units:count() do if units:item(i):type() == GENERAL then u = units:item(i) end end
if not u then return "no " .. GENERAL end
local T = {n = 0, log = {}}
_G.TP_FLY = T
local function note(s) T.log[#T.log + 1] = s out("derpy_tp fly probe: " .. s) end
local last
bm:repeat_real_callback(function()
	T.n = T.n + 1
	local ok, err = pcall(function()
		local flying = u:is_currently_flying()
		if flying ~= last then note("t=" .. T.n .. " flying " .. tostring(flying)) last = flying end
		if T.n == 1 then
			if not E.F.on then E.main.start(u) end
			note("third person " .. tostring(E.F.on))
		elseif T.n == 5 then
			local root = core:get_ui_root()
			local pane = find_uicomponent(root, "battle_orders")
			local b = find_uicomponent(root, "button_toggle_flying")
			note("battle_orders " .. (pane and tostring(pane:Visible()) or "absent") .. ", button " .. (b and (tostring(b:Visible()) .. " state " .. tostring(b:CurrentState())) or "absent"))
			if b then b:SimulateLClick() note("clicked") end
		end
	end)
	if not ok then T.error = tostring(err) end
	if T.n >= 65 or not ok then
		bm:remove_real_callback("tp_fly")
		T.ended = true
		pcall(E.main.stop, "fly probe")
	end
end, 100, "tp_fly")
return "started"
