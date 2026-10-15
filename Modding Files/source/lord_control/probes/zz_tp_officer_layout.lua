-- Read-only: in the first Ironbreaker regiment, the officer (model 1, +3ac5c40) against an infantryman (model 3,
-- +390d4f8) on every field the walk code reads: position, both steering copies, the command (0x330) and its type
-- marker, the anim pointer (0x308) and slots 1557 and the walk slot. NO string library calls.
local E = _G.DERPY_TP
if not E then return "no DERPY_TP" end
local P, mr = E.P, _G.memreader_plus
local u
local units = bm:get_player_alliance():armies():item(1):units()
for i = 1, units:count() do if units:item(i):type() == "wh_main_dwf_inf_ironbreakers_spear" then u = units:item(i) break end end
if not u then return "no ironbreakers" end
local q = u:position()
local function f(v) return math.floor(v * 10 + 0.5) / 10 end
local function read(m)
	local r = {}
	local ok, err = pcall(function()
		r.vt = mr.tostring(mr.read_pointer(m, 0))
		local x, y, z = P.model_pos(m)
		r.pos = f(x - q:get_x()) .. "," .. f(y) .. "," .. f(z - q:get_z())
		r.steer_a = f(mr.read_float(m, 0x1e0) - x) .. "," .. f(mr.read_float(m, 0x1e8) - z)
		r.steer_b = f(mr.read_float(m, 0x194) - x) .. "," .. f(mr.read_float(m, 0x198) - z)
		local c = mr.read_pointer(m, 0x330)
		r.command = mr.is_null(c) and "null" or mr.tostring(mr.read_pointer(c, 0))
		local anim = mr.read_pointer(m, 0x308)
		r.anim = mr.is_null(anim) and "null" or "set"
		r.slot1557 = P.has_slot(m, 1557)
		r.alive = P.alive(u, m)
	end)
	if not ok then r.err = tostring(err) end
	return r
end
local ms = P.models(u)
return {officer = read(ms[1]), officer2 = read(ms[2]), man = read(ms[3]), front = mr.eq(E.move.front_man(u), ms[1]),
	steer = tostring(P.features.steer)}
