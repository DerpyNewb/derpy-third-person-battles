-- 2026-11-27 where a man's battle animation table (land_units.man_animation) and skeleton names can be read, for the
-- sync kill pair check. Loaded after zz_tp_live_20261108.lua (_G.TPT). No string library calls but a plain find.
--
-- S.scan(m, needles, span1, span2, span3): m's own first span1 bytes; every 8-byte field of m in span1 read as a
--   pointer, the block it points at (first span3 bytes) searched; and every pointer in that block's first span2 bytes,
--   its block searched too. Returns one line per hit: needle, then the chain of offsets (decimal).
-- S.men(ty): the models of the first unit of type ty on either side, as a list
local T = _G.TPT
if not (T and T.E) then return "load TPT first" end
local P = T.E.P
local mr = _G.memreader_plus
local S = _G.TPS or {}
_G.TPS = S

local function raw(p, off, n)
	local ok, s = pcall(mr.read, p, off, n)
	if ok and type(s) == "string" then return s end
end
local function ptr(p, off)
	local ok, q = pcall(mr.read_pointer, p, off)
	if ok and q and not mr.is_null(q) then return q end
end

function S.scan(m, needles, span1, span2, span3)
	local hits, seen, n = {}, {}, 0
	local function look(s, where)
		if not s then return end
		for _, needle in ipairs(needles) do
			local i = string.find(s, needle)
			if i then hits[#hits + 1] = needle .. " @ " .. where .. " +" .. (i - 1) end
		end
	end
	look(raw(m, 0, span1), "self")
	for o1 = 0, span1 - 8, 8 do
		local p = ptr(m, o1)
		local k = p and mr.tostring(p)
		if p and not seen[k] then
			seen[k] = true
			n = n + 1
			look(raw(p, 0, span3), tostring(o1))
			for o2 = 0, span2 - 8, 8 do
				local q = ptr(p, o2)
				local k2 = q and mr.tostring(q)
				if q and not seen[k2] then
					seen[k2] = true
					n = n + 1
					look(raw(q, 0, span3), o1 .. " > " .. o2)
				end
			end
		end
	end
	return {blocks = n, hits = hits}
end

local function find(alliance, ty)
	local armies = alliance:armies()
	for a = 1, armies:count() do
		local us = armies:item(a):units()
		for i = 1, us:count() do
			local u = us:item(i)
			if u:type() == ty then return u end
		end
	end
end

function S.men(ty)
	local als = bm:alliances()
	for a = 1, als:count() do
		local u = find(als:item(a), ty)
		if u then return P.models(u) end
	end
	return {}
end

function S.write(path, lines)
	local f = io.open(path, "w")
	if not f then return false end
	for _, l in ipairs(lines) do f:write(tostring(l), "\n") end
	f:close()
	return true
end
return "TPS loaded"
