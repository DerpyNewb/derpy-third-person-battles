-- Test scaffolding (2026-10-17, the deployed pack): an ammo change and back in third person on _G.TP_TO_TYPE (default
-- the Pyretitans Mortar). Third person on, its transform cast through the pack's own key path (E.abilities.cast) at 1 s;
-- once the new form is played, the new form's own transform cast 1.5 s later, the same way; off 1 s after the second
-- take-over. Every frame where on/unit/new card changes is kept, with the pack's log and once-lines and whether the
-- HUD's cast went through the card (E.hud.ability_command). Read with zz_tp_takeover_read.lua. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local F = E.F
	local want = _G.TP_TO_TYPE or "emp_pyretitans_mortar"
	local army = bm:get_player_army()
	local u
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 0 then u = x end
	end
	if not u then return "no " .. tostring(want) end
	if F.on then E.main.stop("takeover test") end
	local T = {type = want, tl = {}, log = {}, casts = {}, hud_cmd = {}, done = false}
	_G.TP_TO = T
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
	local log_was, once_was, cmd_was = E.log, E.once, E.hud.ability_command
	local t0 = now()
	E.log = function(msg) if #T.log < 80 then T.log[#T.log + 1] = r2(now() - t0) .. " " .. tostring(msg) end return log_was(msg) end
	E.once = function(tag, msg) T.log[#T.log + 1] = r2(now() - t0) .. " ONCE " .. tostring(msg) return once_was(tag, msg) end
	E.hud.ability_command = function(...)
		local fine, err = pcall(cmd_was, ...)
		T.hud_cmd[#T.hud_cmd + 1] = r2(now() - t0) .. " " .. tostring(fine) .. (fine and "" or (" " .. tostring(err)))
		if not fine then error(err) end
	end
	local function finish(why)
		T.done, T.why = true, why
		if F.on then pcall(E.main.stop, "takeover test") end
		E.log, E.once, E.hud.ability_command = log_was, once_was, cmd_was
		pcall(function() bm:remove_real_callback("tp_takeover") end)
	end
	local function cast_transform()
		local keys = F.unit:owned_non_passive_special_abilities() or {}
		for n = 1, #keys do
			if E.D.abilities[keys[n]] == "transform" then
				local fine, why = pcall(E.abilities.cast, n)
				T.casts[#T.casts + 1] = r2(now() - t0) .. " " .. keys[n] .. " slot " .. n .. " " .. tostring(fine) .. " " .. tostring(why)
				return true
			end
		end
		T.casts[#T.casts + 1] = r2(now() - t0) .. " no transform in " .. #keys .. " slots"
	end
	local ids = {u:unique_ui_id()}
	E.main.start(u)
	if not F.on then finish("could not start") return T.why end
	local step, at, last = "wait_cast1", 1, nil
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = now() - t0
			local id = F.on and F.unit and F.unit:unique_ui_id()
			local cards = ""
			for i = 1, army:units():count() do
				local x = army:units():item(i)
				if find_uicomponent(core:get_ui_root(), "cards_panel", tostring(x:unique_ui_id())) then cards = cards .. x:unique_ui_id() .. " " end
			end
			local line = "on " .. tostring(F.on) .. " unit " .. tostring(id) .. " cards " .. cards
			if line ~= last then last = line T.tl[#T.tl + 1] = r2(t) .. " " .. line end
			if step == "wait_cast1" and t >= at then
				if not cast_transform() then finish("no transform on the first form") return end
				step = "wait_take1"
			elseif step == "wait_take1" and id and id ~= ids[1] then
				ids[2], T.take1 = id, r2(t)
				step, at = "wait_cast2", t + 1.5
			elseif step == "wait_cast2" and t >= at then
				if not cast_transform() then finish("no transform on the second form") return end
				step = "wait_take2"
			elseif step == "wait_take2" and id and id ~= ids[2] then
				ids[3], T.take2 = id, r2(t)
				step, at = "wait_off", t + 1
			elseif step == "wait_off" and t >= at then
				finish("both ways")
			end
			if t > 30 then finish("timed out at " .. step) end
		end)
		if not worked then T.err = tostring(err) finish("probe error") end
	end, 1, "tp_takeover")
	T.ids = ids
	return "started on " .. want
end)
return ok and res or "ERR " .. tostring(res)
