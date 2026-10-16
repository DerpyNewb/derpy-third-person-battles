-- Log every native write the pack makes on a man: each clip push, and each steer/hold/guard that changed the command
-- at +0x330, with the vtable before and after. The script log is unbuffered, so after a crash its last "tpx" line is the
-- pack's last write. Test scaffolding, not shipped. Send BEFORE zz_tp_input_sweep.lua (the sweep keeps our guard).
-- Undo: _G.TPX.unwrap(). No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.P and E.log and mr) then return "load the pack in a battle first" end
	if _G.TPX then return "already wrapped, " .. _G.TPX.n .. " lines" end
	local P = E.P
	local X = {n = 0, max = 5000, orig = {play = P.play, hold = P.hold, guard = P.guard, steer = P.steer}}
	_G.TPX = X
	local function body(m)
		local okb, b = pcall(function() return P.mount(m) or m end)
		return okb and b or m
	end
	local function vt(m)
		local okv, c = pcall(function() return mr.tostring(mr.read_pointer(body(m), 0x330)) end)
		return okv and c or "?"
	end
	local function log(s)
		if X.n >= X.max then return end
		X.n = X.n + 1
		E.log("tpx " .. X.n .. " t " .. tostring(bm:time_elapsed_ms()) .. " " .. s)
	end
	local function who(m) return mr.tostring(body(m)) end
	P.play = function(m, slot, mask)
		local before = vt(m)
		local r = X.orig.play(m, slot, mask)
		log("play " .. who(m) .. " slot " .. tostring(slot) .. " mask " .. tostring(mask) .. " cmd " .. before .. " sent " .. tostring(r))
		return r
	end
	P.hold = function(m, x, z, yaw)
		local before = vt(m)
		local r = X.orig.hold(m, x, z, yaw)
		local after = vt(m)
		if after ~= before then log("hold " .. who(m) .. " cmd " .. before .. " -> " .. after) end
		return r
	end
	P.guard = function(m)
		local before = vt(m)
		local r = X.orig.guard(m)
		if r then log("guard " .. who(m) .. " cmd " .. before .. " -> " .. vt(m)) end
		return r
	end
	P.steer = function(m, x, z, run, yaw, scale)
		local before = vt(m)
		local r = X.orig.steer(m, x, z, run, yaw, scale)
		local after = vt(m)
		if after ~= before then log("steer " .. who(m) .. " cmd " .. before .. " -> " .. after) end
		return r
	end
	function X.unwrap() for k, f in pairs(X.orig) do P[k] = f end end
	log("wrapped play/hold/guard/steer")
	return "wrapped play/hold/guard/steer"
end)
return ok and res or "ERR " .. tostring(res)
