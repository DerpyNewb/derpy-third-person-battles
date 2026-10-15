local ok, res = pcall(function()
	return {memreader = _G.memreader_plus ~= nil, tp = _G.DERPY_TP ~= nil, follow = _G.DERPY_FOLLOW ~= nil,
		mp = bm:is_multiplayer(), t = bm:time_elapsed_ms(), tick = bm:model_tick_time_ms()}
end)
if ok then return res end
return "ERR " .. tostring(res)
