-- Test scaffolding (2026-10-29), never shipped. Where does a man in the engine's own melee keep the man he fights?
-- In normal melee a clip's IMPACT_POS hits that man (SPLASH_ATTACK is an extra area hit, docs/ANM_META_TAGS.md); a
-- clip the pack plays has none, so it hits nothing. TPS.scan(our_uid, their_uid, n) reads n of our men's blocks,
-- 0 .. LIMIT, for a qword equal to one of the enemy unit's men (or pointing up to 0x40 into one) and a dword equal to
-- one of their ids (+0x258 lo, +0x25a hi), and counts the offsets that hold one. TPS.fields(m, offs) reads given
-- offsets off one man. The command at +0x330 is embedded, so its fields show here too (0x330 .. 0x400).
-- Bridge-only: local f = loadfile("<this path>") setfenv(f, core:get_env()) f(). No string library calls.
local mr = _G.memreader_plus
local E = _G.DERPY_TP
local P = E.P
local TPS = _G.TPS or {}
_G.TPS = TPS
local LIMIT = 0xc00

local function unit_of(uid)
	for _, al in ipairs({bm:get_player_alliance(), bm:get_non_player_alliance()}) do
		local armies = al:armies()
		for a = 1, armies:count() do
			local us = armies:item(a):units()
			for i = 1, us:count() do if us:item(i):unique_ui_id() == uid then return us:item(i) end end
		end
	end
end
TPS.unit_of = unit_of
-- an address as its top 12 hex digits (a string) and its low 16 bits: a float32 Lua number holds neither whole
local function halves(p) local s = mr.tostring(p) return s:sub(1, 12), tonumber(s:sub(13, 16), 16) end
TPS.halves = halves

