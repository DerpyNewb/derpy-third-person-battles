-- RE step 6: queue the engine's own play-animation command for the general's model (what
-- play_anim_for_captain builds, but with the model it cannot find). 9.0 addresses:
-- command type exe+3901cd0, queue push exe+2e969ac, battle global exe+4479ee0 (+0x468 -> gate
-- bytes +0x3b0/+0x3b1, queue +0x644e8), model = unit object (+0xa8)[0].
local ID, TAG = %ID%, "%TAG%"
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local u
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then u = units:item(i) end
	end
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local model = mr.read_pointer(mr.read_pointer(obj, 0xa8), 0)
	local b = mr.read_pointer(mr.read_pointer(mr.add(mr.add(mr.base, 0x4400000), 0x79ee0)), 0x468)
	if mr.read_uint8(b, 0x3b0) ~= 0 or mr.read_uint8(b, 0x3b1) ~= 0 then return "gate closed" end
	local queue = mr.read_pointer(b, 0x644e8)
	local msg = _G.DERPY_ANIM_MSG or mr.alloc(32)
	_G.DERPY_ANIM_MSG = msg
	mr.write(msg, 0, mr.add(mr.add(mr.base, 0x3900000), 0x1cd0))
	mr.write(msg, 8, model)
	mr.write(msg, 0x10, mr.uint16(ID))
	mr.write(msg, 0x12, mr.uint8(0))
	mr.write(msg, 0x14, mr.uint32(0))
	local push = mr.add(mr.add(mr.base, 0x2e00000), 0x969ac)
	local q = u:position()
	local bb = math.rad(u:bearing())
	local fx, fz = math.sin(bb), math.cos(bb)
	bm:camera():move_to(v(q:get_x() + fz * 5, q:get_y() + 1.6, q:get_z() - fx * 5), v(q:get_x(), q:get_y() + 1.2, q:get_z()), 0, false, -1, false)
	bm:real_callback(function() common.take_screenshot("derpy_" .. TAG .. "_0.tga") end, 300, "derpy_q_0")
	bm:real_callback(function() _G.DERPY_ANIM_RET = mr.tonumber(mr.call(push, "uint8(pointer, pointer)", queue, msg)) end, 450, "derpy_q_go")
	local shots = {700, 1000, 1400}
	for k = 1, #shots do
		bm:real_callback(function() common.take_screenshot("derpy_" .. TAG .. "_" .. k .. ".tga") end, shots[k], "derpy_q_" .. k)
	end
	return {model = mr.tostring(model), queue = mr.tostring(queue), id = ID}
end)
if ok then return res end
return "ERR " .. tostring(res)
