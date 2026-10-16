-- Read-only: is a man's animation fragment (model+0x308, what P.has_slot reads) his own or shared by his regiment
-- and his unit type, and what does it hold around the slot table at +0x50 (u16 per slot, 0xffff absent)?
-- Groundwork for an attack-less copy of the controlled man's fragment. No writes. No string library calls.
local ok, res = pcall(function()
	local E, mr = _G.DERPY_TP, _G.memreader_plus
	if not (E and E.P and mr) then return "load the pack in a battle first" end
	local P = E.P
	local out = {}
	local function frag(m) return mr.read_pointer(m, 0x308) end
	local function attack_slots(a)
		local t = {}
		for _, s in ipairs({454, 455, 456, 457, 458, 459, 460, 484, 489, 494, 1902, 1903, 1931, 42, 135}) do
			t[#t + 1] = s .. "=" .. mr.read_uint16(a, 0x50 + s * 2)
		end
		return table.concat(t, " ")
	end
	local function head(a)
		local t = {}
		for k = 0, 9 do t[#t + 1] = mr.tostring(mr.read_pointer(a, k * 8)) end
		return table.concat(t, " ")
	end
	local army = bm:get_player_army()
	local want = {hef_calith_gatekeepers = true, wh2_main_hef_cha_tyrion_1 = true, wh2_main_hef_cav_dragon_princes = true}
	local seen = {}
	for i = 1, army:units():count() do
		local u = army:units():item(i)
		if want[u:type()] then
			local ms = P.models(u)
			local row = {type = u:type(), men = #ms, frags = {}, mounts = {}}
			for k = 1, math.min(3, #ms) do
				local m = ms[k]
				local a = frag(m)
				row.frags[k] = mr.tostring(a)
				local h = P.mount(m)
				if h then row.mounts[k] = mr.tostring(frag(h)) end
				if k == 1 and not mr.is_null(a) then
					row.head = head(a)
					row.slots = attack_slots(a)
					if h and not mr.is_null(frag(h)) then row.mount_slots = attack_slots(frag(h)) end
				end
			end
			seen[u:type()] = true
			out[#out + 1] = row
		end
	end
	return out
end)
return ok and res or "ERR " .. tostring(res)
