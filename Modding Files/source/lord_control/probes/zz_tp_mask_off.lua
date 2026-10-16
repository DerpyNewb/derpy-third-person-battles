-- Undo probes/zz_tp_mask_experiment.lua if it is on: the men it disarmed get their own fragment back. Not shipped.
local ok, res = pcall(function()
	local X = _G.TPMASK
	if not X then return "mask experiment not on" end
	X.unwrap()
	_G.TPMASK = nil
	return "mask experiment off, " .. tostring(X.n_copies) .. " copies kept"
end)
return ok and res or "ERR " .. tostring(res)
