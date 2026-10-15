-- Tries CA's PerformAbilityForOwner on the tank's masterful_calibration (BattleAbilityList index 3) through three
-- context paths, reading its recharge and active state after each. Casts a self-buff; harmless. NO string library.
local id = "1001"
local base = "BattleAbilityList.At(3)."
local function read(tag)
	local function g(e) local ok, v = pcall(common.get_context_value, "CcoBattleUnit", id, e) return ok and tostring(v) or "err" end
	return tag .. ": key " .. g(base .. "SetupAbilityContext.RecordKey") .. " recharge " .. g(base .. "RechargeTimeRemainingSecs")
		.. " active " .. g(base .. "IsActive") .. " setup_active " .. g(base .. "SetupAbilityContext.IsActive")
end
local out = {read("before")}
for _, path in ipairs({base .. "SetupAbilityContext.PerformAbilityForOwner", base .. "PerformAbilityForOwner",
	base .. "SetupAbilityContext.PerformAbilityForOwner()"}) do
	local ok, err = pcall(common.call_context_command, "CcoBattleUnit", id, path)
	out[#out + 1] = path .. " -> " .. (ok and "ok" or tostring(err))
	out[#out + 1] = read("after")
end
return out
