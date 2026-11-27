-- 2026-11-27 sync kills (docs/sessions/HANDOFF_20261127_THIRD_PERSON_SYNC_KILLS.md). Loaded after zz_tp_live_20261108.lua
-- (_G.TPT), zz_tp_verify_20261125.lua (_G.TPY, Y.swing) and zz_tp_verify_20261127.lua (_G.TPZ, Z.chance). No string
-- library calls and no s:method(); every per-frame read is in a pcall. Times are battle time.
--
-- Q.watch_start(me_type, k): every frame, each man of my unit `me_type` and of the enemy unit T.enemy[k]: a matched combat
--   is an episode of P.matched(m) (his +0xb20 holds CA's matched-combat interaction, exe+3ad5918), with the slots he plays
--   in it (COMBAT_n from 534) and whether he was dead at its end. Also the cave's sync counts (P.synced) at start and now.
-- Q.watch_stop() / Q.watch_read()
local T = _G.TPT
if not (T and T.E) then return "load TPT first" end
local E = T.E
local P = E.P
local Q = _G.TPQ or {}
_G.TPQ = Q

local function now() return bm:time_elapsed_ms() / 1000 end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end

local function find(alliance, ty)
	local armies = alliance:armies()
	for a = 1, armies:count() do
		local us = armies:item(a):units()
		for i = 1, us:count() do
			local u = us:item(i)
			if u:type() == ty then return u end
		end
	end
end

-- shots: an in-game screenshot tpsync_pair_<n>.tga 1.2 s into each of my first `shots` episodes
function Q.watch_start(me_type, k, shots)
	pcall(function() bm:remove_real_callback("tpq_watch") end)
	local me = find(bm:get_player_alliance(), me_type)
	local e = T.enemy and T.enemy[k or 1]
	if not (me and e) then return "missing: me " .. tostring(me ~= nil) .. ", enemy " .. tostring(e ~= nil) end
	local n0, t0n = P.synced()
	local w = {t0 = now(), me = me, e = e.u, men = {}, eps = {}, frames = 0, errs = 0, synced0 = n0, tries0 = t0n, b20 = {}, combat = {},
		features = tostring(P.features.sync), shots = shots or 0, shot = 0}
	Q.w = w
	local function track(m, side)
		local key = tostring(m)
		local s = w.men[key]
		if not s then s = {side = side} w.men[key] = s end
		local on = P.matched(m)
		local slot = P.anim_slot(m)
		local hp = P.model_hp(m)
		local t = now() - w.t0
		-- whatever is at +0xb20, by class; and any GENERIC_MATCHED / COMBAT_n slot entered (530-700), by side
		local mr = _G.memreader_plus
		local it = mr.read_pointer(m, 0xb20)
		if not mr.is_null(it) then
			local k = mr.tostring(mr.read_pointer(it, 0))
			w.b20[k] = (w.b20[k] or 0) + 1
		end
		if slot and slot >= 530 and slot <= 700 and s.slot ~= slot then
			local k = side .. " " .. slot
			w.combat[k] = (w.combat[k] or 0) + 1
		end
		s.slot = slot
		if on and not s.ep then
			s.ep = {side = side, from = r1(t), slots = {}, hp0 = hp}
			w.eps[#w.eps + 1] = s.ep
			if side == "me" and w.shot < w.shots and not w.shot_at then w.shot_at = t + 1.2 end
		end
		if s.ep then
			if slot and not s.ep.slots[slot] then s.ep.slots[slot] = r1(t - s.ep.from) end
			if not on then s.ep.till, s.ep.hp1, s.ep = r1(t), hp, nil end
		end
	end
	bm:repeat_real_callback(function()
		local ok = pcall(function()
			w.frames = w.frames + 1
			for _, m in ipairs(P.models(w.me)) do track(P.mount(m) or m, "me") if P.mount(m) then track(m, "me rider") end end
			for _, m in ipairs(P.models(w.e)) do track(m, "enemy") end
			if w.shot_at and now() - w.t0 >= w.shot_at then
				w.shot, w.shot_at = w.shot + 1, nil
				common.take_screenshot("tpsync_pair_" .. w.shot .. ".tga")
			end
		end)
		if not ok then w.errs = w.errs + 1 end
	end, 1, "tpq_watch")
	return "watching " .. me_type .. " vs " .. e.u:type() .. ", sync feature " .. w.features
end

function Q.watch_stop() pcall(function() bm:remove_real_callback("tpq_watch") end) return "stopped" end

-- Q.diag_start(wait): P.sync wrapped. Each click's sync wait stretched to `wait` s from its first ask (combat.lua's lock
-- reads F.lock.sync.till), and per ask: s since the first, his unit in melee, his running action's class (+0x4a8), and
-- the first time the pair showed. Q.diag_stop() puts P.sync back; Q.diag_read() lists one line per click.
function Q.diag_start(wait)
	local F = E.F
	local mr = _G.memreader_plus
	local orig = Q.sync_orig or P.sync
	Q.sync_orig, Q.diags = orig, {}
	P.sync = function(m, victim)
		local L = F.lock and F.lock.sync
		if L and not L.diag then
			L.diag = {t0 = now(), asks = 0, melee_at = nil, vts = {}, paired_at = nil}
			L.till = L.diag.t0 + (wait or 1.5)
			Q.diags[#Q.diags + 1] = L.diag
		end
		local d = L and L.diag
		if d then
			d.asks = d.asks + 1
			local t = r1(now() - d.t0)
			local ok = pcall(function()
				if F.unit:is_in_melee() and not d.melee_at then d.melee_at = t end
				local vt = mr.tostring(mr.read_pointer(m, 0x4a8))
				if d.last_vt ~= vt then d.vts[#d.vts + 1] = vt .. "@" .. t d.last_vt = vt end
			end)
		end
		return orig(m, victim)
	end
	bm:repeat_real_callback(function()
		pcall(function()
			for _, d in ipairs(Q.diags) do
				if not d.paired_at and not d.over then
					local L = F.lock and F.lock.sync
					if L and L.diag == d and L.on then d.paired_at = r1(now() - d.t0) end
					if not (L and L.diag == d) then d.over = r1(now() - d.t0) end
				end
			end
		end)
	end, 1, "tpq_diag")
	return "diag on, wait " .. tostring(wait or 1.5)
end
function Q.diag_stop()
	pcall(function() bm:remove_real_callback("tpq_diag") end)
	if Q.sync_orig then P.sync = Q.sync_orig end
	return "diag off"
end
function Q.diag_read()
	local out = {}
	for i, d in ipairs(Q.diags or {}) do
		out[i] = "asks " .. d.asks .. " melee " .. tostring(d.melee_at) .. " paired " .. tostring(d.paired_at) .. " over "
			.. tostring(d.over) .. " vts " .. table.concat(d.vts, " ")
	end
	return out
end

function Q.watch_read()
	local w = Q.w
	if not w then return "not started" end
	local n, tries = P.synced()
	local out = {frames = w.frames, errs = w.errs, synced = n - w.synced0, tries = tries - w.tries0, episodes = #w.eps,
		features = w.features, list = {}, b20 = w.b20, combat = w.combat}
	for _, ep in ipairs(w.eps) do
		local sl = {}
		for s, t in pairs(ep.slots) do sl[#sl + 1] = s .. "@" .. t end
		table.sort(sl)
		out.list[#out.list + 1] = ep.side .. " " .. ep.from .. "-" .. tostring(ep.till) .. " hp " .. tostring(ep.hp0) .. ">"
			.. tostring(ep.hp1) .. " slots " .. table.concat(sl, " ")
	end
	return out
end
return "TPQ loaded"
