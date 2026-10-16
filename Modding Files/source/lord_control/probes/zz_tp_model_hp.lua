-- 2026-10-15, "should be health of the individual unit not the whole battalion": which field of a man's model object
-- holds his hit points. Every 4-byte offset of each live model below LIMIT is read; a value counts only when its bits
-- are a finite positive float (integer tests: this compiler's float comparisons let NaN through, measured). An offset
-- is kept when, for EVERY unit read, the sum over its models comes within 1% of the unit's HealthValue (absolute), or
-- the sum times HealthMax / initial men does (a fraction of his maximum). Read-only; no string library calls.
local LIMIT = 0x1000
local mr = _G.memreader_plus
local E = _G.DERPY_TP
if not mr or not E or not E.P then return "no memreader or no DERPY_TP" end
local ok, res = pcall(function()
	local root = core:get_ui_root()
	local units = bm:get_player_army():units()
	local abs, frac = {}, {}
	for off = 0, LIMIT - 4, 4 do abs[off], frac[off] = true, true end
	local used = 0
	for i = 1, units:count() do
		local u = units:item(i)
		local card = find_uicomponent(root, "cards_panel", tostring(u:unique_ui_id()))
		local id = card and card:GetContextObjectId("CcoBattleUnit")
		local hv = id and common.get_context_value("CcoBattleUnit", id, "HealthValue")
		local hm = id and common.get_context_value("CcoBattleUnit", id, "HealthMax")
		local ms = E.P.models(u)
		if hv and #ms > 0 and #ms == u:number_of_men_alive() then
			used = used + 1
			local per = hm / u:initial_number_of_men()
			for off = 0, LIMIT - 4, 4 do
				if abs[off] or frac[off] then
					local s, bad = 0, false
					for _, m in ipairs(ms) do
						local b = mr.read_int32(m, off)
						if b <= 0 or b >= 0x7f800000 then bad = true break end
						s = s + mr.read_float(m, off)
					end
					if bad then abs[off], frac[off] = false, false
					else
						local da, df = s - hv, s * per - hv
						if da < 0 then da = -da end
						if df < 0 then df = -df end
						if da > hv * 0.01 + 1 then abs[off] = false end
						if df > hv * 0.01 + 1 then frac[off] = false end
					end
				end
			end
		end
	end
	local out = "units read " .. used .. " || absolute:"
	for off = 0, LIMIT - 4, 4 do if abs[off] then out = out .. " " .. off end end
	out = out .. " || fraction:"
	for off = 0, LIMIT - 4, 4 do if frac[off] then out = out .. " " .. off end end
	-- the most damaged unit's first five men at every kept offset
	local worst, wf = nil, 2
	for i = 1, units:count() do
		local u = units:item(i)
		if u:number_of_men_alive() > 1 and u:unary_hitpoints() < wf then worst, wf = u, u:unary_hitpoints() end
	end
	if worst then
		local ms = E.P.models(worst)
		out = out .. " || " .. worst:type() .. " at " .. wf .. ":"
		for off = 0, LIMIT - 4, 4 do
			if abs[off] or frac[off] then
				out = out .. " [" .. off .. "]"
				for k = 1, math.min(5, #ms) do out = out .. " " .. mr.read_float(ms[k], off) end
			end
		end
	end
	return out
end)
return tostring(ok) .. " " .. tostring(res)
