-- Test scaffolding (2026-10-17): Manual fire on _G.TP_MV_TYPE, sampled every frame for 6 s - is first_person_ui
-- open, the button's state, the selection, E.fp and F.on. _G.TP_MV_MODE "plain": third person off, the unit selected
-- and CA's button clicked 0.3 s later, as a player would; "pack": third person on the unit, then the pack's mode key
-- route (E.combat.mode); "stopped": third person on and off, then CA's button 2 s later;
-- "orders" / "camera" / "cinematic": one part of what M.stop puts back, then the button. _G.TP_MV_FOR: seconds
-- watched (6). Read with zz_tp_manual_read.lua. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local F = E.F
	local want, mode = _G.TP_MV_TYPE, _G.TP_MV_MODE or "plain"
	local army, u = bm:get_player_army(), nil
	for i = 1, army:units():count() do if army:units():item(i):type() == want then u = army:units():item(i) end end
	if not u then return "no " .. tostring(want) end
	if F.on then E.main.stop("manual test") end
	local T = {type = want, mode = mode, samples = {}, done = false}
	_G.TP_MV = T
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function button() return find_uicomponent(core:get_ui_root(), "hud_battle", "porthole_parent", "button_unit_manual_fire") end
	local t0 = now()
	local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
	local last
	local function sample()
		local fp = find_uicomponent(core:get_ui_root(), "first_person_ui")
		local b = button()
		local s = (fp and fp:Visible() and "OPEN" or "shut") .. " b " .. tostring(b and b:Visible() and b:CurrentState())
			.. " sel " .. bm:num_units_selected() .. " fp " .. tostring(E.fp ~= nil) .. " on " .. tostring(F.on)
			.. " exit " .. tostring(E.fp ~= nil and E.fp.exit_at ~= nil) .. " seen " .. tostring(E.fp ~= nil and E.fp.seen)
			.. " rmb " .. tostring(E.P.held(E.S.keys.mode)) .. " focus " .. tostring(E.P.focused())
		if s ~= last then
			last = s
			T.samples[#T.samples + 1] = (math.floor((now() - t0) * 100 + 0.5) / 100) .. " " .. s
		end
	end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			sample()
			if now() - t0 > (_G.TP_MV_FOR or 6) then T.done = true bm:remove_real_callback("tp_manual") end
		end)
		if not worked then T.err = tostring(err) T.done = true pcall(function() bm:remove_real_callback("tp_manual") end) end
	end, 1, "tp_manual")
	if mode == "plain" then
		bm:clear_selection()
		u:select_in_ui()
		bm:real_callback(function()
			local b = button()
			T.clicked = b ~= nil and b:Visible()
			if T.clicked then b:SimulateLClick() end
		end, 800, "tp_manual_click")
	elseif mode == "stopped" then
		-- third person on, off again 0.5 s later, the unit selected, and CA's button clicked once it shows, no sooner than
		-- _G.TP_MV_DELAY ms (2000) after that
		E.main.start(u)
		bm:real_callback(function()
			pcall(E.main.stop, "manual test", _G.TP_MV_KEEP) -- TP_MV_KEEP: the floor kept, as C.manual does
			u:select_in_ui()
			local from = os.clock()
			-- as the pack's watch: clicked once the button shows, no sooner than the delay
			bm:repeat_real_callback(function()
				local b = button()
				if os.clock() - from < (_G.TP_MV_DELAY or 2000) / 1000 or not (b and b:Visible()) then return end
				T.clicked = r2(now() - t0)
				b:SimulateLClick()
				bm:remove_real_callback("tp_manual_click2")
			end, 50, "tp_manual_click2")
		end, 500, "tp_manual_click")
	elseif mode == "orders" or mode == "camera" or mode == "cinematic" then
		-- one half of what M.stop puts back, set as third person sets it, put back 2 s later and the button clicked once it
		-- shows: the unit's fire at will and defend, or the camera's functions and floor
		local uc = army:create_unit_controller()
		uc:add_units(u)
		local function put(on)
			if mode == "cinematic" then
				-- as the pack's cursor(): CA's interface off with the cursor hidden, and back
				if on then bm:enable_cinematic_ui(true, false, false) else bm:enable_cinematic_ui(false, true, false) end
			elseif mode == "orders" then
				uc:fire_at_will(not on)
				uc:change_behaviour_active("defend", on, false)
				uc:release_control()
			else
				-- _G.TP_MV_CAM "fn" or "h": the functions alone, or the floor alone;
				if _G.TP_MV_CAM ~= "h" then cam:enable_functionality("CAMERA_ALL_FUNCTIONS", not on) end
				-- "keep": the floor lowered as third person has it and left so through Manual fire
				if _G.TP_MV_CAM ~= "fn" then
					if on then cam:change_height_range(0, 100) elseif _G.TP_MV_CAM ~= "keep" then cam:change_height_range(-1, -1) end
				end
			end
		end
		bm:clear_selection()
		u:select_in_ui()
		put(true)
		bm:real_callback(function()
			put(false)
			local from = os.clock()
			bm:repeat_real_callback(function()
				local b = button()
				if os.clock() - from < (_G.TP_MV_DELAY or 100) / 1000 or not (b and b:Visible()) then return end
				T.clicked = r2(now() - t0)
				b:SimulateLClick()
				bm:remove_real_callback("tp_manual_click2")
			end, 50, "tp_manual_click2")
		end, 2000, "tp_manual_click")
	else
		E.main.start(u)
		bm:real_callback(function() pcall(E.combat.mode, now()) T.clicked = true end, 500, "tp_manual_click")
	end
	return "watching " .. want .. " " .. mode
end)
return ok and res or "ERR " .. tostring(res)
