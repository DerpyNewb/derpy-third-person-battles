-- Live probes, 2026-11-11. Loaded after zz_tp_live_20261108.lua (_G.TPT) and, for the reach, run beside
-- zz_tp_crowd_focus.lua. No string library calls and no s:method() (memory: wh3-mcp-bridge-wedges-on-interface-walks).
--  R.reach_start(): on every locked swing, the frame its clip shows (the frame combat.lua victim() picks), how far the
--    locked enemy's nearest man stands past the blow's reach: past = d - his body radius - reach - STRIKE_SLACK (0.5),
--    with d measured from the swinging model, as victim() does. past <= 0: inside the reach victim() uses.
--  R.hp_start(attacker): a row each time his hit points, his clip, his mount's, the pack's shield, a battle's
--    invincibility or the attacker's clip changes, and every pack log line, model ms each. For the 1 hp report.
--  R.read(): what was recorded.
local T, E = _G.TPT, _G.DERPY_TP
if not (T and E and E.main) then return "load zz_tp_live_20261108 first" end
local P, F = E.P, E.F
local R = _G.TPR or {}
_G.TPR = R
local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
local function now_ms() return bm:time_elapsed_ms() end

-- the log, kept whatever the debug setting
R.lines = R.lines or {}
if not R.log_was then
	R.log_was = E.log
	E.log = function(s)
		if #R.lines < 600 then R.lines[#R.lines + 1] = now_ms() .. " " .. tostring(s) end
		return R.log_was(s)
	end
end

local IMPACTS = {{454, "impacts"}, {494, "impacts_fly"}, {1901, "impacts_rider"}, {1941, "impacts_rider_fly"}}
local function impact(slot)
	for _, t in ipairs(IMPACTS) do
		if slot >= t[1] and slot < t[1] + 10 then
			local d = E.D[t[2]] and E.D[t[2]][F.utype]
			return d and d[slot - t[1] + 1] or nil
		end
	end
end

function R.reach_start()
	if R.strike_was then return "already wrapped" end
	R.swings = {}
	local was = E.combat.strike
	R.strike_was = was
	E.combat.strike = function(now)
		local ok, err = pcall(function()
			local s, t = F.strike, F.target
			if not (s and t and P.anim_slot(s.m) == s.slot) then return end
			local imp = impact(s.slot)
			local rx, rz = imp and imp[1] or 0, imp and imp[2] or 2.5
			local reach = math.max(math.sqrt(rx * rx + rz * rz), 0.01)
			local x, _, z = P.model_pos(s.m)
			local yaw = P.heading(s.m) or E.rig.yaw
			local c, sn = math.cos(yaw), math.sin(yaw)
			local ix, iz = x + rx * c + rz * sn, z - rx * sn + rz * c
			local dx, dz = (ix - x) / reach, (iz - z) / reach
			local body = E.D.bodies and E.D.bodies[t:type()]
			local r = body and body[1] or 0.5
			local best
			for _, em in ipairs(P.models(t)) do
				if P.model_hp(em) > 0 then
					local vm = P.mount(em) or em
					local ex, _, ez = P.model_pos(vm)
					local ox, oz = ex - x, ez - z
					local d = math.sqrt(ox * ox + oz * oz)
					if not best or d < best.d then best = {d = d, cos = (ox * dx + oz * dz) / math.max(d, 0.01)} end
				end
			end
			if best then
				R.swings[#R.swings + 1] = {ms = now_ms(), slot = s.slot, reach = r2(reach), r = r2(r), d = r2(best.d),
					past = r2(best.d - r - reach - 0.5), cos = r2(best.cos)}
			end
		end)
		if not ok then R.reach_err = tostring(err) end
		return was(now)
	end
	return "wrapped"
end
function R.reach_stop()
	if R.strike_was then E.combat.strike = R.strike_was R.strike_was = nil end
	return "unwrapped"
end

local function find(alliance, ty)
	local armies = alliance:armies()
	for a = 1, armies:count() do
		local us = armies:item(a):units()
		for i = 1, us:count() do local u = us:item(i) if u:type() == ty then return u, armies:item(a) end end
	end
end
R.find = find

function R.hp_start(attacker_type)
	R.rec, R.rec_full = {}, false
	local enemy = attacker_type and find(bm:get_non_player_alliance(), attacker_type)
	R.attacker = enemy
	pcall(function() bm:remove_real_callback("tpr_hp") end)
	bm:repeat_real_callback(function()
		pcall(function()
			if not F.on then return end
			local man = F.single or F.model
			if not man then return end
			local rec = R.rec
			if #rec >= 3000 then R.rec_full = true return end
			local mount = P.mount(man)
			local am = enemy and enemy:number_of_men_alive() > 0 and P.models(enemy)[1]
			local row = {ms = now_ms(), hp = P.model_hp(man), s = P.anim_slot(man), ms_ = mount and P.anim_slot(mount),
				inv = F.invincible == true, guard = F.lock ~= nil and F.lock.guard == true, killed = F.killed == true,
				invul = F.unit:is_invulnerable() == true, a = am and P.anim_slot(am) or nil, block = F.block ~= nil,
				st = r2(F.stamina or 0)}
			local l = rec[#rec]
			if not l or l.hp ~= row.hp or l.s ~= row.s or l.ms_ ~= row.ms_ or l.inv ~= row.inv or l.guard ~= row.guard
				or l.killed ~= row.killed or l.invul ~= row.invul or l.a ~= row.a or l.block ~= row.block then
				rec[#rec + 1] = row
			end
		end)
	end, 1, "tpr_hp")
	return "recording" .. (enemy and (" against " .. enemy:type()) or "")
end
function R.hp_stop() pcall(function() bm:remove_real_callback("tpr_hp") end) return #(R.rec or {}) .. " rows" end

-- rows as lines, from row i (default: the last n = 60)
function R.rows(i, n)
	local rec = R.rec or {}
	n = n or 60
	i = i or math.max(1, #rec - n + 1)
	local out = {}
	for k = i, math.min(#rec, i + n - 1) do
		local w = rec[k]
		out[#out + 1] = k .. " " .. w.ms .. " hp " .. tostring(w.hp) .. " clip " .. tostring(w.s) .. "/" .. tostring(w.ms_)
			.. " a " .. tostring(w.a) .. (w.inv and " INV" or "") .. (w.guard and " GUARD" or "") .. (w.invul and " INVUL" or "")
			.. (w.killed and " KILLED" or "") .. (w.block and " BLOCK" or "") .. " st " .. tostring(w.st)
	end
	return out
end
function R.log(i, n)
	local out = {}
	n = n or 40
	i = i or math.max(1, #R.lines - n + 1)
	for k = i, math.min(#R.lines, i + n - 1) do out[#out + 1] = R.lines[k] end
	return out
end
function R.read()
	local out = {}
	for _, w in ipairs(R.swings or {}) do
		out[#out + 1] = w.ms .. " slot " .. w.slot .. " reach " .. w.reach .. " r " .. w.r .. " d " .. w.d .. " past " .. w.past
			.. " cos " .. w.cos
	end
	return {swings = out, err = R.reach_err, rows = #(R.rec or {}), lines = #R.lines}
end
return "TPR loaded"
