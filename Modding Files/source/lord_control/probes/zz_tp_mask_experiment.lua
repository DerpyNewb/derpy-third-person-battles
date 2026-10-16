-- Experiment for "no auto attack" (2026-10-16): the engine's melee order starts its swing inside its own battle tick, so a
-- stop from the script always lands after it. Instead, the controlled man's body (and rider) points at a private copy of
-- his animation fragment (model+0x308, shared by his whole regiment) whose attack slots read 0xffff (absent): the engine
-- finds no swing to start on him. The rest of the regiment keeps the shared table. Rides on P.guard (main.lua calls it
-- for the controlled man every unpaused frame). Copies are kept referenced in _G.TPMASK for the battle; the man handed
-- off gets his own table back. Not shipped. Send BEFORE zz_tp_auto_attack.lua. Undo: _G.TPMASK.unwrap().
-- No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.P and E.F and mr) then return "load the pack in a battle first" end
	if _G.TPMASK then return "already on" end
	local P = E.P
	local FRAG, TABLE, SPAN = 0x308, 0x50, 0x50 + 6001 * 2 -- a slot scan read 6000 slots past every table safely
	local SIZE = SPAN + (8 - SPAN % 8) % 8
	local X = {copies = {}, orig_of = {}, masked = {}, n_copies = 0, n_points = 0, guard = P.guard}
	_G.TPMASK = X
	local function attack(s) return s >= 454 and s <= 463 or s >= 484 and s <= 500 or s >= 1901 and s <= 1950 end
	local function copy_of(a)
		local key = mr.tostring(a)
		local c = X.copies[key]
		if c then return c end
		local buf = mr.alloc(SIZE)
		X.keep = X.keep or {}
		X.keep[#X.keep + 1] = buf -- referenced for the battle: the engine reads it from here on
		c = mr.add(buf, 0)
		for off = 0, SIZE - 8, 8 do mr.write(c, off, mr.read_pointer(a, off)) end
		for s = 454, 1950 do if attack(s) then mr.write(c, TABLE + s * 2, mr.uint16(0xffff)) end end
		X.copies[key] = c
		X.orig_of[mr.tostring(c)] = a
		X.n_copies = X.n_copies + 1
		return c
	end
	local function point(x)
		local a = mr.read_pointer(x, FRAG)
		if mr.is_null(a) or X.orig_of[mr.tostring(a)] then return end -- none, or already ours
		mr.write(x, FRAG, copy_of(a))
		X.masked[#X.masked + 1] = {x = x, a = a}
		X.n_points = X.n_points + 1
	end
	local function restore_all()
		for _, r in ipairs(X.masked) do
			local now_a = mr.read_pointer(r.x, FRAG)
			local o = X.orig_of[mr.tostring(now_a)]
			if o then mr.write(r.x, FRAG, o) end
		end
		X.masked, X.who = {}, nil
	end
	P.guard = function(m)
		local r = X.guard(m)
		local key = mr.tostring(m)
		if X.who ~= key then restore_all() X.who = key end -- a new man: the last one gets his own table back
		local b = P.mount(m)
		point(b or m)
		if b then point(m) end -- the rider's own sword
		return r
	end
	function X.unwrap() P.guard = X.guard restore_all() end
	return "mask experiment on, copy " .. SIZE .. " bytes"
end)
return ok and res or "ERR " .. tostring(res)
