-- 2026-10-15, per-man hit points, second pass: no field below 0x1000 of a man's model sums to his unit's HealthValue as
-- a float, an int32 or a fraction (zz_tp_model_hp.lua). Here, the most damaged regiment only: every offset whose
-- values differ between men and average within 10% of the unit's mean health per man (hp) or damage per man (dmg), read
-- as float, int32 and int16. A float counts only when its bits are finite and positive. Read-only; no string library.
local LIMIT = 0x1000
local mr = _G.memreader_plus
local E = _G.DERPY_TP
if not mr or not E or not E.P then return "no memreader or no DERPY_TP" end
local ok, res = pcall(function()
	local root = core:get_ui_root()
	local units = bm:get_player_army():units()
	local u, worst = nil, 2
	for i = 1, units:count() do
		local x = units:item(i)
		if x:number_of_men_alive() > 4 and x:unary_hitpoints() < worst then u, worst = x, x:unary_hitpoints() end
	end
	if not u then return "no damaged regiment" end
	local card = find_uicomponent(root, "cards_panel", tostring(u:unique_ui_id()))
	local id = card and card:GetContextObjectId("CcoBattleUnit")
	local hv = common.get_context_value("CcoBattleUnit", id, "HealthValue")
	local hm = common.get_context_value("CcoBattleUnit", id, "HealthMax")
	local ms = E.P.models(u)
	local n, n0 = #ms, u:initial_number_of_men()
	local per = hm / n0
	local mean_hp, mean_dmg = hv / n, per - hv / n
	local out = u:type() .. " men " .. n .. "/" .. n0 .. " hp " .. hv .. "/" .. hm .. " per man " .. per .. " mean hp "
		.. mean_hp .. " mean dmg " .. mean_dmg
	local function test(kind, off, read)
		local s, lo, hi = 0, 1e18, -1e18
		for _, m in ipairs(ms) do
			local val = read(m, off)
			if val == nil then return end
			s = s + val
			if val < lo then lo = val end
			if val > hi then hi = val end
		end
		if hi - lo < 0.5 then return end -- the same for every man: not a damage field
		local mean = s / n
		for _, want in ipairs({{"hp", mean_hp}, {"dmg", mean_dmg}}) do
			local d = mean - want[2]
			if d < 0 then d = -d end
			if want[2] > 1 and d <= want[2] * 0.1 then
				out = out .. " || " .. kind .. " " .. off .. " " .. want[1] .. " mean " .. math.floor(mean * 10) / 10 .. " range "
					.. math.floor(lo * 10) / 10 .. ".." .. math.floor(hi * 10) / 10
			end
		end
	end
	local function rf(m, off)
		local b = mr.read_int32(m, off)
		if b <= 0 or b >= 0x7f800000 then return nil end
		return mr.read_float(m, off)
	end
	local function ri(m, off) return mr.read_int32(m, off) end
	local function rh(m, off) return mr.read_uint16(m, off) end
	for off = 0, LIMIT - 4, 4 do test("float", off, rf) test("int32", off, ri) end
	for off = 0, LIMIT - 2, 2 do test("u16", off, rh) end
	return out
end)
return tostring(ok) .. " " .. tostring(res)
