-- Read-only: the base, and for one man of the first player unit, his object's vtable, his command's vtable and the 16
-- bytes at +0x368 (a forced clip's payload). Test scaffolding. No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	local P = E.P
	local want = _G.TP_VT_TYPE
	local army, out = bm:get_player_army(), {base = mr.tostring(mr.base)}
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		if (not want or u:type() == want) and u:number_of_men_alive() > 1 then
			local m = E.F.model or P.models(u)[1]
			out.type = u:type()
			out.vt = mr.tostring(mr.read_pointer(m, 0))
			out.cmd = mr.tostring(mr.read_pointer(m, 0x330))
			out.p0 = mr.tostring(mr.read_pointer(m, 0x368))
			out.p1 = mr.tostring(mr.read_pointer(m, 0x370))
			out.clip = P.anim_slot(m)
			out.h_queued = mr.tostring(mr.read_pointer(m, 0x5c8))
			out.h_running = mr.tostring(mr.read_pointer(m, 0x490))
			out.h_cmd = mr.tostring(mr.read_pointer(m, 0x328))
			local b = P.mount(m)
			if b then out.body_vt = mr.tostring(mr.read_pointer(b, 0)) end
			return out
		end
	end
	return out
end)
return ok and res or "ERR " .. tostring(res)
