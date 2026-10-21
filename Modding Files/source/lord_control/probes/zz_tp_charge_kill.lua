-- The charge experiment (the 2026-10-20 plan, Task 2): enemy men killed in the first 2 s of contact, per case.
-- Bridge-only, loaded from disk: local f = loadfile("<this path>") setfenv(f, core:get_env()) f()
--   TPC.run(case, attacker_index, opts)   one run; TPC.res holds the results, TPC.busy while one runs
-- cases: "base" CA's attack_unit with third person off; "order" third person on, whole or a unit of one, CA's order
-- through F.uc; "sprint" third person on, W and the sprint key held (faked: P.held reads TPC.keys, P.focused true, the
-- look calls no-ops) at the enemy - the pack's own charge (combat.lua C.charge). The "one" case (the cave's charge on one
-- man) is gone: it crashed the game twice, and the cave was reverted (2026-10-20).
-- opts.gap: metres between the two at the start (40). opts.noguard: P.guard off for the run (the pack stops a melee command on a man it plays).
-- Contact: the first attacker model (his body for a rider) within 2 m of an enemy model; the kill count is the enemy
-- unit's men lost from contact to contact + 2 s; touched: the attacker's bodies within 2 m of an enemy in those 2 s.
local E = _G.DERPY_TP
local P = E.P
local TPC = _G.TPC or {res = {}}
_G.TPC = TPC
-- the MCT's one-man setting forced per run (settings are read again at every start)
if not E._real_settings then
	E._real_settings = E.settings
	E.settings = function(...) local S = E._real_settings(...) if E._one_man ~= nil then S.one_man = E._one_man end return S end
end
-- faked input for the "sprint" case, so the author's cursor is never taken
TPC.keys = TPC.keys or {}
if not E._real_input then
	E._real_input = {focused = P.focused, held = P.held, look_begin = P.look_begin, look_delta = P.look_delta, wheel = P.wheel}
	P.focused = function() return true end
	P.held = function(k) return TPC.keys[k] == true end
	P.look_begin = function() end
	P.look_delta = function() return 0, 0 end
	P.wheel = function() return 0 end
end
local function army(enemy) return enemy and bm:get_non_player_alliance():armies():item(1) or bm:get_player_army() end

-- every enemy unit held where it stands, again before each run
TPC.hold = TPC.hold or {}
function TPC.hold_all()
	local ea = army(true):units()
	for i = 1, ea:count() do
		local uc = TPC.hold[i] or create_unitcontroller(ea:item(i))
		TPC.hold[i] = uc
		uc:take_control() uc:halt()
	end
end

-- the freshest regiment of the fodder, never one that has run
local function pick_enemy()
	local ea = army(true):units()
	local best, bi
	for i = 1, ea:count() do
		local u = ea:item(i)
		local t = u:type()
		if (t:find("clanrat") or t:find("skavenslave")) and not u:is_routing() and not u:is_shattered()
			and (not best or u:number_of_men_alive() > best:number_of_men_alive()) then best, bi = u, i end
	end
	return best, bi
end

