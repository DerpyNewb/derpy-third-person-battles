-- The charge's flicker, 2026-10-16 (the author: "charging animation logic flawed, it resets the running after 1 frame
-- then start of charge animation again, causing the weapon to flicker"). Read only, 5 minutes, every frame while he
-- sprints (F.charging) and 1 s after: each change of the command on him (+0x330, named) or of his clip, with the model
-- time, the real time and whether the pack re-sent CHARGE that frame (F.charge_at moved). No orders, no writes. No
-- string library calls. Read back: zz_tp_charge_watch_read.lua.
local E = _G.DERPY_TP
if not (E and E.P and E.F) then return "load the pack first" end
local mr = _G.memreader_plus
if not mr then return "no memreader_plus" end
if _G.TP_CW and not _G.TP_CW.done then return "already running" end
local P, F = E.P, E.F
local function at(hi, lo) return mr.add(mr.add(mr.base, hi), lo) end
local NAMES = {
	{"walk(pack)", at(0x3ae0000, 0x2400)}, {"clip(pack)", at(0x3910000, 0x1fb0)}, {"stand", at(0x3910000, 0x26f0)},
	{"regiment walk", at(0x3910000, 0x9350)}, {"move 9f8", at(0x3910000, 0x99f8)}, {"idle b28", at(0x3910000, 0x9b28)},
	{"move 928", at(0x3ae0000, 0x1928)}, {"melee 4b8", at(0x3ad0000, 0x24b8)},
}
local function name(c)
	for _, n in ipairs(NAMES) do if mr.eq(c, n[2]) then return n[1] end end
	return mr.tostring(c)
end
local T = {events = {}, done = false, frames = 0, runs = 0}
_G.TP_CW = T
local t0, last, last_at, after = os.clock(), nil, nil, 0
bm:repeat_real_callback(function()
	local ok, err = pcall(function()
		if os.clock() - t0 > 300 or #T.events >= 600 then T.done = true return end
		if not (F.on and F.model) then last = nil return end
		if F.charging then after = os.clock() + 1 elseif os.clock() > after then last, last_at = nil, nil return end
		T.frames = T.frames + 1
		local m = F.model
		local s = name(mr.read_pointer(m, 0x330)) .. " clip " .. tostring(P.anim_slot(m))
		local sent = F.charge_at ~= last_at
		if sent and F.charge_at then T.runs = T.runs + 1 end
		last_at = F.charge_at
		if s ~= last or sent then
			if not last then T.events[#T.events + 1] = "----" end
			T.events[#T.events + 1] = math.floor((os.clock() - t0) * 1000) .. "ms m" .. bm:time_elapsed_ms() .. " " .. s
				.. (sent and " SENT" or "") .. (F.charging and "" or " (sprint over)")
			last = s
		end
	end)
	if not ok then T.err = tostring(err) T.done = true end
	if T.done then bm:remove_real_callback("tp_cw") end
end, 0, "tp_cw")
return "recording the charge for 5 minutes: sprint (shift held on the move) a few times"
