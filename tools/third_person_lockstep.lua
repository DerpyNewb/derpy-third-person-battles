-- The two-machine lockstep simulation for derpy_third_person: two (or more) copies of the shipped mod in one Lua
-- process, each with its own keys, frame rate, army and fake battle, sharing one fake command queue. Loaded by
-- tools/third_person_harness.lua after its own definitions; defines the global L. Not shipped.
--
-- A WH3 multiplayer battle is lockstep: every machine runs the same simulation and only queued commands reach every
-- machine. The oracle checks two things after every 100 ms tick. First, each machine's fake engine APPLIED the same
-- commands. Second, and the one that matters, each machine's fake BATTLE is the same: every man's place, heading,
-- health, clip, guard and disarm, every unit's order and behaviours, and the battle writes the fake records. A
-- write one machine makes outside the queue shows in the second, not the first. This proves the mod's discipline
-- (only the owner decides, every change goes through the queue, code run on both machines is order-independent, the
-- delay drops nothing), never the engine's.
--
-- Isolation: every harness function reads the global H when it is called. So each machine gets its own H, indexing the
-- harness's (H0), and swapping a machine in sets H and every global that is not in BASE (the keys of _G once this file
-- has loaded): what loading the mod added is measured after each H.fresh, and anything new is measured again at every
-- swap-out, so a global one machine creates is taken out of _G before the other runs.
local H0 = H
local M = H.platform_module()
local real_unitcontroller = create_unitcontroller

-- Measured live on ONE machine: every queued command takes effect two ticks after the script call.
-- PROVISIONAL until the two-machine figure is measured.
local DELAY_TICKS = 2
local TICK = 0.1 -- s: the battle's model tick

-- one parked action per man per tick, the later command wins (measured live: MOVE then clip, the clip plays; clip then MOVE,
-- the MOVE runs). HALT and FOLLOW are the same per-man override family and take the same holder (inferred, not measured).
local ACTIONS = {move = true, halt = true, follow = true, play = true}

-- battle calls outside the platform that the engine RECORDS (the feasibility record's Replay table: trigger_projectile_launch
-- and set_current_ammo_unary replayed at the same tick), so in net mode they are queued like a uc: call: kind "bm" or "unit"
local BM_QUEUED = {trigger_projectile_launch = true}
local UNIT_QUEUED = {set_current_ammo_unary = true}

-- the battle writes the fake records (H.calls), compared machine against machine each tick. Every uc: call is one too.
-- Not compared, because they are local to the player's own machine: the camera (terrain_floor, camera_*), the cursor
-- (look_begin, hide_cursor), the UI (vis, img, text, resize, rot, adopt, click, select_in_ui, clear_selection,
-- disable_orders, disable_shortcut, cinematic_ui, tooltips, banners, subtitle, hide_subtitles, cco*), and sound
-- (sound, taunt, voices_off)
local COMPARED = {steer = true, hold = true, face = true, play = true, guard = true, disarm = true, arm = true,
	place = true, gate = true, launch = true, set_ammo = true, slide = true, dropped_order = true}

-- L.ALLOW: the battle writes the mod still makes on one machine and a later change is to move onto every machine. Each
-- entry names the change; the entry goes when it lands. Never loosen the comparison instead.
L = {}
L.ALLOW = {} -- empty since the order gate went in on every machine at one tick; the mechanism stays for the next entry

-- an order for keys of any type: by type, then value (numbers, strings), else by text
local function key_less(a, b)
	local ta, tb = type(a), type(b)
	if ta ~= tb then return ta < tb end
	if ta == "number" or ta == "string" then return a < b end
	return tostring(a) < tostring(b)
end

