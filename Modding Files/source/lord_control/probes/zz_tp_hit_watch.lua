-- Test scaffolding (2026-10-19), never shipped. Watches, never drives: what a man's body shows when a blow lands on him.
-- Every frame for _G.TP_HW_SECONDS (default 20) s, on the first model of the player's unit _G.TP_HW_TYPE (and his mount):
-- a row whenever his command (the vtable at +0x330, as an offset from the exe), his clip (+0x278), his mount's clip or his
-- hit points change. Names the commands BATTLE_ENGINE_RE.md section 5 knows. Read: _G.TP_HW.rows. No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.P and mr) then return "no pack" end
	if _G.TP_HW and not _G.TP_HW.done then return "already watching" end
	local P = E.P
	local want = _G.TP_HW_TYPE
	local unit
	local a = bm:get_player_army()
	for i = 1, a:units():count() do local u = a:units():item(i) if u:type() == want then unit = u end end
	if not unit then return "no " .. tostring(want) end
	local NAMES = {[0x3ae2de8] = "DEFEND", [0x3ae2a08] = "fight_a", [0x3912820] = "fight_b", [0x3ae2b38] = "fight_c",
		[0x3ad24b8] = "melee_attack", [0x3919b28] = "idle", [0x39126f0] = "stand", [0x3911fb0] = "forced_clip",
		[0x3919350] = "reg_walk", [0x3ae2400] = "own_walk", [0x39199f8] = "move_a", [0x3ae1928] = "move_b", [0x3ad2d18] = "charge"}
	local probes = {}
	for off, name in pairs(NAMES) do probes[#probes + 1] = {mr.add(mr.base, off), name, off} end
	local function cmd_of(m)
		local c = mr.read_pointer(m, 0x330)
		for _, p in ipairs(probes) do if mr.eq(c, p[1]) then return p[2] end end
		return "?" .. mr.tostring(c)
	end
	local T = {rows = {}, done = false}
	_G.TP_HW = T
	local function now() return bm:time_elapsed_ms() / 1000 end
	local t0, last = now(), nil
	local function finish() T.done = true pcall(function() bm:remove_real_callback("tp_hit_watch") end) end
	bm:repeat_real_callback(function()
		local worked, err = pcall(function()
			local t = now()
			if t - t0 > (_G.TP_HW_SECONDS or 20) or _G.TP_HW_STOP then finish() return end
			local m = P.models(unit)[1]
			if not m then return end
			local mount = P.mount(m)
			local body = mount or m
			local hp = P.model_hp(m)
			local row = cmd_of(m) .. (mount and ("/" .. cmd_of(mount)) or "") .. " clip " .. tostring(P.anim_slot(m))
				.. " mount " .. tostring(mount and P.anim_slot(mount)) .. " hp " .. tostring(hp)
				.. " inv " .. tostring(unit:is_invulnerable()) .. " melee " .. tostring(unit:is_in_melee())
			if row ~= last and #T.rows < 1500 then
				last = row
				T.rows[#T.rows + 1] = math.floor((t - t0) * 1000) .. " " .. row
			end
		end)
		if not worked then T.err = tostring(err) finish() end
	end, 1, "tp_hit_watch")
	return "watching " .. want
end)
return ok and res or "ERR " .. tostring(res)
