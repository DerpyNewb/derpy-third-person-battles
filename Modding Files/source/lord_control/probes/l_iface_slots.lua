-- memreader pass 2: the first 0x40 bytes of the general's and the camera's script-interface
-- objects, as 8-byte slots. +0x10 held 0x20 for both, so the game object is somewhere else.
local ok, res = pcall(function()
	local mr = _G.memreader_plus
	local lord
	local units = bm:get_player_army():units()
	for i = 1, units:count() do
		if units:item(i):is_commanding_unit() then lord = units:item(i) end
	end
	local cam = bm:camera()
	local r = {lord = {}, cam = {}}
	local a, c = mr.ud_topointer(lord), mr.ud_topointer(cam)
	for k = 0, 7 do
		r.lord[k + 1] = mr.tostring(mr.read_pointer(a, k * 8))
		r.cam[k + 1] = mr.tostring(mr.read_pointer(c, k * 8))
	end
	return r
end)
if ok then return res end
return "ERR " .. tostring(res)
