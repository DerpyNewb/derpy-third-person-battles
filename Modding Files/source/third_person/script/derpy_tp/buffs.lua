-- Unit stats (the MCT page's "Unit stats", stats.lua): each step chosen there sits on the unit played, while it is played.
-- A step is an army ability every faction's army owns (tools/build_third_person.py stat_rows), aimed at the ground under
-- him: the friendly unit nearest that point takes its phase, which stays until the ability is used again. So one cast
-- puts it on and the next takes it off, wherever it is aimed (measured 2026-10-24, memory
-- wh3-script-cast-army-ability-on-one-unit). Nothing here counts casts: each check reads the unit's effect list and casts
-- only when that is not what is wanted, so a cast that missed or landed late is put right by the next check.
return function(E)
	local B, F, P = {}, E.F, E.P
	local GAP = 0.5 -- s of model time a cast is given to land (it read back at 0.3 s) before the list is read again
	local cast_at, on, used = {}, {}, {} -- by ability key: the model time of its last cast, the unit it was put on, ever wanted
	local checked, refused = false, false -- refused: this army's faction owns none, another mod's (stat_rows covers CA's 739)

	local function list(unit, expr)
		local ok, s = pcall(common.get_context_value, "CcoBattleUnit", tostring(unit:unique_ui_id()), expr)
		return ok and type(s) == "string" and "," .. s .. "," or ","
	end
	-- keys are [a-z0-9_]: no pattern character, so a plain match
	local function has(unit, key)
		return list(unit, 'ActiveEffectList(false).JoinString(PhaseRecordContext.Key, ",")'):match("," .. key .. ",") ~= nil
	end
	local function alive(unit) local ok, n = pcall(unit.number_of_men_alive, unit) return ok and n > 0 end

	-- where to aim: the man played alone, else the unit (a regiment's centre is its own men's)
	local function spot(unit)
		if F.model and unit == F.unit then
			local ok, x, y, z = pcall(P.model_pos, F.model)
			if ok and x then return v(x, y, z) end
		end
		return unit:position()
	end

	-- the steps MCT asks for, by ability key: E.S.stats is read again at every start
	local function wanted()
		local out = {}
		for stat, step in pairs(E.S.stats or {}) do out[E.T.ability(stat, step)] = true end
		return out
	end

	function B.tick(now)
		if refused or P.features.net then return end -- multiplayer: a player's own settings stay out of a shared battle
		local unit = F.on and alive(F.unit) and F.unit or nil
		local want = unit and wanted() or {}
		if unit and next(want) and not checked then
			checked = true
			if not list(unit, 'ArmyContext.ArmyAbilitiesList(false).JoinString(RecordKey, ",")'):match("," .. next(want) .. ",") then
				refused = true
				E.once("stats_faction", "unit stats: this army's faction owns none of the stat abilities")
				E.say("derpy_tp_stats_faction")
				return
			end
		end
		for key in pairs(want) do used[key] = true end
		for key in pairs(used) do
			if now - (cast_at[key] or -1e9) >= GAP then
				local target, last = want[key] and unit or nil, on[key]
				local function cast(at)
					cast_at[key] = now
					local ok, err = pcall(function() at:army():use_special_ability(key, spot(at)) end)
					if not ok then E.once("stats_cast", "unit stats: " .. key .. " was not cast: " .. tostring(err)) end
				end
				if target and has(target, key) then
					on[key] = target
				elseif last and last ~= target and alive(last) and has(last, key) then
					cast(last) -- off, from the unit that has it
					on[key] = nil
				elseif target then
					cast(target) -- on; or, were it on a unit not looked at, off, and the next check casts again
					on[key] = target
				end
			end
		end
	end

	return B
end
