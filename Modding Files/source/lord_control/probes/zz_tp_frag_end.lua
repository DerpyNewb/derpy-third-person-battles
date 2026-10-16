-- Read-only: does every fragment's slot table end at the same slot? Prints, per distinct fragment in both armies, the
-- clip count and slots 2326-2341 (index-like = under the clip count or 0xffff). No writes. No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.P and mr) then return "load the pack in a battle first" end
	local P = E.P
	local seen, out = {}, {}
	local function look(u)
		local m = P.models(u)[1]
		if not m then return end
		for _, x in ipairs({m, P.mount(m)}) do
			local a = x and mr.read_pointer(x, 0x308)
			if a and not mr.is_null(a) and not seen[mr.tostring(a)] and #out < 14 then
				seen[mr.tostring(a)] = true
				local clips, t = mr.read_int32(a, 0x40), {}
				for s = 2326, 2341 do
					local v = mr.read_uint16(a, 0x50 + s * 2)
					t[#t + 1] = (v == 0xffff and "-" or v < clips and "i" or "X")
				end
				out[#out + 1] = u:type() .. " clips " .. clips .. " slots 2326-2341: " .. table.concat(t)
			end
		end
	end
	for _, al in ipairs({bm:get_player_alliance(), bm:get_non_player_alliance()}) do
		local armies = al:armies()
		for a = 1, armies:count() do
			local us = armies:item(a):units()
			for i = 1, us:count() do look(us:item(i)) end
		end
	end
	return out
end)
return ok and res or "ERR " .. tostring(res)
