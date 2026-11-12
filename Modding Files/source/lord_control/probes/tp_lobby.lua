-- Custom battle lobby over the bridge: one call sets both slots' factions and units, and the battle type.
-- LOBBY.setup{me = faction, mine = {units}, ai = faction, theirs = {units}, siege = bool}
local L = {}
_G.LOBBY = L
local R = "CustomBattleLobbyContext."
local function cmd(s) return common.call_context_command("CcoFrontendRoot", "", R .. s) end
local function get(s) return common.get_context_value("CcoFrontendRoot", "", R .. s) end
L.cmd, L.get = cmd, get
local ME = "LocalPlayerSlotContext"
local AI = "TeamList.At(0).PlayerSlotList.At(0)"
local function fill(slot, faction, units)
	cmd(slot .. '.SetFaction(DatabaseRecordContext("CcoFactionRecord", "' .. faction .. '"))')
	cmd(slot .. ".ClearUnits")
	for _, u in ipairs(units) do
		cmd(slot .. '.RecruitUnit(DatabaseRecordContext("CcoMainUnitRecord", "' .. u .. '").CustomBattlePermissionsContext(DatabaseRecordContext("CcoFactionRecord", "' .. faction .. '")), true)')
	end
	local n = get(slot .. ".UnitList.Size") or 0
	local names = {}
	for i = 0, n - 1 do names[#names + 1] = get(slot .. ".UnitList.At(" .. i .. ").Name") or "?" end
	return names
end
function L.setup(t)
	local out = {}
	if t.type then cmd('SettingsContext.SetBattleTypeRecordContext(DatabaseRecordContext("CcoBattleTypeRecord", "' .. t.type .. '"))') end
	out.mine = fill(ME, t.me, t.mine)
	out.theirs = fill(AI, t.ai, t.theirs)
	out.type = get("SettingsContext.BattleTypeRecordContext.Key")
	return out
end
return "lobby loaded"
