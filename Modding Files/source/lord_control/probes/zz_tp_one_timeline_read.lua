-- Reads zz_tp_one_timeline.lua's record. No string library calls.
local ok, res = pcall(function()
	local T = _G.TP_OT
	if not T then return "no test" end
	local out = {head = (T.done and ("done (" .. tostring(T.why) .. ")") or "running") .. " " .. T.script .. " " .. T.type
		.. (T.gate and (" gate " .. tostring(T.gated) .. " ungated " .. tostring(T.ungated)) or "") .. " err " .. tostring(T.err)}
	local function list(name, t) local s = "" for _, x in ipairs(t) do s = s .. x .. " | " end out[name] = s end
	list("clicks", T.clicks)
	list("got", T.got or {})
	list("sent", T.sent)
	list("starts", T.starts)
	list("speeds", T.speeds)
	local o = ""
	for k, n in pairs(T.orders) do o = o .. "w" .. k .. " x" .. n .. " " end
	out.orders = o
	for i, r in ipairs(T.rows) do out["r" .. (i < 10 and "00" or i < 100 and "0" or "") .. i] = r end
	return out
end)
return ok and res or "ERR " .. tostring(res)