-- B's pairs: keys in reverse sorted order, so any pairs in code both machines run decides differently on B
local function reverse_pairs(t)
	local keys = {}
	for k in next, t do keys[#keys + 1] = k end
	table.sort(keys, key_less)
	local i = #keys + 1
	return function()
		repeat i = i - 1 until i < 1 or t[keys[i]] ~= nil -- a key cleared during the loop is skipped, as next does
		if i >= 1 then return keys[i], t[keys[i]] end
	end, t, nil
end

-- a value as canonical text (sorted keys), so two machines' entries compare as strings. A unit is its id, a vector its
-- coordinates. round: numbers to the millimetre, for the battle snapshot only (A sums 6 x 1/60 a tick, B 4 x 1/40)
local function ser(x, round)
	if type(x) == "string" then return string.format("%q", x) end
	if type(x) == "number" then return string.format(round and "%.3f" or "%.17g", x) end
	if type(x) ~= "table" then return tostring(x) end
	if x.unique_ui_id then return "unit" .. tostring(x._id) end
	if x.get_x then return "(" .. ser(x.x, round) .. "," .. ser(x.y, round) .. "," .. ser(x.z, round) .. ")" end
	local keys = {}
	for k in next, x do keys[#keys + 1] = k end
	table.sort(keys, key_less)
	local parts = {}
	for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. ser(x[k], round) end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function deep(x)
	if type(x) ~= "table" then return x end
	local t = {}
	for k, val in next, x do t[k] = deep(val) end
	return t
end

-- what crosses the wire: a command names men and units by id and points by value, never by this machine's objects
local function wire(x)
	if type(x) ~= "table" then return x end
	if x.unique_ui_id then return {unit = x:unique_ui_id()} end
	if x.get_x then return {vec = {x.x, x.y, x.z}} end
	error("an argument that cannot cross the wire: " .. ser(x))
end

local function wire_args(...)
	local n, args = select("#", ...), {}
	for i = 1, n do args[i] = wire((select(i, ...))) end
	return {args = args, n = n}
end

local function routed() return H.net and not H.net_unrouted end

local function listof(items) return {count = function() return #items end, item = function(_, i) return items[i] end} end

-- the swap ------------------------------------------------------------------------------------------------------
local BASE -- set at the end of this file

local function leave(w, mc)
	for k in next, _G do if not BASE[k] then w.keys[k] = true end end
	for k in next, w.keys do mc.g[k] = rawget(_G, k) end
	for k in next, w.keys do rawset(_G, k, nil) end
	H = H0
end

local function with(w, mc, fn, ...)
	for k in next, w.keys do rawset(_G, k, mc.g[k]) end
	H = mc.H
	local ok, err = pcall(fn, ...)
	leave(w, mc)
	if not ok then error(err, 0) end
end

-- the fake engine, run on every machine at delivery ----------------------------------------------------------------
local function units()
	local t = {}
	for _, list in ipairs({H.units, H.enemies, H.allies}) do for _, u in ipairs(list) do t[#t + 1] = u end end
	table.sort(t, function(a, b) return a._id < b._id end)
	return t
end

local function find_unit(id) for _, u in ipairs(units()) do if u._id == id then return u end end end

local function find_man(id)
	for _, u in ipairs(units()) do for _, m in ipairs(u._models) do
		if m.id == id then return m end
		if m.mount and m.mount.id == id then return m.mount end
	end end
end

local function dead(m) return m.alive == false or (m.hp or 1) <= 0 end

local function unit_alive(u) for _, m in ipairs(u._models) do if not dead(m) then return true end end return false end

-- the man or unit a command lands on, nil when it is missing (then it is dropped). A MOVE, HALT, FOLLOW or clip lands on a
-- dead man who still resolves: the handlers check only that his id resolved (BATTLE_ENGINE_RE section 13), and what the
-- engine then does with him is a live measurement (the feasibility record's Ruling 21). A carrier or a unit's call is
-- dropped for the dead too. A queued call's unit arguments are resolved too, and one missing drops it
local function target(c)
	if c.kind == "carrier" then
		local d = M.uncarrier(c.fields.hi, c.fields.lo)
		local m = d and find_man(d.id)
		return m and not dead(m) and m or nil
	end
	if ACTIONS[c.kind] then return find_man(c.model_id) end
	for i = 1, c.fields.n do
		local a = c.fields.args[i]
		if type(a) == "table" and a.unit and not find_unit(a.unit) then return nil end
	end
	if c.kind == "bm" then return bm end
	local u = find_unit(c.model_id)
	return u and unit_alive(u) and u or nil
end

local UNIT_ORIG = {} -- the harness's own battle_unit methods, filled when L.new wraps them

local function apply(c, x)
	local f, A = c.fields, H.P.apply
	if c.kind == "move" then A.move(x, f.x, f.z, f.run, f.yaw, f.speed)
	elseif c.kind == "halt" then A.halt(x, f.x, f.z, f.yaw)
	elseif c.kind == "follow" then A.follow(x, f.yaw)
	elseif c.kind == "play" then A.play(x, f.slot, f.mask)
	elseif c.kind == "carrier" then
		local d = M.uncarrier(f.hi, f.lo)
		if d.op == "GUARD_ON" then x.guarded = true
		elseif d.op == "GUARD_OFF" then x.guarded = nil
		elseif d.op == "DISARM" then x.disarmed = {shots = d.shots, charge = d.charge}
		elseif d.op == "ARM" then x.disarmed = nil end
		return "carrier", d
	else -- uc, unit, bm: the call as made, on this machine's objects
		local args = {}
		for i = 1, f.n do
			local a = f.args[i]
			if type(a) == "table" and a.unit then a = find_unit(a.unit) elseif type(a) == "table" and a.vec then a = v(a.vec[1], a.vec[2], a.vec[3]) end
			args[i] = a
		end
		local fn, self
		if c.kind == "uc" then self = real_unitcontroller(x) fn = self[f.method]
		elseif c.kind == "unit" then self, fn = x, UNIT_ORIG[f.method]
		else self, fn = x, H.ls.bm_orig[f.method] end
		if not pcall(fn, self, unpack(args, 1, f.n)) then return c.kind .. "_refused", f end
	end
	return c.kind, f
end

-- A lasting melee, measured live: his regiment orders him every tick, and his update resets an action queued for
-- him on a tick an order reached him, so it never starts, unless the order gate is in on THIS machine (platform.lua
-- P.gate). x.in_melee is that standing order: a test sets it on the same man on every machine, never at random
local function start(c, x, put, id)
	if ACTIONS[c.kind] and x.in_melee and not H.gate_on then put("reset", id, {kind = c.kind, fields = c.fields}) return end
	local kind, fields = apply(c, x)
	put(kind, id, fields)
end

-- w.park (opts.park_ticks): a delivered clip waits parked in his queued slot that many ticks before it starts (a block
-- holds one back, a melee without the gate too); an action for him delivered in the ticks between destroys it, on every
-- machine. It starts at the top of its tick, before that tick's commands land
local function deliver(w, due)
	local mc = H.ls
	local function put(kind, id, fields) mc.applied[#mc.applied + 1] = {tick = w.t, kind = kind, model_id = id, fields = deep(fields)} end
	local ids = {}
	for id in next, mc.parked do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local p = mc.parked[id]
		if p.start <= w.t then
			mc.parked[id] = nil
			local x = target(p.c)
			if x then start(p.c, x, put, id) else put("dropped", id, {kind = "play", fields = p.c.fields}) end
		end
	end
	local targets, last = {}, {}
	for i, c in ipairs(due) do
		targets[i] = target(c)
		if targets[i] and ACTIONS[c.kind] then last[c.model_id] = i end
	end
	for i, c in ipairs(due) do
		local p = ACTIONS[c.kind] and targets[i] and mc.parked[c.model_id]
		if p then mc.parked[c.model_id] = nil put("superseded", c.model_id, {kind = "play", fields = p.c.fields}) end
		local hello = c.kind == "carrier" and M.uncarrier(c.fields.hi, c.fields.lo)
		if hello and hello.op == "HELLO" then
			-- no man and no battle state on any machine: with the mod the cave sets the army's bit in its own block and skips
			-- the store, without it the word lands in RELOAD_TIME's global, which no code is known to read (BATTLE_ENGINE_RE.md
			-- section 13). The bit is the rule the cave follows: M.uncarrier's HELLO, which its selftest ties to the cave
			if mc.mod then H.heard[hello.id] = true end
			put("hello", c.model_id, hello)
		elseif c.kind == "carrier" and not mc.mod then
			put("carrier_ignored", c.model_id, M.uncarrier(c.fields.hi, c.fields.lo) or c.fields) -- the vanilla engine's unread global
		elseif not targets[i] then put("dropped", c.model_id, {kind = c.kind, fields = c.fields})
		elseif ACTIONS[c.kind] and last[c.model_id] ~= i then put("superseded", c.model_id, {kind = c.kind, fields = c.fields})
		elseif c.kind == "play" and w.park > 0 then
			mc.parked[c.model_id] = {c = c, start = w.t + w.park}
			put("parked", c.model_id, c.fields)
		else start(c, targets[i], put, c.model_id) end
	end
end

-- the battle as canonical lines, keyed by canonical ids: what the oracle compares machine against machine ----------
local function snapshot(mc, allow)
	local lines, ms = {}, H.model_ms()
	local function man(key, m)
		local slot = m.anim_slot -- as P.anim_slot reads it, which clears it lazily: only the owner reads, so the raw field differs
		if m.anim_end and ms >= m.anim_end and not H.anim_hold then slot = nil end
		lines[#lines + 1] = string.format("man %s x=%s z=%s yaw=%s hp=%s alive=%s anim=%s mask=%s guarded=%s disarmed=%s",
			key, ser(m.x, true), ser(m.z, true), ser(m.yaw, true), ser(m.hp, true), tostring(m.alive ~= false), tostring(slot),
			tostring(m.mask), tostring(m.guarded == true), ser(m.disarmed, true))
	end
	for _, u in ipairs(units()) do
		lines[#lines + 1] = string.format("unit %d ordered=%s faw=%s defend=%s ammo=%s invulnerable=%s",
			u._id, ser(u._ordered, true), tostring(u._faw), tostring(u._defend), ser(u._ammo, true), tostring(u._invulnerable))
		for _, m in ipairs(u._models) do
			man(tostring(m.id), m)
			if m.mount then man(tostring(m.mount.id or m.id .. ".mount"), m.mount) end
		end
	end
	for i = mc.mark + 1, #H.calls do
		local c = H.calls[i]
		if (COMPARED[c[1]] or c[1]:find("^uc:")) and not allow[c[1]] then
			local parts = {"call", c[1]}
			for k = 2, table.maxn(c) do parts[#parts + 1] = ser(c[k], true) end
			lines[#lines + 1] = table.concat(parts, " ")
		end
	end
	mc.mark = #H.calls
	return lines
end

-- the sender: every P.* change in net mode, every uc: call and every queued bm: / unit call lands here -------------
function H0.send(kind, model_id, fields)
	local mc, w = H.ls, H.world
	mc.seq = mc.seq + 1
	w.queue[#w.queue + 1] = {due = w.t + w.delay, from = mc.name, seq = mc.seq, kind = kind, model_id = model_id, fields = deep(fields)}
	mc.sent[#mc.sent + 1] = {kind = kind, model_id = model_id,
		fields = kind == "carrier" and M.uncarrier(fields.hi, fields.lo) or deep(fields)}
end

-- in net mode a unit controller's every call is queued with its method and arguments, and applied at delivery
function create_unitcontroller(u)
	if not routed() then return real_unitcontroller(u) end
	return setmetatable({_u = u}, {__index = function(_, method)
		return function(_, ...)
			local f = wire_args(...)
			f.method = method
			H.send("uc", u._id, f)
		end
	end})
end

-- the world ------------------------------------------------------------------------------------------------------
local W = {}
W.__index = W

function W:tick()
	self.t = self.t + 1
	local due, rest = {}, {}
	for _, c in ipairs(self.queue) do
		if self.drop and self.drop(c) then self.lost[#self.lost + 1] = c
		elseif c.due <= self.t then due[#due + 1] = c else rest[#rest + 1] = c end
	end
	self.queue = rest
	table.sort(due, function(a, b)
		if a.due ~= b.due then return a.due < b.due end
		if a.from ~= b.from then return a.from < b.from end
		return a.seq < b.seq
	end)
	for _, mc in ipairs(self.machines) do with(self, mc, deliver, self, due) end
	for _, mc in ipairs(self.machines) do with(self, mc, function() H.step(TICK) end) end
	-- the outcome: each machine's battle against the first's; the first difference is kept
	local shots = {}
	for k, mc in ipairs(self.machines) do with(self, mc, function() shots[k] = snapshot(mc, self.allow) end) end
	for k = 2, #shots do
		if self.state_diff then break end
		local a, b = shots[1], shots[k]
		for i = 1, math.max(#a, #b) do
			if a[i] ~= b[i] then
				self.state_diff = {tick = self.t, text = string.format("tick %d: %s has [%s], %s has [%s]", self.t,
					self.machines[1].name, a[i] or "nothing", self.machines[k].name, b[i] or "nothing")}
				break
			end
		end
	end
end

function W:run(seconds) for _ = 1, math.max(1, math.floor(seconds / TICK + 0.5)) do self:tick() end end

-- fn with machine `name` swapped in: setup, reads, H.down / H.up. Never H.tap or H.step: they move one clock alone
function W:on(name, fn) with(self, assert(self.by[name], "no machine " .. tostring(name)), fn) end

function W:tap(name, key)
	self:on(name, function() H.down(key) end)
	self:tick()
	self:on(name, function() H.up(key) end)
end

function W:sent(name) return self.by[name].sent end
-- whether a queued command is a HELLO (for opts.drop)
function L.is_hello(c) return c.kind == "carrier" and (M.uncarrier(c.fields.hi, c.fields.lo) or {}).op == "HELLO" end
function W:applied(name) return self.by[name].applied end

-- the order gate on machine `name`: one {tick, on} each time its build or its script set it, the build's first
function W:gates(name)
	local t = {}
	self:on(name, function() for i, g in ipairs(H.gates) do t[i] = {tick = g.ms / (TICK * 1000), on = g.on} end end)
	return t
end

-- a write on ONE machine's log: for the oracle's own test only
function W:inject(name, kind, model_id, fields)
	local log = self.by[name].applied
	log[#log + 1] = {tick = self.t, kind = kind, model_id = model_id, fields = fields}
end

local function entry_text(e) return e and string.format("tick %d %s %s %s", e.tick, e.kind, tostring(e.model_id), ser(e.fields)) or "nothing" end

-- nil, or the earliest difference between the first machine and another: in what their engines applied, or in their
-- battles after a tick. Names the tick and both sides
function W:diverged()
	local a, found = self.machines[1], nil
	for k = 2, #self.machines do
		local b = self.machines[k]
		for i = 1, math.max(#a.applied, #b.applied) do
			local x, y = a.applied[i], b.applied[i]
			local sx, sy = entry_text(x), entry_text(y)
			if sx ~= sy then
				local t = math.min(x and x.tick or math.huge, y and y.tick or math.huge)
				if not found or t < found.tick then
					found = {tick = t, text = string.format("tick %d: %s applied [%s], %s applied [%s]", t, a.name, sx, b.name, sy)}
				end
				break
			end
		end
	end
	if self.state_diff and (not found or self.state_diff.tick < found.tick) then found = self.state_diff end
	return found and found.text or nil
end

-- opts: machines = {{name, fps, army, mod = true, pairs = "normal" | "reverse", route = true, fresh = <H.fresh opts>,
-- deployed = true, hello_refusals = 0, hello_version, spectator, passive}, ...}, armies = {{<H.unit opts>, ...}, ...} (one
-- battle, the same on every machine, each army its own alliance), delay_ticks, park_ticks (deliver), allow (default
-- L.ALLOW), gate = false (every machine's gate goes in and changes nothing), players = "local" (each machine's player
-- list names it alone), drop (a function of a queued command: the network loses it before any machine runs it, kept in
-- w.lost), hello = false (the world starts before the HELLO handshake completes; by default the first machine with the
-- mod asks for it, as its player's F2 press would, and the others answer).
-- Every machine is a player in every machine's list (CA's network player list, platform.lua M.players), client id
-- "client_<name>", name "Player <name>", a machine without the mod too.
-- route = false: that machine's fake platform, unit controllers and recorded calls act locally, as in single player.
-- deployed = false: its "Deployed" waits for the test (H.phase.Deployed()). hello_refusals: its first pushes of a HELLO
-- are refused; hello_version: its HELLOs carry another protocol version (an older or newer build); spectator = true: a
-- client spectating the battle (bm:is_spectator(), its list entry spectating), seated on its army's side; passive = true: a
-- partner watching with units given to them (CA's IsPassiveParticipant), seated in its army
function L.new(opts)
	opts = opts or {}
	for k in next, _G do if not BASE[k] then rawset(_G, k, nil) end end -- the last world's globals
	H = H0
	local w = setmetatable({t = 0, delay = opts.delay_ticks or DELAY_TICKS, park = opts.park_ticks or 0, queue = {}, keys = {}, machines = {}, by = {},
		allow = opts.allow or L.ALLOW, drop = opts.drop, lost = {}}, W)
	local armies = opts.armies or {{{general = true}}, {{general = true, z = 300}}}
	-- one id per unit across the battle, army 1's first, so man 1001 is the same man on every machine
	local ids, n = {}, 0
	for a, list in ipairs(armies) do ids[a] = {} for i in ipairs(list) do n = n + 1 ids[a][i] = n end end
	local specs = opts.machines or {{name = "A", fps = 60, army = 1}, {name = "B", fps = 40, army = 2, pairs = "reverse"}}
	-- machine s's player list: every machine, s's own entry its local player (players = "local": s's alone)
	local function players_for(s)
		local t = {}
		for _, o in ipairs(specs) do
			if opts.players ~= "local" or o == s then
				t[#t + 1] = {id = "client_" .. o.name, name = "Player " .. o.name, me = o == s, spectating = o.spectator, passive = o.passive}
			end
		end
		return t
	end
	for _, s in ipairs(specs) do
		local mc = {name = s.name, fps = s.fps or 60, army = s.army or 1, mod = s.mod ~= false, sent = {}, applied = {}, parked = {}, seq = 0, g = {}}
		local h = setmetatable({}, {__index = H0})
		h.ls, h.world, h.net, h.net_unrouted, h.fps, h.next_unit = mc, w, true, s.route == false, mc.fps, n
		h.hello_refusals, h.hello_version = s.hello_refusals, s.hello_version
		h.net_gate = mc.mod and opts.gate ~= false
		-- the model clock is the ticks the world has run, as in the game, where it moves when a tick is processed: the sends
		-- of one tick read one model time. Counted off the frames, it moved at a frame inside the tick (H.fresh's first step
		-- is 1/60 s), and sends that read two model times landed in one tick
		function h.model_ms() return w.t * TICK * 1000 end
		h.env = setmetatable({cco = H0.env.cco, pairs = s.pairs == "reverse" and reverse_pairs or nil}, getmetatable(H0.env))
		function h.unit(o) -- the harness numbers units as it makes them; here every machine numbers one man alike
			local u = H0.unit(o)
			local id = o._ls_id
			if not id then h.next_unit = h.next_unit + 1 id = h.next_unit end
			u._id = id
			for i, m in ipairs(u._models) do m.id = id * 1000 + i end
			return u
		end
		mc.H = h
		local f = deep(s.fresh or {})
		f.units, f.enemies = {}, {}
		for a, list in ipairs(armies) do for i, o in ipairs(list) do
			o = deep(o)
			o._ls_id = ids[a][i]
			local into = a == mc.army and f.units or f.enemies
			into[#into + 1] = o
		end end
		f.mp = true -- a multiplayer battle, as the game reports it; H.net puts the fake platform in net mode
		f.spectator = s.spectator
		f.players = players_for(s)
		f.tick_ms = f.tick_ms or TICK * 1000
		if not mc.mod then f.memreader = false end -- a peer without the mod: it loads nothing that runs
		w.machines[#w.machines + 1], w.by[mc.name] = mc, mc
		with(w, mc, function()
			H.fresh(f)
			-- the recorded battle_unit and bm calls are queued; the battle_unit methods live on the harness's one metatable,
			-- wrapped once and passing straight through outside net mode
			local UNIT = units()[1] and getmetatable(units()[1])
			for method in next, UNIT and UNIT_QUEUED or {} do
				if not UNIT_ORIG[method] then
					UNIT_ORIG[method] = UNIT[method]
					UNIT[method] = function(u, ...)
						if not routed() then return UNIT_ORIG[method](u, ...) end
						local f2 = wire_args(...)
						f2.method = method
						H.send("unit", u._id, f2)
					end
				end
			end
			mc.bm_orig = {}
			for method in next, BM_QUEUED do
				mc.bm_orig[method] = bm[method]
				bm[method] = function(_, ...)
					if not routed() then return mc.bm_orig[method](bm, ...) end
					local f2 = wire_args(...)
					f2.method = method
					H.send("bm", nil, f2)
				end
			end
			bm.local_alliance = function() return mc.army end
			bm.local_army = function() return 1 end
			-- deployment is over on every machine before anyone plays: net play waits for it (platform.lua P.net_ready)
			if H.phase.Deployed and s.deployed ~= false then H.phase.Deployed() end
			mc.mark = #H.calls -- the battle is compared from here: each mod's own load is its machine's business
		end)
	end
	-- and every machine with the mod has had every player's HELLO, the gate in: net play waits for it (platform.lua
	-- M.handshake). It starts as a press does (P.net_asked, set by main.lua's M.start), on the first machine with the mod,
	-- with no session kept for it to start; the others answer that HELLO by themselves. The oracle compares those ticks too
	if opts.hello ~= false then
		for _, mc in ipairs(w.machines) do
			if mc.mod then with(w, mc, function() H.P.net_asked = true end) break end
		end
		local function waiting()
			for _, mc in ipairs(w.machines) do
				local done = true
				if mc.mod then with(w, mc, function() done = H.P.net_play == true end) end
				if not done then return true end
			end
		end
		for _ = 1, 30 do if not waiting() then break end w:tick() end
		if waiting() then error("the HELLO handshake did not complete in 30 ticks: hello = false starts before it") end
	end
	return w
end

BASE = {}
for k in next, _G do BASE[k] = true end
