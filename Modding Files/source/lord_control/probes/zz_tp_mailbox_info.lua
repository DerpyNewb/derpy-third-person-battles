-- The mailbox's state in the running battle (test scaffolding): platform's flag and block, memreader Plus's view of
-- the cave at a man's update (exe+3086f04), and the block's counters (met +0x4c, stops +0x48, man +0x0)
local ok, r = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	local P = E.P
	local site = mr.add(mr.add(mr.base, 0x3080000), 0x6f04)
	local info = mr.hook_info(site)
	local b = P.mailbox
	return {mailbox = tostring(P.features.mailbox), problems = table.concat(P.problems, "; "),
		kind = info and info.kind or "none", block = b and mr.tostring(b) or "none",
		in_cave = info and info.cave and b and tostring(mr.eq(mr.read_pointer(info.cave, 2), b)) or "-",
		met = b and mr.read_int32(b, 0x4c) or -1, stops = b and mr.read_int32(b, 0x48) or -1,
		man = b and mr.tostring(mr.read_pointer(b, 0)) or "-", phase = bm:get_current_phase_name()}
end)
if ok then return r end
return "ERR " .. tostring(r)
