-- Test scaffolding (2026-10-21, multiplayer plan Task 2 step 6), never shipped. Forges the per-man override commands
-- Task 1b recommends (decision record docs/sessions/MP_FEASIBILITY_20261021_THIRD_PERSON.md, "Override commands", O4) and
-- pushes them into the battle command queue P.play uses, plus the passive reads step 6 asks for. Build 6acec6f4 only.
-- Bridge-only, loaded from disk: local f = loadfile("<this path>") setfenv(f, core:get_env()) f()
--   TPO.move(m, x, y, z, run, speed)   BCQ_ENTITY_USER_OVERRIDE_ORDER_MOVE, forged (header, one record write, length)
--   TPO.halt(m)                        _ORDER_HALT, forged
--   TPO.follow(m, heading16)           _ORDER_FOLLOW_FIRST_PERSON through CA's own pusher exe+2d919dc
--   TPO.reload(v)                      _RELOAD_TIME, forged; TPO.reload_global() reads exe+3d10794
--   TPO.snapshot()                     the gates +0x3b0/+0x3b1, the +0x258 id range, +0x890 per model, and every
--                                      fragment reachable from a model or its mount read at the CARRIER_SLOT candidates
-- Every RVA is written as two exact float32 literals (game Lua numbers are float32). No string library calls.
local mr = _G.memreader_plus
local E = _G.DERPY_TP
local P = E and E.P
local TPO = {}
_G.TPO = TPO
local base = mr.base
local function A(r) return mr.add(mr.add(base, r[1]), r[2]) end
local RV = {
	battle = {0x4480000, 0x0da0}, -- [[it]] + 0x468 is the battle
	header = {0x1bc0000, 0xa278}, -- (writer, queue + 8, &id, version)
	field = {0x1bb0000, 0x1924}, -- (writer, tag, source, size): the tag, then size raw bytes
	length = {0x1bc0000, 0xd5e4}, -- (writer): patch the length, or rewind an overflowed record
	lookup = {0x0660000, 0x8ad4}, -- (&id) -> registry entry: version at +0x10
	follow_push = {0x2d90000, 0x19dc},
	follow_vt = {0x3ab0000, 0x25a8},
	g_move = {0x4060000, 0xc798},
	g_halt = {0x4060000, 0xcea8},
	g_follow = {0x4060000, 0xcc88},
	g_reload = {0x4060000, 0xcda4},
	reload_global = {0x3d10000, 0x0794},
	walk_speed = {0x3030000, 0xb744},
}
TPO.RV = RV
local WR, BLOB, FC = mr.alloc(0x20), mr.alloc(64), mr.alloc(0x90)

function TPO.battle()
	local g = mr.read_pointer(A(RV.battle), 0)
	if mr.is_null(g) then return nil end
	local b = mr.read_pointer(g, 0x468)
	if mr.is_null(b) then return nil end
	return b
end
function TPO.gates()
	local b = TPO.battle()
	if not b then return -1, -1 end
	return mr.read_uint8(b, 0x3b0), mr.read_uint8(b, 0x3b1)
end
local function queue()
	local b = TPO.battle()
	if not b then return nil, "no battle" end
	if mr.read_uint8(b, 0x3b0) ~= 0 or mr.read_uint8(b, 0x3b1) ~= 0 then return nil, "gated" end
	local q = mr.read_pointer(b, 0x644e8)
	if mr.is_null(q) then return nil, "no queue" end
	return q
end
function TPO.version(g)
	local e = mr.call(A(RV.lookup), "pointer(pointer)", A(g))
	if mr.is_null(e) then return nil end
	return mr.read_uint8(e, 0x10)
end
-- the id each global holds (set at start-up), as "hi.lo"
function TPO.id(g) return tostring(mr.read_uint16(A(g), 2)) .. "." .. tostring(mr.read_uint16(A(g), 0)) end
-- BLOB holds the record after its first tag
local function push(g, tag, size)
	local q, why = queue()
	if not q then return false, why end
	local ver = TPO.version(g)
	if not ver then return false, "no registry entry" end
	mr.call(A(RV.header), "pointer(pointer, pointer, pointer, uint8)", WR, mr.add(q, 8), A(g), ver)
	mr.call(A(RV.field), "int32(pointer, uint8, pointer, int32)", WR, tag, BLOB, size)
	local err = mr.read_uint8(WR, 0)
	mr.call(A(RV.length), "int32(pointer)", WR)
	if err ~= 0 then return false, "writer error " .. err end
	return true, "v" .. ver
end
local function man_id(off, m)
	mr.write(BLOB, off, mr.uint16(mr.read_uint16(m, 0x258)))
	mr.write(BLOB, off + 2, mr.uint16(mr.read_uint16(m, 0x25a)))
