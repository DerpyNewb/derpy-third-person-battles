-- memreader: call Windows' GetCursorPos and GetAsyncKeyState through Warhammer3.exe's import table.
-- IAT RVAs from exe_imports.py; each is built from two exact float32 parts. Refuses to call unless
-- both slots point into the system-DLL range (0x7FF...).
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local function iat(lo) return mr.read_pointer(mr.add(mr.add(mr.base, 0x3300000), lo)) end
	local gcp, gaks = iat(0xa2e38), iat(0xa2cc0)
	local r = {gcp = mr.tostring(gcp), gaks = mr.tostring(gaks)}
	local function sysdll(p) local s = mr.tostring(p) return s >= "00007FF000000000" and s < "0000800000000000" end
	if not (sysdll(gcp) and sysdll(gaks)) then r.refused = true return r end
	local buf = mr.alloc(8)
	r.ret = mr.tonumber(mr.call(gcp, "int32(pointer)", buf))
	r.x, r.y = mr.read_int32(buf, 0), mr.read_int32(buf, 4)
	r.mmb = mr.tonumber(mr.call(gaks, "int16(int32)", 4))
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