function TPS.scan(our_uid, their_uid, n)
	local ours, theirs = unit_of(our_uid), unit_of(their_uid)
	local ptr, ids = {}, {}
	local their_men = P.models(theirs)
	for _, m in ipairs(their_men) do
		local hi, lo = halves(m)
		ptr[#ptr + 1] = {hi, lo}
		ids[mr.read_uint16(m, 0x25a) .. "." .. mr.read_uint16(m, 0x258)] = true
	end
	local hits_p, hits_id, scanned = {}, {}, 0
	for k, m in ipairs(P.models(ours)) do
		if k > n then break end
		scanned = scanned + 1
		for off = 0, LIMIT - 8, 8 do
			local ok, v = pcall(mr.read_pointer, m, off)
			if ok and not mr.is_null(v) then
				local hi, lo = halves(v)
				for _, e in ipairs(ptr) do
					if hi == e[1] and lo >= e[2] and lo - e[2] <= 0x40 then
						local key = off .. "+" .. (lo - e[2])
						hits_p[key] = (hits_p[key] or 0) + 1
						break
					end
				end
			end
		end
		for off = 0, LIMIT - 4, 4 do
			local ok, a, b = pcall(function() return mr.read_uint16(m, off), mr.read_uint16(m, off + 2) end)
			if ok and ids[b .. "." .. a] then hits_id[off] = (hits_id[off] or 0) + 1 end
		end
	end
	local out = {"scanned " .. scanned .. " of ours against " .. #their_men .. " of theirs; melee " .. tostring(ours:is_in_melee())}
	local p = {}
	for k, c in pairs(hits_p) do p[#p + 1] = k .. "x" .. c end
	local q = {}
	for k, c in pairs(hits_id) do q[#q + 1] = k .. "x" .. c end
	out[#out + 1] = "pointer offsets (off+into x men): " .. table.concat(p, " ")
	out[#out + 1] = "id offsets (x men): " .. table.concat(q, " ")
	return table.concat(out, " | ")
end

-- a few fields off his men: the command vtable and the given qword offsets, as hex
function TPS.fields(uid, offs, n)
	local out = {}
	for k, m in ipairs(P.models(unit_of(uid))) do
		if k > n then break end
		local row = {"cmd " .. mr.tostring(mr.read_pointer(m, 0x330)):sub(10) .. " 270=" .. mr.read_int32(m, 0x270)}
		for _, o in ipairs(offs) do row[#row + 1] = o .. "=" .. mr.tostring(mr.read_pointer(m, o)):sub(5) end
		out[#out + 1] = table.concat(row, " ")
	end
	return table.concat(out, " || ")
end
-- the pending hit (exe+3251af8 arms it at a swing's launch, exe+32654d0 lands it at the clip's impact frame, both
-- decompiled 2026-10-29): +0xaf0 type (0 blocked, 1 hit, 3/4/5 hit and knock), +0xaf4 damage, +0xaf8 the swing's
-- slot, +0xb00 the victim, +0xb08 pending. Cancelled unless +0x898, +0x284 or the +0xb20 check holds.
-- TPS.sample(uid, secs): every frame, every man of the unit; counts arms (pending 0 -> 1) with their type, damage and
-- whether +0xaf8 is his playing slot, and reads +0x27c, +0x284, +0x898 while one is pending. TPS.sampled: the result.
local function rec(m)
	return mr.read_int32(m, 0xb08), mr.read_int32(m, 0xaf0), mr.read_int32(m, 0xaf4), mr.read_uint16(m, 0xaf8)
end
function TPS.sample(uid, secs, list)
	local men = list or P.models(unit_of(uid))
	local last, res = {}, {arms = 0, types = {}, dmg = {}, slot_match = 0, slot_miss = {}, c284 = {}, c898 = 0,
		pend_frames = 0, frames = 0, ctr = {}}
	TPS.sampled = res
	local t0 = os.clock()
	bm:remove_real_callback("tps_sample")
	bm:repeat_real_callback(function()
		local ok, err = pcall(function()
			res.frames = res.frames + 1
			for k, m in ipairs(men) do
				local pend, ty, dmg, slot = rec(m)
				if pend ~= 0 then
					res.pend_frames = res.pend_frames + 1
					local v = mr.read_int32(m, 0x284)
					res.c284[v] = (res.c284[v] or 0) + 1
					if not mr.is_null(mr.read_pointer(m, 0x898)) then res.c898 = res.c898 + 1 end
					if k == 1 then res.ctr[#res.ctr + 1] = mr.read_int32(m, 0x27c) end
				end
				if pend ~= 0 and (last[k] or 0) == 0 then
					res.arms = res.arms + 1
					res.types[ty] = (res.types[ty] or 0) + 1
					if #res.dmg < 40 then res.dmg[#res.dmg + 1] = dmg end
					local s = mr.read_uint16(m, 0x278)
					if s == slot then res.slot_match = res.slot_match + 1 elseif #res.slot_miss < 12 then res.slot_miss[#res.slot_miss + 1] = slot .. "/" .. s end
				end
				last[k] = pend
			end
			if os.clock() - t0 > secs then res.done = true bm:remove_real_callback("tps_sample") end
		end)
		if not ok then res.err = tostring(err) bm:remove_real_callback("tps_sample") end
	end, 1, "tps_sample")
	return "sampling " .. #men
end
function TPS.report()
	local r = TPS.sampled
	if not r then return "none" end
	local function kv(t) local o = {} for k, c in pairs(t) do o[#o + 1] = k .. "x" .. c end return table.concat(o, " ") end
	local d = {} for _, x in ipairs(r.dmg) do d[#d + 1] = tostring(x) end
	local c = {} for i = 1, math.min(#r.ctr, 30) do c[#c + 1] = tostring(r.ctr[i]) end
	return "done=" .. tostring(r.done) .. " err=" .. tostring(r.err) .. " frames=" .. r.frames .. " arms=" .. r.arms
		.. " types " .. kv(r.types) .. " | dmg " .. table.concat(d, ",") .. " | slot match " .. r.slot_match .. " miss "
		.. table.concat(r.slot_miss, ",") .. " | pending frames " .. r.pend_frames .. " 284 " .. kv(r.c284) .. " 898set "
		.. r.c898 .. " | man1 27c " .. table.concat(c, ",")
end
return "TPS loaded"
