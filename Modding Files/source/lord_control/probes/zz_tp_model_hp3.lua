-- 2026-10-15, per-man hit points: int32 at +0xB1C (2844) of a man's model averaged his regiment's health per man
-- (zz_tp_model_hp2.lua). Here: its sum against HealthValue for every unit of the player's army, and the int32s from
-- +0xB00 to +0xB3C of three men of the most damaged one, for a maximum beside it. Read-only; no string library calls.
local HP = 0xB1C
local mr = _G.memreader_plus
local E = _G.DERPY_TP
if not mr or not E or not E.P then return "no memreader or no DERPY_TP" end
local ok, res = pcall(function()
	local root = core:get_ui_root()
	local units = bm:get_player_army():units()
	local out, worst, wu = "", 2, nil
	for i = 1, units:count() do
		local u = units:item(i)
		local card = find_uicomponent(root, "cards_panel", tostring(u:unique_ui_id()))
		local id = card and card:GetContextObjectId("CcoBattleUnit")
		local hv = id and common.get_context_value("CcoBattleUnit", id, "HealthValue")
		local hm = id and common.get_context_value("CcoBattleUnit", id, "HealthMax")
		local s = 0
		local ms = E.P.models(u)
		for _, m in ipairs(ms) do s = s + mr.read_int32(m, HP) end
		out = out .. " || " .. u:type() .. " men " .. #ms .. "/" .. u:initial_number_of_men() .. " sum " .. s .. " hp "
			.. tostring(hv) .. "/" .. tostring(hm)
		if #ms > 2 and u:unary_hitpoints() < worst then worst, wu = u:unary_hitpoints(), u end
	end
	if wu then
		local ms = E.P.models(wu)
		out = out .. " || NEAR " .. wu:type()
		for k = 1, 3 do
			out = out .. " | man " .. k
			for off = 0xB00, 0xB3C, 4 do out = out .. " " .. off .. "=" .. mr.read_int32(ms[k], off) end
		end
	end
	return out
end)
return tostring(ok) .. " " .. tostring(res)
