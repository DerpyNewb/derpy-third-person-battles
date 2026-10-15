-- Reads back zz_tp_fly_click.lua's log as one string. No string library calls.
local T = _G.TP_FLY
if not T then return "no probe ran" end
local ok, s = pcall(function()
	local out_s = "ended " .. tostring(T.ended) .. " n " .. tostring(T.n) .. " error " .. tostring(T.error)
	for i = 1, #T.log do out_s = out_s .. " | " .. T.log[i] end
	return out_s
end)
return ok and s or ("read failed " .. tostring(s))
