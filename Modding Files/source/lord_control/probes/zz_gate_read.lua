-- read-only: what mr.read gives for the gate site. No string library calls.
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local at = mr.add(mr.add(mr.base, 0x3080000), 0x7388)
	local s = mr.read(at, 0, 2)
	return {t = type(s), n = type(s) == "string" and #s or -1, b0 = mr.read_uint8(at, 0), b1 = mr.read_uint8(at, 1), info = mr.patch_info(at) and "claimed" or "free"}
end)
return ok and res or "ERR " .. tostring(res)
