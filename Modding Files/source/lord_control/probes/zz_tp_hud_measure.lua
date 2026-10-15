-- HUD measurement (plan 2 Task 1): the unit context under cinematic UI. Read only. NO string library calls.
local E = _G.DERPY_TP
if not (E and E.F and E.F.on) then return "turn third person on first (F2)" end
local u = E.F.unit
local root = core:get_ui_root()
local out = {uid = u:unique_ui_id(), utype = u:type()}
out.sw, out.sh = core:get_screen_resolution()
out.rw, out.rh = root:Dimensions()
local card = find_uicomponent(root, "cards_panel", tostring(u:unique_ui_id()))
out.card = card and true or false
local id
if card then
	local ok, r = pcall(function() return card:GetContextObjectId("CcoBattleUnit") end)
	out.card_id_ok, id = ok, r
	out.card_id = tostring(r)
end
local function read(expr, with)
	local ok, r = pcall(function() return common.get_context_value("CcoBattleUnit", with, expr) end)
	return ok and tostring(r) or ("ERR " .. tostring(r))
end
local ids = {card = id, uid = tostring(u:unique_ui_id())}
for tag, with in pairs(ids) do
	if with then
		out[tag .. "_icon"] = read("IconPath", with)
		out[tag .. "_name"] = read("Name", with)
		out[tag .. "_reload"] = read("ReloadPercentMax", with)
		out[tag .. "_n"] = read("SpecialAbilitiesList.Size", with)
		out[tag .. "_key0"] = read("SpecialAbilitiesList.At(0).SetupAbilityContext.RecordKey", with)
		out[tag .. "_icon0"] = read("SpecialAbilitiesList.At(0).SetupAbilityContext.IconPath", with)
		out[tag .. "_secs0"] = read("SpecialAbilitiesList.At(0).RechargeTimeRemainingSecs", with)
	end
end
local keys = u:owned_non_passive_special_abilities() or {}
out.owned = table.concat(keys, ",")
return out
