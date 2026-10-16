-- Read-only: where each fragment's slot table ends. Every u16 from +0x50 is 0xffff (absent) or an index under the clip
-- count at +0x40; the first 8 in a row that are neither mark the end. No writes. No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.P and mr) then return "load the pack in a battle first" end
	local P = E.P
	local frags, order = {}, {}
	local army = bm:get_player_army()
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		local m = P.models(u)[1]
		if m then
			for _, x in ipairs({m, P.mount(m)}) do
				local a = x and mr.read_pointer(x, 0x308)
				if a and not mr.is_null(a) then
					local key = mr.tostring(a)
					if not frags[key] then frags[key] = {a = a, unit = u:type()} order[#order + 1] = key end
				end
			end
		end
	end
	local out = {}
	for n, key in ipairs(order) do
		if n > 8 then break end
		local f = frags[key]
		local clips = mr.read_int32(f.a, 0x40)
		local bad, last_ok, present = 0, -1, 0
		for s = 0, 6000 do
			local v = mr.read_uint16(f.a, 0x50 + s * 2)
			if v == 0xffff or v < clips then
				bad = 0 last_ok = s
				if v ~= 0xffff then present = present + 1 end
			else
				bad = bad + 1
				if bad >= 8 then break end
			end
		end
		out[#out + 1] = f.unit .. " " .. key .. ": clips " .. clips .. ", last slot " .. last_ok .. ", present " .. present
	end
	return out
end)
return ok and res or "ERR " .. tostring(res)
