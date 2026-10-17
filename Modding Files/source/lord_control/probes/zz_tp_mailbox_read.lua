-- zz_tp_mailbox.lua's result
local T = _G.TP_MB
if not T then return "not run" end
local function n(v) if v == nil then return "-" end return tostring(math.floor(v * 10) / 10) end
return (T.done and "done" or "running") .. " (" .. tostring(T.why_end) .. ")" .. (T.err and (" ERR " .. T.err) or "")
	.. " | mailbox " .. tostring(T.mailbox) .. ", cave " .. tostring(T.cave) .. ", its block ours " .. tostring(T.block_in_cave)
	.. ", block " .. tostring(T.block) .. ", horse " .. tostring(T.horse) .. ", posts for the body " .. tostring(T.man_is_body)
	.. " | walk " .. n(T.walk_m) .. " m (met " .. n(T.walk_met) .. ")"
	.. " | hold drift " .. n(T.hold_m) .. " m (met " .. n(T.hold_met) .. ")"
	.. " | melee on " .. tostring(T.enemy) .. " at " .. n(T.enemy_m) .. " m: carried " .. n(T.melee_m) .. " m, net " .. n(T.melee_net)
	.. " m, met " .. n(T.melee_met) .. ", stops " .. n(T.melee_stops)
	.. " | " .. T.log
