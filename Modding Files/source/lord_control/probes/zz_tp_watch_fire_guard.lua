-- Test scaffolding (2026-10-19), never shipped. Watches, never drives: the keys are real, the start is F2.
-- Two live checks: section 10 of HANDOFF_20261018_THIRD_PERSON_SIEGE_WALK_ARTILLERY (one man of a ranged regiment: do
-- the others keep firing, and does he fire on his own) and section 9 (a unit of one: is he invincible through his jump,
-- charge attack and hit clips, and does his health hold still then).
-- For _G.TP_FG_SECONDS (default 60) s, every 0.2 s while third person is on, a row: battle time, unit type, MODEL (one
-- man) or SINGLE, ours = F.invincible, eng = unit:is_invulnerable(), guard = F.lock.guard, held = F.held_fire, the unit's
-- ammo and unary hit points, the man's clip and his mount's (R = a hit clip, S = a shooting clip), his hit points, and
-- how many of the other men are in a shooting clip. P.play is wrapped to log the clips the pack itself plays on him.
-- Read: _G.TP_FG.rows, _G.TP_FG.plays. No string library calls.
local ok, res = pcall(function()
	local E = _G.DERPY_TP
	if not (E and E.main and E.P) then return "no pack" end
	if _G.TP_FG and not _G.TP_FG.done then return "already watching" end
	local P, F = E.P, E.F
	local T = {rows = {}, plays = {}, done = false}
	_G.TP_FG = T
	local function shooting(s) return s and (s >= 1547 and s <= 1599 or s >= 949 and s <= 952 or s >= 2104 and s <= 2116) end
	local function reeling(s)
		return s and (s >= 368 and s <= 387 or s >= 474 and s <= 483 or s >= 504 and s <= 513 or s >= 1217 and s <= 1246
			or s >= 1921 and s <= 1930 or s >= 1951 and s <= 1960 or s >= 2202 and s <= 2221)
	end
	local function tag(s) return tostring(s) .. (reeling(s) and "R" or "") .. (shooting(s) and "S" or "") end
	local function now() return bm:time_elapsed_ms() / 1000 end
	local function r1(x) return math.floor(x * 100 + 0.5) / 100 end
	local play0 = P.play
	P.play = function(m, slot, mask)
		local man = F.on and (F.model or F.single)
		if man and #T.plays < 300 and (P.same(m, man) or P.same(m, P.mount(man) or man)) then
			T.plays[#T.plays + 1] = r1(now()) .. " play " .. tostring(slot) .. " mask " .. tostring(mask)
		end
		return play0(m, slot, mask)
	end
	local t0, last = now(), -1
	local function finish()
		T.done = true
		P.play = play0
		pcall(function() bm:remove_real_callback("tp_watch_fire_guard") end)
	end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			local t = now()
			if t - t0 > (_G.TP_FG_SECONDS or 60) or _G.TP_FG_STOP then finish() return end
			if t - last < 0.2 then return end
			last = t
			if not F.on then return end
			local man = F.model or F.single
			local mount = man and P.mount(man)
			local hp, hpmax = -1, -1
			if man then hp, hpmax = P.model_hp(man) end
			local others, men = 0, 0
			for _, m in ipairs(P.models(F.unit)) do
				men = men + 1
				if not (man and P.same(m, man)) and shooting(P.anim_slot(m)) then others = others + 1 end
			end
			if #T.rows < 900 then
				T.rows[#T.rows + 1] = r1(t) .. " " .. F.unit:type() .. (F.model and " MODEL" or "") .. (F.single and " SINGLE" or "")
					.. " ours " .. tostring(F.invincible or false) .. " eng " .. tostring(F.unit:is_invulnerable())
					.. " guard " .. tostring(F.lock and F.lock.guard or false) .. " held " .. tostring(F.held_fire or false)
					.. " faw " .. tostring(F.unit:is_behaviour_active("fire_at_will")) .. " melee " .. tostring(F.unit:is_in_melee())
					.. " ammo " .. tostring(F.unit:ammo_left()) .. " uhp " .. tostring(r1(F.unit:unary_hitpoints()))
					.. " clip " .. (man and tag(P.anim_slot(man)) or "-") .. " mount " .. (mount and tag(P.anim_slot(mount)) or "-")
					.. " hp " .. tostring(hp) .. "/" .. tostring(hpmax) .. " others_shoot " .. tostring(others) .. "/" .. tostring(men - 1)
			end
		end)
		if not worked then T.err = tostring(err) finish() end
	end, 1, "tp_watch_fire_guard")
	return "watching"
end)
return ok and res or "ERR " .. tostring(res)
