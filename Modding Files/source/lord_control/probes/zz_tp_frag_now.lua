-- Read-only: per rifle unit, ammo, whether its men share one fragment, and slots 1554/1557/454 on it. No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	local P = E.P
	local want = _G.TP_SF_TYPE or "wh3_dlc25_emp_inf_hochland_long_rifles_ror"
	local army, out = bm:get_player_army(), {}
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		if u:type() == want then
			local ms, frags, n = P.models(u), {}, 0
			for _, m in ipairs(ms) do
				local a = mr.tostring(mr.read_pointer(m, 0x308))
				if not frags[a] then frags[a] = true n = n + 1 end
			end
			local a = mr.read_pointer(ms[1], 0x308)
			local function s(k) return mr.read_uint16(a, 0x50 + k * 2) end
			out[#out + 1] = "unit " .. i .. " ammo " .. u:ammo_left() .. "/" .. u:starting_ammo() .. " fragments " .. n
				.. " slots 1554=" .. s(1554) .. " 1557=" .. s(1557) .. " 454=" .. s(454) .. " melee " .. tostring(u:is_in_melee())
		end
	end
	return out
end)
return ok and res or "ERR " .. tostring(res)