local function bodies(unit, only)
	local t = {}
	for _, m in ipairs(only and {only} or P.models(unit)) do
		local b = P.mount(m) or m
		local seen = false
		for _, x in ipairs(t) do if P.same and P.same(x, b) or x == b then seen = true end end
		if not seen and P.model_hp(m) > 0 then t[#t + 1] = b end
	end
	return t
end

local function near(b, enemy_models)
	local x, _, z = P.model_pos(b)
	for _, e in ipairs(enemy_models) do
		local ex, _, ez = P.model_pos(e)
		if (ex - x) ^ 2 + (ez - z) ^ 2 < 4 then return true end
	end
	return false
end

function TPC.run(case, ai, opts)
	opts = opts or {}
	if TPC.busy then return "busy" end
	TPC.busy = true
	TPC.hold_all()
	local att = army(false):units():item(ai)
	local enemy, ei = pick_enemy()
	local spot = TPC.spot
	-- the enemy at the spot facing north, the attacker 40 m north of it facing south; both still
	local euc = TPC.hold[ei]
	euc:teleport_to_location(v(spot[1], 0, spot[2]), 0, 30) euc:halt()
	local auc = TPC.auc and TPC.auc[ai] or create_unitcontroller(att)
	TPC.auc = TPC.auc or {} TPC.auc[ai] = auc
	auc:take_control()
	auc:teleport_to_location(v(spot[1], 0, spot[2] + (opts.gap or 40)), 180, 20) auc:halt() auc:release_control()
	local r = {case = case, unit = att:type(), enemy = enemy:type() .. " #" .. ei, noguard = opts.noguard or nil}
	TPC.res[#TPC.res + 1] = r
	local guard = P.guard
	local t, contact, men0, touched, stage = 0, nil, nil, {}, "settle"
	bm:repeat_callback(function()
		local ok, err = pcall(function()
			t = t + 0.1
			if stage == "settle" and t >= 1.5 then
				stage = "go"
				euc:halt()
				if case == "base" then
					auc:take_control() auc:attack_unit(enemy, true, true) auc:release_control()
				else
					E._one_man = case == "one"
					E.main.start(att)
					r.model = E.F.model ~= nil
					if opts.noguard then P.guard = function() return true end end
					if case == "order" then
						E.F.uc:attack_unit(enemy, true, true) E.F.uc:release_control() E.F.native_attack = true
					else
						E.rig.yaw = math.pi
						TPC.keys[E.S.keys.forward], TPC.keys[E.S.keys.sprint] = true, true
					end
				end
				r.go_t = t
			elseif stage == "go" then
				if case == "sprint" and math.floor(t * 10 + 0.5) % 5 == 0 then
					local q, F = att:position(), E.F
					r.trace = r.trace or {}
					r.trace[#r.trace + 1] = math.floor(t - r.go_t) .. "s " .. math.floor(q:get_x()) .. "," .. math.floor(q:get_z())
						.. " on " .. tostring(F.on) .. " spr " .. tostring(F.sprinting) .. " st " .. string.format("%.2f", F.stamina or -1)
						.. " yaw " .. string.format("%.2f", E.rig.yaw) .. " goal " .. tostring(F.gz and math.floor(F.gz)) .. " co " .. tostring(F.charge_order ~= nil)
						.. " na " .. tostring(F.native_attack) .. " q " .. tostring(F.queued ~= nil)
				end
				if case == "sprint" and E.F.charge_order and not r.charge_t then
					r.charge_t = math.floor((t - r.go_t) * 10) / 10
					r.charge_on = E.F.charge_order.target == enemy
					-- contact and kills on the unit it charged: the fodder stands crowded, the nearest ahead is not always ours
					enemy = E.F.charge_order.target
				end
				local mine = bodies(att, case == "one" and E.F.model or nil)
				local em = P.models(enemy)
				local hit = false
				for _, b in ipairs(mine) do if near(b, em) then hit = true end end
				if hit then
					stage, contact, men0 = "contact", t, enemy:number_of_men_alive()
					r.to_contact = math.floor((t - r.go_t) * 10) / 10
				elseif t - r.go_t > 15 then
					stage, r.result = "done", "no contact in 15 s"
				end
			end
			if stage == "contact" then
				for _, b in ipairs(bodies(att, case == "one" and E.F.model or nil)) do
					if near(b, P.models(enemy)) then touched[tostring(b)] = true end
				end
				if t - contact >= 2 then
					stage = "done"
					r.kills = men0 - enemy:number_of_men_alive()
					local n = 0 for _ in pairs(touched) do n = n + 1 end
					r.touched = n
				end
			end
			if stage == "done" then
				TPC.keys = {}
				bm:remove_process("tpc_run")
				P.guard = guard
				if case ~= "base" then pcall(E.main.stop, "tpc") end
				E._one_man = nil
				TPC.busy = false
			end
		end)
		if not ok then r.error = tostring(err) bm:remove_process("tpc_run") P.guard = guard TPC.busy = false end
	end, 100, "tpc_run")
	return "started"
end
return "loaded"
