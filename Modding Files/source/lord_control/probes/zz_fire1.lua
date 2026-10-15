-- spike: does a forced FIRE animation on ONE man of a missile regiment launch a real missile? (ammo)
local IDX, SLOTS = 4, {1557, 1557, 1557}
local CMD_TYPE, CMD_PUSH, BATTLE_GLOBAL = {0x3900000, 0x1cd0}, {0x2e00000, 0x969ac}, {0x4400000, 0x79ee0}
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local function at(p) return mr.add(mr.add(mr.base, p[1]), p[2]) end
	local u = bm:get_player_army():units():item(IDX)
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local m = mr.read_pointer(mr.read_pointer(obj, 0xa8), 0)
	local b = mr.read_pointer(mr.read_pointer(at(BATTLE_GLOBAL)), 0x468)
	local T = {ammo0 = u:ammo_left(), gate = mr.read_uint8(b, 0x3b0) .. mr.read_uint8(b, 0x3b1), trace = {}}
	_G.DERPY_F1 = T
	local cmd = mr.alloc(32)
	local function push(slot)
		mr.write(cmd, 0, at(CMD_TYPE))
		mr.write(cmd, 8, m)
		mr.write(cmd, 0x10, mr.uint16(slot))
		mr.write(cmd, 0x12, mr.uint8(0))
		mr.write(cmd, 0x14, mr.uint32(0))
		return mr.tonumber(mr.call(at(CMD_PUSH), "uint8(pointer, pointer)", mr.read_pointer(b, 0x644e8), cmd))
	end
	-- the regiment stops shooting on its own first; ammo must hold still before any push
	local uc = create_unitcontroller(u)
	uc:fire_at_will(false)
	uc:halt()
	for _, ms in ipairs({1000, 2000, 3000}) do
		bm:real_callback(function() T.trace[#T.trace + 1] = "quiet" .. ms .. ":" .. u:ammo_left() end, ms, "derpy_f1_q" .. ms)
	end
	for i, slot in ipairs(SLOTS) do
		bm:real_callback(function() T.trace[#T.trace + 1] = "push" .. slot .. "(ret" .. push(slot) .. ") at ammo " .. u:ammo_left() end, 3000 + (i - 1) * 2500 + 50, "derpy_f1_" .. i)
	end
	bm:real_callback(function() T.ammo_end = u:ammo_left() end, 11000, "derpy_f1_end")
	bm:real_callback(function() common.take_screenshot("derpy_fire1.tga") end, 4100, "derpy_f1_shot")
	return T
end)
if ok then return res end
return "ERR " .. tostring(res)
