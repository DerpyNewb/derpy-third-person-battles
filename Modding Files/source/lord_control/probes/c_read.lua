-- Read back whatever the last probe left in its global table.
local ok, res = pcall(function()
	local P = _G.DERPY_CAM_RATES
	local F = _G.DERPY_CAM_FOLLOW
	local r = {}
	if P then r.rates = {done = P.done, frames = P.frames, elapsed = P.elapsed, max_gap = P.max_gap, pos_changes = P.pos_changes} end
	if F then r.follow = {runs = F.runs, running = F.running, done = F.done, frames = F.frames, elapsed = F.elapsed, moved_off = F.moved_off, max_off = F.max_off, steps = F.steps, span_sum = F.span_sum, errors = F.err} end
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
