-- spike: forced FIRE_LEVEL on every crossbowman at once; real bolts would cut the pinned rats down
local MY, SLOT = 4, 1557
local CMD_TYPE, CMD_PUSH, BATTLE_GLOBAL = {0x3900000, 0x1cd0}, {0x2e00000, 0x969ac}, {0x4400000, 0x79ee0}
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local S = _G.DERPY_TGT
	local function at(p) return mr.add(mr.add(mr.base, p[1]), p[2]) end
	local u = bm:get_player_army():units():item(MY)
	local obj = mr.read_pointer(mr.ud_topointer(u), 8)
	local n, models = mr.read_int32(obj, 0xa4), mr.read_pointer(obj, 0xa8)
	local b = mr.read_pointer(mr.read_pointer(at(BATTLE_GLOBAL)), 0x468)
	local queue = mr.read_pointer(b, 0x644e8)
	local T = {trace = {}}
	_G.DERPY_VOLLEY = T
	local function note(tag) T.trace[#T.trace + 1] = tag .. " rats" .. S.enemy:number_of_men_alive() .. " ammo" .. u:ammo_left() end
	note("base0")
	bm:real_callback(function() note("base3") end, 3000, "derpy_v_b3")
	bm:real_callback(function()
		note("push")
		local cmd = mr.alloc(32)
		mr.write(cmd, 0, at(CMD_TYPE))
		mr.write(cmd, 0x10, mr.uint16(SLOT))
		mr.write(cmd, 0x12, mr.uint8(0))
		mr.write(cmd, 0x14, mr.uint32(0))
		local pushed = 0
		for k = 0, n - 1 do
			mr.write(cmd, 8, mr.read_pointer(models, k * 8))
			pushed = pushed + mr.tonumber(mr.call(at(CMD_PUSH), "uint8(pointer, pointer)", queue, cmd))
		end
		T.pushed = pushed
	end, 3100, "derpy_v_push")
	for _, ms in ipairs({4000, 5000, 6000, 8000, 11000}) do
		bm:real_callback(function() note("+" .. (ms - 3100)) end, ms, "derpy_v_" .. ms)
	end
	bm:real_callback(function() common.take_screenshot("derpy_volley.tga") end, 4300, "derpy_v_shot")
	return "running"
end)
if ok then return res end
return "ERR " .. tostring(res)
