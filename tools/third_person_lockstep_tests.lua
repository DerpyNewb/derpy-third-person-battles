-- Two-machine lockstep tests for derpy_third_person: two copies of the shipped mod, A and B, in one process, sharing
-- one fake command queue (tools/third_person_lockstep.lua, the global L). Run by tools/third_person_harness.lua.
-- What a green run proves is the MOD's discipline only: the engine carrying a command to the other machine is for the
-- two-machine session to measure.
local T = {}

-- what machine n sent, by kind; a carrier also counts under "carrier:<op>"
local function sent_kinds(w, n)
	local k = {}
	for _, c in ipairs(w:sent(n)) do
		k[c.kind] = (k[c.kind] or 0) + 1
		local op = c.kind == "carrier" and (c.fields.op or "unknown")
		if op then k["carrier:" .. op] = (k["carrier:" .. op] or 0) + 1 end
	end
	return k
end

-- a move for man id that machine n's engine ran (not superseded, not dropped)
local function ran_move(w, n, id)
	for _, a in ipairs(w:applied(n)) do if a.kind == "move" and a.model_id == id then return true end end
	return false
end

T.ls_the_oracle_catches_a_one_sided_write = function()
	local w = L.new({})
	w:run(0.5)
	w:inject("A", "follow", 1001, {angle = 100})
	w:run(0.2)
	check(w:diverged() and w:diverged():find("follow"), "a write on one machine is reported")
end

T.ls_machines_share_nothing = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:on("A", function() check(H.E.F.on, "A is on") end)
	w:on("B", function() check(not H.E.F.on, "B never saw A's key") end)
end

