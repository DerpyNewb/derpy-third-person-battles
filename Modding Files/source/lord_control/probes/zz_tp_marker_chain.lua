-- Selection-marker flag via the battle global, 2026-10-14 (build 6ac6d907): battle -> +0x2f0 -> +0x100
-- {u32 count at +8, data at +0x10} -> the entry with vtable exe+0x3ac95c8 -> +0xa8 owner (vtable
-- exe+0x3ac9700) {u32 count at +0xa0, data at +0xa8} -> flag objects (vtable exe+0x3ac9958): unit at +0xf8,
-- selected byte at +0xd8. Read only. No string library calls; every constant above 2^24 split in two.
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
local units, out_s = bm:get_player_army():units(), ""
for i = 1, units:count() do
	local u = units:item(i)
	local ms = E.P.models(u)
	local up = ms[1] and mr.read_pointer(ms[1], 0x2e8)
	local f, why = up and flag_for(up)
	out_s = out_s .. u:type() .. " = " .. (f and tostring(mr.read_uint8(f, 0xd8)) or ("none: " .. tostring(why))) .. " | "
end
return out_s
