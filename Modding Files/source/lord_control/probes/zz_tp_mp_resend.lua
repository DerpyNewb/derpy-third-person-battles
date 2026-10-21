-- Test scaffolding (2026-10-21, multiplayer plan Task 2, fix round 1), never shipped. The control the melee MOVE result
-- lacked: what re-sending a forged MOVE does to a man's walk on open ground, with no enemy near and no regiment order.
-- Five fresh men of one idle infantry unit (the front rank, spread along it), one run each, 10 s apart:
--   once      one MOVE, 20 m ahead
--   0.1 / 0.3 / 0.5   the same MOVE re-sent every 1, 3 or 5 ticks for 5 s, the target fixed
--   0.1 lead  re-sent every tick for 5 s, the target moving 0.5 m further ahead at each send (a steering lead)
-- Each run's man goes into _G.TPW_MEN, so zz_tp_mp_watch.lua (loaded after TPR.plan) logs his position, heading,
-- command and queued holder every tick. Sends are logged as "TPR <model ms> <run> <n> ...".
-- Needs zz_tp_mp_override.lua loaded first. Bridge-only, loaded from disk:
--   local f = loadfile("<this path>") setfenv(f, core:get_env()) f()
--   TPR.plan(unit_index)   picks the five men, sets _G.TPW_MEN; TPR.run() starts the runs
-- Men are found again by their +0x258 id at every send. No string library calls.
local mr = _G.memreader_plus
local E = _G.DERPY_TP
local TPO = _G.TPO
if not (mr and E and E.P and E.P.models and TPO) then return "no platform, or zz_tp_mp_override.lua not loaded" end
local P = E.P
local TPR = {}
_G.TPR = TPR
local function now() return bm:time_elapsed_ms() end
local function log(s) out("TPR " .. now() .. " " .. s) end
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
local function live(w)
	for _, m in ipairs(P.models(w.u)) do if TPO.model_id(m) == w.id then return m end end
	return nil
end
local RUNS = {
	{name = "once", t = 2, every = 0, lead = 0},
	{name = "every_0.1", t = 12, every = 1, lead = 0},
	{name = "every_0.3", t = 22, every = 3, lead = 0},
	{name = "every_0.5", t = 32, every = 5, lead = 0},
	{name = "lead_0.1", t = 42, every = 1, lead = 0.5},
}
local SEND_SECS, AHEAD = 5, 20

function TPR.plan(n)
	local mine, theirs = bm:get_player_army(), bm:get_non_player_alliance():armies():item(1)
	local function centre(army)
		local sx, sz, k = 0, 0, 0
		for i = 1, army:units():count() do local p = army:units():item(i):position() sx, sz, k = sx + p:get_x(), sz + p:get_z(), k + 1 end
		return sx / k, sz / k
	end
	local mx, mz = centre(mine)
	local ex, ez = centre(theirs)
	local d = math.sqrt((ex - mx) ^ 2 + (ez - mz) ^ 2)
	TPR.f = {(ex - mx) / d, (ez - mz) / d}
	local u = mine:units():item(n)
	-- the front rank: the men furthest toward the enemy, then five spread along it
	local ms = {}
	for _, m in ipairs(P.models(u)) do
		local x, _, z = P.model_pos(m)
		ms[#ms + 1] = {m = m, k = x * TPR.f[1] + z * TPR.f[2]}
	end
	table.sort(ms, function(a, b) return a.k > b.k end)
	local front = {}
	for i = 1, math.min(25, #ms) do front[#front + 1] = ms[i].m end
	local tag = "1.1." .. n
	local men, lines = {}, {"unit " .. u:type() .. " forward " .. r1(TPR.f[1]) .. "," .. r1(TPR.f[2]) .. " gap to the enemy " .. r1(d)}
	for i, r in ipairs(RUNS) do
		local m = front[1 + (i - 1) * 5]
		r.w = {u = u, id = TPO.model_id(m)}
		men[#men + 1] = {name = r.name, tag = tag, id = r.w.id}
		lines[#lines + 1] = r.name .. " " .. r.w.id
	end
	_G.TPW_MEN = men
	return table.concat(lines, " ; ")
end

local function send(r)
	local m = live(r.w)
	if not m then return "gone" end
	if not r.tx then
		local x, _, z = P.model_pos(m)
		r.x0, r.z0 = x, z
		r.tx, r.tz = x + TPR.f[1] * AHEAD, z + TPR.f[2] * AHEAD
		r.speed = TPO.speed(m, false)
	elseif r.lead > 0 then
		r.tx, r.tz = r.tx + TPR.f[1] * r.lead, r.tz + TPR.f[2] * r.lead
	end
	local okm, why = TPO.move(m, r.tx, bm:get_terrain_height(r.tx, r.tz), r.tz, false, r.speed)
	r.n = (r.n or 0) + 1
	local x, _, z = P.model_pos(m)
	return tostring(okm) .. " " .. tostring(why) .. " at " .. r1(x) .. "," .. r1(z) .. " to " .. r1(r.tx) .. "," .. r1(r.tz)
		.. " speed " .. r1(r.speed) .. " heading " .. mr.read_uint16(m, 0xb0)
end

function TPR.run()
	if TPR.on then return "already running" end
	TPR.on, TPR.t0 = true, now()
	log("run t0 " .. TPR.t0)
	bm:repeat_callback(function()
		local tick = math.floor((now() - TPR.t0) / 100 + 0.5)
		for _, r in ipairs(RUNS) do
			local k = tick - r.t * 10
			local due = r.every == 0 and k == 0 or r.every > 0 and k >= 0 and k < SEND_SECS * 10 and k % r.every == 0
			if due then
				local okf, res = pcall(send, r)
				if r.every == 0 or (r.n or 0) <= 1 or (r.n or 0) % 10 == 0 or k + r.every >= SEND_SECS * 10 then
					log(r.name .. " " .. tostring(r.n) .. " " .. tostring(okf) .. " " .. tostring(res))
				end
			end
		end
		if tick > 560 then TPR.on = false bm:remove_process("tp_mp_resend") log("finished") end
	end, 100, "tp_mp_resend")
	return "running from " .. TPR.t0
end
return "TPR loaded"