T.ls_two_machines_stay_in_step_while_A_plays = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:on("A", function() H.down("W") end)
	w:run(2.0)
	w:on("A", function() H.up("W") end)
	w:tap("A", "Left mouse")
	w:run(5.0)
	local k = sent_kinds(w, "A")
	-- play: the click's swing; follow: standing, turned to the camera once its 4 s clip is over (nothing is sent to him
	-- while the clip is in flight, platform.lua M.net_rules)
	for _, kind in ipairs({"move", "follow", "play", "carrier:GUARD_ON"}) do check(k[kind], "A sent no " .. kind) end
	check(ran_move(w, "B", 1001), "B's engine ran A's move for 1001")
	-- B's one send is its own HELLO, from the world's start (L.new runs the handshake)
	check(#w:sent("B") == 1 and w:sent("B")[1].fields.op == "HELLO", "B decided nothing for A's man")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- three ways for him to go, each with his commands still in the queue: no health, dead, and gone from his unit. The
-- engine's handlers check only that his id resolves, so a MOVE, HALT, FOLLOW or clip lands on a dead man who still
-- resolves and is dropped for one who is gone (what a dead model does with it is a live measurement, the feasibility
-- record's Ruling 21). Whichever, the same on both machines
T.ls_a_command_for_a_dead_man_lands_alike_on_both = function()
	local ways = {
		hp = function(u) u._models[1].hp = 0 end,
		alive = function(u) u._models[1].alive = false end,
		gone = function(u) table.remove(u._models, 1) end,
	}
	local ACTION = {move = true, halt = true, follow = true, play = true}
	for _, how in ipairs({"hp", "alive", "gone"}) do
		local w = L.new({delay_ticks = 3})
		w:tap("A", "F2")
		w:on("A", function() H.down("W") end)
		w:run(0.15)
		-- the same man on both: A's own, who on B is in the other army (B plays army 2). H.units[1] on both would kill
		-- two different men, one on each machine, and the oracle rightly calls that a desync
		w:on("A", function() ways[how](H.units[1]) end)
		w:on("B", function() ways[how](H.enemies[1]) end)
		local died = w.t
		w:run(0.5)
		check(w:diverged() == nil, how .. ": " .. tostring(w:diverged()))
		for _, n in ipairs({"A", "B"}) do
			local ran, dropped = 0, 0
			for _, a in ipairs(w:applied(n)) do
				if a.model_id == 1001 and a.tick > died then
					if ACTION[a.kind] then ran = ran + 1 end
					if a.kind == "dropped" and ACTION[a.fields.kind] then dropped = dropped + 1 end
				end
			end
			if how == "gone" then
				check(dropped > 0 and ran == 0, how .. ": " .. n .. " dropped " .. dropped .. " and ran " .. ran .. " for the man who is gone")
			else
				check(ran > 0 and dropped == 0, how .. ": " .. n .. " ran " .. ran .. " and dropped " .. dropped .. " for the dead man")
			end
		end
	end
end

-- a guard entry is freed by the id it was claimed with, whatever became of the man: when the played man dies and the
-- next is played, and at the stop after he died. Never twice for one GUARD_ON
local function guard_ids(w, n)
	local on, off = {}, {}
	for _, c in ipairs(w:sent(n)) do
		if c.kind == "carrier" and c.fields.op == "GUARD_ON" then on[c.fields.id] = (on[c.fields.id] or 0) + 1 end
		if c.kind == "carrier" and c.fields.op == "GUARD_OFF" then off[c.fields.id] = (off[c.fields.id] or 0) + 1 end
	end
	return on, off
end

T.ls_a_guarded_man_who_dies_is_unguarded_by_his_id = function()
	local w = L.new({armies = {{{general = true, men = 3}}, {{general = true, z = 300}}}})
	w:tap("A", "F2")
	w:run(0.5)
	local played, next_man
	w:on("A", function() played = H.E.F.model and H.E.F.model.id end)
	check(played == 1002, "the front man is played: " .. tostring(played))
	w:on("A", function() H.units[1]._models[2].hp = 0 end)
	w:on("B", function() H.enemies[1]._models[2].hp = 0 end)
	w:run(0.5)
	w:on("A", function() next_man = H.E.F.model and H.E.F.model.id end)
	check(next_man and next_man ~= 1002, "the next man is played: " .. tostring(next_man))
	local on, off = guard_ids(w, "A")
	check(on[1002] == 1 and off[1002] == 1, "the dead man's entry freed by his id: on " .. tostring(on[1002]) .. ", off "
		.. tostring(off[1002]))
	check(on[next_man] == 1 and off[next_man] == nil, "the next man guarded")
	w:tap("A", "F2")
	w:run(0.3)
	on, off = guard_ids(w, "A")
	check(off[next_man] == 1 and off[1002] == 1, "the stop frees the next man's, and the dead man's not again: "
		.. tostring(off[next_man]) .. ", " .. tostring(off[1002]))
	check(w:diverged() == nil, tostring(w:diverged()))
end

T.ls_the_stop_after_the_guarded_man_died_unguards_him = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:run(0.5)
	w:on("A", function() H.units[1]._models[1].hp = 0 end)
	w:on("B", function() H.enemies[1]._models[1].hp = 0 end)
	w:run(0.5)
	w:on("A", function() check(not H.E.F.on, "his unit lost: the session stopped") end)
	local on, off = guard_ids(w, "A")
	check(on[1001] == 1 and off[1001] == 1, "GUARD_OFF for the dead man at the stop: on " .. tostring(on[1001]) .. ", off "
		.. tostring(off[1001]))
	w:tap("A", "F2")
	w:run(0.3)
	on, off = guard_ids(w, "A")
	check(off[1001] == 1, "once: " .. tostring(off[1001]))
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- a uc: command for a unit whose only man has no health is dropped, by the same rule as the man's own commands
T.ls_a_uc_command_for_a_dead_unit_is_dropped = function()
	local w = L.new({})
	w:on("A", function() H.units[1]._models[1].hp = 0 end)
	w:on("B", function() H.enemies[1]._models[1].hp = 0 end)
	w:on("A", function() create_unitcontroller(H.units[1]):halt() end)
	w:run(0.3)
	for _, n in ipairs({"A", "B"}) do
		local a
		for _, x in ipairs(w:applied(n)) do if x.kind ~= "hello" then a = x break end end -- past the world's handshake
		check(a and a.kind == "dropped" and a.fields.kind == "uc", n .. ": " .. tostring(a and a.kind))
	end
end

T.ls_both_play_at_once = function()
	local w = L.new({})
	for _, n in ipairs({"A", "B"}) do w:tap(n, "F2") w:on(n, function() H.down("W") end) end
	w:run(3.0)
	-- walking straight he is turned by his move's own heading: no follow is sent, and no play without a click
	for _, n in ipairs({"A", "B"}) do
		local k = sent_kinds(w, n)
		for _, kind in ipairs({"move", "carrier:GUARD_ON", "carrier:DISARM"}) do check(k[kind], n .. " sent no " .. kind) end
	end
	check(ran_move(w, "B", 1001) and ran_move(w, "A", 2001), "each engine ran the other's moves")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- the swap set is measured, not listed: what loading the mod adds to _G, and anything a machine adds later
T.ls_a_new_global_cannot_leak = function()
	local w = L.new({machines = {{name = "A", fps = 60, army = 1, fresh = {mct = {}}}, {name = "B", fps = 40, army = 2, pairs = "reverse"}}})
	local a_mod
	w:on("A", function() a_mod = DERPY_TP check(get_mct ~= nil and a_mod == H.E, "A has its MCT and its mod") end)
	w:on("B", function() check(get_mct == nil, "B never sees A's MCT") check(DERPY_TP == H.E and DERPY_TP ~= a_mod, "B has its own mod") end)
	w:on("A", function() DERPY_TP_LEAK = 1 end)
	w:on("B", function() check(DERPY_TP_LEAK == nil, "B never sees a global A made") end)
	w:run(0.2)
	w:on("A", function() check(DERPY_TP_LEAK == 1, "A keeps it") end)
	w:on("B", function() check(DERPY_TP_LEAK == nil, "not after a tick either") end)
end

-- a peer without the mod writes the carrier's global and reads nothing: the oracle sees the desync. A never starts against
-- such a peer (ls_a_peer_without_the_mod_is_never_sent_to), so its platform guards directly here
T.ls_a_peer_without_the_mod_ignores_carriers = function()
	local w = L.new({hello = false, machines = {{name = "A", fps = 60, army = 1}, {name = "B", fps = 40, army = 2, mod = false}}})
	w:on("A", function() H.P.guard(H.units[1]._models[1]) end)
	w:run(0.5)
	local ignored = 0
	for _, a in ipairs(w:applied("B")) do if a.kind == "carrier_ignored" then ignored = ignored + 1 end end
	check(ignored > 0, "B ignores the carriers")
	check(w:diverged() and w:diverged():find("carrier_ignored"), tostring(w:diverged()))
end

-- the oracle's own tests: a change made on one machine only is reported, whichever path it took --------------------

-- hello = false: nobody presses F2, so no machine says HELLO and no gate goes in (Ruling 26); these tests are about one
-- call each
local UNROUTED = {hello = false, machines = {{name = "A", fps = 60, army = 1, route = false}, {name = "B", fps = 40, army = 2, pairs = "reverse"}}}

-- the platform writing on its own machine instead of queuing: each call alone, then the mod playing
T.ls_oracle_sees_unrouted_platform_calls = function()
	local calls = {
		steer = function(m) H.P.steer(m, 5, 5, false, 1.0, 1) end,
		hold = function(m) H.P.hold(m, 0, 0, 1.0) end,
		face = function(m) H.P.face(m, 1.0) end,
		play = function(m) H.P.play(m, 454, 6) end,
		guard = function(m) H.P.guard(m) end,
		disarm = function(m) H.P.disarm(m, true, false) end,
		arm = function(m) H.P.arm(m) end,
	}
	for _, name in ipairs({"steer", "hold", "face", "play", "guard", "disarm", "arm"}) do
		local w = L.new(UNROUTED)
		w:on("A", function() calls[name](H.units[1]._models[1]) end)
		w:run(0.3)
		local d = w:diverged() -- the man's own state when the call changes it, else the recorded call
		check(d and (d:find("man 1001") or d:find("call " .. name)), name .. ": " .. tostring(d))
		check(#w:sent("A") == 0, name .. " was not queued")
		check(#w:gates("A") == 0 and #w:gates("B") == 0, name .. ": nobody pressed, so no gate on either machine")
	end
	-- then the mod playing unrouted. Both players press: A's HELLO lands on A alone and B's on both, so A's half of the
	-- handshake completes and A starts, and B's never does. A's gate alone goes in, a one-sided write this world allows so
	-- that what is caught is the playing. The control: the same world with nobody pressing stays in step
	local PLAY = {hello = false, allow = {gate = "A's half handshake, unrouted"}, machines = UNROUTED.machines}
	local w = L.new(PLAY)
	w:run(3.0)
	check(w:diverged() == nil, "nobody pressing: in step, " .. tostring(w:diverged()))
	w = L.new(PLAY)
	w:tap("A", "F2")
	w:tap("B", "F2")
	w:run(1.0)
	local playing
	w:on("A", function() playing = H.E.F.on end)
	check(playing, "A plays")
	w:on("A", function() H.down("W") end)
	w:run(2.0)
	check(w:diverged(), "the mod playing unrouted")
end

-- battle calls outside the platform: one-sided they are reported; the recorded ones, queued, land on both
T.ls_oracle_sees_one_sided_battle_calls = function()
	local function first(opts, fn)
		local w = L.new(opts)
		w:on("A", fn)
		w:run(0.3)
		return w, w:diverged()
	end
	local man = function() return H.units[1]._models[1] end
	local _, d = first({}, function() H.P.place(man(), 5, 5) end) -- never routed: a direct write
	check(d and d:find("x=5.000"), "place: " .. tostring(d))
	local u
	u, d = first(UNROUTED, function() bm:trigger_projectile_launch("test_shot", v(0, 0, 0), v(0, 0, 10)) end)
	check(d and d:find("call launch"), "launch: " .. tostring(d))
	check(#u:gates("A") == 0, "launch: nobody pressed, so no gate")
	u, d = first(UNROUTED, function() H.units[1]:set_current_ammo_unary(0.5) end)
	check(d and d:find("set_ammo"), "set_ammo: " .. tostring(d))
	check(#u:gates("A") == 0, "set_ammo: nobody pressed, so no gate")
	_, d = first({}, function() H.units[1]._ammo = 3 end) -- a write to the unit itself
	check(d and d:find("ammo=3"), "ammo: " .. tostring(d))
	-- the gate goes in on every machine at the handshake's tick, so one machine's script setting it is a one-sided write
	-- like the rest; the allowance mechanism stays for the next entry
	check(L.ALLOW.gate == nil, "the gate needs no allowance: it goes in on both machines at one tick")
	_, d = first({}, function() H.P.gate(true) end)
	check(d and d:find("call gate"), "gate: " .. tostring(d))
	_, d = first({allow = {gate = "a test's allowance"}}, function() H.P.gate(true) end)
	check(d == nil, "an allowance still lets a write through: " .. tostring(d))
	-- routed, the engine records them: queued, and applied on both
	local w
	w, d = first({}, function()
		bm:trigger_projectile_launch("test_shot", v(0, 0, 0), v(0, 0, 10))
		H.units[1]:set_current_ammo_unary(0.5)
	end)
	check(d == nil, "queued: " .. tostring(d))
	for _, n in ipairs({"A", "B"}) do
		local k = {}
		for _, a in ipairs(w:applied(n)) do k[a.kind] = true end
		check(k.bm and k.unit, n .. " applied both")
	end
end

-- a man picked with the machine's own pairs and written directly: B's pairs runs in reverse, so B picks another man
local function pick_with_pairs()
	local men = {}
	for _, list in ipairs({H.units, H.enemies}) do for _, u in ipairs(list) do men[#men + 1] = u._models[1] end end
	table.sort(men, function(a, b) return a.id < b.id end)
	for _, m in H.env.pairs(men) do return m end
end

T.ls_oracle_sees_pairs_order = function()
	local w = L.new({})
	local picked = {}
	for _, n in ipairs({"A", "B"}) do w:on(n, function() local m = pick_with_pairs() picked[n] = m.id m.x = 77 end) end
	w:run(0.2)
	check(picked.A ~= picked.B, "A and B picked different men")
	check(w:diverged() and w:diverged():find("x=77"), tostring(w:diverged()))
	-- the control: with B's pairs in order, both pick the same man and nothing diverges
	w = L.new({machines = {{name = "A", fps = 60, army = 1}, {name = "B", fps = 40, army = 2, pairs = "normal"}}})
	for _, n in ipairs({"A", "B"}) do w:on(n, function() pick_with_pairs().x = 77 end) end
	w:run(0.2)
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- what the mod sends in net mode -------------------------------------------------------------------------------------

T.ls_at_most_one_move_per_tick = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:on("A", function() H.down("W") end)
	w:run(1.0)
	local n = 0
	for _, c in ipairs(w:sent("A")) do if c.kind == "move" then n = n + 1 end end
	check(n >= 1 and n <= 11, "at most one move per man per 100 ms tick, got " .. n)
end

-- the later command per man per tick wins (record, "The overrides, live"): W held while clicking must not eat the swing
T.ls_a_swing_is_not_cancelled_by_a_move_in_its_tick = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:on("A", function() H.down("W") end)
	w:run(0.5)
	w:tap("A", "Left mouse")
	w:run(1.5)
	for _, n in ipairs({"A", "B"}) do
		local played = false
		for _, a in ipairs(w:applied(n)) do if a.kind == "play" then played = true end end
		check(played, n .. " played the swing")
	end
	check(w:diverged() == nil, tostring(w:diverged()))
end

T.ls_a_swing_survives_the_queue_delay = function()
	local w = L.new({delay_ticks = 4})
	w:tap("A", "F2")
	w:tap("A", "Left mouse")
	w:run(1.5)
	for _, n in ipairs({"A", "B"}) do
		local played = false
		for _, a in ipairs(w:applied(n)) do if a.kind == "play" then played = true end end
		check(played, n .. " played the swing")
	end
end

-- a queue slower than the swing lock's one-tick window (combat.lua LOCK_WAIT, 1 s): the lock waits P.net_delay more for
-- the clip to show, so he is not turned, stepped or disarmed under a swing still in the queue
T.ls_a_slow_queue_keeps_the_swing_locked_until_it_shows = function()
	local w = L.new({delay_ticks = 11})
	w:tap("A", "F2")
	w:tap("A", "Left mouse")
	w:run(1.0) -- 1.1 s after the click: past LOCK_WAIT, inside it and P.net_delay
	w:on("A", function() check(H.E.F.lock and H.E.F.lock.m and not H.E.F.lock.seen, "still waiting for the clip") end)
	w:run(0.1)
	w:on("A", function() check(H.E.F.lock and H.E.F.lock.seen, "the clip showed inside the lock") end)
end

-- the disarm goes when its kind changes, not each frame: walking, then a swing arms him for its clip, then he is disarmed again
T.ls_disarm_is_sent_on_change_only = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:on("A", function() H.down("W") end)
	w:run(2.0)
	local k = sent_kinds(w, "A")
	check(k["carrier:DISARM"] == 1 and not k["carrier:ARM"], "one disarm while walking, got " .. tostring(k["carrier:DISARM"]))
	w:on("A", function() H.up("W") end)
	w:tap("A", "Left mouse")
	w:run(6.0)
	k = sent_kinds(w, "A")
	check(k["carrier:ARM"] == 1 and k["carrier:DISARM"] == 2, "armed for the swing and disarmed after, got "
		.. tostring(k["carrier:ARM"]) .. " and " .. tostring(k["carrier:DISARM"]))
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- a clip held parked (a block, a melee without the gate) is destroyed by any later action for him, on every machine: the
-- face that turns him to the crosshair until the clip shows must wait for it. However long it is parked: the wait ends
-- when it shows or at its give-up, not after the queue's delay, which cancels (the record's Ruling 19)
T.ls_a_parked_swing_is_not_replaced_by_a_later_face = function()
	for _, park in ipairs({3, 4, 8}) do
		local w = L.new({park_ticks = park})
		w:tap("A", "F2")
		w:run(0.5)
		-- the camera turned, and he is still turning to it (each FOLLOW lands two ticks on): the lock faces him to the swing's
		-- facing until the clip shows
		w:on("A", function() H.mouse = {300, 0} end)
		w:run(0.3)
		w:tap("A", "Left mouse")
		w:run(1.5)
		for _, n in ipairs({"A", "B"}) do
			local played, lost = false, false
			for _, a in ipairs(w:applied(n)) do
				if a.kind == "play" then played = true end
				if a.kind == "superseded" and a.fields.kind == "play" then lost = true end
			end
			check(played and not lost, "parked " .. park .. " ticks: " .. n .. " played the swing, never replaced")
		end
		check(w:diverged() == nil, "parked " .. park .. " ticks: " .. tostring(w:diverged()))
	end
end

-- the ticks from a click to A's first MOVE, W held from the click, for a unit of one whose swing (ATTACK_1) runs 1 s; nil,
-- none in 4.5 s
local function first_move_after_a_swing(opts)
	opts.armies = {{{general = true, clip_ms = {[454] = 1000}}}, {{general = true, z = 300}}}
	local w = L.new(opts)
	w:tap("A", "F2")
	w:run(0.5)
	w:on("A", function() H.down("W") H.down("Left mouse") end)
	w:tick()
	w:on("A", function() H.up("Left mouse") end)
	local click, seen = w.t, #w:sent("A")
	check(seen > 0 and w:sent("A")[seen].kind == "play", "the click's swing went: " .. tostring(w:sent("A")[seen].kind))
	for _ = 1, 45 do
		w:tick()
		local s = w:sent("A")
		for i = seen + 1, #s do if s[i].kind == "move" then return w.t - click, w end end
		seen = #s
	end
	return nil, w
end

-- a swing that played and ended lets him walk again as it ends, though nothing was sent for him while it played: by
-- 13 ticks after the click for a 1 s clip, not at the give-up (32 ticks)
T.ls_he_walks_again_once_his_swing_has_played = function()
	local t, w = first_move_after_a_swing({})
	check(t and t <= 13, "the first MOVE " .. tostring(t) .. " ticks after the click; the 1 s clip ended 12 after it")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- a swing that never shows still holds his steps to its give-up, LOCK_MAX and the delay from the click (the record's
-- Ruling 22): parked past it, a MOVE any sooner would replace it
T.ls_a_swing_that_never_shows_holds_his_steps_to_its_give_up = function()
	local t, w = first_move_after_a_swing({park_ticks = 40})
	check(t and t >= 32 and t <= 34, "the first MOVE " .. tostring(t) .. " ticks after the click, its give-up 32")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- a rider is steered, held, faced and guarded through his mount: a MOVE naming the rider is done at once (record O2) and
-- a cavalry lord would not move. The armies opt has no mounts: the same mount, id 9001, is put under man 1001 on both
local function mounted(w)
	w:on("A", function() H.units[1]._models[1].mount = {id = 9001, x = 0, y = 0, z = 0, hp = 100, hp_max = 100} end)
	w:on("B", function() H.enemies[1]._models[1].mount = {id = 9001, x = 0, y = 0, z = 0, hp = 100, hp_max = 100} end)
end

T.ls_a_mounted_man_is_driven_through_his_mount = function()
	local w = L.new({})
	mounted(w)
	w:tap("A", "F2")
	w:run(0.5)
	w:on("A", function() H.mouse = {300, 0} end) -- standing, turned: a FOLLOW
	w:run(0.5)
	w:on("A", function() H.down("W") end)
	w:run(0.5)
	local by = {}
	for _, c in ipairs(w:sent("A")) do
		local kind = c.kind == "carrier" and c.fields.op or c.kind
		by[kind] = by[kind] or {}
		by[kind][c.model_id] = true
	end
	for _, kind in ipairs({"halt", "follow", "move", "GUARD_ON"}) do
		check(by[kind] and by[kind][9001] and not by[kind][1001], kind .. " names the mount alone")
	end
	check(by.DISARM and by.DISARM[9001] and by.DISARM[1001], "the disarm names both, as single player's")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- standing: one HALT, then a FOLLOW only when his heading changes
T.ls_a_standing_man_gets_one_halt_and_turns_on_change = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:run(2.0)
	local k = sent_kinds(w, "A")
	check(k.halt == 1, "one halt, got " .. tostring(k.halt))
	local f = k.follow or 0
	check(f <= 1, "no follow while his heading stands, got " .. f)
	w:on("A", function() H.mouse = {300, 0} end)
	w:run(1.0)
	k = sent_kinds(w, "A")
	check((k.follow or 0) > f, "a follow as the camera turns him")
	check(k.halt == 1, "and still one halt, got " .. tostring(k.halt))
end

-- what the rules kept of a session goes with it: the next session's first hold stops him anew
T.ls_each_session_stops_him_anew = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:run(1.0)
	w:tap("A", "F2")
	w:run(0.5)
	w:tap("A", "F2")
	w:run(1.0)
	local k = sent_kinds(w, "A")
	check(k.halt == 2, "a halt each session, got " .. tostring(k.halt))
end

T.ls_guard_is_sent_once_per_session = function()
	local w = L.new({})
	w:tap("A", "F2")
	w:run(2.0)
	w:tap("A", "F2")
	w:run(0.5)
	local on, off = 0, 0
	for _, c in ipairs(w:sent("A")) do
		if c.kind == "carrier" and c.fields.op == "GUARD_ON" then on = on + 1 end
		if c.kind == "carrier" and c.fields.op == "GUARD_OFF" then off = off + 1 end
	end
	check(on == 1 and off == 1, "one on, one off, got " .. on .. " and " .. off)
end

-- the order gate -----------------------------------------------------------------------------------------------------
-- It patches one branch in the game's code and changes the simulation: a man's queued action beats the order his regiment
-- gives him each tick. Every machine puts it in at the tick the last HELLO landed (platform.lua M.handshake) and keeps it
-- to the end of the battle; one machine setting it at a key press is a desync in the first melee.

local function gate_text(g)
	local t = {}
	for _, e in ipairs(g) do t[#t + 1] = (e.on and "in" or "out") .. "@" .. e.tick end
	return "[" .. table.concat(t, " ") .. "]"
end

T.ls_the_gate_goes_in_at_one_tick_and_stays = function()
	local w = L.new({})
	local at = w:gates("A")[1]
	check(at and at.on and at.tick > 0, "A's gate in at the handshake, not at build: " .. gate_text(w:gates("A")))
	local function held(when)
		for _, n in ipairs({"A", "B"}) do
			local g = w:gates(n)
			check(#g == 1 and g[1].on and g[1].tick == at.tick, when .. ": " .. n .. " has the gate in from tick " .. at.tick
				.. " and no change after, got " .. gate_text(g))
		end
	end
	held("before any key")
	-- a session, it ends, then a second one still on as the battle ends
	w:tap("A", "F2")
	w:run(1.0)
	w:tap("A", "F2")
	w:run(0.5)
	w:tap("A", "F2")
	w:run(1.0)
	held("before Complete")
	for _, n in ipairs({"A", "B"}) do w:on(n, function() H.phase.Complete() end) end
	w:run(0.3)
	held("at Complete") -- the next battle's build puts the game's own branch back, and its handshake the gate (platform.lua)
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- Measured live: in a lasting melee a MOVE sent every tick never starts without the gate and starts with it. The man is A's
-- own on A and in the other army on B, in melee on both
T.ls_a_move_in_melee_needs_the_gate = function()
	local function walk(gate)
		local w = L.new({gate = gate})
		w:on("A", function() H.units[1]._models[1].in_melee = true end)
		w:on("B", function() H.enemies[1]._models[1].in_melee = true end)
		w:tap("A", "F2")
		w:on("A", function() H.down("W") end)
		w:run(2.0)
		return w
	end
	local function count(w, n, kind)
		local k, first = 0, nil
		for _, a in ipairs(w:applied(n)) do
			if a.kind == kind and a.model_id == 1001 then k = k + 1 first = first or a.tick end
		end
		return k, first
	end
	local out = walk(false)
	check(sent_kinds(out, "A").move, "A sent moves")
	for _, n in ipairs({"A", "B"}) do
		local ran = count(out, n, "move")
		local reset = count(out, n, "reset")
		check(ran == 0 and reset > 0, "gate out: " .. n .. " ran " .. ran .. " moves and reset " .. reset)
	end
	check(out:diverged() == nil, "gate out on both: " .. tostring(out:diverged()))
	local w = walk(true)
	local ran_a, at_a = count(w, "A", "move")
	local ran_b, at_b = count(w, "B", "move")
	check(ran_a > 0 and ran_a == ran_b and at_a == at_b, "gate in: A ran " .. ran_a .. " moves from tick " .. tostring(at_a)
		.. ", B " .. ran_b .. " from tick " .. tostring(at_b))
	check(count(w, "A", "reset") == 0 and count(w, "B", "reset") == 0, "gate in: nothing is reset")
	check(w:diverged() == nil, "gate in on both: " .. tostring(w:diverged()))
end

-- the HELLO handshake (platform.lua M.handshake, the feasibility record's Rulings 25 and 26) ------------------------------
-- Net play and the gate wait until every human army's machine has said HELLO. A machine says one, for its own army, once
-- its player has pressed F2 or another army's HELLO has landed, and only once its copy table is built; the carrier cave
-- sets that army's bit on every machine at one tick. The press is kept, and starts third person when the handshake
-- completes; the player is told to wait only once the handshake is 5 model s late (platform.lua HELLO_WAIT)

local NEEDS = "derpy_tp_mp_needs_everyone"

-- how many times machine n's player was shown key
local function said(w, n, key)
	local k = 0
	w:on(n, function() for _, s in ipairs(H.all("subtitle")) do if s[2] == key then k = k + 1 end end end)
	return k
end

local function hellos(w, n)
	local k = 0
	for _, c in ipairs(w:sent(n)) do if c.kind == "carrier" and c.fields.op == "HELLO" then k = k + 1 end end
	return k
end

-- what machine n sent that acts on a man: everything but a HELLO
local function sent_for_men(w, n)
	local t = {}
	for _, c in ipairs(w:sent(n)) do if not (c.kind == "carrier" and c.fields.op == "HELLO") then t[#t + 1] = c.kind end end
	return t
end

local function on(w, n) local r w:on(n, function() r = H.E.F.on end) return r end

-- the subtitle line machine n's player sees, its needs-everyone text given as "no answer from %s."
local function loc_names(w, n) w:on(n, function() H.loc[NEEDS] = "no answer from %s." end) end
local function line(w, n)
	local t
	w:on(n, function() local c = find_uicomponent(H.root, "scripted_subtitles", "text_child") t = c and c.text end)
	return t
end
local function logged(w, n, text)
	local k = 0
	w:on(n, function() for _, l in ipairs(H.log) do if l:find(text, 1, true) then k = k + 1 end end end)
	return k
end

local MIXED = {hello = false, machines = {{name = "A", fps = 60, army = 1}, {name = "B", fps = 40, army = 2, mod = false}}}

-- B has no mod, and nobody presses F2: A has the mod installed and forges nothing at all, not even a HELLO, so nothing
-- of A's reaches B's battle
T.ls_a_mixed_lobby_where_nobody_presses_carries_nothing = function()
	local w = L.new(MIXED)
	w:run(6.0)
	check(#w:sent("A") == 0, "A sent nothing: " .. #w:sent("A"))
	check(#w:gates("A") == 0, "the gate never went in on A: " .. gate_text(w:gates("A")))
	check(said(w, "A", NEEDS) == 0, "and nobody was told anything")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- B has no mod: A's press sends one HELLO, which nobody answers, so A never starts. A's player is told once the handshake
-- is 5 s late, not before, and nothing of A's reaches B but that HELLO, which changes no battle state on either machine
-- (tools/third_person_lockstep.lua deliver): the battles stay in step
T.ls_a_peer_without_the_mod_is_never_sent_to = function()
	local w = L.new(MIXED)
	w:run(1.0)
	w:tap("A", "F2")
	w:on("A", function() H.down("W") end)
	w:run(4.5)
	check(hellos(w, "A") == 1, "A's press said HELLO, once: " .. hellos(w, "A"))
	check(said(w, "A", NEEDS) == 0, "not told before the handshake is late")
	loc_names(w, "A")
	w:run(1.0)
	check(said(w, "A", NEEDS) == 1, "told once it is: " .. said(w, "A", NEEDS))
	check(line(w, "A") == "no answer from Player B.", "B named: " .. tostring(line(w, "A")))
	check(not on(w, "A"), "A never started")
	check(#sent_for_men(w, "A") == 0, "A sent nothing for a man: " .. table.concat(sent_for_men(w, "A"), " "))
	check(#w:gates("A") == 0, "the gate never went in on A: " .. gate_text(w:gates("A")))
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- a second press while one is kept is ignored (the record's Ruling 29): it sends nothing, restarts no clock and adds no
-- message (the one message comes 5 s after the first press), and the kept press still starts third person when the
-- handshake completes. With B unmodded the handshake never completes; with B modded, a second press made before B's
-- answer lands leaves A to start by itself
T.ls_a_second_press_while_waiting_sends_nothing = function()
	local w = L.new(MIXED)
	w:tap("A", "F2")
	w:run(2.0)
	local sent = #w:sent("A")
	check(sent == 1 and hellos(w, "A") == 1, "the first press said HELLO: " .. sent)
	w:tap("A", "F2")
	w:run(2.5)
	check(#w:sent("A") == sent, "the second press sent nothing: " .. #w:sent("A") - sent .. " more")
	check(said(w, "A", NEEDS) == 0, "and said nothing")
	w:run(1.0)
	check(said(w, "A", NEEDS) == 1, "told 5 s after the first press, not the second: " .. said(w, "A", NEEDS))
	w:tap("A", "F2")
	w:run(1.0)
	check(#w:sent("A") == sent and said(w, "A", NEEDS) == 1, "a third press after it: nothing more")
	check(not on(w, "A") and w:diverged() == nil, tostring(w:diverged()))
	w = L.new({hello = false})
	w:tap("A", "F2")
	w:tick()
	w:tap("A", "F2") -- before B's answer has landed
	w:run(1.0)
	local ga, gb = w:gates("A"), w:gates("B")
	check(#ga == 1 and #gb == 1 and ga[1].tick == gb[1].tick, "the handshake completed: " .. gate_text(ga) .. " " .. gate_text(gb))
	check(on(w, "A"), "the kept press still starts third person, with no third press")
	check(hellos(w, "A") == 1, "one HELLO for the two presses: " .. hellos(w, "A"))
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- a spectating client with the pack (CA: battle:is_spectator()) never starts third person, by a press before the
-- handshake or after it, and forges nothing but its HELLO: its machine runs the battle, so it answers the players' and
-- the gate waits for it (Ruling 30), going in on every machine at one tick (Ruling 27)
T.ls_a_spectator_never_starts = function()
	local w = L.new({hello = false, machines = {{name = "A", fps = 60, army = 1}, {name = "B", fps = 40, army = 2, pairs = "reverse"},
		{name = "S", fps = 50, army = 1, spectator = true}}})
	w:tap("S", "F2")
	w:run(1.0)
	check(not on(w, "S") and #w:sent("S") == 0, "S's press before the handshake: nothing kept, nothing sent")
	check(#w:sent("A") == 0 and #w:sent("B") == 0, "and no machine asked to say HELLO")
	w:tap("A", "F2")
	w:run(1.0)
	check(on(w, "A"), "the players' handshake completes, and A starts")
	local ga, gs = w:gates("A"), w:gates("S")
	check(#ga == 1 and #gs == 1 and gs[1].on and gs[1].tick == ga[1].tick, "S's gate in at the players' tick: "
		.. gate_text(ga) .. " " .. gate_text(gs))
	check(not on(w, "S"), "S's earlier press was never kept")
	w:tap("S", "F2")
	w:run(0.5)
	check(not on(w, "S"), "nor does a press after it start S")
	check(#w:sent("S") == 1 and hellos(w, "S") == 1, "S forged its HELLO and nothing else: " .. #w:sent("S"))
	local gb = w:gates("B")
	check(#gb == 1 and gb[1].tick == ga[1].tick, "B's at that tick too: " .. gate_text(gb))
	check(logged(w, "S", "plays no army") == 1, "said once in S's log: " .. logged(w, "S", "plays no army"))
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- both have the mod and nobody has pressed: nothing is sent. A's press says HELLO, B answers by itself, and A starts
-- with no second press, both gates in at one tick. B, whose player pressed nothing, does not start, and starts at once on
-- its own press
T.ls_play_starts_once_everyone_said_hello = function()
	local w = L.new({hello = false})
	w:run(1.0)
	check(#w:sent("A") == 0 and #w:sent("B") == 0, "nobody pressed: nothing sent")
	w:tap("A", "F2")
	check(not on(w, "A"), "F2 before the handshake does not start it")
	w:run(1.0)
	check(hellos(w, "A") == 1 and hellos(w, "B") == 1, "A's press said HELLO, and B answered by itself: "
		.. hellos(w, "A") .. " " .. hellos(w, "B"))
	local ga, gb = w:gates("A"), w:gates("B")
	check(#ga == 1 and ga[1].on and #gb == 1 and gb[1].on and ga[1].tick == gb[1].tick,
		"both HELLOs landed: the gate in on both at one tick, " .. gate_text(ga) .. " and " .. gate_text(gb))
	check(on(w, "A"), "A started by itself, with no second press")
	check(not on(w, "B"), "B's player pressed nothing")
	check(said(w, "A", NEEDS) == 0, "and nobody was told to wait")
	w:on("A", function() H.down("W") end)
	w:run(1.0)
	check(sent_kinds(w, "A").move, "A plays")
	w:tap("B", "F2")
	check(on(w, "B"), "B starts at its own press")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- B runs another build, whose HELLO carries another protocol version (here 1, the army-slot build of 2026-10-21 and 22):
-- no machine counts it, nor answers it, and nobody starts
T.ls_a_hello_of_another_version_is_not_counted = function()
	local w = L.new({hello = false, machines = {{name = "A", fps = 60, army = 1},
		{name = "B", fps = 40, army = 2, pairs = "reverse", hello_version = 1}}})
	w:tap("B", "F2")
	w:run(1.0)
	local b = w:sent("B")
	check(#b == 1 and b[1].kind == "carrier" and b[1].fields.lo == 1 * 256 + 1, "B said HELLO for its player, slot 1, version 1")
	check(#w:sent("A") == 0, "A did not answer it")
	for _, n in ipairs({"A", "B"}) do
		local dropped = false
		for _, a in ipairs(w:applied(n)) do if a.kind == "dropped" and a.fields.kind == "carrier" then dropped = true end end
		check(dropped, n .. " dropped B's HELLO")
	end
	w:tap("A", "F2")
	w:run(6.0)
	for _, n in ipairs({"A", "B"}) do check(#w:gates(n) == 0, n .. " never put the gate in: " .. gate_text(w:gates(n))) end
	check(not on(w, "A") and said(w, "A", NEEDS) == 1, "A cannot start, and is told")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- B's "Deployed" comes late (its table builder slower): it hears A's HELLO but answers only once its table is built, and
-- A cannot start until that answer lands, so no DISARM reaches a machine whose table is not built (the record's Ruling 23)
T.ls_a_late_copy_table_holds_everyone_back = function()
	local w = L.new({hello = false, machines = {{name = "A", fps = 60, army = 1},
		{name = "B", fps = 40, army = 2, pairs = "reverse", deployed = false}}})
	w:tap("A", "F2")
	w:run(2.0)
	check(hellos(w, "A") == 1 and hellos(w, "B") == 0, "A said HELLO, B not before its table")
	check(not on(w, "A"), "A cannot start before it")
	w:on("B", function() H.phase.Deployed() end)
	w:tick()
	check(hellos(w, "B") == 1, "B's HELLO once its table is built")
	check(not on(w, "A"), "nor while it is in the queue")
	w:run(0.5)
	local g = w:gates("A")
	check(#g == 1 and g[1].on, "it landed: the gate in, " .. gate_text(g))
	check(on(w, "A"), "and A starts, from its first press")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- a HELLO the queue did not take goes again on the next tick; once gone, never again
T.ls_a_lost_hello_push_goes_again = function()
	local w = L.new({hello = false, machines = {{name = "A", fps = 60, army = 1},
		{name = "B", fps = 40, army = 2, pairs = "reverse", hello_refusals = 3}}})
	w:tap("B", "F2")
	local refused = 0
	for _ = 1, 10 do
		w:on("B", function() refused = H.count("hello_refused") end)
		if refused > 0 then break end
		w:tick()
	end
	check(refused == 1 and hellos(w, "B") == 0, "the first push refused: " .. refused)
	w:run(1.0)
	w:on("B", function() refused = H.count("hello_refused") end)
	check(refused == 3 and hellos(w, "B") == 1, "refused on three ticks, then it went, once: " .. refused .. " " .. hellos(w, "B"))
	local ga, gb = w:gates("A"), w:gates("B")
	check(#ga == 1 and #gb == 1 and ga[1].tick == gb[1].tick, "the gate in on both at one tick: " .. gate_text(ga) .. " " .. gate_text(gb))
	check(on(w, "B"), "and B starts, from its press")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- a player list naming this machine alone would start it alone: refused on every machine, no HELLO, and the player told
-- the list is the trouble, with why in the log
T.ls_a_list_naming_only_this_machine_never_starts = function()
	local w = L.new({hello = false, players = "local"})
	w:tap("A", "F2")
	w:run(6.0)
	check(hellos(w, "A") == 0 and hellos(w, "B") == 0, "no HELLO from either")
	check(not on(w, "A") and said(w, "A", "derpy_tp_mp_no_players") == 1, "A cannot start, and is told the list is why")
	for _, n in ipairs({"A", "B"}) do check(#w:gates(n) == 0, n .. " never put the gate in: " .. gate_text(w:gates(n))) end
	check(logged(w, "A", "the player list cannot be used: it names 1 player") == 1, "the log says why")
	check(#sent_for_men(w, "A") == 0, "A sent nothing for a man")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- the report of 2026-10-22, a campaign battle against the AI: A plays the one human army, B (the partner, with the mod)
-- watches. Counting armies, it never started on either machine; counting players, A's press is answered by B's machine,
-- A starts, and B, watching, does not
T.ls_a_battle_against_the_ai_starts_with_the_partner_watching = function()
	local w = L.new({hello = false, machines = {{name = "A", fps = 60, army = 1}, {name = "B", fps = 40, army = 1, pairs = "reverse", spectator = true}}})
	w:tap("A", "F2")
	w:tap("B", "F2")
	w:run(1.0)
	check(hellos(w, "A") == 1 and hellos(w, "B") == 1, "A's HELLO, and B's answer: " .. hellos(w, "A") .. " " .. hellos(w, "B"))
	local ga, gb = w:gates("A"), w:gates("B")
	check(#ga == 1 and #gb == 1 and ga[1].tick == gb[1].tick, "the gate in on both at one tick: " .. gate_text(ga) .. " " .. gate_text(gb))
	check(on(w, "A") and not on(w, "B"), "A plays, B watches")
	check(said(w, "A", NEEDS) + said(w, "B", NEEDS) == 0, "nobody told to get the mod")
	w:on("A", function() H.down("W") end)
	w:run(1.0)
	check(sent_kinds(w, "A").move, "A plays")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- the partner joins on A's side with units A gave them (CA's IsPassiveParticipant): one army, two machines. Their
-- machine says HELLO and the handshake completes; A starts, the partner's F2 starts nothing
T.ls_a_partner_given_units_counts_and_does_not_start = function()
	local w = L.new({hello = false, machines = {{name = "A", fps = 60, army = 1}, {name = "B", fps = 40, army = 1, pairs = "reverse", passive = true}}})
	w:tap("A", "F2")
	w:run(1.0)
	check(on(w, "A") and hellos(w, "B") == 1, "B's machine answered, and A starts")
	w:tap("B", "F2")
	w:run(0.5)
	check(not on(w, "B"), "B's press starts nothing")
	check(logged(w, "B", "plays no army") == 1, "said once in B's log")
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- a watcher without the mod: their machine runs the battle and would not run A's commands, so nobody starts, and A's
-- player is told who did not answer
T.ls_a_watcher_without_the_mod_holds_everyone_back = function()
	local w = L.new({hello = false, machines = {{name = "A", fps = 60, army = 1}, {name = "B", fps = 40, army = 1, spectator = true, mod = false}}})
	loc_names(w, "A")
	w:tap("A", "F2")
	w:run(6.0)
	check(not on(w, "A") and #w:gates("A") == 0, "A never starts, the gate never in")
	check(line(w, "A") == "no answer from Player B.", "the watcher named: " .. tostring(line(w, "A")))
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- the network loses every HELLO (the forged command never runs on any machine): each player is told their own check
-- never came back, which no missing mod explains
T.ls_a_hello_the_network_loses_is_told_as_this_machines_own = function()
	local w = L.new({hello = false, drop = L.is_hello})
	w:tap("A", "F2")
	w:tap("B", "F2")
	w:run(6.0)
	check(#w.lost == 2, "both HELLOs lost: " .. #w.lost)
	for _, n in ipairs({"A", "B"}) do
		check(not on(w, n) and #w:gates(n) == 0, n .. " never starts")
		check(said(w, n, "derpy_tp_mp_no_route") == 1 and said(w, n, NEEDS) == 0, n .. " told its own check failed")
	end
	check(w:diverged() == nil, tostring(w:diverged()))
end

-- the host runs its own forged command and drops the client's: A is told B did not answer, B that its own did not land
T.ls_a_client_hello_the_host_drops = function()
	local w = L.new({hello = false, drop = function(c) return L.is_hello(c) and c.from == "B" end})
	loc_names(w, "A")
	w:tap("A", "F2")
	w:tap("B", "F2")
	w:run(6.0)
	check(not on(w, "A") and not on(w, "B"), "nobody starts")
	check(line(w, "A") == "no answer from Player B.", "A names B: " .. tostring(line(w, "A")))
	check(said(w, "B", "derpy_tp_mp_no_route") == 1, "B is told its own check failed")
	check(w:diverged() == nil, tostring(w:diverged()))
end

return T