end
function TPO.model_id(m) return tostring(mr.read_uint16(m, 0x25a)) .. "." .. tostring(mr.read_uint16(m, 0x258)) end
-- the speed the engine gives his unit for a gait (P.steer's call)
function TPO.speed(m, run)
	local unit = mr.read_pointer(m, 0x2e8)
	if mr.is_null(unit) then return nil end
	return mr.call(A(RV.walk_speed), "float(pointer, uint8)", unit, run and 1 or 0)
end
-- MOVE: 0x23 man; 0x0c x y z; 0x26 0; 0x27 0; 0x04 run; 0x0a speed. 37 bytes after the first tag, 45 on the wire
function TPO.move(m, x, y, z, run, speed)
	man_id(0, m)
	mr.write(BLOB, 4, mr.uint8(0x0c)) mr.write(BLOB, 5, x) mr.write(BLOB, 9, y) mr.write(BLOB, 13, z)
	mr.write(BLOB, 17, mr.uint8(0x26)) mr.write(BLOB, 18, mr.uint32(0))
	mr.write(BLOB, 22, mr.uint8(0x27)) mr.write(BLOB, 23, mr.uint32(0))
	mr.write(BLOB, 27, mr.uint8(4)) mr.write(BLOB, 28, mr.uint32(run and 1 or 0))
	mr.write(BLOB, 32, mr.uint8(0x0a)) mr.write(BLOB, 33, speed)
	return push(RV.g_move, 0x23, 37)
end
function TPO.halt(m)
	man_id(0, m)
	return push(RV.g_halt, 0x23, 4)
end
function TPO.reload(v)
	mr.write(BLOB, 0, v)
	return push(RV.g_reload, 0x0a, 4)
end
function TPO.reload_global() return mr.read_float(A(RV.reload_global), 0) end
-- FOLLOW through CA's own pusher: the 0x90-byte command the builder exe+2d9b4ec makes (O4 recipe)
function TPO.follow(m, heading16)
	local q, why = queue()
	if not q then return false, why end
	for o = 0, 0x8c, 4 do mr.write(FC, o, mr.uint32(0)) end
	mr.write(FC, 0, A(RV.follow_vt))
	mr.write(FC, 8, m)
	mr.write(FC, 0x30, mr.uint16(heading16))
	mr.write(FC, 0x78, mr.int32(-1))
	mr.write(FC, 0x80, mr.uint32(0x81))
	mr.write(FC, 0x88, 1.0)
	mr.call(A(RV.follow_push), "uint8(pointer, pointer)", q, FC)
	return true, "pushed"
end

local function each_unit(fn)
	for _, al in ipairs({bm:get_player_alliance(), bm:get_non_player_alliance()}) do
		local armies = al:armies()
		for a = 1, armies:count() do
			local us = armies:item(a):units()
			for i = 1, us:count() do fn(us:item(i)) end
		end
	end
end
local SLOTS = {2123, 2126, 2127}
-- lexicographic on (hi, lo): an id read whole as a number would round above 2^24
local function less(h1, l1, h2, l2) return h1 < h2 or h1 == h2 and l1 < l2 end
function TPO.snapshot()
	local ga, gb = TPO.gates()
	local lines = {"gates +0x3b0 " .. ga .. " +0x3b1 " .. gb .. " reload_global " .. tostring(TPO.reload_global())}
	lines[#lines + 1] = "ids move " .. TPO.id(RV.g_move) .. " halt " .. TPO.id(RV.g_halt) .. " follow " .. TPO.id(RV.g_follow)
		.. " reload " .. TPO.id(RV.g_reload) .. " versions " .. tostring(TPO.version(RV.g_move)) .. " " .. tostring(TPO.version(RV.g_halt))
		.. " " .. tostring(TPO.version(RV.g_follow)) .. " " .. tostring(TPO.version(RV.g_reload))
	local seen, nfr, nmount, models, n890 = {}, 0, 0, 0, 0
	local hits, bound129 = {}, 0
	local lo_h, lo_l, hi_h, hi_l
	local function frag(x, kind, utype)
		local f = mr.read_pointer(x, 0x308)
		if mr.is_null(f) then return end
		local k = mr.tostring(f)
		if seen[k] then return end
		seen[k] = true
		nfr = nfr + 1
		if kind == "mount" then nmount = nmount + 1 end
		for _, s in ipairs(SLOTS) do
			local v = mr.read_uint16(f, 0x50 + s * 2)
			if v ~= 0xffff then hits[#hits + 1] = kind .. " " .. utype .. " slot " .. s .. " clip " .. v end
		end
		if kind == "mount" then
			local v = mr.read_uint16(f, 0x50 + 129 * 2)
			if v ~= 0xffff then bound129 = bound129 + 1 hits[#hits + 1] = "mount " .. utype .. " slot 129 clip " .. v end
		end
	end
	local function id_range(x)
		local h, l = mr.read_uint16(x, 0x25a), mr.read_uint16(x, 0x258)
		if not lo_h or less(h, l, lo_h, lo_l) then lo_h, lo_l = h, l end
		if not hi_h or less(hi_h, hi_l, h, l) then hi_h, hi_l = h, l end
	end
	each_unit(function(u)
		local ty = u:type()
		for _, m in ipairs(P.models(u)) do
			models = models + 1
			if not mr.is_null(mr.read_pointer(m, 0x890)) then n890 = n890 + 1 end
			id_range(m)
			frag(m, "man", ty)
			local mt = mr.read_pointer(m, 0x2e0)
			if not mr.is_null(mt) then id_range(mt) frag(mt, "mount", ty) end
		end
	end)
	lines[#lines + 1] = "models " .. models .. " with +0x890 set " .. n890 .. "; model ids " .. tostring(lo_h) .. "." .. tostring(lo_l)
		.. " .. " .. tostring(hi_h) .. "." .. tostring(hi_l)
	lines[#lines + 1] = "fragments " .. nfr .. " (" .. nmount .. " mount); bound at 2123/2126/2127 (and mount 129): " .. #hits
	for _, h in ipairs(hits) do lines[#lines + 1] = "  " .. h end
	return table.concat(lines, " ; ")
end
return "TPO loaded"
