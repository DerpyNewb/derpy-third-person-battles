-- The unit panel's health and winds of magic, 2026-10-15 ("should be also health and winds of magic(if wizard) on the
-- unit panel"). For every unit card in the player's army, which CcoBattleUnit expressions answer: hit points, its army's
-- winds pool, and whether it casts. No string library calls; read-only.
local root = core:get_ui_root()
local exprs = {"HitPoints", "HitPointsInitial", "MaxHitPoints", "HitPointsPercent", "HealthPercent",
	"ArmyContext.WindsOfMagicPoolContext.CurrentWind", "ArmyContext.WindsOfMagicPoolContext.MaxWind",
	"ArmyContext.WindsOfMagicPoolContext.ReserveWind", "ArmyContext.WindsOfMagicPoolContext.IsEnabled",
	"IsCaster", "CanCastSpells", "IsSpellcaster", "UnitRecordContext.IsCaster", "AgentSubtypeContext.IsCaster",
	"CharacterContext.AgentSubtypeContext.IsCaster", "IsCharacter", "IsGeneral"}
local out = ""
local units = bm:get_player_army():units()
for i = 1, units:count() do
	local u = units:item(i)
	local card = find_uicomponent(root, "cards_panel", tostring(u:unique_ui_id()))
	local id = card and card:GetContextObjectId("CcoBattleUnit")
	out = out .. " || " .. u:type() .. " men " .. u:number_of_men_alive() .. " hp " .. u:unary_hitpoints()
	if id then
		for _, e in ipairs(exprs) do
			local ok, v = pcall(common.get_context_value, "CcoBattleUnit", id, e)
			if ok and v ~= nil then out = out .. " | " .. e .. "=" .. tostring(v) end
		end
	end
end
local a = bm:get_player_army()
local ok, cur = pcall(function() return a:winds_of_magic_current() end)
local ok2, res = pcall(function() return a:winds_of_magic_reserve() end)
return "army winds " .. tostring(cur) .. " reserve " .. tostring(res) .. out
