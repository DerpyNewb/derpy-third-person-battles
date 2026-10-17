-- Test scaffolding: a transformation ability (the Deithland Pyretitans' ammo modes, spawn_is_transformation) cast with
-- third person off - as CA's button, PerformAbilityForOwner on the card's ability - or on, through the pack's own cast;
-- then the army each tick for 6 s: every unit's type, ui id and men, and each new unit's man count and first man.
-- "on" stops third person 3 s after the cast. _G.TP_TF_TYPE unit type, _G.TP_TF_KEY ability key, _G.TP_TF_MODE "off"
-- or "on". Read back with zz_tp_transform_read.lua. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	local P, F = E.P, E.F
	local want, key, mode = _G.TP_TF_TYPE, _G.TP_TF_KEY, _G.TP_TF_MODE or "off"
	local army = bm:get_player_army()
	local u
	for i = 1, army:units():count() do
		local x = army:units():item(i)
		if x:type() == want and x:number_of_men_alive() > 0 then u = x end
	end
	if not u then return "no " .. tostring(want) end
	local function now() return bm:time_elapsed_ms() / 1000 end
	local T = {mode = mode, type = want, key = key, tl = {}, before = {}}
	_G.TP_TF = T
	for i = 1, army:units():count() do T.before[army:units():item(i):unique_ui_id()] = true end
	local function snap()
		local list, new = {}, {}
		for i = 1, army:units():count() do
			local x = army:units():item(i)
			list[#list + 1] = x:type() .. "#" .. x:unique_ui_id() .. ":" .. x:number_of_men_alive()
			if not T.before[x:unique_ui_id()] then
				local ms = P.models(x)
				local m = ms[1]
				local where = ""
				if m then local mx, my, mz = P.model_pos(m) where = " at " .. math.floor(mx) .. "," .. math.floor(my) .. "," .. math.floor(mz) end
				new[#new + 1] = x:type() .. "#" .. x:unique_ui_id() .. " models " .. #ms .. where
			end
		end
		local pl = ""
		if F.on then
			pl = "on " .. tostring(F.unit and F.unit:unique_ui_id()) .. " men " .. tostring(F.unit and F.unit:number_of_men_alive())
			if F.model then
				local mx, my, mz = P.model_pos(F.model)
				pl = pl .. " model alive " .. tostring(P.alive(F.unit, F.model)) .. " at " .. math.floor(mx) .. "," .. math.floor(my) .. "," .. math.floor(mz)
			end
		end
		return table.concat(list, " "), table.concat(new, "; "), pl
	end
	local function cast_off()
		local card = find_uicomponent(core:get_ui_root(), "cards_panel", tostring(u:unique_ui_id()))
		local id = card and card:GetContextObjectId("CcoBattleUnit")
		if not id then return "no card context" end
		for i = 0, common.get_context_value("CcoBattleUnit", id, "BattleAbilityList.Size") - 1 do
			if common.get_context_value("CcoBattleUnit", id, "BattleAbilityList.At(" .. i .. ").SetupAbilityContext.RecordKey") == key then
				common.call_context_command("CcoBattleUnit", id, "BattleAbilityList.At(" .. i .. ").PerformAbilityForOwner")
				return "cast at " .. i
			end
		end
		return "no " .. tostring(key) .. " in the card's list"
	end
	local function cast_on()
		local keys = F.unit:owned_non_passive_special_abilities() or {}
		for n = 1, #keys do
			if keys[n] == key then return "slot " .. n .. ": " .. tostring(E.abilities.cast(n)) end
		end
		return "no " .. tostring(key) .. " in his slots"
	end
	local function finish()
		T.done = true
		pcall(function() bm:remove_real_callback("tp_transform") end)
	end
	local t0 = now()
	local last
	if mode == "on" then
		E.main.start(u)
		if not F.on then finish() T.err = "could not start" return T.err end
	end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			if T.done then return end
			local t = now() - t0
			if not T.cast_at and t >= 0.5 then
				T.cast_at = t
				local fine, why = pcall(mode == "on" and cast_on or cast_off)
				T.cast = tostring(fine) .. " " .. tostring(why)
			end
			if mode == "on" and T.cast_at and F.on and t >= T.cast_at + 3 then pcall(E.main.stop, "transform test") T.stopped = t end
			local list, new, pl = snap()
			local line = list .. " | " .. new .. " | " .. pl
			if line ~= last then last = line T.tl[#T.tl + 1] = math.floor(t * 1000) .. " " .. line end
			if t > 6.5 then finish() end
		end)
		if not worked then T.err = tostring(err) finish() end
	end, 1, "tp_transform")
	return "started " .. mode .. " on " .. want
end)
return ok and res or "ERR " .. tostring(res)
