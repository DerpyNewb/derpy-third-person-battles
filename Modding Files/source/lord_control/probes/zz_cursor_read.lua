local ok, res = pcall(function()
	local T = _G.DERPY_CURSOR
	local flags, nulls = 0, 0
	for _, f in ipairs(T.flags) do if f == 1 then flags = flags + 1 end end
	for _, n in ipairs(T.null_cursor) do nulls = nulls + n end
	return {route = T.route, done = T.done, gave_up = T.gave_up, focused_s = T.focused_s, frames = T.frames,
		samples = #T.flags, showing_flag = flags, null_cursor = nulls, after_hide = T.after_hide, after_show = T.after_show}
end)
if ok then return res end
return "ERR " .. tostring(res)
