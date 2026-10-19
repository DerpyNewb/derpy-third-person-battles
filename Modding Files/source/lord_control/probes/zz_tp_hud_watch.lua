-- Test scaffolding (2026-10-19), never shipped. Watches, never drives (the keys are real): the HUD through a
-- transformation and the interface keys (a player: "turned the UI off mid transformation and the HUD stayed off for the
-- rest of the match"). Every 0.1 s for _G.TP_HUW_SECONDS (default 60) s, a row when it changes: third person on, the
-- unit, F.ui_off, the HUD panel's and its portrait's Visible, and the battle's own hud (CA's) root child. Read:
-- _G.TP_HUW.rows. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.F) then return "no pack" end
	if _G.TP_HUW and not _G.TP_HUW.done then return "already watching" end
	local F = E.F
	local T = {rows = {}, done = false}
	_G.TP_HUW = T
	local function now() return os.clock() end
	local t0, last, lt = now(), nil, -1
	local function finish() T.done = true pcall(function() bm:remove_real_callback("tp_hud_watch") end) end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			local t = now()
			if t - t0 > (_G.TP_HUW_SECONDS or 60) or _G.TP_HUW_STOP then finish() return end
			if t - lt < 0.1 then return end
			lt = t
			local root = core:get_ui_root()
			local hud = find_uicomponent(root, "derpy_tp_hud")
			local portrait = hud and find_uicomponent(hud, "portrait")
			local ca = find_uicomponent(root, "hud_battle")
			local row = "on " .. tostring(F.on) .. " " .. tostring(F.on and F.utype) .. " ui_off " .. tostring(F.ui_off)
				.. " hud " .. tostring(hud and hud:Visible()) .. " portrait " .. tostring(portrait and portrait:Visible())
				.. " ca_hud " .. tostring(ca and ca:Visible()) .. " t " .. math.floor(bm:time_elapsed_ms() / 100) / 10
			local key = "on " .. tostring(F.on) .. tostring(F.on and F.utype) .. tostring(F.ui_off) .. tostring(hud and hud:Visible())
				.. tostring(portrait and portrait:Visible()) .. tostring(ca and ca:Visible())
			if key ~= last and #T.rows < 400 then
				last = key
				T.rows[#T.rows + 1] = math.floor((t - t0) * 10) / 10 .. " " .. row
			end
		end)
		if not worked then T.err = tostring(err) finish() end
	end, 1, "tp_hud_watch")
	return "watching the HUD"
end)
return ok and res or "ERR " .. tostring(res)
