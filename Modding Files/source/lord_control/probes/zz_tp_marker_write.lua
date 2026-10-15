-- Selection-marker flag via the battle global, 2026-10-14 (build 6ac6d907): battle -> +0x2f0 -> +0x100
-- {u32 count at +8, data at +0x10} -> the entry with vtable exe+0x3ac95c8 -> +0xa8 owner (vtable
-- exe+0x3ac9700) {u32 count at +0xa0, data at +0xa8} -> flag objects (vtable exe+0x3ac9958): unit at +0xf8,
-- selected byte at +0xd8. Paired-screenshot write test: select the Iron Hail Gunners, hold their flag at 0 from 1 s to 4 s, give it back. No string library calls; every constant above 2^24 split in two.
local E = _G.DERPY_TP
if not (E and E.P) then return "ERR load the bridge first" end
local mr = memreader_plus
local base = mr.base
local function at(hi, lo) return mr.add(mr.add(base, hi), lo) end
local VT_LIST, VT_OWNER, VT_FLAG = at(0x3ac0000, 0x95c8), at(0x3ac0000, 0x9700), at(0x3ac0000, 0x9958)
local function flag_for(unit_ptr)
	local battle = mr.read_pointer(at(0x4470000, 0x9ee0), 0)
	local x1 = mr.read_pointer(mr.read_pointer(battle, 0x2f0), 0x100)
	local n, arr = mr.read_int32(x1, 8), mr.read_pointer(x1, 0x10)
	local owner
	for i = 0, n - 1 do
		local p = mr.read_pointer(arr, i * 8)
		if mr.eq(mr.read_pointer(p, 0), VT_LIST) then owner = mr.add(p, 0xa8) end
	end
	if not owner or not mr.eq(mr.read_pointer(owner, 0), VT_OWNER) then return nil, "no owner" end
	local m, data = mr.read_int32(owner, 0xa0), mr.read_pointer(owner, 0xa8)
	for j = 0, m - 1 do
		local f = mr.read_pointer(data, j * 8)
		if mr.eq(mr.read_pointer(f, 0), VT_FLAG) and mr.eq(mr.read_pointer(f, 0xf8), unit_ptr) then return f end
	end
	return nil, "not among " .. m
end
local GUN = "wh3_main_cth_inf_iron_hail_gunners_0"
local units = bm:get_player_army():units()
local g
for i = 1, units:count() do if units:item(i):type() == GUN then g = units:item(i) end end
if not g then return "ERR no gunners" end
local f, why = flag_for(mr.read_pointer(E.P.models(g)[1], 0x2e8))
if not f then return "ERR " .. tostring(why) end
g:select_in_ui()
local q = g:position()
bm:camera():move_to(v(q:get_x() - 30, q:get_y() + 22, q:get_z() - 30), v(q:get_x(), q:get_y(), q:get_z()), 0, false, -1, false)
local T = {n = 0, log = ""}
_G.TP_MCHAIN = T
local t0 = os.clock()
bm:repeat_real_callback(function()
	local t = os.clock() - t0
	T.n = T.n + 1
	if T.n == 30 then T.log = T.log .. "at 0.3 s flag " .. mr.read_uint8(f, 0xd8) .. " | " end
	if t >= 1 and t < 4 then mr.write(f, 0xd8, mr.uint8(0)) end
	if t >= 4 and not T.back then T.back = true mr.write(f, 0xd8, mr.uint8(1)) T.log = T.log .. "given back | " end
	if t >= 6 then bm:remove_real_callback("tp_mchain") T.ended = true end
end, 10, "tp_mchain")
return "started"
