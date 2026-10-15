-- Is the general's memory position (game object +0x208/+0x210) per-frame, unlike unit:position()
-- (~0.3 s steps)? Orders him 40 m forward, then for 5 s counts, per frame, how often each source
-- changes and the longest run of frames each one held still. Read back with x3_smooth_read.lua.
local SECONDS = 5
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	bm:remove_real_callback("derpy_smooth")
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	local obj = mr.read_pointer(mr.ud_topointer(lord), 8)
	local q = lord:position()
	local uc = create_unitcontroller(lord)
	uc:goto_location(v(q:get_x(), q:get_y(), q:get_z() - 40), false)
	uc:release_control()
	local T = {frames = 0, s_changes = 0, m_changes = 0, s_hold = 0, m_hold = 0, s_run = 0, m_run = 0, samples = {}, t0 = os.clock()}
	_G.DERPY_SMOOTH = T
	bm:repeat_real_callback(function()
		local good, err = pcall(function()
			local p = lord:position()
			local sx, sz = p:get_x(), p:get_z()
			local mx, mz = mr.read_float(obj, 0x208), mr.read_float(obj, 0x210)
			T.frames = T.frames + 1
			if T.sx then
				if sx ~= T.sx or sz ~= T.sz then T.s_changes = T.s_changes + 1 T.s_run = 0 else T.s_run = T.s_run + 1 end
				if mx ~= T.mx or mz ~= T.mz then T.m_changes = T.m_changes + 1 T.m_run = 0 else T.m_run = T.m_run + 1 end
				if T.s_run > T.s_hold then T.s_hold = T.s_run end
				if T.m_run > T.m_hold then T.m_hold = T.m_run end
			end
			T.sx, T.sz, T.mx, T.mz = sx, sz, mx, mz
			if T.frames % 20 == 0 then T.samples[#T.samples + 1] = {sx, sz, mx, mz} end
			if os.clock() - T.t0 > SECONDS then
				T.done, T.elapsed = true, os.clock() - T.t0
				bm:remove_real_callback("derpy_smooth")
			end
		end)
		if not good then T.err = tostring(err) bm:remove_real_callback("derpy_smooth") end
	end, 1, "derpy_smooth")
	return {start = {q:get_x(), q:get_z()}, mem = {mr.read_float(obj, 0x208), mr.read_float(obj, 0x210)}}
end)
if ok then return res end
return "ERR " .. tostring(res)
