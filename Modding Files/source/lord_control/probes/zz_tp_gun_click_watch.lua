-- Test scaffolding (2026-10-18, the author: "the artillery in melee still makes all the crew do a melee attack").
-- Read-only: every 200 ms for 5 s, the played unit's ammo, men in an attack clip (ATTACK_1-7, 454-460) and in a
-- block (474-483), in melee, and how far its centre has moved. "read" returns the samples. No string library calls.
local ok, res = pcall(function()
	if _G.TP_GC_MODE == "read" then
		local s = ""
		for _, l in ipairs(_G.TP_GC or {}) do s = s .. l .. " || " end
		return s
	end
	local T = _G.DERPY_TP
	local u = T.F.unit
	local p0 = u:position()
	local x0, z0, t0 = p0:get_x(), p0:get_z(), bm:time_elapsed_ms()
	_G.TP_GC = {}
	bm:remove_real_callback("tp_gun_click")
	bm:repeat_real_callback(function()
		local t = bm:time_elapsed_ms() - t0
		if t > 5000 then bm:remove_real_callback("tp_gun_click") return end
		local swing, block = 0, 0
		for _, m in ipairs(T.P.models(u)) do
			local c = T.P.anim_slot(m)
			if c and c >= 454 and c <= 460 then swing = swing + 1 elseif c and c >= 474 and c <= 483 then block = block + 1 end
		end
		local p = u:position()
		_G.TP_GC[#_G.TP_GC + 1] = math.floor(t / 100) / 10 .. "s ammo " .. u:ammo_left() .. " swing " .. swing .. " block " .. block
			.. " melee " .. tostring(u:is_in_melee()) .. " moved " .. math.floor(math.sqrt((p:get_x() - x0) ^ 2 + (p:get_z() - z0) ^ 2))
	end, 200, "tp_gun_click")
	return "sampling " .. u:type()
end)
return ok and res or "ERR " .. tostring(res)
